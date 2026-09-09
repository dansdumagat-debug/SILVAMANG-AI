<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AlertResource extends JsonResource
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
            'alert_type' => $this->alert_type,
            'severity' => $this->severity,
            'title' => $this->title,
            'message' => $this->message,
            'related_scan_record_id' => ApiId::encode($this->related_scan_record_id),
            'status' => $this->status,
            'related_scan_record' => new ScanRecordResource($this->whenLoaded('relatedScanRecord')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
