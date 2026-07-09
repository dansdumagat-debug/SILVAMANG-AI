<?php

namespace App\Http\Resources;

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
            'id' => $this->id,
            'scan_record_id' => $this->scan_record_id,
            'plant_part' => $this->plant_part,
            'image_path' => $this->image_path,
            'image_url' => $this->image_path ? $request->getSchemeAndHttpHost() . '/storage/' . ltrim($this->image_path, '/') : null,
            'original_filename' => $this->original_filename,
            'mime_type' => $this->mime_type,
            'file_size' => $this->file_size,
            'width' => $this->width,
            'height' => $this->height,
            'local_uri' => $this->local_uri,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
