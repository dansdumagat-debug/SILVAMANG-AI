<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreScanImageRequest extends FormRequest
{
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
            'scan_record_id' => ['required', 'exists:scan_records,id'],
            'plant_part' => ['required', 'string', Rule::in([
                'leaves',
                'bark',
                'roots',
                'flowers',
                'canopy',
                'full_tree',
                'other',
            ])],
            'image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
            'local_uri' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
