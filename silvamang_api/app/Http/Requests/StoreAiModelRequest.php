<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreAiModelRequest extends FormRequest
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
            'model_name' => ['required', 'string', 'max:255'],
            'model_type' => ['required', 'string', 'max:50'],
            'version' => ['nullable', 'string', 'max:50'],
            'accuracy' => ['nullable', 'numeric', 'between:0,100'],
            'precision_score' => ['nullable', 'numeric', 'between:0,100'],
            'recall_score' => ['nullable', 'numeric', 'between:0,100'],
            'f1_score' => ['nullable', 'numeric', 'between:0,100'],
            'top_k_accuracy' => ['nullable', 'numeric', 'between:0,100'],
            'status' => ['nullable', 'string', 'max:50'],
            'deployed_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
        ];
    }
}
