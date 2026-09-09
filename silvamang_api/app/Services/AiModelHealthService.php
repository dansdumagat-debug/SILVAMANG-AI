<?php

namespace App\Services;

use App\Models\AiModel;

class AiModelHealthService
{
    public function __construct(private readonly AIService $aiService)
    {
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function refreshStatuses(): array
    {
        try {
            $health = $this->aiService->health();
        } catch (\Throwable) {
            $health = [
                'models' => [],
                'errors' => [
                    'cnn' => 'Python AI service is unavailable.',
                    'yolov8' => 'Python AI service is unavailable.',
                    'segmentation' => 'Python AI service is unavailable.',
                    'midas' => 'Python AI service is unavailable.',
                ],
            ];
        }

        if (! is_array($health)) {
            $health = [];
        }

        $checkedAt = now();
        $details = [];

        foreach (AiModel::query()->get() as $model) {
            $modelHealth = $this->healthForModel($model, $health, $checkedAt);

            $model->forceFill([
                'status' => $modelHealth['available'] ? 'active' : 'inactive',
            ])->save();

            $details[$model->id] = $modelHealth;
        }

        return $details;
    }

    /**
     * @return array<string, mixed>
     */
    private function healthForModel(AiModel $model, array $health, mixed $checkedAt): array
    {
        $endpoint = $this->endpointForModel($model);
        $healthKey = $this->healthKeyForModel($model);
        $available = $healthKey !== null
            ? (bool) data_get($health, "models.{$healthKey}", false)
            : false;
        $version = $healthKey !== null
            ? data_get($health, "model_versions.{$healthKey}", $model->version)
            : $model->version;
        $error = $healthKey !== null
            ? data_get($health, "errors.{$healthKey}")
            : 'No health mapping is configured for this model type.';

        return [
            'available' => $available,
            'status' => $available ? 'active' : 'inactive',
            'endpoint' => $endpoint,
            'version' => $version ?: $model->version,
            'last_checked_at' => $checkedAt,
            'message' => $available ? 'Endpoint available' : ($error ?: 'Endpoint unavailable'),
        ];
    }

    private function endpointForModel(AiModel $model): string
    {
        return match ($this->canonicalType($model)) {
            'classification' => '/ai/classify',
            'detection' => '/ai/detect',
            'segmentation' => '/ai/segment',
            'depth_estimation' => '/ai/measure',
            default => 'Not mapped',
        };
    }

    private function healthKeyForModel(AiModel $model): ?string
    {
        return match ($this->canonicalType($model)) {
            'classification' => 'cnn',
            'detection' => 'yolov8',
            'segmentation' => 'segmentation',
            'depth_estimation' => 'midas',
            default => null,
        };
    }

    private function canonicalType(AiModel $model): string
    {
        $type = strtolower((string) $model->model_type);
        $name = strtolower((string) $model->model_name);

        return match (true) {
            str_contains($type, 'class') || str_contains($name, 'cnn') || str_contains($name, 'classifier') => 'classification',
            str_contains($type, 'seg') || str_contains($name, 'seg') => 'segmentation',
            str_contains($type, 'detect') || str_contains($name, 'yolo') => 'detection',
            str_contains($type, 'depth') || str_contains($type, 'measure') || str_contains($name, 'midas') => 'depth_estimation',
            default => $type,
        };
    }
}
