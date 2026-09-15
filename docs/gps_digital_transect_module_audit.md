# GPS-Based Digital Transect Monitoring Module

## Architecture Audit

SILVAMANG AI already had the main building blocks needed for digital transects:

- Flutter authentication and an authenticated Dio API client
- GPS permission and current-location handling through `geolocator`
- Interactive maps through `flutter_map` and `latlong2`
- Online OpenStreetMap tiles and cache-aware satellite tiles
- Scan records containing ownership, species, images, measurements, notes, and GPS coordinates
- Hive-backed offline queue storage and connectivity-triggered synchronization
- Laravel API resources with encrypted public identifiers and role-based record access

The module reuses these components. It does not introduce a second map stack, login system, scan model, or offline database.

## Field Workflow

1. Open **Digital Transects** from the mobile Home screen.
2. Select **New Transect** and enter the transect name, location, date, and optional notes.
3. Choose one collection mode:
   - **GPS Walk** records the first accepted fix and appends meaningful movement while the researcher walks. Weak fixes above 50 m accuracy are rejected. Small GPS drift is filtered with an adaptive movement threshold.
   - **Manual Map** lets the researcher tap a start and end point. Further taps move the end point so correction is quick.
4. Attach existing scan observations. An attached observation keeps its species, image, height, canopy width, GPS position, and notes snapshot.
5. Save. The record is written locally first and uploaded when connectivity is available.

## Distance And Direction

The app and API calculate distance from the recorded polyline using the Haversine formula and Earth radius 6,371,000 m. Direction is the initial bearing from the first point to the final point. The server recalculates both values instead of trusting client totals.

For GPS walk mode, points are accepted when:

- reported accuracy is within the configured limit; and
- movement exceeds an adaptive 1.5 m to 5 m threshold; or
- at least eight seconds passed and movement is at least 1 m.

This reduces stationary drift while retaining slow field movement.

## Data Model

### `transects`

Stores owner, generated code, name, location, notes, collection mode, status, start/end coordinates, server-calculated distance and bearing, average GPS accuracy, GeoJSON-style geometry, offline reference, unresolved scan references, recording time, and sync time.

### `transect_points`

Stores ordered coordinates, accuracy, altitude, and timestamp. The `(transect_id, sequence_number)` pair is unique.

### `transect_observations`

Joins a transect to existing scan records. The `(transect_id, scan_record_id)` pair is unique, preventing duplicate attachments.

## Offline Synchronization

- A stable UUID is generated before local save and sent as `offline_reference`.
- Repeating an upload with the same reference updates the same server transect instead of creating a duplicate.
- Offline scan records use their own stable reference.
- On reconnect, pending scan records synchronize first. Transects synchronize second so observation links can resolve.
- If a scan has not reached the server, its reference remains in `pending_observation_references` and is retried later without losing the local observation snapshot.
- Mobile history is scoped to the authenticated user's local ID/email. The API enforces the same ownership boundary; authorized admin/research roles can view all records.

## Maps And Reporting

The mobile history/detail screens show the user's transects, sync state, distance, direction, points, attached scans, species distribution, and reconstructed path. Street tiles require internet; satellite tiles use the existing cache-aware provider.

The Laravel dashboard provides searchable/filterable transects, street/satellite map layers, start/end and observation markers, per-transect details, and CSV export for authorized users.

## Scientific Limitations

This feature is a GPS-based field documentation and distance-estimation tool. Consumer-phone GPS can be affected by canopy, device quality, weather, multipath interference, and satellite geometry. The module does not claim to replace formal ecological transect protocols, calibrated survey equipment, required replication, or expert validation.

## Verification Coverage

- Laravel unit test for polyline distance and bearing
- Laravel API tests for idempotent upload, unresolved-link retry, ownership isolation, role access, and CSV export
- Flutter tests for Haversine distance, direction, average accuracy, drift filtering, weak-fix rejection, local serialization, ownership, sync state, and API payload references

Before a field release, test outdoors on a known measured line, compare multiple phones, verify offline save/reconnect, and inspect exported coordinates in GIS software.
