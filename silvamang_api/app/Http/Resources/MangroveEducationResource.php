<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MangroveEducationResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $species = $this->resource->relationLoaded('species') ? $this->species : null;

        return [
            'id' => ApiId::encode($this->id),
            'species_id' => ApiId::encode($this->species_id),
            'scientific_name' => $species?->scientific_name,
            'display_name' => $species?->scientific_name,
            'common_name' => $species?->common_name,
            'family' => $species?->family,
            'overview' => $this->overview,
            'description' => $this->overview,
            'physical_characteristics' => $this->physical_characteristics ?? [],
            'leaf_characteristics' => $this->leaf_characteristics,
            'root_characteristics' => $this->root_characteristics,
            'habitat' => $this->habitat ?? [],
            'distribution' => $this->distribution ?? [],
            'ecological_importance' => $this->ecological_importance ?? [],
            'history' => $this->history,
            'scientific_study' => $this->scientific_study,
            'conservation_information' => $this->conservation_information ?? [],
            'conservation_note' => implode(' ', array_slice($this->conservation_information ?? [], 0, 2)),
            'interesting_facts' => $this->interesting_facts ?? [],
            'trivia' => $this->interesting_facts ?? [],
            'references' => $this->references ?? [],
            'location_validation_hint' => 'commonly_found',
            'status' => $this->status,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
