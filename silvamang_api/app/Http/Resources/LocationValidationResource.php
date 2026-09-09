<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class LocationValidationResource extends JsonResource
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
            'scan_record_id' => ApiId::encode($this->scan_record_id),
            'species_id' => $this->species_id,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'result' => $this->result,
            'distance_to_known_distribution_km' => $this->distance_to_known_distribution_km !== null ? (float) $this->distance_to_known_distribution_km : null,
            'message' => $this->message,
            'validated_at' => $this->validated_at,
            'species' => new SpeciesResource($this->whenLoaded('species')),
            'scan_record' => new ScanRecordResource($this->whenLoaded('scanRecord')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
