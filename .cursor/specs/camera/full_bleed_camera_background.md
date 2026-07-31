# Full-Bleed Camera Background

## Description

Optional appearance setting that replaces the black letterbox stage on the main camera screen with an edge-to-edge live camera preview under the chrome.

## Requirements

- [x] Persist a boolean `isFullBleedCameraBackgroundEnabled` in `AppSettings` (UserDefaults)
- [x] Expose a Settings → Appearance toggle labeled for full-screen camera background
- [x] When enabled, the viewfinder fills the available screen (no black letterboxing from aspect framing)
- [x] When disabled, keep the existing black stage and aspect-fitted viewfinder frame
- [x] Works with both floating and classic chrome layouts
- [x] Does not attach a second preview layer to the same capture port (single viewfinder only)

## Acceptance Criteria

- Toggling the setting immediately updates the camera screen after leaving Settings
- Floating panels remain readable over the full-bleed preview
- Capture / export behavior continues to use existing layout and ratio logic

## Notes

A port can feed only one `AVCaptureVideoPreviewLayer`, so immersive fill expands the single viewfinder rather than stacking a dimmed duplicate preview.
