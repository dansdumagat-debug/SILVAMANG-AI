<?php

namespace App\Services;

use Illuminate\Http\Client\RequestException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Throwable;

class PythonAiService
{
    private ?int $lastStatusCode = null;
    private ?string $lastResponseMode = null;
    private ?string $lastError = null;

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
                'cnn' => $data['cnn'] ?? null,
                'measurement' => $data['measurement'] ?? null,
                'message' => $data['message'] ?? null,
            ];
        } catch (Throwable $error) {
            return $this->unavailable($error->getMessage());
        }
    }

    public function predict(array $payload = [], array $images = []): array
    {
        $this->lastStatusCode = null;
        $this->lastResponseMode = null;
        $this->lastError = null;

        try {
            $validImages = array_values(array_filter($images, fn ($image) => $image instanceof UploadedFile));
            $request = empty($validImages)
                ? $this->client()->asForm()
                : $this->multipartRequest($payload, $validImages[0]);

            $response = $request->post($this->url('/predict'), empty($validImages) ? $payload : []);
            $this->lastStatusCode = $response->status();

            if (! $response->successful()) {
                $this->lastError = "Python AI service returned HTTP {$response->status()}.";
                throw new RequestException($response);
            }

            $json = $response->json();
            $this->lastResponseMode = data_get($json, 'data.mode') ?? data_get($json, 'mode');

            return $json;
        } catch (Throwable $error) {
            $this->lastError ??= $error->getMessage();

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

    private function multipartRequest(array $payload, UploadedFile $image)
    {
        $request = $this->client()->attach(
            'image',
            fopen($image->getRealPath(), 'r'),
            $image->getClientOriginalName()
        );

        foreach ($payload as $key => $value) {
            if ($value === null) {
                continue;
            }

            if (is_array($value)) {
                foreach ($value as $item) {
                    if ($key === 'plant_parts') {
                        $request = $request->attach('plant_parts', (string) $item);
                        $request = $request->attach('plant_parts[]', (string) $item);
                    } else {
                        $request = $request->attach($key, (string) $item);
                    }
                }

                continue;
            }

            $request = $request->attach($key, (string) $value);
        }

        return $request;
    }

    public function lastStatusCode(): ?int
    {
        return $this->lastStatusCode;
    }

    public function lastResponseMode(): ?string
    {
        return $this->lastResponseMode;
    }

    public function lastError(): ?string
    {
        return $this->lastError;
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
