<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateTransectRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'transect_name' => ['sometimes', 'required', 'string', 'max:255'],
            'location_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'mode' => ['sometimes', 'required', Rule::in(['gps_tracking', 'manual_points'])],
            'status' => ['sometimes', Rule::in(['draft', 'completed'])],
            'recorded_at' => ['sometimes', 'nullable', 'date'],
            'points' => ['sometimes', 'required', 'array', 'min:2', 'max:5000'],
            'points.*.latitude' => ['required_with:points', 'numeric', 'between:-90,90'],
            'points.*.longitude' => ['required_with:points', 'numeric', 'between:-180,180'],
            'points.*.accuracy_m' => ['nullable', 'numeric', 'min:0', 'max:10000'],
            'points.*.altitude_m' => ['nullable', 'numeric', 'between:-1000,10000'],
            'points.*.recorded_at' => ['nullable', 'date'],
            'observation_references' => ['sometimes', 'nullable', 'array', 'max:500'],
            'observation_references.*' => ['required', 'string', 'max:512'],
        ];
    }
}
