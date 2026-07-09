<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateSpeciesRequest extends FormRequest
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
        $species = $this->route('species');

        return [
            'scientific_name' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('species', 'scientific_name')->ignore($species?->id)],
            'common_name' => ['nullable', 'string', 'max:255'],
            'family' => ['nullable', 'string', 'max:255'],
            'genus' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'habitat' => ['nullable', 'string'],
            'distribution_notes' => ['nullable', 'string'],
            'ecological_role' => ['nullable', 'string'],
            'identification_notes' => ['nullable', 'string'],
            'conservation_status' => ['nullable', 'string', 'max:255'],
            'native_status' => ['nullable', 'string', 'max:255'],
            'max_height_m' => ['nullable', 'numeric', 'min:0'],
            'status' => ['nullable', 'string', 'max:50'],
        ];
    }
}
