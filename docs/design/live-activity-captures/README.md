# Rest timer Live Activity capture matrix

This matrix tracks the remaining Rest Timer surfaces. Captures must identify their source revision, device, OS runtime, and provenance; older screenshots do not prove changed styling.

| Capture | Required state | Output path | Status |
|---------|----------------|-------------|--------|
| iPhone portrait | Active rest timer, compact Dynamic Island | `iphone-dynamic-island-portrait.png` | Pending compact Island capture |
| iPhone landscape | Active rest timer, limited-width compact Dynamic Island | `iphone-dynamic-island-landscape-limited.png` | Pending landscape Island capture |
| Apple Watch | Paired iPhone Live Activity shown in Smart Stack small family | `watch-smart-stack-small.png` | Pending paired Watch/runtime capture |

The integrated [actual design map](../phone-design-map/actual/index.html) exists and links to the [WLA01 Watch workout Live Activity gallery](../phone-design-map/actual/live-activity/index.html). Its [capture index](../phone-design-map/actual/live-activity/capture-index.json) records iPhone Notification Center running and paused states from a DEBUG Watch snapshot. Those are system ActivityKit captures, but do not prove a paired Watch, a physically locked iPhone, Dynamic Island, or small family. The [DESERT HORIZON system capture index](../full-redesign-map/review/desert-horizon-final-2026-10-24/system/capture-index.json) also records a light-appearance Rest Timer Notification Center capture and widget gallery images. Its Rest Timer card rendered on the dark system surface, so it is not evidence of a cream/light Live Activity surface. None of these captures satisfies the three pending rows above.

For each capture, record the device/runtime and confirm the countdown advances. Review the combined VoiceOver description in the Watch layout. A screenshot alone does not prove accessibility behavior.
