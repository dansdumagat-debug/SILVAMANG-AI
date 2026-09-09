<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AiModelResource extends JsonResource
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
            'model_name' => $this->model_name,
            'model_type' => $this->model_type,
            'version' => $this->version,
            'accuracy' => $this->accuracy !== null ? (float) $this->accuracy : null,
            'precision_score' => $this->precision_score !== null ? (float) $this->precision_score : null,
            'recall_score' => $this->recall_score !== null ? (float) $this->recall_score : null,
            'f1_score' => $this->f1_score !== null ? (float) $this->f1_score : null,
            'top_k_accuracy' => $this->top_k_accuracy !== null ? (float) $this->top_k_accuracy : null,
            'status' => $this->status,
            'deployed_at' => $this->deployed_at,
            'notes' => $this->notes,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
