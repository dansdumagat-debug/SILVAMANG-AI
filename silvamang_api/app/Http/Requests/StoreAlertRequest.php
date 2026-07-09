<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreAlertRequest extends FormRequest
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
            'alert_type' => ['required', 'string', 'max:50'],
            'severity' => ['nullable', 'string', 'max:50'],
            'title' => ['required', 'string', 'max:255'],
            'message' => ['nullable', 'string'],
            'related_scan_record_id' => ['nullable', 'exists:scan_records,id'],
            'status' => ['nullable', 'string', 'max:50'],
        ];
    }
}
