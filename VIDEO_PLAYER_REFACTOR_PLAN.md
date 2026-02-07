# Video Player UI Refactoring Plan (v3 - Final Polish)

## Reference Design Requirements
1. ✅ **Video Title**: Truncated after 15 chars.
2. ✅ **Top Bar Mirroring**: Remove text. Show only icon. Tap opens native system menu.
3. ✅ **Center Controls**:
    - Reduce size of Play/Pause and Skip icons.
    - Remove white borders/circles from 10s Skip buttons (only icons visible).
4. ✅ **Bottom Bar**:
    - Reduce excess bottom spacing below the slider.
    - Add **Rotate Button** at the far right bottom.
5. ✅ **Sheets**: **Audio & Captions** sheet must be full screen and animate bottom-to-top in both orientations.
6. ✅ **Lock Mode**:
    - When locked, show the lock icon at the top-right (replacing/at the position of the settings icon).
    - Maintain touch blocking.

## Implementation Tasks

### ✅ Task A: Bottom Bar & Center Controls Refinement
- Reduce padding in `PlayerBottomBar.swift`.
- Add Rotate button.
- Resize and de-border center icons in `PlayerControlsView.swift`.

### ✅ Task B: Top Bar & Lock UI
- Simplify Mirroring button to icon-only.
- Implement Lock icon positioning in `PlayerTopBar.swift` or `PlayerControlsView.swift` when `isLocked` is true.

### ✅ Task C: Audio & Captions Sheet Animation
- Update `AudioCaptionsSheet.swift` presentation logic in `PlayerControlsView.swift`.

---
**Status: COMPLETE** ✅
