# Field Distance Measurement Guide

## Purpose

The Field Distance Meter lets a field user estimate the distance from their
standing scan position to the mangrove/front point before taking identification
photos. This supports later height and canopy measurement workflows without
requiring a physical measuring tape in every field session.

## How To Measure Before Scanning

1. Open the Identify / Capture flow.
2. Tap `Measure Distance First`.
3. Stand at the planned scan position.
4. Tap `Set Standing Point`.
5. Walk toward the mangrove/front point.
6. Watch the live estimated distance update.
7. Tap `Set Target Point`.
8. Tap `Use Distance for Scan`.
9. Continue capturing plant-part images.

## GPS Walk Measurement vs Tape Measure

The current Field Distance Meter uses GPS-based walking distance as a prototype
field tool. It reduces the need for a physical measuring tape but should be
treated as an estimate. Accuracy depends on GPS signal quality and should be
validated during field testing.

The app collects multiple GPS samples for both the standing point and target
point, discards poorer samples when better samples are available, averages the
accepted latitude/longitude values, then calculates the geodesic distance
between the averaged points. This improves reliability compared with using a
single GPS reading.

A tape measure is still more precise for close-range measurements. GPS is most
useful when the user can stand and walk in an open area with a stable signal.

## Accuracy Warning

The app warns the user when GPS accuracy may affect the result:

- More than 10 meters: GPS accuracy is low, so the estimate may be inaccurate.
- More than 30 meters: GPS accuracy is too low for reliable distance measurement.
- Less than 1 meter measured: distance is too short and should be remeasured.

The UI labels this value as `Estimated distance`, not exact distance.

For exact measurements, validate with field instruments such as tape measure,
rangefinder, or other approved field tools.

## Use In Height And Canopy Measurement

The Measurement screen reads the saved field distance from the scan session and
shows:

```text
Distance from standing point: <distance_meters> m
```

If no GPS walk distance exists, the user can enter a manual distance in meters.
Manual override stays available because GPS may be inaccurate under trees,
near structures, or during poor satellite reception.

Field Distance Meter can also provide the distance input for the
Camera Pointing Measurement workflow. In that workflow, the app combines the
field/manual distance with user-provided angle values to estimate tree height or
canopy width.

Measurement point marking uses the actual captured mangrove image from the
scan flow. For height, mark the tree base first and the highest visible point
second. For canopy width, mark the left canopy edge first and the right canopy
edge second.

For height or canopy width, a full-tree or canopy image gives a better
prototype estimate. If only a leaves image is available, the app still allows
prototype marking but warns that the result should be treated cautiously.

The measurement output is a `geometric_scaling_prototype` estimate. It is not
an exact tree height, exact canopy width, or final AI measurement. Field
validation with tape measure, rangefinder, or approved field tools is required.

Measurement result metadata includes:

- `fieldDistanceMeters`
- `distanceSource`

Supported distance sources:

- `gps_walk_measurement`
- `manual_input`
- `unavailable`

## Save And Offline Queue Behavior

Online scan save keeps distance metadata in scan notes until Laravel has
dedicated field distance columns.

Offline queued scans keep:

- `field_distance_m`
- `distance_source`
- `distance_start_latitude`
- `distance_start_longitude`
- `distance_start_accuracy_m`
- `distance_start_timestamp`
- `distance_target_latitude`
- `distance_target_longitude`
- `distance_target_accuracy_m`
- `distance_target_timestamp`
- `distance_accuracy_note`

TODO: Add field distance columns to backend scan records.

## Future AR Mode

Future AR Mode:

- Use ARCore anchor / hit test / depth support for visual distance measurement.
- This will allow a Pokemon Go-style camera overlay.
- Current version uses GPS walk measurement for safer field prototype.

No ARCore dependency or paid map/API key is required in the current prototype.
