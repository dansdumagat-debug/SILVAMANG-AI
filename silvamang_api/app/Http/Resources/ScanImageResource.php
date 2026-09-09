<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ScanImageResource extends JsonResource
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
            'plant_part' => $this->plant_part,
            'image_path' => $this->image_path,
            'image_url' => $this->image_path ? $request->getSchemeAndHttpHost() . '/storage/' . ltrim($this->image_path, '/') : null,
            'original_filename' => $this->original_filename,
            'mime_type' => $this->mime_type,
            'file_size' => $this->file_size,
            'width' => $this->width,
            'height' => $this->height,
            'local_uri' => $this->local_uri,
            'verified_species_id' => $this->verified_species_id,
            'verified_species' => $this->whenLoaded('verifiedSpecies', fn () => new SpeciesResource($this->verifiedSpecies)),
            'verified_plant_part' => $this->verified_plant_part,
            'dataset_status' => $this->dataset_status,
            'image_quality' => $this->image_quality,
            'verified_by' => ApiId::encode($this->verified_by),
            'verifier' => $this->whenLoaded('verifier', fn () => [
                'id' => ApiId::encode($this->verifier?->id),
                'name' => $this->verifier?->name,
                'email' => $this->verifier?->email,
            ]),
            'verified_at' => $this->verified_at,
            'rejection_reason' => $this->rejection_reason,
            'dataset_notes' => $this->dataset_notes,
            'dataset_exported_at' => $this->dataset_exported_at,
            'dataset_export_path' => $this->dataset_export_path,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
