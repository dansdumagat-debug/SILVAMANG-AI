<?php

namespace App\Http\Requests;

use App\Support\ApiId;
use Illuminate\Foundation\Http\FormRequest;
use InvalidArgumentException;

class AssistantChatRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (! $this->filled('scan_record_id')) {
            return;
        }

        try {
            $this->merge([
                'scan_record_id' => ApiId::decodeOrFail(
                    $this->input('scan_record_id'),
                    allowPlainNumeric: ! $this->is('api/*')
                ),
            ]);
        } catch (InvalidArgumentException) {
            abort(400, 'Invalid scan record ID.');
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'question' => ['nullable', 'required_without:message', 'string', 'min:2', 'max:2000'],
            'message' => ['nullable', 'required_without:question', 'string', 'min:2', 'max:2000'],
            'context' => ['nullable', 'string', 'max:4000'],
            'scan_record_id' => ['nullable', 'exists:scan_records,id'],
            'history' => ['nullable', 'array', 'max:12'],
            'history.*.role' => ['required_with:history', 'string', 'in:user,assistant'],
            'history.*.content' => ['required_with:history', 'string', 'max:2000'],
        ];
    }
}
