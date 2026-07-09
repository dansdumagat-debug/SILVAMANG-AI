<?php

namespace App\Services;

use Illuminate\Http\Client\RequestException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Throwable;

class PythonAiService
{
    public function health(): array
    {
        try {
            $response = $this->client()->get($this->url('/health'));

            if (! $response->successful()) {
                return $this->unavailable("AI service returned HTTP {$response->status()}.");
            }

            $data = $response->json();

            return [
                'available' => true,
                'status' => $data['status'] ?? 'ok',
                'service' => $data['service'] ?? null,
                'mode' => $data['mode'] ?? null,
                'version' => $data['version'] ?? null,
                'message' => $data['message'] ?? null,
            ];
        } catch (Throwable $error) {
            return $this->unavailable($error->getMessage());
        }
    }

    public function predict(array $payload = [], array $images = []): array
    {
        try {
            $validImages = array_values(array_filter($images, fn ($image) => $image instanceof UploadedFile));
            $request = empty($validImages)
                ? $this->client()->asForm()
                : $this->client()->withOptions(['multipart' => $this->multipartPayload($payload, $validImages)]);

            $response = $request->post($this->url('/predict'), empty($validImages) ? $payload : []);

            if (! $response->successful()) {
                throw new RequestException($response);
            }

            return $response->json();
        } catch (Throwable $error) {
            throw new \RuntimeException(
                'Python AI service is unavailable. Using Laravel fallback mock prediction.',
                previous: $error
            );
        }
    }

    public function measure(array $payload = [], ?UploadedFile $image = null): array
    {
        try {
            $request = $this->client();

            if ($image instanceof UploadedFile) {
                $request = $request->attach(
                    'image',
                    fopen($image->getRealPath(), 'r'),
                    $image->getClientOriginalName()
                );
            }

            $response = $request->post($this->url('/measure'), $payload);

            if (! $response->successful()) {
                throw new RequestException($response);
            }

            return $response->json();
        } catch (Throwable $error) {
            throw new \RuntimeException(
                'Python AI service is unavailable. Using Laravel fallback mock measurement.',
                previous: $error
            );
        }
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

    private function multipartPayload(array $payload, array $images): array
    {
        $multipart = [];

        foreach ($payload as $key => $value) {
            if ($value === null) {
                continue;
            }

            if (is_array($value)) {
                foreach ($value as $item) {
                    $multipart[] = [
                        'name' => $key,
                        'contents' => (string) $item,
                    ];
                }

                continue;
            }

            $multipart[] = [
                'name' => $key,
                'contents' => (string) $value,
            ];
        }

        foreach ($images as $image) {
            $multipart[] = [
                'name' => 'images',
                'contents' => fopen($image->getRealPath(), 'r'),
                'filename' => $image->getClientOriginalName(),
            ];
        }

        return $multipart;
    }

    private function unavailable(string $message): array
    {
        return [
            'available' => false,
            'status' => 'unavailable',
            'service' => null,
            'mode' => config('services.ai_service.mode', 'mock'),
            'version' => null,
            'message' => $message,
        ];
    }
}
