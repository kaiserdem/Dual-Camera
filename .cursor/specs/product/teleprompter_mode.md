# Teleprompter Mode

## Description

A teleprompter overlay for the Dual Camera app that displays scrolling script text on top of the camera viewfinder. Enables on-screen reading while recording video or capturing photos. Designed as a pure SwiftUI overlay — no changes to AVCaptureSession or video pipeline.

## Requirements

### State / Settings
- [x] `teleprompterText: String` — the script content, persisted via UserDefaults
- [x] `teleprompterSpeed: Double` — scroll speed multiplier (0.2…3.0, default 1.0), persisted
- [x] `teleprompterFontSize: Double` — overlay font size in points (12…48, default 28), persisted
- [x] `teleprompterAutoStartWithRecording: Bool` — when true, starting video recording activates the overlay and starts scroll (if script text exists); default `false`, persisted
- [x] `teleprompterStartDelaySeconds: Int` — countdown before scroll begins (presets `0 / 3 / 5 / 10`, default `0`), persisted
- [x] `isTeleprompterActive: Bool` — runtime flag, not persisted
- [x] `isTeleprompterScrolling: Bool` — runtime play/pause for overlay scroll, not persisted

### TeleprompterView
- [x] Full mid-stage layout: text area fills **all** space between TopBar and BottomBar (zoom/shutter) — not a narrow ~200pt strip
- [x] Light background only under the text lane — no full-screen opaque dim that blocks hit testing
- [x] When inactive, middle chrome slot is a pass-through `Spacer` (`allowsHitTesting(false)`)
- [x] Text auto-scrolls from bottom to top at a configurable speed
- [x] Scroll can be paused / resumed via tap on the text band or compact Play/Pause button
- [x] Vertical swipe on the text band adjusts scroll speed in real time (swipe up = faster, swipe down = slower), clamped to 0.2…3.0, persisted via `teleprompterSpeed` Binding
- [x] Brief on-screen speed feedback (e.g. `1.5×`) while adjusting; tap remains play/pause and does not conflict with the drag gesture
- [x] Large, readable white font with drop shadow for visibility on any background; size comes from `teleprompterFontSize`
- [x] Compact Close + Play/Pause controls on the trailing edge of the text area — do not cover shutter / zoom / swap
- [x] "Close" button dismisses the overlay without stopping recording
- [x] When `teleprompterStartDelaySeconds > 0`, show a visible countdown before scroll starts; text is visible during the countdown
- [x] Pause/resume after the countdown has finished does **not** restart the delay

### TeleprompterEditorView
- [x] Full-screen cover (`fullScreenCover`) with `TextEditor` for entering / pasting the script
- [x] Speed slider (0.2…3.0)
- [x] Font size controls (A− / A+) that adjust `teleprompterFontSize` within 12…48
- [x] "Clear" button resets text
- [x] Toggle **«Автостарт з записом»** bound to `teleprompterAutoStartWithRecording`
- [x] Segmented control **«Затримка старту»** for `0 / 3 / 5 / 10` seconds bound to `teleprompterStartDelaySeconds`
- [x] Navigation: circular Back (`chevron.left`) on the leading side only — matches Settings; no trailing **Done**
- [x] Leaving via Back saves the draft text only — does **not** auto-activate the overlay
- [x] No live preview section in the editor

### Integration
- [x] Idle (not recording): teleprompter button opens `TeleprompterEditorView` via `fullScreenCover`
- [x] Recording in progress: teleprompter button toggles overlay + scroll — does **not** open the editor
- [x] Recording top bar shows a teleprompter control so toggle is available during a take
- [x] When `teleprompterAutoStartWithRecording` is on and recording starts with non-empty script → `isTeleprompterActive = true` and scroll starts (after optional delay)
- [x] When recording stops → hide overlay and stop scroll (`deactivateTeleprompter`)
- [x] Overlay lives in chrome `VStack` middle slot: TopBar → Teleprompter (flex) → BottomBar (zoom)
- [x] Shutter, pause, zoom, and other chrome controls remain accessible while teleprompter is active (not covered by text area)
- [x] `AppSettings` extended with teleprompter settings keys
- [x] `teleprompterFontSize` and `startDelaySeconds` are passed from `CameraView` into `TeleprompterView`

## Acceptance Criteria

1. User can enter text in the full-screen editor and tap Back → settings are saved; overlay does not start until user activates it (button / recording auto-start)
2. Text scrolls continuously from bottom to top; tapping the text band pauses/resumes
3. Speed slider in editor changes scroll rate in real-time when overlay is live
4. Vertical swipe on the text band changes speed in real time without opening the editor; value stays within 0.2…3.0 and is persisted
5. Font size buttons (A− / A+) change overlay text size; value stays within 12…48 and is persisted
6. Closing overlay (X button) hides text but keeps script saved for next activation
7. Camera shutter, pause recording, zoom, and top/bottom chrome work normally while teleprompter overlay is visible (text area sits strictly between TopBar and BottomBar)
8. Compact teleprompter controls (play/pause scroll, close) work and do not block zoom / shutter
9. Settings are persisted across app launches (including auto-start and start-delay)
10. Teleprompter text area uses the full available height between chrome bars (not a fixed ~200pt mid-strip)
11. «Автостарт з записом» starts the teleprompter when video recording begins (script required)
12. Start-delay countdown runs before scroll on manual activate and on auto-start with recording
13. Editor toolbar: Back on the left, no Done on the right
14. While recording, teleprompter button toggles overlay; while idle, it opens settings

## Notes

- Only SwiftUI overlays — do NOT modify AVCaptureSession, DualVideoEngine, or DualFrameCompositor
- Follow Swift API Guidelines: camelCase, descriptive names
- Use `@MainActor` on ViewModel extensions
- Consistent with existing dark-theme SF Symbols UI style
- Layout model: `[TopBar] [Teleprompter fills remaining height] [BottomBar/zoom]`; trailing compact controls; no full-screen blocking background
- «Recording» means `isRecording` (capture in progress), not gallery playback
