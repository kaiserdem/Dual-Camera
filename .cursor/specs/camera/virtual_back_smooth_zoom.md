# Virtual Back Smooth Zoom (0.5×)

## Description

Use a virtual back camera (`builtInDualWideCamera` / `builtInTripleCamera`) in the multi-cam session so 0.5× ↔ 1× ↔ 2× uses `videoZoomFactor` ramp instead of swapping Ultra Wide / Wide inputs (black flash).

## Requirements

- [x] Prefer Triple, then DualWide, when `supportedMultiCamDeviceSets` includes that device with the front camera
- [x] Fall back to Wide + UltraWide input switch when virtual back is unavailable or incompatible
- [x] Map UI 0.5 / 1× / 2 to device zoom via `minAvailableVideoZoomFactor` and `virtualDeviceSwitchOverVideoZoomFactors`
- [x] Animate zoom with `ramp(toVideoZoomFactor:withRate:)` on the virtual device
- [x] Log chosen back device, multi-cam compatibility, and `hardwareCost` for device validation
- [x] Keep showing the 0.5 control when virtual back provides ultra-wide FOV

## Acceptance Criteria

- [x] On compatible hardware, switching 0.5 ↔ 1× does not tear down the back input (no full black flash from `removeInput`)
- [ ] On incompatible hardware, previous UltraWide switch behavior still works
- [x] Default zoom after session start remains 1× (wide FOV)
- [ ] Back virtual multi-cam format prefers ≥720p video (not 640×480 stills-heavy format)

## Notes

- Virtual device still emits one fused back stream; front remains a separate input for PiP
- `hardwareCost` may force lower multi-cam formats
