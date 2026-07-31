# Collapsible Top Bar

## Description

Allow the idle camera top chrome to collapse so the viewfinder stays unobstructed, with a small pill to restore it.

## Requirements

- [x] Chevron button collapses the idle top bar
- [x] Swipe up on the expanded bar collapses it past a threshold
- [x] Collapsed state shows a compact pill (handle + chevron) centered at the top
- [x] Tap pill or swipe down on the pill expands the bar again
- [x] Recording always shows the timer bar (auto-expands if collapsed)
- [x] Floating panel background is omitted while collapsed so only the pill remains

## Acceptance Criteria

- Collapsing frees vertical space for the capture stage
- Overlays dismiss when the bar collapses
- Expand/collapse animates smoothly
