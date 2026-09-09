<?php

namespace App\Services;

use Illuminate\Support\Facades\File;

class CnnMetricsReaderService
{
    private string $reportPath;

    public function __construct()
    {
        $this->reportPath = base_path('../silvamang_ai_service/reports/efficientnet_transfer');
    }

    public function metrics(): array
    {
        $path = $this->reportPath . DIRECTORY_SEPARATOR . 'test_metrics.json';

        if (! File::exists($path)) {
            $path = $this->reportPath . DIRECTORY_SEPARATOR . 'val_metrics.json';

            if (! File::exists($path)) {
                return [];
            }
        }

        $data = json_decode((string) File::get($path), true);

        if (! is_array($data)) {
            return [];
        }

        return [
            'accuracy' => $this->metricValue($data, ['accuracy']),
            'precision' => $this->metricValue($data, ['macro_precision', 'precision', 'precision_score']),
            'recall' => $this->metricValue($data, ['macro_recall', 'recall', 'recall_score']),
            'f1_score' => $this->metricValue($data, ['macro_f1', 'f1_score', 'f1-score', 'f1']),
            'top_3_accuracy' => $this->metricValue($data, ['top_3_accuracy', 'top_k_accuracy', 'top3_accuracy']),
            'raw' => $data,
        ];
    }

    public function classificationReport(): array
    {
        $path = $this->reportPath . DIRECTORY_SEPARATOR . 'classification_report.csv';

        if (! File::exists($path)) {
            return [];
        }

        $rows = array_map('str_getcsv', file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: []);
        $headers = array_shift($rows);

        if (! is_array($headers)) {
            return [];
        }

        return collect($rows)
            ->map(function (array $row) use ($headers) {
                return collect($headers)
                    ->mapWithKeys(fn ($header, $index) => [$header => $row[$index] ?? null])
                    ->all();
            })
            ->all();
    }

    public function confusionMatrixPath(): ?string
    {
        $path = $this->reportPath . DIRECTORY_SEPARATOR . 'confusion_matrix.png';

        return File::exists($path) ? $path : null;
    }

    public function confusionMatrixPreviewPath(): ?string
    {
        $path = $this->confusionMatrixPath();

        if ($path === null) {
            return null;
        }

        return 'data:image/png;base64,' . base64_encode((string) File::get($path));
    }

    public function hasMetrics(): bool
    {
        return $this->metrics() !== [];
    }

    private function metricValue(array $data, array $keys): ?float
    {
        foreach ($keys as $key) {
            if (array_key_exists($key, $data) && is_numeric($data[$key])) {
                return round((float) $data[$key] * 100, 2);
            }
        }

        return null;
    }
}
