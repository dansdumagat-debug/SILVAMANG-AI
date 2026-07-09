<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Measurement extends Model
{
    use HasFactory;

    protected $fillable = [
        'scan_record_id',
        'height_m',
        'canopy_width_m',
        'dbh_cm',
        'measurement_method',
        'confidence',
        'notes',
        'measured_at',
    ];

    protected $casts = [
        'height_m' => 'decimal:2',
        'canopy_width_m' => 'decimal:2',
        'dbh_cm' => 'decimal:2',
        'confidence' => 'decimal:2',
        'measured_at' => 'datetime',
    ];

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }
}
