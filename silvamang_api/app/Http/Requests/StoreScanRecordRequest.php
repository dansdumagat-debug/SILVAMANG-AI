<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use InvalidArgumentException;

class StoreScanRecordRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (! $this->filled('user_id')) {
            return;
        }

        try {
            $this->merge([
                'user_id' => ApiId::decodeOrFail($this->input('user_id')),
            ]);
        } catch (InvalidArgumentException) {
            abort(400, 'Invalid user ID.');
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
            'record_code' => ['nullable', 'string', 'max:255', 'unique:scan_records,record_code'],
            'user_id' => ['nullable', 'exists:users,id'],
            'species_id' => ['nullable', 'exists:species,id'],
            'top_scientific_name' => ['nullable', 'string', 'max:255'],
            'top_common_name' => ['nullable', 'string', 'max:255'],
            'confidence' => ['nullable', 'numeric', 'between:0,100'],
            'capture_mode' => ['nullable', 'string', 'max:50'],
            'identification_status' => ['nullable', 'string', 'max:50'],
            'validation_status' => ['nullable', 'string', 'max:50'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'accuracy' => ['nullable', 'numeric', 'min:0'],
            'location_name' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'manual_barangay' => ['nullable', 'string', 'max:255'],
            'location_lookup_status' => ['nullable', 'string', 'max:255'],
            'height_m' => ['nullable', 'numeric', 'min:0'],
            'canopy_width_m' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'offline_reference' => ['nullable', 'string', 'max:255'],
            'captured_at' => ['nullable', 'date'],
            'synced_at' => ['nullable', 'date'],
        ];
    }
}
