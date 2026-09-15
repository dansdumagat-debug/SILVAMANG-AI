<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreTransectRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'transect_name' => ['required', 'string', 'max:255'],
            'location_name' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:5000'],
            'mode' => ['required', Rule::in(['gps_tracking', 'manual_points'])],
            'status' => ['nullable', Rule::in(['draft', 'completed'])],
            'offline_reference' => ['nullable', 'string', 'max:255'],
            'recorded_at' => ['nullable', 'date'],
            'points' => ['required', 'array', 'min:2', 'max:5000'],
            'points.*.latitude' => ['required', 'numeric', 'between:-90,90'],
            'points.*.longitude' => ['required', 'numeric', 'between:-180,180'],
            'points.*.accuracy_m' => ['nullable', 'numeric', 'min:0', 'max:10000'],
            'points.*.altitude_m' => ['nullable', 'numeric', 'between:-1000,10000'],
            'points.*.recorded_at' => ['nullable', 'date'],
            'observation_references' => ['nullable', 'array', 'max:500'],
            'observation_references.*' => ['required', 'string', 'max:512'],
        ];
    }
}
