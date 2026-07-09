<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreMeasurementRequest extends FormRequest
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
            'height_m' => ['nullable', 'numeric', 'min:0'],
            'canopy_width_m' => ['nullable', 'numeric', 'min:0'],
            'dbh_cm' => ['nullable', 'numeric', 'min:0'],
            'measurement_method' => ['nullable', 'string', 'max:50'],
            'confidence' => ['nullable', 'numeric', 'between:0,100'],
            'notes' => ['nullable', 'string'],
            'measured_at' => ['nullable', 'date'],
        ];
    }
}
