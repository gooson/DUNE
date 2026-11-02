# T06 native evidence: HRV on four device tiers and the historical iPad matrix

Open [index.html](index.html). Per-image sources, timestamps, hashes, results and limits are recorded in [evidence.json](evidence.json).

## HRV after captures on four device tiers

- iPhone: `c0b51078`, November 2. Five focused methods passed; the selected initial frame shows HRV at 75 ms.
- Duo folded and open: `c0b51078`, November 2. One HRV identity method passed in each posture, with two strict root/teardown capture pairs per run. Readback identifies 0° with LCD active and 180° with LCD-1 active. These runs do not establish other metrics, dark appearance, maximum text size or period flows on Duo.
- iPad: `f9f1d852`, **October 31 historical capture**, selected from the 18-identity matrix. This is not a new November 2 iPad run.

Every left reference is the genuine original **iPad HRV capture from October 31**, revision `0dc77dc4`, showing 75 ms. The gallery explicitly identifies the different device and viewport for iPhone and Duo. It does not claim four matching same-device before captures. The incorrect Sleep image formerly used for canonical T06 has been replaced with actual HRV.

## Historical iPad matrix: 18 metric identities

The 17 original pairs come from `0dc77dc4`. The separate original Swimming capture comes from `f06d4a73`; its protected View and ViewModel match `0dc77dc4`. It preserves the legacy display error in which a 1,314 m input appeared as 1,314 min. No distinct original lower-screen capture exists for Swimming.

The after matrix comes from `f9f1d852`: one passing method visits 18 identities, and one peer-comparison method also passes. The corrected Running and Swimming initial/highlight frames come from `61bdbf84`. Those two distance methods passed, while that bundle had an overall result of two passes and one failure; its peer failure remains disclosed. The peer source panel comes from a separate passing method at `3d299a50`. Superseded distance frames from `f9f1d852` remain explicitly labelled as process evidence rather than the corrected final display.

These are 18 identities, not 18 independent test cases or coverage on all four device tiers. The matrix captures were taken on October 31 and assembled here on November 2. Current main equivalence and overall PR readiness are outside this gallery's claims.

## Canonical map scope

Only canonical T06 records and images, their derived galleries and boards, the portal/comparison page and README navigation were updated. All other captured records, including T05 records and image bytes, are preserved from `a6f52495`. The map publisher did not run app tests, builds, simulators or new captures, and did not commit changes.
