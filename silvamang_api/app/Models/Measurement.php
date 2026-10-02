<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Measurement extends Model
{
    use HasFactory;

    protected $fillable = [
        'scan_record_id',
        'gbh_cm',
        'gbh_m',
        'dbh_m',
        'basal_area_m2',
        'canopy_1_m',
        'canopy_2_m',

        'height_m',
        'canopy_width_m',
        'dbh_cm',
        'measurement_method',
        'confidence',
        'notes',
        'measured_at',
    ];

    protected $casts = [
        'gbh_cm' => 'decimal:6',
        'gbh_m' => 'decimal:6',
        'dbh_m' => 'decimal:6',
        'basal_area_m2' => 'decimal:6',
        'canopy_1_m' => 'decimal:6',
        'canopy_2_m' => 'decimal:6',

        'height_m' => 'decimal:2',
        'canopy_width_m' => 'decimal:2',
        'dbh_cm' => 'decimal:2',
        'confidence' => 'decimal:2',
        'measured_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::saving(function (Measurement $measurement): void {
            // Existing workbook methodology: GBH = DBH * pi; BA = pi * (DBH_m / 2)^2.
            // GBH input is authoritative when present; legacy direct DBH remains supported.
            if ($measurement->gbh_cm !== null) {
                $measurement->dbh_cm = round((float) $measurement->gbh_cm / pi(), 2);
            }
            $measurement->gbh_m = $measurement->gbh_cm !== null ? (float) $measurement->gbh_cm / 100 : null;
            $measurement->dbh_m = $measurement->dbh_cm !== null ? (float) $measurement->dbh_cm / 100 : null;
            $measurement->basal_area_m2 = $measurement->dbh_m !== null ? pi() * ((float) $measurement->dbh_m / 2) ** 2 : null;
            // Canopy axes do not imply width: preserve a separately recorded width.
        });
    }

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }
}
