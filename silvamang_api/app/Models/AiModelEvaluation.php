<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiModelEvaluation extends Model
{
    public const CNN_METRICS = [
        'accuracy',
        'precision',
        'recall',
        'f1_score',
        'confusion_matrix',
    ];

    public const YOLO_METRICS = [
        'precision',
        'recall',
        'map',
        'iou',
    ];

    public const MIDAS_METRICS = [
        'mae',
        'rmse',
        'measurement_error',
    ];

    protected $fillable = [
        'model_id',
        'metric_name',
        'metric_value',
        'date',
    ];

    protected $casts = [
        'metric_value' => 'json',
        'date' => 'date',
    ];

    public function aiModel(): BelongsTo
    {
        return $this->belongsTo(AiModel::class, 'model_id');
    }

    public function getDisplayValueAttribute(): string
    {
        $value = $this->metric_value;

        if ($value === null || $value === '') {
            return 'Not available';
        }

        if (is_array($value)) {
            return json_encode($value) ?: 'Not available';
        }

        if (is_numeric($value)) {
            return rtrim(rtrim(number_format((float) $value, 4, '.', ''), '0'), '.');
        }

        return (string) $value;
    }
}
