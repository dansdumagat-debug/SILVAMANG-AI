<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MapScanRecordResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $image = $this->relationLoaded('images') ? $this->images->first() : null;
        $measurement = $this->relationLoaded('measurement') ? $this->measurement : null;
        $validation = $this->relationLoaded('locationValidation') ? $this->locationValidation : null;
        $isMine = $this->user_id === $request->user()?->id;
        $canViewAll = $request->user()?->roles->contains(
            fn ($role) => in_array($role->name, ['super_admin', 'admin', 'researcher'], true)
        ) ?? false;

        return [
            'id' => ApiId::encode($this->id),
            'local_id' => ApiId::encode($this->id),
            'server_id' => ApiId::encode($this->id),
            'user_id' => ApiId::encode($this->user_id),
            'record_code' => $this->record_code,
            'scanner_name' => $this->user?->name ?? 'Unknown scanner',
            'is_mine' => $isMine,
            'can_view_record' => $isMine || $canViewAll,
            'species_name' => $this->top_scientific_name ?? $this->species?->scientific_name ?? 'Unknown species',
            'common_name' => $this->top_common_name ?? $this->species?->common_name,
            'confidence' => $this->confidence !== null ? (float) $this->confidence : null,
            'image_url' => $image?->image_path
                ? $request->getSchemeAndHttpHost() . '/storage/' . ltrim($image->image_path, '/')
                : null,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : ($validation?->latitude !== null ? (float) $validation->latitude : null),
            'longitude' => $this->longitude !== null ? (float) $this->longitude : ($validation?->longitude !== null ? (float) $validation->longitude : null),
            'accuracy' => $this->accuracy !== null ? (float) $this->accuracy : null,
            'barangay' => $this->barangay ?: $this->manual_barangay ?: $this->location_name,
            'location_source' => 'server_scan_record',
            'height_m' => $this->height_m !== null ? (float) $this->height_m : ($measurement?->height_m !== null ? (float) $measurement->height_m : null),
            'canopy_width_m' => $this->canopy_width_m !== null ? (float) $this->canopy_width_m : ($measurement?->canopy_width_m !== null ? (float) $measurement->canopy_width_m : null),
            'validation_status' => $this->validation_status,
            'sync_status' => 'synced',
            'captured_at' => ($this->captured_at ?? $this->created_at)?->toIso8601String(),
            'created_at' => ($this->captured_at ?? $this->created_at)?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
