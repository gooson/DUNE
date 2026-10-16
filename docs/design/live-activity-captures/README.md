# Rest timer Live Activity capture matrix

These captures are required for PR7. They must come from the current implementation and current OS runtime; do not reuse older screenshots.

| Capture | Required state | Output path | Status |
|---------|----------------|-------------|--------|
| iPhone portrait | Active rest timer, compact Dynamic Island | `iphone-dynamic-island-portrait.png` | Pending host/simulator access |
| iPhone landscape | Active rest timer, limited-width compact Dynamic Island | `iphone-dynamic-island-landscape-limited.png` | Pending host/simulator access |
| Apple Watch | Paired iPhone Live Activity shown in Smart Stack small family | `watch-smart-stack-small.png` | Pending paired Watch/runtime access |

The repository-level instruction also requires the affected entries in `docs/design/phone-design-map/actual/index.html` to be refreshed. That integrated actual map is absent from this worktree at the time of implementation, so no map entry is marked captured here. Confirm the canonical map path before recording final evidence.

For each capture, record the device/runtime and confirm the countdown advances. Review the combined VoiceOver description in the Watch layout. A screenshot alone does not prove accessibility behavior.
