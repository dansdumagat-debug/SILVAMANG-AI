<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AssistantLogResource extends JsonResource
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
            'user_id' => ApiId::encode($this->user_id),
            'scan_record_id' => ApiId::encode($this->scan_record_id),
            'question' => $this->question,
            'response' => $this->response,
            'intent' => $this->intent,
            'source' => $this->source,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
