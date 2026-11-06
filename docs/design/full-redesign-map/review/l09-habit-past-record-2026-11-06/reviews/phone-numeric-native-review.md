# Batch03 L09 numeric iPhone native review

## Findings

- P1: None in this exact selector.
- P2: None in this exact selector.
- P3: None in this exact selector.

## Scope and result

- Source: `608fe5eb568d74fe9ca7f03187bab8e2977cf763`; iPhone normal.
- Separate extra execution of `testPastReadTotalReplacesYesterdayAndLeavesTodayUnchanged` **passed 1/1**.
- The original `batch03-phone-normal` pipeline retains its **two failed executions**. This report does not change or relabel either aggregate. The extra-run policy and immutable-pipeline linkage are recorded in `phone-numeric-entry-standing-grant-resolution.md` and `phone-numeric-original-check-attempt3.json`.

## Native observations

- The focused Read duration field visibly holds `30` with the numeric keyboard; AX reports value `30` and `Keyboard Focused`. Current total `30`, selected Read, date Nov 5, 2026, and Save remain readable.
- After saving the replacement total, the Today Read card remains `0/30 min` and shows `Record updated`.
- Read history shows `Recorded later`, Yesterday/Nov 5, 2026, and `40/30 min`; AX exposes the same `40/30 min` value. History is the existing L05 child view, observed as the result of this L09 path.

## SHA-256 inventory

All four selected PNG/AX pairs were SHA-256 verified.

| # | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---|---|---|
| 0 | tap habit-past-record-total | `5c9d579ed375089989c26ea2f192376287f938cd38797b8741dac16d56b49321` | `683a82175cb9411a22b187600c3170ac360060ba1e9221d8f762cacd753ca816` |
| 1 | L09 focused duration total and software keyboard | `101ad47a649e8416092ed6e6e3547f45fd1f90c44353f306f589e1651a50ef41` | `4c5b5a19b09343aefb564d80cb5b0cf88793a15baf8a641b777ecb8b794c1aed` |
| 2 | tap habit-past-record-save | `d65783a8d309484183c0cec54edfec0cd944fa8c450fde9ccd2f4232eae12131` | `4255955e5327e54e78496d6d9d871875570e99ad175e1e96e5790f016449b8ba` |
| 3 | L05-Life-history-recorded-later | `518e0fdbc66d5feaf3e89e92b5f8506de7492dc53dce56dfbeea02ef2cff1b82` | `81e24f154ab933735262429c4c9825f1c8a3fc10e1e7ec2f14272d43dd05183a` |

Full pair paths are in the adjacent JSON report.

## Limits

This review clears only the named selector and profile. It does not claim that the original aggregate passed, or that other devices and broader regressions passed.
