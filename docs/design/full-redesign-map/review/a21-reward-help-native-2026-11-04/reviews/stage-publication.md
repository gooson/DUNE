# A21 actual design map — independent stage and publication review

- `source_head`: `9208e68ca8f2cd1b9e209fd7c9fb40a8164547ef`
- `stage`: `/private/tmp/a21-gallery-stage-9208-a20-complete-v2`
- `stage_inventory_sha256`: `bd50d031bb73e3e4f6e2194de2bc2ae7fefa89256be99a41b42ecafe29476319`
- `installer`: `/private/tmp/a21-gallery/install-9208.py`, SHA-256 `3f6c5c4d6acb45cc89c186f2066eba95e5ba388b61d3dd29693e2c1a722c3740`
- `builder`: `/private/tmp/a21-gallery/build-9208-ipad-a20-v2.py`, SHA-256 `9d1c3ce34bd30d89bb1e30cb63f3a89a8e7d6a152041669973cf5eec451b000a`
- `complete_input_sha256`: `beccb8f3bd4b65b4dad95180a4149ea0b597c535cd417a204a6b147a28ca7776`
- `selected_17_pairs_sha256`: `289028d939aaa93159a07e81ef55c87ea1745f31c65c2e951a4414ed88a3a068`
- `open_P1`: 0; `open_P2`: 0; `open_P3`: 0.

## Findings

No open findings in the frozen v2 stage or installer publication scope. The earlier private v1 stage was rejected because its regular iPhone before-state incorrectly said there was no original capture. V2 identifies the actual 495d original iPhone capture; iPad and both Duo profiles explicitly have no original A21 capture on those devices. V2 changes only the gallery evidence JSON and HTML from v1; v1 is not an installation input.

## Stage preservation and provenance

Read-only verification matched the inventory SHA and all 55 staged file hashes: 19 permitted outputs plus 36 gallery files. The 19 outputs comprise 15 existing paths and four newly created `images/A21.png` paths, one per regular iPhone, iPad, closed Duo and open Duo. All four destination images are currently absent in ROOT. No staged symlinks were found. The stage evidence has the exact 9208 HEAD, pending-review status, and 662 validated input paths; every input digest matched at review time.

Each tier's capture index retains every pre-existing `captured` entry value-for-value as parsed JSON and adds only A21. Other top-level metadata remains equal except the explicit last-refresh A21 fields. The four tier galleries grow from 110 to 111 cards; their changes are the count labels and one A21 card. The comparison page's embedded evidence preserves all non-A21 rows and adds only A21 for each tier. Activity boards grow in height; each of the 20 prior tile pixel regions per tier is identical to ROOT. The four new canonical image hashes match both their actual XCTest/host source and the staged A21 tile and gallery copy. Their four AX proof hashes match the selected native source. All ten Duo MAX PNG/AX pairs, one original 495d phone pair and two notification open/return pairs match their source and staged copies: 17 selected pairs total. Gallery local image and proof links exist; the portal and README A21 links resolve to the staged gallery path.

The stage describes six actual passed cases: closed Duo 2/2, open Duo 1/1, phone Activity plus Notification 2/2, and A20 Pro iPad 1/1. Historical d87 and 400c closed runs remain 2 executed/1 passed/1 failed each; cc0 retains an incomplete 13-file SDK bundle with no aggregate; unsupported A21 iPad type is a pre-device failure with zero UI executions and zero devices created. The iPad after capture is labeled `iPad mini (A20 Pro)` and its actual A20 type. No other-device before capture is inferred from the 495d phone baseline.

## Installer gate and recovery

The reviewed installer allows exactly the 19 paths above and a new exclusive gallery directory. Before writing, it checks source HEAD and cleanliness, source and baseline hashes, the full stage inventory, all stage-validated input hashes, four absent A21 destinations, and three independent reports (`source_review`, `native_quality`, `stage_review`) with zero open P1/P2/P3. Native quality and stage reports must bind this inventory SHA; the native report must name each selected PNG/AX digest. It takes an exclusive install lock, backs up all 15 existing outputs, creates the gallery directory exclusively, uses exclusive creation for four new images and replacement files for existing outputs. On failure it restores files only while their staged hashes still match, checks ownership before removing new outputs or the gallery, and retains backups plus an error report if a destination was changed or left partial. This is a fail-closed manual-recovery condition, not a successful publication. Install execution and post-install path/hash review remain with ROOT.

Scope: read-only private stage/installer inspection and digest comparisons only. No ROOT edit, installer invocation, simulator, build, test, or new native result was produced by this review. Existing source and native quality reports are separate gates.
