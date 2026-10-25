import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "audit-agent-sessions.py"
SPEC = importlib.util.spec_from_file_location("audit_agent_sessions", SCRIPT)
audit_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit_module)


def write_lines(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def codex_event(time, kind, payload):
    return {"timestamp": time, "type": kind, "payload": payload}


def claude_event(time, kind, message=None, **extra):
    return {"timestamp": time, "type": kind, "message": message or {}, **extra}


class AuditAgentSessionsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.codex = self.root / "codex"
        self.claude = self.root / "claude"
        self.start = audit_module.timestamp("2026-10-01T00:00:00Z")
        self.end = audit_module.timestamp("2026-10-22T00:00:00Z")

    def audit(self):
        return audit_module.audit(self.start, self.end, self.codex, self.claude)

    def test_modern_codex_usage_supersedes_legacy_and_deduplicates_fork(self):
        usage = {"input_tokens": 100, "cached_input_tokens": 30,
                 "cache_write_input_tokens": 10, "output_tokens": 20,
                 "reasoning_output_tokens": 5, "total_tokens": 120}
        path = self.codex / "sessions" / "one.jsonl"
        write_lines(path, [
            codex_event("2026-10-03T00:00:00Z", "session_meta", {"id": "one", "cwd": "/work/Health"}),
            codex_event("2026-10-03T00:00:00Z", "turn_context", {"model": "gpt", "cwd": "/work/Health"}),
            codex_event("2026-10-03T00:00:01Z", "token_usage_record", {"response_id": "resp_1", "usage": usage}),
            codex_event("2026-10-03T00:00:02Z", "event_msg", {"type": "token_count", "info": {"total_token_usage": usage}}),
        ])
        write_lines(self.codex / "archived_sessions" / "two.jsonl", [
            codex_event("2026-10-04T00:00:00Z", "token_usage_record", {"response_id": "resp_1", "usage": usage})
        ])
        result = self.audit()
        self.assertEqual(result["tokens"], {"input": 100, "cached": 30, "cache_write": 10,
                                            "output": 20, "reasoning": 5, "total": 120, "uncached": 60})
        self.assertEqual(result["groups"]["project"]["Health"]["total"], 120)

    def test_modern_turn_precedence_crosses_window_boundaries(self):
        for modern_time in ("2026-09-30T23:59:59Z", "2026-10-22T00:00:00Z"):
            with self.subTest(modern_time=modern_time):
                usage = {"input_tokens": 10, "total_tokens": 10}
                rows = [
                    codex_event("2026-09-30T00:00:00Z", "session_meta", {"id": "boundary"}),
                    codex_event("2026-09-30T00:00:00Z", "turn_context", {"turn_id": "same-turn"}),
                    codex_event(modern_time, "token_usage_record", {
                        "response_id": "boundary-response", "turn_id": "same-turn", "usage": usage}),
                    codex_event("2026-10-02T00:00:00Z", "event_msg", {
                        "type": "token_count", "info": {"total_token_usage": usage}}),
                ]
                write_lines(self.codex / "sessions" / "boundary.jsonl",
                            sorted(rows, key=lambda row: row["timestamp"]))
                result = self.audit()
                self.assertEqual(result["tokens"]["total"], 0)
                self.assertEqual(result["coverage"]["legacy_usage_records"], 0)

    def test_legacy_deltas_use_prewindow_baseline_and_ignore_repeats(self):
        def counter(time, value):
            return codex_event(time, "event_msg", {"type": "token_count", "info": {
                "total_token_usage": {"input_tokens": value, "output_tokens": value // 10,
                                      "total_tokens": value + value // 10}}})
        write_lines(self.codex / "sessions" / "legacy.jsonl", [
            counter("2026-09-30T00:00:00Z", 100),
            counter("2026-10-02T00:00:00Z", 120),
            counter("2026-10-02T00:00:01Z", 120),
            counter("2026-10-03T00:00:00Z", 10),
        ])
        result = self.audit()
        self.assertEqual(result["tokens"]["input"], 30)
        self.assertEqual(result["tokens"]["output"], 3)
        self.assertEqual(result["tokens"]["total"], 33)

    def test_claude_repeated_partial_blocks_use_max_fields_and_cache_once(self):
        path = self.claude / "projects" / "Health" / "session.jsonl"
        first = {"input_tokens": 2, "cache_creation_input_tokens": 40,
                 "cache_read_input_tokens": 20, "output_tokens": 4}
        second = {**first, "output_tokens": 9, "output_tokens_details": {"thinking_tokens": 3},
                  "iterations": [{"input_tokens": 1000}]}
        write_lines(path, [
            claude_event("2026-10-05T00:00:00Z", "assistant", {"id": "msg_1", "model": "claude", "usage": first},
                         cwd="/work/Health", sessionId="session"),
            claude_event("2026-10-05T00:00:01Z", "assistant", {"id": "msg_1", "model": "claude", "usage": second},
                         cwd="/work/Health", sessionId="session"),
            claude_event("2026-10-05T00:00:02Z", "user", {"content": "[Request interrupted by user]"}),
        ])
        result = self.audit()
        self.assertEqual(result["tokens"], {"input": 62, "cached": 20, "cache_write": 40,
                                            "output": 9, "reasoning": 3, "total": 71, "uncached": 2})
        self.assertEqual(result["event_counts"]["request_interrupted_by_user"], 1)

    def test_malformed_and_missing_usage_remain_unknown(self):
        path = self.codex / "sessions" / "bad.jsonl"
        write_lines(path, [codex_event("2026-10-03T00:00:00Z", "token_usage_record",
                                       {"response_id": "r", "usage": {"other": 7}})])
        with path.open("a") as handle:
            handle.write("not json\n")
        result = self.audit()
        self.assertEqual(result["tokens"]["total"], 0)
        self.assertEqual(result["coverage"]["malformed_lines"], 1)
        self.assertEqual(result["coverage"]["usage_without_supported_fields"], 1)

    def test_interruptions_are_unique_by_turn_and_separate_from_completion(self):
        path = self.codex / "sessions" / "turn.jsonl"
        aborted = {"type": "turn_aborted", "turn_id": "turn_a", "reason": "user"}
        write_lines(path, [
            codex_event("2026-10-03T00:00:00Z", "event_msg", aborted),
            codex_event("2026-10-03T00:00:01Z", "event_msg", aborted),
            codex_event("2026-10-03T00:00:02Z", "event_msg", {"type": "task_complete", "turn_id": "turn_b"}),
        ])
        result = self.audit()
        self.assertEqual(result["event_counts"]["turn_aborted"], 1)
        self.assertEqual(result["event_counts"]["turn_aborted_reason:user"], 1)
        self.assertEqual(result["event_counts"]["task_complete"], 1)

    def test_mixed_codex_turns_keep_legacy_only_for_turn_without_modern_usage(self):
        def legacy(time, total):
            return codex_event(time, "event_msg", {"type": "token_count", "info": {
                "total_token_usage": {"input_tokens": total, "output_tokens": 0, "total_tokens": total}}})
        write_lines(self.codex / "sessions" / "mixed.jsonl", [
            codex_event("2026-10-02T00:00:00Z", "session_meta", {"id": "mixed", "cwd": "/work/Health"}),
            codex_event("2026-10-02T00:00:01Z", "event_msg", {"type": "task_started", "turn_id": "old"}),
            codex_event("2026-10-02T00:00:02Z", "turn_context", {"turn_id": "old", "model": "old-model"}),
            legacy("2026-10-02T00:00:03Z", 10),
            codex_event("2026-10-03T00:00:01Z", "event_msg", {"type": "task_started", "turn_id": "new"}),
            codex_event("2026-10-03T00:00:02Z", "turn_context", {"turn_id": "new", "model": "new-model"}),
            legacy("2026-10-03T00:00:03Z", 30),
            codex_event("2026-10-03T00:00:04Z", "token_usage_record", {"response_id": "new-response",
                "turn_id": "new", "usage": {"input_tokens": 40, "output_tokens": 0, "total_tokens": 40}}),
        ])
        result = self.audit()
        self.assertEqual(result["tokens"]["total"], 50)
        self.assertEqual(result["groups"]["model"]["old-model"]["total"], 10)
        self.assertEqual(result["groups"]["model"]["new-model"]["total"], 40)

    def test_guardian_and_list_interruption_are_classified_without_raw_text(self):
        write_lines(self.codex / "sessions" / "guardian.jsonl", [
            codex_event("2026-10-05T00:00:00Z", "session_meta", {"id": "g", "source": {"subagent": {
                "thread_spawn": {"parent_thread_id": "p", "agent_path": "/root/guardian"}}}}),
            codex_event("2026-10-05T00:00:01Z", "event_msg", {"type": "task_started", "turn_id": "gturn",
                "turn_attribution": {"turn_trigger": "guardian_review"}}),
            codex_event("2026-10-05T00:00:02Z", "token_usage_record", {"response_id": "gr", "turn_id": "gturn",
                "usage": {"input_tokens": 2, "output_tokens": 1}}),
        ])
        write_lines(self.claude / "projects" / "x" / "interrupt.jsonl", [
            claude_event("2026-10-05T00:00:03Z", "user", {"content": [
                {"type": "text", "text": "[Request interrupted by user for tool use]"}]}),
            claude_event("2026-10-05T00:00:04Z", "system", subtype="model_refusal_no_fallback"),
        ])
        result = self.audit()
        self.assertEqual(result["groups"]["role"]["guardian"]["total"], 3)
        self.assertEqual(result["event_counts"]["request_interrupted_by_user"], 1)
        self.assertEqual(result["event_counts"]["model_refusal_no_fallback"], 1)

    def test_session_breakdown_reconciles_project_and_model_after_context_switch(self):
        write_lines(self.codex / "sessions" / "switch.jsonl", [
            codex_event("2026-10-02T00:00:00Z", "session_meta", {"id": "switch", "cwd": "/work/Health"}),
            codex_event("2026-10-02T00:00:01Z", "turn_context", {"turn_id": "a", "model": "one", "cwd": "/work/Health"}),
            codex_event("2026-10-02T00:00:02Z", "token_usage_record", {"response_id": "r1", "turn_id": "a",
                "usage": {"input_tokens": 10, "output_tokens": 0}}),
            codex_event("2026-10-03T00:00:01Z", "turn_context", {"turn_id": "b", "model": "two", "cwd": "/work/Other"}),
            codex_event("2026-10-03T00:00:02Z", "token_usage_record", {"response_id": "r2", "turn_id": "b",
                "usage": {"input_tokens": 20, "output_tokens": 0}}),
        ])
        result = self.audit()
        row = result["sessions"][0]
        self.assertEqual(row["usage_breakdown"]["project"]["Health"]["total"], 10)
        self.assertEqual(row["usage_breakdown"]["project"]["Other"]["total"], 20)
        self.assertEqual(row["usage_breakdown"]["model"]["one"]["total"], 10)
        self.assertEqual(row["last_observed_project"], "Other")
        self.assertEqual(result["groups"]["project"]["Health"]["total"], 10)

    def test_legacy_duplicate_archive_and_missing_response_id_are_counted_once(self):
        events = [
            codex_event("2026-10-02T00:00:00Z", "session_meta", {"id": "copy", "cwd": "/work/Health"}),
            codex_event("2026-10-02T00:00:01Z", "event_msg", {"type": "task_started", "turn_id": "old"}),
            codex_event("2026-10-02T00:00:02Z", "event_msg", {"type": "token_count", "info": {
                "total_token_usage": {"input_tokens": 7, "output_tokens": 0, "total_tokens": 7}}}),
            codex_event("2026-10-02T00:00:03Z", "token_usage_record", {"turn_id": "new", "usage": {
                "input_tokens": 99, "output_tokens": 0}}),
        ]
        write_lines(self.codex / "sessions" / "copy.jsonl", events)
        write_lines(self.codex / "archived_sessions" / "copy.jsonl", events)
        result = self.audit()
        self.assertEqual(result["tokens"]["total"], 7)
        self.assertEqual(result["coverage"]["legacy_usage_records"], 1)
        self.assertEqual(result["coverage"]["usage_missing_response_id"], 2)

    def test_partial_archive_legacy_snapshots_use_global_baseline(self):
        meta = codex_event("2026-10-01T00:00:00Z", "session_meta", {"id": "shared"})
        def counter(time, count):
            return codex_event(time, "event_msg", {"type": "token_count", "info": {
                "total_token_usage": {"input_tokens": count, "output_tokens": 0, "total_tokens": count}}})
        early = counter("2026-10-02T00:00:00Z", 5)
        late = counter("2026-10-03T00:00:00Z", 12)
        write_lines(self.codex / "sessions" / "shared.jsonl", [meta, early, late])
        write_lines(self.codex / "archived_sessions" / "shared.jsonl", [meta, late])
        result = self.audit()
        self.assertEqual(result["tokens"]["total"], 12)

    def test_legacy_reset_repeats_values_without_counting_archive_copies(self):
        def counter(time, count):
            return codex_event(time, "event_msg", {"type": "token_count", "info": {
                "total_token_usage": {"input_tokens": count, "output_tokens": 0,
                                      "total_tokens": count}}})
        events = [codex_event("2026-10-01T00:00:00Z", "session_meta", {"id": "reset"})]
        events.extend(counter(f"2026-10-02T00:00:0{index}Z", count)
                      for index, count in enumerate((10, 20, 10, 20), 1))
        write_lines(self.codex / "sessions" / "reset.jsonl", events)
        write_lines(self.codex / "archived_sessions" / "reset.jsonl", events)
        result = self.audit()
        self.assertEqual(result["tokens"]["total"], 40)
        self.assertEqual(result["coverage"]["legacy_usage_records"], 4)

    def test_outside_window_records_keep_baseline_and_partial_message(self):
        pre = "2026-09-30T23:59:59Z"
        late = "2026-10-22T00:00:01Z"
        def counter(time, count):
            return codex_event(time, "event_msg", {"type": "token_count", "info": {
                "total_token_usage": {"input_tokens": count, "output_tokens": 0,
                                      "total_tokens": count}}})
        write_lines(self.codex / "sessions" / "boundary.jsonl", [
            codex_event(pre, "session_meta", {"id": "boundary"}),
            counter(pre, 30), counter("2026-10-01T00:00:00Z", 40),
            codex_event(pre, "token_usage_record", {"response_id": "old", "turn_id": "modern",
                                                    "usage": {"input_tokens": 2}}),
            codex_event("2026-10-01T00:00:01Z", "token_usage_record",
                        {"response_id": "old", "turn_id": "modern", "usage": {"input_tokens": 2}}),
            codex_event("2026-10-01T00:00:02Z", "token_usage_record",
                        {"response_id": "new", "turn_id": "modern", "usage": {"input_tokens": 5}}),
        ])
        overlapping_late = self.claude / "projects" / "x" / "a-late.jsonl"
        unrelated_late = self.claude / "projects" / "x" / "b-unrelated-late.jsonl"
        write_lines(overlapping_late, [
            claude_event(late, "assistant", {"id": "partial", "usage": {"input_tokens": 2,
                         "output_tokens": 9}}),
        ])
        write_lines(unrelated_late, [
            claude_event(late, "assistant", {"id": "unrelated", "usage": {"input_tokens": 500}}),
        ])
        write_lines(self.claude / "projects" / "x" / "z-window.jsonl", [
            claude_event(pre, "assistant", {"id": "old", "usage": {"input_tokens": 100}}),
            claude_event("2026-10-01T00:00:03Z", "assistant",
                         {"id": "old", "usage": {"input_tokens": 100}}),
            claude_event("2026-10-01T00:00:04Z", "assistant",
                         {"id": "partial", "usage": {"input_tokens": 2, "output_tokens": 4}}),
        ])
        with mock.patch.object(audit_module, "jsonl_lines", wraps=audit_module.jsonl_lines) as reader:
            result = self.audit()
        self.assertEqual(result["groups"]["provider"]["codex"]["total"], 15)
        self.assertEqual(result["groups"]["provider"]["claude"]["total"], 11)
        opened = [call.args[0] for call in reader.call_args_list]
        self.assertEqual(opened.count(overlapping_late), 2)
        self.assertEqual(opened.count(unrelated_late), 1)

    def test_output_is_private_atomic_and_does_not_follow_symlink(self):
        private = self.root / "private.json"
        public = self.root / "public.json"
        public.write_text("existing", encoding="utf-8")
        public.chmod(0o644)
        command = ["python3", "-B", str(SCRIPT), "--start", self.start.isoformat(),
                   "--end", self.end.isoformat(), "--codex-root", str(self.codex),
                   "--claude-root", str(self.claude), "--output"]
        subprocess.run([*command, str(public)], check=True)
        self.assertEqual(public.stat().st_mode & 0o777, 0o600)
        private.write_text("do not change", encoding="utf-8")
        public.unlink()
        public.symlink_to(private)
        subprocess.run([*command, str(public)], check=True)
        self.assertFalse(public.is_symlink())
        self.assertEqual(public.stat().st_mode & 0o777, 0o600)
        self.assertEqual(private.read_text(encoding="utf-8"), "do not change")
        self.assertEqual(list(self.root.glob(".session-audit-*.tmp")), [])

    @unittest.skipUnless(shutil.which("zstd"), "zstd CLI unavailable")
    def test_compressed_jsonl_is_read(self):
        source = self.root / "compressed.jsonl"
        write_lines(source, [codex_event("2026-10-02T00:00:00Z", "token_usage_record", {
            "response_id": "compressed", "usage": {"input_tokens": 3, "output_tokens": 2}})])
        target = self.codex / "sessions" / "compressed.jsonl.zst"
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("wb") as output:
            subprocess.run(["zstd", "-q", "-c", str(source)], check=True, stdout=output)
        self.assertEqual(self.audit()["tokens"]["total"], 5)


if __name__ == "__main__":
    unittest.main()
