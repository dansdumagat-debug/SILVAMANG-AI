# Barangay Location Guide

GPS only provides coordinates: latitude, longitude, accuracy, and timestamp.
It does not automatically provide the barangay name.

GPS cannot directly produce barangay. Accurate barangay lookup requires
official barangay boundary GeoJSON or an approved reverse geocoding service.

To show an accurate barangay, SILVAMANG AI needs either:

- online reverse geocoding from an approved service, or
- offline barangay boundary data in GeoJSON format.

For an offline barangay lookup, use official LGU or government barangay
boundary data converted to GeoJSON.

Recommended sources include LGU GIS offices, PSA/NAMRIA datasets, or an
OpenStreetMap-derived project source only when approved by the adviser.

Use official LGU/NAMRIA/approved boundary data whenever possible. The app must
not invent barangay names and must not use fake fallback coordinates.

Local file path:

```text
silvamang_mobile/assets/geo/barangay_boundaries.geojson
```

The app includes a valid empty placeholder file at this path so builds do not
fail when official boundary data is not ready yet.

If the boundary file is empty, the app correctly shows:

```text
Barangay: Not available
Lookup: Barangay boundary data is not available.
```

The GeoJSON file must be a `FeatureCollection`.

Each GeoJSON feature should include a barangay name property such as:

- `barangay`
- `brgy`
- `name`
- `Name`
- `brgy_name`
- `BRGY_NAME`
- `ADM4_EN`
- `ADM4_NAME`

The app must not invent barangay names. If boundary data is missing, incomplete,
or does not contain the scan coordinate, the app should show:

```text
Barangay: Not available
```

GPS accuracy affects barangay accuracy. If accuracy is around 30-60 meters, the
scan may be near a boundary and the barangay result may be uncertain.
