<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use InvalidArgumentException;

class StoreAssistantLogRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        foreach (['user_id', 'scan_record_id'] as $key) {
            if (! $this->filled($key)) {
                continue;
            }

            try {
                $this->merge([
                    $key => ApiId::decodeOrFail($this->input($key)),
                ]);
            } catch (InvalidArgumentException) {
                abort(400, 'Invalid ID.');
            }
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
            'user_id' => ['nullable', 'exists:users,id'],
            'scan_record_id' => ['nullable', 'exists:scan_records,id'],
            'question' => ['nullable', 'string'],
            'response' => ['nullable', 'string'],
            'intent' => ['nullable', 'string', 'max:255'],
            'source' => ['nullable', 'string', 'max:255'],
        ];
    }
}
