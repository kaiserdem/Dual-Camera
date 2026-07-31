# Fit and Full Aspect Modes

## Description

Split the former single “Crop” mode into two ratio options so users can choose stock-camera framing or uncropped sensor framing.

## Requirements

- [x] `AspectRatio.full` titled **Fit**: viewfinder proportions, aspect-fit (no side crop)
- [x] `AspectRatio.fill` titled **Full**: portrait 9:16 (1080×1920 at 1080p), aspect-fill like stock Camera
- [x] Ratio overlay lists Fit, Full, 1:1, 4:3, 16:9
- [x] Preview gravity and compositors respect `prefersAspectFit` only for Fit
- [x] Existing saved `full` selection continues to map to Fit

## Acceptance Criteria

- Fit export matches on-screen viewfinder aspect and does not crop sensor sides
- Full export is 1080×1920 (or 720×1280) with filled framing
- Switching modes updates preview immediately
- On-screen viewfinder frame matches the selected ratio (capture field visible before gallery)

## Notes

Previously both behaviors were conflated under one “Crop” label.
