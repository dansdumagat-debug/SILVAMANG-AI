<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransectResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => ApiId::encode($this->id),
            'user_id' => ApiId::encode($this->user_id),
            'transect_code' => $this->transect_code,
            'transect_name' => $this->transect_name,
            'location_name' => $this->location_name,
            'description' => $this->description,
            'mode' => $this->mode,
            'status' => $this->status,
            'start_latitude' => (float) $this->start_latitude,
            'start_longitude' => (float) $this->start_longitude,
            'end_latitude' => (float) $this->end_latitude,
            'end_longitude' => (float) $this->end_longitude,
            'total_distance_m' => (float) $this->total_distance_m,
            'target_distance_m' => $this->target_distance_m !== null ? (float) $this->target_distance_m : null,
            'contributions' => $this->contributions ?? [],
            'handoff_sequence' => $this->handoff_sequence,
            'bearing_degrees' => $this->bearing_degrees !== null ? (float) $this->bearing_degrees : null,
            'direction' => $this->directionLabel($this->bearing_degrees),
            'gps_accuracy_m' => $this->gps_accuracy_m !== null ? (float) $this->gps_accuracy_m : null,
            'geometry' => $this->geometry,
            'offline_reference' => $this->offline_reference,
            'pending_observation_references' => $this->pending_observation_references ?? [],
            'point_count' => $this->relationLoaded('points') ? $this->points->count() : null,
            'observation_count' => $this->relationLoaded('observations') ? $this->observations->count() : null,
            'researcher' => $this->whenLoaded('user', fn () => [
                'id' => ApiId::encode($this->user?->id),
                'name' => $this->user?->name,
            ]),
            'points' => TransectPointResource::collection($this->whenLoaded('points')),
            'observations' => $this->whenLoaded('observations', function () use ($request) {
                return $this->observations->map(function ($record) use ($request) {
                    $validation = $record->relationLoaded('locationValidation')
                        ? $record->locationValidation
                        : null;
                    $latitude = $record->latitude ?? $validation?->latitude;
                    $longitude = $record->longitude ?? $validation?->longitude;
                    $image = $record->relationLoaded('images') ? $record->images->first() : null;

                    return [
                        'id' => ApiId::encode($record->id),
                        'offline_reference' => $record->offline_reference,
                        'record_code' => $record->record_code,
                        'scientific_name' => $record->top_scientific_name ?? $record->species?->scientific_name,
                        'common_name' => $record->top_common_name ?? $record->species?->common_name,
                        'height_m' => $record->height_m !== null
                            ? (float) $record->height_m
                            : ($record->measurement?->height_m !== null ? (float) $record->measurement->height_m : null),
                        'canopy_width_m' => $record->canopy_width_m !== null
                            ? (float) $record->canopy_width_m
                            : ($record->measurement?->canopy_width_m !== null ? (float) $record->measurement->canopy_width_m : null),
                        'latitude' => $latitude !== null ? (float) $latitude : null,
                        'longitude' => $longitude !== null ? (float) $longitude : null,
                        'accuracy_m' => $record->accuracy !== null ? (float) $record->accuracy : null,
                        'location_name' => $record->barangay
                            ?: $record->manual_barangay
                            ?: $record->location_name
                            ?: $record->address,
                        'notes' => $record->notes,
                        'image_url' => $image?->image_path
                            ? $request->getSchemeAndHttpHost() . '/storage/' . ltrim($image->image_path, '/')
                            : null,
                        'captured_at' => $record->captured_at,
                    ];
                })->values();
            }),
            'species_distribution' => $this->relationLoaded('observations')
                ? $this->observations
                    ->groupBy(fn ($record) => $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Unidentified')
                    ->map(fn ($records, $name) => ['species' => $name, 'count' => $records->count()])
                    ->values()
                : [],
            'recorded_at' => $this->recorded_at,
            'synced_at' => $this->synced_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }

    private function directionLabel(mixed $bearing): ?string
    {
        if ($bearing === null) {
            return null;
        }

        $labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
        $index = (int) round(((float) $bearing) / 45) % 8;

        return $labels[$index];
    }
}
