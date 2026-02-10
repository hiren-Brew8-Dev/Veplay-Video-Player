# Swipe-Down-to-Dismiss Gesture Implementation

## Overview
Implemented a YouTube-style swipe-down gesture to dismiss the video player from anywhere in the center video area.

## Key Features

### 1. **Gesture Isolation**
- Uses `.simultaneousGesture()` instead of `.gesture()` to avoid blocking other gestures
- Minimum distance of 10pt before activation
- Uses `.local` coordinate space for better control

### 2. **Smart Conflict Avoidance**
The gesture is disabled when:
- Controls are visible (prevents accidental dismiss while using controls)
- Any sheet is open (Settings, Audio & CC, Sleep Timer, etc.)
- Swipe starts in restricted zones:
  - Top 80pt (navbar area)
  - Bottom 100pt (control bar area)
  - Left/Right 40pt edges

### 3. **Direction Detection**
- Only responds to DOWNWARD swipes (positive Y translation)
- Ignores horizontal gestures (prevents conflict with seek gestures)
- Rejects gestures where horizontal movement > 50% of vertical movement

### 4. **YouTube-Like Dismiss Conditions**
Three ways to trigger dismiss:
1. **Fast Swipe**: Velocity > 800 pts/sec
2. **Long Swipe**: Translation > 150pt
3. **Medium Swipe**: Translation > 80pt AND velocity > 400 pts/sec

### 5. **Smooth Animations**
- **During drag**: 60% resistance for natural feel
- **On dismiss**: Slides all the way down with easeOut (0.25s)
- **On cancel**: Spring animation snaps back (0.35s response, 0.75 damping)

## Implementation Details

### Gesture Flow
```
User starts swipe in center area
    ↓
Check constraints (controls hidden, no sheets, valid zone)
    ↓
Track vertical movement with resistance
    ↓
On release, check velocity + distance
    ↓
Dismiss OR Snap back
```

### Thresholds
- **Minimum distance**: 10pt (prevents accidental activation)
- **Fast swipe**: 800 pts/sec velocity
- **Long swipe**: 150pt distance
- **Medium swipe**: 80pt + 400 pts/sec
- **Resistance**: 0.6x (dampens movement)

### Protected Zones
```
┌─────────────────────────┐
│   Top 80pt (Navbar)     │ ← Ignored
├─────────────────────────┤
│ L │                 │ R │
│ 4 │                 │ 4 │
│ 0 │  ACTIVE ZONE    │ 0 │ ← Gesture works here
│ p │                 │ p │
│ t │                 │ t │
├─────────────────────────┤
│  Bottom 100pt (Controls)│ ← Ignored
└─────────────────────────┘
```

## Benefits

1. **No Conflicts**: Doesn't interfere with:
   - Play/pause taps
   - Double-tap seek
   - Horizontal seek gestures
   - Control interactions
   - Sheet presentations

2. **Natural Feel**: 
   - Resistance makes it feel like pulling down a curtain
   - Velocity-aware (fast swipes dismiss easily)
   - Smooth animations match iOS standards

3. **Safe**: 
   - Won't accidentally dismiss during normal use
   - Requires intentional downward swipe in center area
   - Disabled when controls/sheets are active

## Testing Checklist

- [ ] Swipe down in center dismisses player
- [ ] Fast swipe dismisses even with small distance
- [ ] Slow/short swipe snaps back
- [ ] Horizontal swipes don't trigger dismiss
- [ ] Swipes near edges are ignored
- [ ] Swipes with controls visible are ignored
- [ ] Swipes with sheets open are ignored
- [ ] Play/pause still works
- [ ] Double-tap seek still works
- [ ] Seek gestures still work
- [ ] All control buttons still work
