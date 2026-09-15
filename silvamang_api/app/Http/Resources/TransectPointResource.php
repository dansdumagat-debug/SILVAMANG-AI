<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransectPointResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => ApiId::encode($this->id),
            'sequence_number' => $this->sequence_number,
            'latitude' => (float) $this->latitude,
            'longitude' => (float) $this->longitude,
            'accuracy_m' => $this->accuracy_m !== null ? (float) $this->accuracy_m : null,
            'altitude_m' => $this->altitude_m !== null ? (float) $this->altitude_m : null,
            'recorded_at' => $this->recorded_at,
        ];
    }
}
