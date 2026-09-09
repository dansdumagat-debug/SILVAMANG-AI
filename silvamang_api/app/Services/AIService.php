<?php

namespace App\Services;

use Illuminate\Http\Client\RequestException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Throwable;

class AIService
{
    public function health(): array
    {
        return $this->get('/ai/health');
    }

    public function classify(array $payload = [], ?UploadedFile $image = null): array
    {
        return $this->post('/ai/classify', $payload, $image);
    }

    public function detect(array $payload = [], ?UploadedFile $image = null): array
    {
        return $this->post('/ai/detect', $payload, $image);
    }

    public function segment(array $payload = [], ?UploadedFile $image = null): array
    {
        return $this->post('/ai/segment', $payload, $image);
    }

    public function measure(array $payload = [], ?UploadedFile $image = null): array
    {
        return $this->post('/ai/measure', $payload, $image);
    }

    private function get(string $path): array
    {
        try {
            $response = $this->client()->get($this->url($path));

            if (! $response->successful()) {
                throw new RequestException($response);
            }

            return $response->json() ?? [];
        } catch (Throwable $error) {
            return [
                'status' => 'error',
                'message' => 'Python AI service unavailable',
                'error' => $error->getMessage(),
            ];
        }
    }

    private function post(string $path, array $payload, ?UploadedFile $image): array
    {
        try {
            $request = $image instanceof UploadedFile
                ? $this->multipartClient($image)
                : $this->client()->asForm();

            $response = $request->post($this->url($path), $this->cleanPayload($payload));

            if (! $response->successful()) {
                throw new RequestException($response);
            }

            return $response->json() ?? [];
        } catch (Throwable $error) {
            return [
                'status' => 'error',
                'message' => 'Python AI service unavailable',
                'error' => $error->getMessage(),
            ];
        }
    }

    private function multipartClient(UploadedFile $image)
    {
        return $this->client()->attach(
            'image',
            fopen($image->getRealPath(), 'r'),
            $image->getClientOriginalName()
        );
    }

    private function client()
    {
        return Http::acceptJson()
            ->timeout((int) config('services.ai_service.timeout', 30));
    }

    private function url(string $path): string
    {
        return rtrim((string) config('services.ai_service.url', 'http://127.0.0.1:9000'), '/') . $path;
    }

    private function cleanPayload(array $payload): array
    {
        return array_filter($payload, fn ($value) => $value !== null && $value !== '');
    }
}
