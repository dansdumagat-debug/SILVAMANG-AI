<?php

namespace Database\Seeders;

use App\Models\AiModel;
use Illuminate\Database\Seeder;

class AiModelSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $models = [
            [
                'model_name' => 'SILVAMANG EfficientNet-B0 Classifier',
                'model_type' => 'classification',
                'version' => 'transfer-learning-0.1.0',
                'accuracy' => 84.42,
                'precision_score' => 86.69,
                'recall_score' => 84.52,
                'f1_score' => 85.38,
                'top_k_accuracy' => null,
                'status' => 'active',
                'notes' => 'Runtime classifier used by the Python AI service. Metrics are from silvamang_ai_service/reports/efficientnet_transfer/test_metrics.json.',
            ],
            [
                'model_name' => 'SILVAMANG YOLOv8 Detector',
                'model_type' => 'detection',
                'version' => '0.1.0',
                'status' => 'inactive',
            ],
            [
                'model_name' => 'SILVAMANG YOLOv8-Seg Segmenter',
                'model_type' => 'segmentation',
                'version' => '0.1.0',
                'status' => 'inactive',
            ],
            [
                'model_name' => 'SILVAMANG MiDaS Depth Estimator',
                'model_type' => 'depth_estimation',
                'version' => '0.1.0',
                'status' => 'inactive',
            ],
        ];

        foreach ($models as $model) {
            if ($model['model_type'] === 'classification') {
                $existingClassifier = AiModel::query()
                    ->where('model_type', 'classification')
                    ->whereIn('model_name', [
                        'SILVAMANG CNN Classifier',
                        'SILVAMANG EfficientNet-B0 Classifier',
                    ])
                    ->first();

                if ($existingClassifier) {
                    $existingClassifier->update($model);
                    continue;
                }
            }

            AiModel::updateOrCreate(
                [
                    'model_name' => $model['model_name'],
                    'model_type' => $model['model_type'],
                ],
                $model
            );
        }
    }
}
