---
tags: [swift, xctest, test-projection, declaration-scope]
date: 2026-11-14
category: testing
status: resolved
---

# Preserve class ownership when publishing scoped UI checks

## Problem

The first unmerged S03 projection appended the baseline helpers and later test classes before the five new S03 methods, duplicating baseline classes and placing the methods in the wrong scope. Method-body hashes alone did not detect the file assembly error.

## Solution

Rebuild from the actual PR base and insert only the two S03 selectors and three numeric-input helpers before the first class's existing `openExerciseDefaults` method. Keep the base suffix exactly once. The repaired whole file is byte-identical to source `334150759`, whose iPad normal/MAX checks passed in 99.478/109.867 seconds. The original unmerged publication remains in branch history; the repair is an ordinary follow-up commit.

## Prevention

Check class membership, duplicate declarations and the complete published file in addition to individual method hashes. Compare all final Swift owner files against the executed source before merging. Preserve unrelated base changes rather than replacing whole files with an older integrated tree.

## Lessons Learned

A successful integrated test run validates its exact source. Publication assembly needs a separate final reconciliation; identical method bodies can still be inserted into the wrong class.
