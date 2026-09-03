# Fit and Full Aspect Modes

## Description

Split the former single “Crop” mode into two ratio options.

- **Fit**: WYSIWYG — what you see in the viewfinder (aspect-fill, no letterboxing) is what exports, using the viewfinder’s aspect ratio.
- **Full**: Stock Camera style — portrait 9:16 (1080×1920 at 1080p), aspect-fill.

## Requirements

- [x] `AspectRatio.full` titled **Fit**: viewfinder proportions, aspect-fill preview, export matches viewfinder aspect
- [x] `AspectRatio.fill` titled **Full**: portrait 9:16, aspect-fill like stock Camera
- [x] Ratio overlay lists Fit, Full, 1:1, 4:3, 16:9
- [x] Compositors aspect-fill (`prefersAspectFit` = false); Fit export size from `viewfinderSize` (photo + video)
- [x] Existing saved `full` selection continues to map to Fit

## Acceptance Criteria

- Fit: no black letterbox bars on preview; saved photo/video matches on-screen framing and PiP position
- Full export is 1080×1920 (or 720×1280) with filled framing
- Switching modes updates preview immediately
- On-screen viewfinder frame matches the selected ratio (capture field visible before gallery)

## Notes

Fit is **not** “show entire sensor with letterboxing” — that UX was rejected. Fit = same crop window as the live viewfinder.
