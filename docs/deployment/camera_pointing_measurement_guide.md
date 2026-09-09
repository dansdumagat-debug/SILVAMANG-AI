# Camera Pointing Measurement Guide

This guide describes the SILVAMANG AI camera-pointing measurement prototype for tree height and canopy width. It is intended for field demo use and does not claim exact measurements.

## Purpose

The camera-pointing workflow lets the user aim the phone camera at visible reference points on a mangrove tree, then calculates an approximate result from the recorded pointing steps and a known distance reference.

Use it when:

- A live camera-guided workflow is easier than marking points on a still image.
- A field distance has already been measured.
- AR/depth support is unavailable and a geometric fallback is acceptable for prototype use.

## Height Workflow: Base To Top

1. Choose `Tree Height`.
2. Point the center crosshair at the base of the tree.
3. Tap the preview or press `Set Base Point`.
4. Move the camera to the visible top of the tree.
5. Tap the preview or press `Set Top Point`.
6. Review the calculated prototype estimate.

Formula used by the fallback:

```text
height = distance * (tan(top_angle) - tan(base_angle))
```

## Canopy Workflow: Left Edge To Right Edge

1. Choose `Canopy Width`.
2. Point the center crosshair at the left canopy edge.
3. Tap the preview or press `Set Left Edge`.
4. Move the camera to the right canopy edge.
5. Tap the preview or press `Set Right Edge`.
6. Review the calculated prototype estimate.

Formula used by the fallback:

```text
canopy_width = 2 * distance * tan(horizontal_angle_difference / 2)
```

## Camera Movement

Keep the phone as steady as possible when setting each point. The app records the current frame center and available device/location metadata for each point.

If realtime sensor data is unavailable, the app shows:

```text
Realtime estimate unavailable. Set both points to calculate.
```

## Crosshair Reference

The center crosshair is the measurement reference. Place the target point exactly under the crosshair before setting each point.

## Measurement Method

Current method:

```text
camera_pointing_prototype
```

AR/depth support is not forced. If ARCore or depth data is unavailable, the app keeps working through the geometric fallback.

## Geometric Fallback

The fallback requires:

- A distance reference from the field distance meter, or
- A manual distance entered under `Advanced fallback / Manual reference`

The manual distance input is intentionally kept out of the main camera UI so the primary workflow stays focused on pointing the camera.

## Accuracy Limits

This workflow produces prototype estimates only. Accuracy depends on:

- Distance reference quality
- Camera aiming stability
- Visibility of tree base/top or canopy edges
- Device orientation sensor quality
- GPS availability and accuracy

Use the saved result as supporting field data, not as a certified forestry measurement.
