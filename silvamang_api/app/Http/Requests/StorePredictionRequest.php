<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use InvalidArgumentException;

class StorePredictionRequest extends FormRequest
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
            'rank' => ['required', 'integer', 'min:1'],
            'scientific_name' => ['required', 'string', 'max:255'],
            'common_name' => ['nullable', 'string', 'max:255'],
            'confidence' => ['required', 'numeric', 'between:0,100'],
            'model_name' => ['nullable', 'string', 'max:255'],
            'model_version' => ['nullable', 'string', 'max:255'],
        ];
    }
}
