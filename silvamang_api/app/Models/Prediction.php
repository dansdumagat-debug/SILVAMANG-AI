<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Prediction extends Model
{
    use HasFactory;

    protected $fillable = [
        'scan_record_id',
        'species_id',
        'rank',
        'scientific_name',
        'common_name',
        'confidence',
        'model_name',
        'model_version',
    ];

    protected $casts = [
        'rank' => 'integer',
        'confidence' => 'decimal:2',
    ];

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }

    public function species()
    {
        return $this->belongsTo(Species::class);
    }
}
