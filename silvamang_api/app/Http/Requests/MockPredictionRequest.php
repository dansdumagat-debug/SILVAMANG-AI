<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class MockPredictionRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if ($this->filled('plant_part') && ! $this->has('plant_parts')) {
            $this->merge([
                'plant_parts' => [$this->input('plant_part')],
            ]);
        }

        if ($this->has('plant_parts') && ! is_array($this->input('plant_parts'))) {
            $this->merge([
                'plant_parts' => [$this->input('plant_parts')],
            ]);
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png', 'max:10240'],
            'images' => ['nullable'],
            'images.*' => ['nullable', 'image', 'mimes:jpg,jpeg,png', 'max:10240'],
            'plant_part' => ['nullable', 'string', Rule::in([
                'leaves',
                'bark',
                'roots',
                'flowers',
                'canopy',
                'full_tree',
                'other',
            ])],
            'plant_parts' => ['nullable', 'array'],
            'plant_parts.*' => ['nullable', 'string', Rule::in([
                'leaves',
                'bark',
                'roots',
                'flowers',
                'canopy',
                'full_tree',
                'other',
            ])],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ];
    }
}
