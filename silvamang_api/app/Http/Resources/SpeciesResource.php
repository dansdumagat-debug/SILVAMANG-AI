<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SpeciesResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'scientific_name' => $this->scientific_name,
            'common_name' => $this->common_name,
            'family' => $this->family,
            'genus' => $this->genus,
            'description' => $this->description,
            'habitat' => $this->habitat,
            'distribution_notes' => $this->distribution_notes,
            'ecological_role' => $this->ecological_role,
            'identification_notes' => $this->identification_notes,
            'conservation_status' => $this->conservation_status,
            'native_status' => $this->native_status,
            'max_height_m' => $this->max_height_m !== null ? (float) $this->max_height_m : null,
            'status' => $this->status,
            'images' => SpeciesImageResource::collection($this->whenLoaded('images')),
            'distributions' => SpeciesDistributionResource::collection($this->whenLoaded('distributions')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
