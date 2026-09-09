<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use InvalidArgumentException;

class StoreMeasurementRequest extends FormRequest
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
            'height_m' => ['nullable', 'numeric', 'min:0.001', 'required_without_all:canopy_width_m,dbh_cm'],
            'canopy_width_m' => ['nullable', 'numeric', 'min:0.001', 'required_without_all:height_m,dbh_cm'],
            'dbh_cm' => ['nullable', 'numeric', 'min:0.001', 'required_without_all:height_m,canopy_width_m'],
            'measurement_method' => ['nullable', 'string', 'max:50'],
            'confidence' => ['nullable', 'numeric', 'between:0,100'],
            'notes' => ['nullable', 'string'],
            'measured_at' => ['nullable', 'date'],
        ];
    }
}
