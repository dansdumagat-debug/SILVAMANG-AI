<?php

namespace App\Http\Resources;

use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $roles = $this->whenLoaded(
            'roles',
            fn () => $this->roles->pluck('name')->values(),
            collect()
        );

        return [
            'id' => ApiId::encode($this->id),
            'name' => $this->name,
            'email' => $this->email,
            'role' => $roles->first(),
            'roles' => $roles,
        ];
    }
}
