<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ExternalSpeciesObservationResource extends JsonResource
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
            'species_id' => $this->species_id,
            'source' => $this->source,
            'source_observation_id' => $this->source_observation_id,
            'source_url' => $this->sourceUrl(),
            'photo_url' => $this->photo_url,
            'observer' => $this->observer,
            'location' => $this->location,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'observed_date' => $this->observed_date?->toDateString(),
            'quality_grade' => $this->quality_grade,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
            'species' => new SpeciesResource($this->whenLoaded('species')),
        ];
    }

    private function sourceUrl(): ?string
    {
        if ($this->source !== 'inaturalist' || ! $this->source_observation_id) {
            return null;
        }

        return "https://www.inaturalist.org/observations/{$this->source_observation_id}";
    }
}
