<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ScanRecordResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => ApiId::encode($this->id),
            'user_id' => ApiId::encode($this->user_id),
            'species_id' => $this->species_id,
            'record_code' => $this->record_code,
            'top_scientific_name' => $this->top_scientific_name,
            'top_common_name' => $this->top_common_name,
            'confidence' => $this->confidence !== null ? (float) $this->confidence : null,
            'capture_mode' => $this->capture_mode,
            'identification_status' => $this->identification_status,
            'validation_status' => $this->validation_status,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'accuracy' => $this->accuracy !== null ? (float) $this->accuracy : null,
            'location_name' => $this->location_name,
            'address' => $this->address,
            'barangay' => $this->barangay,
            'manual_barangay' => $this->manual_barangay,
            'location_lookup_status' => $this->location_lookup_status,
            'height_m' => $this->height_m !== null ? (float) $this->height_m : null,
            'canopy_width_m' => $this->canopy_width_m !== null ? (float) $this->canopy_width_m : null,
            'notes' => $this->notes,
            'offline_reference' => $this->offline_reference,
            'captured_at' => $this->captured_at,
            'synced_at' => $this->synced_at,
            'species' => new SpeciesResource($this->whenLoaded('species')),
            'images' => ScanImageResource::collection($this->whenLoaded('images')),
            'predictions' => PredictionResource::collection($this->whenLoaded('predictions')),
            'measurement' => new MeasurementResource($this->whenLoaded('measurement')),
            'location_validation' => new LocationValidationResource($this->whenLoaded('locationValidation')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
