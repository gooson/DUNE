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
| iPad portrait | Same 2D map | Selected inline detail below the map, followed by volume and recovery | Tap a muscle to toggle inline detail; remain on A03 |
| Duo unfolded / wide adaptive layout | Same 2D map in left pane | Selected detail and analysis in right pane | Tap a muscle to toggle right-pane detail; remain on A03 |
| No selected muscle | Same 2D map | Volume analysis and recovery status | No empty substitute for data |
| No volume data | Same 2D map | Existing `No Volume Data` message and recovery status | Do not synthesize volume |
| Large text / Reduce Motion | Existing adaptive panes | Existing readable content and reduced animation | Same selection and no 3D navigation |

A04 keeps the explicit `3D Muscle Map` cube button visible but disabled and disables the compact-width automatic 3D push. It retains the existing 3D destination and all 3D implementation source for a later decision. The Activity root's muscle map detail link remains. The 2D map, legend, volume, recovery and selected muscle content retain their current order and behavior.

Theme contract: use the existing DUNE Activity theme tokens and `DetailWaveBackground`. No palette, background, ring, graph or motion direction changes. The [theme map](../theme-map/index.html) remains the visual source. The [Activity root layout](index.html#activity) already removes its 3D shortcut; this document covers the detail screen's remaining entries.

The [A04 native review](../full-redesign-map/review/a04-muscle-map-disabled-entry-native-2026-11-03/index.html) records actual A03 defaults and selected details across ordinary iPhone, iPad and both Duo poses. Phone uses a clean 1f7f9900 historical run under a scoped source/input closure; the other three are new 8274d1cb runs. Compact default may not show the offscreen cube, so selected-state supplements preserve its visible disabled state. The 3D viewer screen is unchanged by A04 and its old capture must not be presented as a new A04 capture.
