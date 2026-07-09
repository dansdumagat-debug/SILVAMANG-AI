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
                'model_name' => 'SILVAMANG CNN Classifier',
                'model_type' => 'classification',
                'version' => '0.1.0',
                'accuracy' => 91.70,
                'precision_score' => 89.30,
                'recall_score' => 88.60,
                'f1_score' => 88.90,
                'top_k_accuracy' => 95.40,
                'status' => 'active',
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
