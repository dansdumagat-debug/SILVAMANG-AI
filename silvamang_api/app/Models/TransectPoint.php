<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TransectPoint extends Model
{
    use HasFactory;

    protected $fillable = [
        'transect_id',
        'sequence_number',
        'latitude',
        'longitude',
        'accuracy_m',
        'altitude_m',
        'recorded_at',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'accuracy_m' => 'decimal:2',
        'altitude_m' => 'decimal:2',
        'recorded_at' => 'datetime',
    ];

    public function transect()
    {
        return $this->belongsTo(Transect::class);
    }
}
