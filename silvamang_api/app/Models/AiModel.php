<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AiModel extends Model
{
    use HasFactory;

    protected $fillable = [
        'model_name',
        'model_type',
        'version',
        'accuracy',
        'precision_score',
        'recall_score',
        'f1_score',
        'top_k_accuracy',
        'status',
        'deployed_at',
        'notes',
    ];

    protected $casts = [
        'accuracy' => 'decimal:2',
        'precision_score' => 'decimal:2',
        'recall_score' => 'decimal:2',
        'f1_score' => 'decimal:2',
        'top_k_accuracy' => 'decimal:2',
        'deployed_at' => 'datetime',
    ];
}
