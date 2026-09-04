# Solo Layouts (Main / Front)

## Description

Add two single-camera layouts alongside PiP / Vertical / Horizontal so users can capture with only the rear or front camera without a separate product mode. Dual session stays configured; solo is a compose + preview choice (battery optimization deferred).

## Requirements

- [x] `CameraLayout.backOnly` titled **Main** — full-frame rear camera
- [x] `CameraLayout.frontOnly` titled **Front** — full-frame front camera
- [x] `CameraLayout.usesSingleCamera` helper for UI / recorder / photo paths
- [x] Viewfinder shows physical back or front preview (not primary/secondary swap role)
- [x] `CaptureLayoutContext.isPrimaryBack` snapshot so export picks the correct buffer after swap
- [x] `DualFrameCompositor` / `DualImageCompositor` draw one camera fullscreen for solo
- [x] `DualVideoRecorder` does not wait for the unused camera before writing solo frames
- [x] Photo path finalizes when the needed solo camera image arrives
- [x] Layout overlay: horizontal chip scroll; hide border/separator for solo
- [x] Optional later: disconnect unused input to save battery / heat
- [x] Solo layouts disable unused video/photo `AVCaptureConnection`s (inputs stay wired; dual restores both)

## Acceptance Criteria

- Selecting Main shows only the rear camera in the viewfinder; Front shows only the front
- Photo and video export for Main/Front contain only that camera, full frame
- PiP / Vertical / Horizontal behavior unchanged
- Layout can still be locked while recording
- Swap does not change which physical camera Main/Front refer to

## Notes

Session still runs MultiCam with both inputs in v1. Solo is layout-level, not a separate `AVCaptureSession`.
