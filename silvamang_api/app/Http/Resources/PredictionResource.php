<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PredictionResource extends JsonResource
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
            'rank' => $this->rank,
            'scientific_name' => $this->scientific_name,
            'common_name' => $this->common_name,
            'confidence' => (float) $this->confidence,
            'model_name' => $this->model_name,
            'model_version' => $this->model_version,
            'species' => new SpeciesResource($this->whenLoaded('species')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
