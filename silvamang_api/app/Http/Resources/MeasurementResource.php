<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MeasurementResource extends JsonResource
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
            'height_m' => $this->height_m !== null ? (float) $this->height_m : null,
            'canopy_width_m' => $this->canopy_width_m !== null ? (float) $this->canopy_width_m : null,
            'dbh_cm' => $this->dbh_cm !== null ? (float) $this->dbh_cm : null,
            'measurement_method' => $this->measurement_method,
            'confidence' => $this->confidence !== null ? (float) $this->confidence : null,
            'notes' => $this->notes,
            'measured_at' => $this->measured_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
