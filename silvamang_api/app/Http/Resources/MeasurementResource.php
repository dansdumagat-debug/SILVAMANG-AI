<?php

namespace App\Http\Resources;

use App\Support\ApiId;
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
            'id' => ApiId::encode($this->id),
            'scan_record_id' => ApiId::encode($this->scan_record_id),
            'height_m' => $this->height_m !== null ? (float) $this->height_m : null,
            'canopy_width_m' => $this->canopy_width_m !== null ? (float) $this->canopy_width_m : null,
            'dbh_cm' => $this->dbh_cm !== null ? (float) $this->dbh_cm : null,
            'gbh_cm' => $this->gbh_cm !== null ? (float) $this->gbh_cm : null,
            'gbh_m' => $this->gbh_m !== null ? (float) $this->gbh_m : null,
            'dbh_m' => $this->dbh_m !== null ? (float) $this->dbh_m : null,
            'basal_area_m2' => $this->basal_area_m2 !== null ? (float) $this->basal_area_m2 : null,
            'canopy_1_m' => $this->canopy_1_m !== null ? (float) $this->canopy_1_m : null,
            'canopy_2_m' => $this->canopy_2_m !== null ? (float) $this->canopy_2_m : null,
            'measurement_method' => $this->measurement_method,
            'confidence' => $this->confidence !== null ? (float) $this->confidence : null,
            'notes' => $this->notes,
            'measured_at' => $this->measured_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
