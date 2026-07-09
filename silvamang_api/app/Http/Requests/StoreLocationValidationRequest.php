<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreLocationValidationRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'scan_record_id' => ['required', 'exists:scan_records,id'],
            'species_id' => ['nullable', 'exists:species,id'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'result' => ['nullable', 'string', Rule::in(['pending', 'match', 'mismatch', 'likely_found', 'unknown'])],
            'distance_to_known_distribution_km' => ['nullable', 'numeric', 'min:0'],
            'message' => ['nullable', 'string'],
            'validated_at' => ['nullable', 'date'],
        ];
    }
}
