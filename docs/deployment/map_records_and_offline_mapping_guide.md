# Map Records and Offline Mapping Guide

## Purpose of Map Records

SILVAMANG AI stores each saved mangrove scan as a map-ready record so field observations can be reviewed geographically. A map record can include the identified species, confidence, GPS coordinates, barangay lookup result, image thumbnail path, measurement data, and sync status.

## Online Map Mode

When the phone has internet access, the map uses satellite imagery tiles through `flutter_map`.

Online behavior:

- Shows a real global slippy map, not a fixed San Ramon-only drawing.
- Loads map tiles normally.
- Uses cached tiles when available.
- Can update/create cached map tiles while browsing.
- Shows saved scan pins when latitude and longitude exist.
- Keeps local pins visible even if tile loading fails.
- Lets users choose a species filter, then tap each scan pin to view that record.

No Google Maps API key is required.

## Offline Map Mode

When the phone is offline, the map attempts to use downloaded/cached map tiles.

Offline behavior:

- Uses cached tiles only.
- Shows `Offline map not downloaded for this area.` if no tiles exist.
- Still shows local scan pins if records have coordinates.
- Does not block scan saving if map tiles are unavailable.

## Local Scan Record Storage

Flutter stores local map records using the existing offline sync storage foundation.

Each local map record may contain:

- Local ID
- Optional Laravel server ID
- User email/user ownership marker
- Scientific name
- Common name
- Confidence
- Image path
- Latitude and longitude
- GPS accuracy
- Barangay
- Manual barangay note
- Barangay lookup status
- Height/canopy/field distance values
- Notes
- Sync status
- Created/updated timestamps

Records without latitude/longitude can still be saved for history, but they will not appear as map pins.

## Scan Pins and Sync Status

Map pin colors indicate sync state:

- Green: synced
- Orange: pending sync or local only
- Red: failed sync
- Blue: selected/current scan

Tapping a pin opens scan details such as species, confidence, barangay, scan date, sync status, coordinates, and thumbnail if available.

## Barangay GeoJSON Lookup

GPS only provides latitude and longitude. Barangay names require boundary polygons.

The app uses:

```text
silvamang_mobile/assets/geo/barangay_boundaries.geojson
```

The file must be a GeoJSON `FeatureCollection`. GeoJSON coordinates must be in `[longitude, latitude]` order.

Supported geometry types:

- Polygon
- MultiPolygon

Supported property names:

- `barangay`
- `brgy`
- `brgy_name`
- `BRGY_NAME`
- `name`
- `Name`
- `ADM4_EN`
- `ADM4_NAME`

If the GeoJSON file is empty, the app shows:

```text
Barangay: Not available
Lookup: Barangay boundary data is not available.
```

If no polygon contains the GPS point, the app shows:

```text
Barangay: Not available
Lookup: Barangay boundary not found for this coordinate.
```

Manual barangay can be entered as a field note, but it is stored separately as `manualBarangay` and is not GPS-verified.

## Offline Tile Caching

Offline tiles are handled through `flutter_map_tile_caching`.

The offline download page lets users download satellite map tiles around Southern Leyte or the current phone GPS area with radius choices:

- 1 km
- 3 km
- 5 km
- 10 km
- 25 km
- 50 km

Users should download the municipality or field area before going offline. The Offline Map Manager includes a Southern Leyte preset so field users can prepare map tiles for Southern Leyte even before standing at the scan site. Users can also switch to the current GPS area when they need a smaller local package. Downloaded tiles can be cleared from the app if storage needs to be reclaimed.

Large satellite downloads are slower than street-map downloads. To keep the 50 km Southern Leyte package practical, the app downloads a faster broad-coverage zoom range for large areas and reserves high-detail zoom levels for smaller areas:

- 50 km: zoom 9-13
- 25 km: zoom 10-14
- 10 km: zoom 11-15
- 1-5 km: zoom 12-16

For fastest field prep, download the 50 km Southern Leyte package first, then download smaller 1-10 km areas for sites that need close-up detail.

If barangay boundary data is not available yet, the app can still download map tiles. The map will work visually offline, but barangay auto-fill will remain unavailable until official boundary polygons are added.

Do not try to download the whole world or the whole Philippines for offline use on a phone. Offline map tiles become very large quickly. Download Southern Leyte or the specific municipalities/field areas where scanning will happen.

GPS still works without internet. Offline map download only prepares the visual base map; the saved scan pin still uses the phone's real GPS latitude and longitude at scan time.

Barangay auto-fill requires official boundary polygons for those municipalities in:

```text
silvamang_mobile/assets/geo/barangay_boundaries.geojson
```

Map tiles only show the visual map. They do not contain barangay names.

## Laravel Sync

Local map records can be synced to Laravel scan records when authenticated and online.

Sync behavior:

- Pending local records are uploaded to Laravel.
- Successful uploads become `synced`.
- The returned Laravel server ID is stored locally.
- Failed uploads remain visible locally and are marked `failed` or kept pending depending on the sync path.
- Normal Laravel authentication controls server-side ownership.

Nullable map/location fields prepared for future map queries:

- `accuracy`
- `barangay`
- `manual_barangay`
- `location_lookup_status`
- `height_m`
- `canopy_width_m`

## Limitations

- GPS accuracy affects pin precision.
- Barangay requires real boundary GeoJSON data.
- The placeholder GeoJSON has no features until real barangay polygons are added.
- Add official barangay polygons for every municipality where the system will be used.
- Offline map display requires tiles to be downloaded before field use.
- Scan pins can still appear offline even when map tiles are missing.
- Manual barangay notes are not GPS-verified.

## Testing Checklist

- Start Laravel backend.
- Log in to the Flutter app.
- Enable location permission on the phone.
- Confirm GPS latitude/longitude appears after scanning.
- Confirm barangay lookup status appears.
- Add real barangay boundary GeoJSON if barangay auto-tagging is required.
- Save an observation with latitude/longitude.
- Open the map records screen and confirm a pin appears.
- Tap the pin and confirm species, confidence, date, coordinates, barangay/manual barangay, and sync status.
- Download an offline map area while online.
- Disable internet or use airplane mode.
- Open the map and confirm cached tiles show if available.
- Confirm local pins still show even if base tiles are unavailable.
- Reconnect internet.
- Sync pending map records and confirm status changes to synced.
