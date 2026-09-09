<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use InvalidArgumentException;

class StoreLocationValidationRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (! $this->filled('scan_record_id')) {
            return;
        }

        try {
            $this->merge([
                'scan_record_id' => ApiId::decodeOrFail($this->input('scan_record_id')),
            ]);
        } catch (InvalidArgumentException) {
            abort(400, 'Invalid scan record ID.');
        }
    }

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
