#!/usr/bin/env python3
"""Read-only, event-time audit of local Codex and Claude JSONL sessions.

Token totals are observed usage, not cost or a measure of productive work. Codex
modern response records take precedence over legacy cumulative counters within
each turn. A legacy counter reset starts a new sequence at the new value.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any, Iterator


FIELDS = ("input", "cached", "cache_write", "output", "reasoning", "total", "uncached")
LARGE_OUTPUT_CHARS = 20_000
TRUNCATION_MARKERS = ("truncated", "output limit", "chars truncated")


def timestamp(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed.astimezone(timezone.utc) if parsed.tzinfo else None
    except ValueError:
        return None


def number(value: Any) -> int:
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else 0


def codex_usage(raw: dict[str, Any]) -> dict[str, int]:
    input_tokens = number(raw.get("input_tokens"))
    cached = number(raw.get("cached_input_tokens"))
    cache_write = number(raw.get("cache_write_input_tokens"))
    output = number(raw.get("output_tokens"))
    return {"input": input_tokens, "cached": cached, "cache_write": cache_write,
            "output": output, "reasoning": number(raw.get("reasoning_output_tokens")),
            "total": number(raw.get("total_tokens")) or input_tokens + output,
            "uncached": max(0, input_tokens - cached - cache_write)}


def claude_usage(raw: dict[str, Any]) -> dict[str, int]:
    uncached = number(raw.get("input_tokens"))
    cached = number(raw.get("cache_read_input_tokens"))
    cache_write = number(raw.get("cache_creation_input_tokens"))
    output = number(raw.get("output_tokens"))
    details = raw.get("output_tokens_details") or {}
    reasoning = number(details.get("thinking_tokens")) if isinstance(details, dict) else 0
    return {"input": uncached + cached + cache_write, "cached": cached,
            "cache_write": cache_write, "output": output, "reasoning": reasoning,
            "total": uncached + cached + cache_write + output, "uncached": uncached}


def add_usage(target: dict[str, int], usage: dict[str, int]) -> None:
    for field in FIELDS:
        target[field] += usage[field]


def blank_usage() -> dict[str, int]:
    return {field: 0 for field in FIELDS}


def project_for(cwd: str) -> str:
    parts = Path(cwd).parts if cwd else ()
    if "Health" in parts:
        return "Health"
    if "worktrees" in parts and "Health" in cwd:
        return "Health"
    return parts[-1] if parts else "unknown"


def codex_role(payload: dict[str, Any]) -> str:
    source = payload.get("source")
    thread_source = payload.get("thread_source")
    spawn = source.get("subagent") if isinstance(source, dict) else None
    if isinstance(spawn, dict):
        spawn = spawn.get("thread_spawn") or spawn
    else:
        spawn = {}
    path = str(payload.get("agent_path") or spawn.get("agent_path") or "")
    role = str(spawn.get("agent_role") or "").lower()
    if "guardian" in path.lower() or "guardian" in role:
        return "guardian"
    if payload.get("parent_thread_id") or spawn.get("parent_thread_id") or thread_source == "subagent":
        return "subagent"
    return "root"


def jsonl_lines(path: Path) -> Iterator[tuple[int, str]]:
    if path.suffix == ".zst":
        process = subprocess.Popen(["zstd", "-dc", "--", str(path)], stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace")
        assert process.stdout is not None
        try:
            yield from enumerate(process.stdout, 1)
        finally:
            process.stdout.close()
        if process.wait() != 0:
            raise OSError("zstd failed to read compressed session")
    else:
        with path.open(encoding="utf-8", errors="replace") as source:
            yield from enumerate(source, 1)


def session_row(provider: str, path: Path) -> dict[str, Any]:
    return {"provider": provider, "session_id": path.stem.replace(".jsonl", ""),
            "source": str(path), "first_line": None, "model": "unknown", "project": "unknown",
            "role": "unknown", "tokens": blank_usage(), "events": Counter(),
            "usage_breakdown": {dimension: {} for dimension in ("provider", "model", "project", "role")},
            "tool_calls": Counter(), "tool_output_proxy": {"count": 0, "bytes": 0,
            "large_count": 0, "truncation_marker_count": 0}, "usage_records": 0}


def tool_output(row: dict[str, Any], value: Any) -> None:
    content = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    proxy = row["tool_output_proxy"]
    proxy["count"] += 1
    proxy["bytes"] += len(content.encode("utf-8"))
    proxy["large_count"] += len(content) > LARGE_OUTPUT_CHARS
    proxy["truncation_marker_count"] += any(marker in content.lower() for marker in TRUNCATION_MARKERS)


def in_window(when: datetime | None, start: datetime, end: datetime) -> bool:
    return when is not None and start <= when < end


def audit(start: datetime, end: datetime, codex_root: Path, claude_root: Path) -> dict[str, Any]:
    paths = [("codex", p) for folder in (codex_root / "sessions", codex_root / "archived_sessions")
             if folder.exists() for p in folder.rglob("*.jsonl*") if p.name.endswith((".jsonl", ".jsonl.zst"))]
    folder = claude_root / "projects"
    paths += [("claude", p) for p in folder.rglob("*.jsonl")] if folder.exists() else []
    paths.sort(key=lambda item: str(item[1]))
    coverage: dict[str, Any] = {"files_discovered": len(paths), "files_scanned": 0,
                                "read_errors": [], "malformed_lines": 0,
                                "events_without_timestamp": 0, "usage_events_without_timestamp": 0,
                                "usage_without_supported_fields": 0, "usage_missing_response_id": 0,
                                "modern_usage_records": 0, "legacy_usage_records": 0,
                                "claude_usage_messages": 0}
    rows: list[dict[str, Any]] = []
    codex_responses: dict[str, tuple[datetime, dict[str, Any], dict[str, int], int, dict[str, str], str]] = {}
    claude_messages: dict[str, tuple[datetime, dict[str, Any], dict[str, int], int, dict[str, str]]] = {}
    legacy_records: list[tuple[datetime, dict[str, Any], dict[str, int], int, dict[str, str], str, tuple[int, ...], str]] = []
    legacy_baselines: dict[str, tuple[datetime, int, dict[str, int]]] = {}
    modern_turns: set[tuple[str, str]] = set()
    usage_items: list[tuple[dict[str, Any], dict[str, int], dict[str, str]]] = []
    seen_legacy: set[tuple[str, str, datetime, tuple[int, ...], str]] = set()
    earlier_codex_ids: set[str] = set()
    earlier_claude_ids: set[str] = set()
    late_claude_ids: dict[Path, set[str]] = defaultdict(set)
    seen_interruptions: set[tuple[str, str]] = set()
    seen_events: set[tuple[str, str, str]] = set()
    seen_tools: set[tuple[str, str]] = set()
    seen_tool_outputs: set[tuple[str, str]] = set()
    for provider, path in paths:
        row = session_row(provider, path)
        rows.append(row)
        current_turn = "unknown"
        session_in_window = False
        try:
            for line_no, line in jsonl_lines(path):
                try:
                    event = json.loads(line)
                except (ValueError, TypeError):
                    coverage["malformed_lines"] += 1
                    continue
                if not isinstance(event, dict):
                    coverage["malformed_lines"] += 1
                    continue
                when = timestamp(event.get("timestamp"))
                if when is None:
                    coverage["events_without_timestamp"] += 1
                    if event.get("type") == "token_usage_record" or (
                        event.get("type") == "event_msg" and isinstance(event.get("payload"), dict)
                        and event["payload"].get("type") == "token_count") or (
                        provider == "claude" and event.get("type") == "assistant"
                        and isinstance(event.get("message"), dict) and "usage" in event["message"]):
                        coverage["usage_events_without_timestamp"] += 1
                    continue
                current = in_window(when, start, end)
                session_in_window |= current
                if current and row["first_line"] is None:
                    row["first_line"] = line_no
                kind = event.get("type")
                payload = event.get("payload") or {}
                if not isinstance(payload, dict):
                    payload = {}
                if provider == "codex":
                    if kind == "session_meta":
                        row["session_id"] = str(payload.get("id") or payload.get("session_id") or row["session_id"])
                        row["project"] = project_for(str(payload.get("cwd") or ""))
                        row["role"] = codex_role(payload)
                    elif kind == "turn_context":
                        row["model"] = str(payload.get("model") or row["model"])
                        row["project"] = project_for(str(payload.get("cwd") or ""))
                        current_turn = str(payload.get("turn_id") or current_turn)
                    elif kind == "token_usage_record":
                        usage = payload.get("usage")
                        response_id = payload.get("response_id")
                        turn_id = str(payload.get("turn_id") or current_turn)
                        if not isinstance(usage, dict) or not any(k in usage for k in ("input_tokens", "output_tokens")):
                            coverage["usage_without_supported_fields"] += 1
                        elif response_id:
                            modern_turns.add((row["session_id"], turn_id))
                            if when < start:
                                earlier_codex_ids.add(response_id)
                                codex_responses.pop(response_id, None)
                            elif current and response_id not in earlier_codex_ids:
                                previous = codex_responses.get(response_id)
                                if previous is None or when < previous[0]:
                                    metadata = {key: row[key] for key in ("provider", "model", "project", "role")}
                                    codex_responses[response_id] = (when, row, codex_usage(usage), line_no, metadata, turn_id)
                        else:
                            coverage["usage_missing_response_id"] += 1
                    elif kind == "event_msg":
                        subtype = payload.get("type")
                        if subtype == "token_count":
                            info = payload.get("info") or {}
                            counter = info.get("total_token_usage") if isinstance(info, dict) else None
                            if isinstance(counter, dict):
                                observed = codex_usage(counter)
                                metadata = {key: row[key] for key in ("provider", "model", "project", "role")}
                                signature = tuple(observed[field] for field in FIELDS)
                                if when < start:
                                    key = row["session_id"]
                                    previous = legacy_baselines.get(key)
                                    if previous is None or (when, line_no) > previous[:2]:
                                        legacy_baselines[key] = (when, line_no, observed)
                                elif current:
                                    event_id = str(event.get("uuid") or "")
                                    legacy_records.append((when, row, observed, line_no, metadata,
                                                           current_turn, signature, event_id))
                        elif subtype == "task_started":
                            current_turn = str(payload.get("turn_id") or current_turn)
                            attribution = payload.get("turn_attribution") or {}
                            if isinstance(attribution, dict) and attribution.get("turn_trigger") == "guardian_review":
                                row["role"] = "guardian"
                        if current and subtype in ("task_started", "task_complete", "turn_aborted"):
                            if subtype == "turn_aborted":
                                turn_id = str(payload.get("turn_id") or payload.get("root_turn_id") or f"{path}:{line_no}")
                                identity = (row["session_id"], turn_id)
                                if identity not in seen_interruptions:
                                    seen_interruptions.add(identity)
                                    row["events"][subtype] += 1
                                    reason = str(payload.get("reason") or "unspecified")
                                    row["events"][f"turn_aborted_reason:{reason}"] += 1
                            else:
                                identity = (row["session_id"], subtype, str(payload.get("turn_id") or f"{path}:{line_no}"))
                                if identity not in seen_events:
                                    seen_events.add(identity)
                                    row["events"][subtype] += 1
                    elif kind == "compacted" and current:
                        identity = (row["session_id"], "compacted", str(payload.get("turn_id") or event.get("ordinal") or line_no))
                        if identity not in seen_events:
                            seen_events.add(identity)
                            row["events"]["compacted"] += 1
                    elif kind == "response_item" and current:
                        subtype = payload.get("type")
                        if subtype in ("function_call", "custom_tool_call"):
                            identity = (row["session_id"], str(payload.get("call_id") or payload.get("id") or f"{path}:{line_no}"))
                            if identity not in seen_tools:
                                seen_tools.add(identity)
                                row["tool_calls"][str(payload.get("name") or "unknown")] += 1
                        elif subtype in ("function_call_output", "custom_tool_call_output"):
                            identity = (row["session_id"], str(payload.get("call_id") or payload.get("id") or f"{path}:{line_no}"))
                            if identity not in seen_tool_outputs:
                                seen_tool_outputs.add(identity)
                                tool_output(row, payload.get("output") or "")
                else:
                    cwd = str(event.get("cwd") or "")
                    if cwd:
                        row["project"] = project_for(cwd)
                    row["session_id"] = str(event.get("sessionId") or event.get("session_id") or row["session_id"])
                    row["role"] = "subagent" if event.get("isSidechain") or "subagents" in path.parts else "root"
                    if kind == "assistant":
                        message = event.get("message") or {}
                        if not isinstance(message, dict):
                            continue
                        row["model"] = str(message.get("model") or row["model"])
                        usage = message.get("usage")
                        if isinstance(usage, dict):
                            key = str(message.get("id") or event.get("uuid") or f"{path}:{line_no}")
                            if not any(k in usage for k in ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")):
                                coverage["usage_without_supported_fields"] += 1
                                continue
                            if when < start:
                                earlier_claude_ids.add(key)
                                claude_messages.pop(key, None)
                            elif key not in earlier_claude_ids:
                                if current or key in claude_messages:
                                    normalized = claude_usage(usage)
                                    metadata = {name: row[name] for name in ("provider", "model", "project", "role")}
                                    existing = claude_messages.get(key)
                                    if existing is None:
                                        claude_messages[key] = (when, row, normalized, line_no, metadata)
                                    else:
                                        earliest, owner, prior, first_line, prior_metadata = existing
                                        combined = {field: max(prior[field], normalized[field]) for field in FIELDS}
                                        combined["input"] = combined["uncached"] + combined["cached"] + combined["cache_write"]
                                        combined["total"] = combined["input"] + combined["output"]
                                        claude_messages[key] = (min(earliest, when), owner if earliest <= when else row,
                                                                combined, first_line if earliest <= when else line_no,
                                                                prior_metadata if earliest <= when else metadata)
                                elif when >= end:
                                    late_claude_ids[path].add(key)
                        if current:
                            content = message.get("content") or []
                            for block in content if isinstance(content, list) else []:
                                if isinstance(block, dict) and block.get("type") == "tool_use":
                                    identity = (row["session_id"], str(block.get("id") or f"{path}:{line_no}"))
                                    if identity not in seen_tools:
                                        seen_tools.add(identity)
                                        row["tool_calls"][str(block.get("name") or "unknown")] += 1
                    elif current and kind == "user":
                        message = event.get("message") or {}
                        content = message.get("content") if isinstance(message, dict) else None
                        texts = [content] if isinstance(content, str) else [block.get("text") for block in content
                                if isinstance(block, dict) and block.get("type") == "text"] if isinstance(content, list) else []
                        if any(isinstance(text, str) and text.startswith("[Request interrupted by user") for text in texts):
                            identity = (row["session_id"], "request_interrupted_by_user", str(event.get("uuid") or f"{path}:{line_no}"))
                            if identity not in seen_events:
                                seen_events.add(identity)
                                row["events"]["request_interrupted_by_user"] += 1
                        elif isinstance(content, list):
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "tool_result":
                                    identity = (row["session_id"], str(block.get("tool_use_id") or f"{path}:{line_no}"))
                                    if identity not in seen_tool_outputs:
                                        seen_tool_outputs.add(identity)
                                        tool_output(row, block.get("content") or "")
                    elif current and kind == "system":
                        subtype = str(event.get("subtype") or "")
                        if subtype in ("api_error", "model_refusal", "model_refusal_no_fallback", "compact_boundary"):
                            identity = (row["session_id"], subtype, str(event.get("uuid") or f"{path}:{line_no}"))
                            if identity not in seen_events:
                                seen_events.add(identity)
                                row["events"][subtype] += 1
        except (OSError, UnicodeError) as error:
            coverage["read_errors"].append({"source": str(path), "error": str(error)[:200]})
        else:
            coverage["files_scanned"] += 1
        row["in_window"] = session_in_window
    if claude_messages:
        # A later partial block can be scanned before its in-window archive copy.
        eligible_ids = claude_messages.keys()
        for path, ids in late_claude_ids.items():
            if ids.isdisjoint(eligible_ids):
                continue
            try:
                for _line_no, line in jsonl_lines(path):
                    try:
                        event = json.loads(line)
                    except (ValueError, TypeError):
                        continue
                    if not isinstance(event, dict) or event.get("type") != "assistant":
                        continue
                    when = timestamp(event.get("timestamp"))
                    if when is None or when < end:
                        continue
                    message = event.get("message")
                    if not isinstance(message, dict) or not isinstance(message.get("usage"), dict):
                        continue
                    key = str(message.get("id") or event.get("uuid") or "")
                    existing = claude_messages.get(key)
                    if existing is None:
                        continue
                    earliest, owner, prior, first_line, metadata = existing
                    normalized = claude_usage(message["usage"])
                    combined = {field: max(prior[field], normalized[field]) for field in FIELDS}
                    combined["input"] = combined["uncached"] + combined["cached"] + combined["cache_write"]
                    combined["total"] = combined["input"] + combined["output"]
                    claude_messages[key] = (earliest, owner, combined, first_line, metadata)
            except (OSError, UnicodeError) as error:
                coverage["read_errors"].append({"source": str(path), "error": str(error)[:200]})
    for when, row, usage, line_no, metadata, _turn_id in codex_responses.values():
        if in_window(when, start, end):
            add_usage(row["tokens"], usage)
            usage_items.append((row, usage, metadata))
            coverage["modern_usage_records"] += 1
            row["usage_records"] += 1
            row["first_line"] = row["first_line"] or line_no
    previous_legacy: dict[str, dict[str, int]] = {
        session_id: baseline[2] for session_id, baseline in legacy_baselines.items()
    }
    for when, row, observed, line_no, metadata, turn_id, signature, event_id in sorted(
        legacy_records, key=lambda item: (item[1]["session_id"], item[0], item[3])
    ):
        identity = (row["session_id"], turn_id, when, signature, event_id)
        if identity in seen_legacy:
            continue
        seen_legacy.add(identity)
        previous = previous_legacy.get(row["session_id"])
        if previous is None or observed["total"] < previous["total"]:
            usage = observed
        else:
            usage = {field: max(0, observed[field] - previous[field]) for field in FIELDS}
        previous_legacy[row["session_id"]] = observed
        if in_window(when, start, end) and usage["total"] and (row["session_id"], turn_id) not in modern_turns:
            add_usage(row["tokens"], usage)
            usage_items.append((row, usage, metadata))
            coverage["legacy_usage_records"] += 1
            row["usage_records"] += 1
            row["first_line"] = row["first_line"] or line_no
    for when, row, usage, line_no, metadata in claude_messages.values():
        if in_window(when, start, end):
            add_usage(row["tokens"], usage)
            usage_items.append((row, usage, metadata))
            coverage["claude_usage_messages"] += 1
            row["usage_records"] += 1
            row["first_line"] = row["first_line"] or line_no
    groups: dict[str, dict[str, dict[str, int]]] = {dimension: defaultdict(blank_usage)
                                                    for dimension in ("provider", "model", "project", "role")}
    event_counts: Counter[str] = Counter()
    calls: Counter[str] = Counter()
    output_proxy = {"count": 0, "bytes": 0, "large_count": 0, "truncation_marker_count": 0}
    for row, usage, metadata in usage_items:
        for dimension in groups:
            add_usage(groups[dimension][metadata[dimension]], usage)
            bucket = row["usage_breakdown"][dimension].setdefault(metadata[dimension], blank_usage())
            add_usage(bucket, usage)
    for row in rows:
        event_counts.update(row["events"])
        calls.update(row["tool_calls"])
        for key in output_proxy:
            output_proxy[key] += row["tool_output_proxy"][key]
    totals = blank_usage()
    for usage in groups["provider"].values():
        add_usage(totals, usage)
    def compact_row(row: dict[str, Any]) -> dict[str, Any]:
        return {**row, "events": dict(row["events"]), "tool_calls": dict(row["tool_calls"]),
                "last_observed_model": row["model"], "last_observed_project": row["project"],
                "last_observed_role": row["role"]}
    sessions = {(row["provider"], row["session_id"]) for row in rows if row["in_window"]}
    known_sessions = {(row["provider"], row["session_id"]) for row in rows if row["in_window"] and row["usage_records"]}
    coverage["sessions_in_window"] = len(sessions)
    coverage["sessions_by_provider"] = dict(Counter(provider for provider, _ in sessions))
    coverage["sessions_with_known_usage"] = len(known_sessions)
    coverage["sessions_without_known_usage"] = coverage["sessions_in_window"] - coverage["sessions_with_known_usage"]
    return {"window": {"start": start.isoformat(), "end_exclusive": end.isoformat()},
            "coverage": coverage, "tokens": totals,
            "metric_definitions": {"uncached": "input excluding cached reads and cache writes; Claude input includes all three categories",
                                   "reasoning": "subset of output, not additional tokens",
                                   "session_model_project_role": "last observed metadata; use usage_breakdown for token attribution",
                                   "tool_output_proxy": "UTF-8 bytes of serialized locally recorded output, including image payloads"},
            "groups": {dimension: dict(sorted(values.items())) for dimension, values in groups.items()},
            "event_counts": dict(event_counts), "tool_calls": dict(calls),
            "tool_output_proxy": output_proxy,
            "sessions": [compact_row(row) for row in rows if row["in_window"]],
            "top_sessions": [compact_row(row) for row in sorted(rows, key=lambda item: item["tokens"]["total"], reverse=True)[:15]
                             if row["usage_records"] or row["events"]]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", required=True, help="timezone-aware ISO timestamp, inclusive")
    parser.add_argument("--end", required=True, help="timezone-aware ISO timestamp, exclusive")
    parser.add_argument("--codex-root", type=Path, default=Path.home() / ".codex")
    parser.add_argument("--claude-root", type=Path, default=Path.home() / ".claude")
    parser.add_argument("--output", type=Path, help="write JSON to this local path")
    arguments = parser.parse_args()
    start, end = timestamp(arguments.start), timestamp(arguments.end)
    if start is None or end is None or start >= end:
        parser.error("--start and --end must be timezone-aware ISO timestamps with start < end")
    result = audit(start, end, arguments.codex_root, arguments.claude_root)
    rendered = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=arguments.output.parent,
                                             prefix=".session-audit-", suffix=".tmp", delete=False) as output:
                temporary = Path(output.name)
                os.fchmod(output.fileno(), 0o600)
                output.write(rendered)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, arguments.output)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
