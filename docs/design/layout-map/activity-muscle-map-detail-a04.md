---
tags: [design, layout, activity, muscle-map]
date: 2026-10-31
category: plan
status: implementation-contract
---

# A03 · Activity muscle map detail / A04 entry availability

This map defines the current A04 behavior for the A03 actual screen `activity-musclemap-detail-screen`. It is an implementation contract, not an app capture.

| Width / state | Primary pane | Secondary pane | User action |
|---|---|---|---|
| Compact iPhone / Duo folded | Expanded 2D front/back recovery map | Selected muscle inline detail, volume analysis, recovery status | Tap a muscle to toggle its 2D selection; remain on A03 |
| Regular iPad / Duo unfolded | Same 2D map | Same detail and analysis in adjacent pane | Tap a muscle to toggle adjacent detail; remain on A03 |
| No selected muscle | Same 2D map | Volume analysis and recovery status | No empty substitute for data |
| No volume data | Same 2D map | Existing `No Volume Data` message and recovery status | Do not synthesize volume |
| Large text / Reduce Motion | Existing adaptive panes | Existing readable content and reduced animation | Same selection and no 3D navigation |

A04 keeps the explicit `3D Muscle Map` cube button visible but disabled and disables the compact-width automatic 3D push. It retains the existing 3D destination and all 3D implementation source for a later decision. The Activity root's muscle map detail link remains. The 2D map, legend, volume, recovery and selected muscle content retain their current order and behavior.

Theme contract: use the existing DUNE Activity theme tokens and `DetailWaveBackground`. No palette, background, ring, graph or motion direction changes. The [theme map](../theme-map/index.html) remains the visual source. The [Activity root layout](index.html#activity) already removes its 3D shortcut; this document covers the detail screen's remaining entries.

Actual A03 screenshots for ordinary iPhone, iPad, Duo folded and unfolded must be refreshed after runtime validation. Existing captures are historical evidence only until then. The 3D viewer screen is unchanged by A04 and its old capture must not be presented as a new A04 capture.
