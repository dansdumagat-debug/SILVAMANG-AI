<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use InvalidArgumentException;

class UpdateAlertRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (! $this->filled('related_scan_record_id')) {
            return;
        }

        try {
            $this->merge([
                'related_scan_record_id' => ApiId::decodeOrFail($this->input('related_scan_record_id')),
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
            'alert_type' => ['sometimes', 'required', 'string', 'max:50'],
            'severity' => ['nullable', 'string', 'max:50'],
            'title' => ['sometimes', 'required', 'string', 'max:255'],
            'message' => ['nullable', 'string'],
            'related_scan_record_id' => ['nullable', 'exists:scan_records,id'],
            'status' => ['nullable', 'string', 'max:50'],
        ];
    }
}
