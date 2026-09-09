<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ScanImage extends Model
{
    use HasFactory;

    protected $fillable = [
        'scan_record_id',
        'plant_part',
        'image_path',
        'original_filename',
        'mime_type',
        'file_size',
        'width',
        'height',
        'local_uri',
        'verified_species_id',
        'verified_plant_part',
        'dataset_status',
        'image_quality',
        'verified_by',
        'verified_at',
        'rejection_reason',
        'dataset_notes',
        'dataset_exported_at',
        'dataset_export_path',
    ];

    protected $casts = [
        'file_size' => 'integer',
        'width' => 'integer',
        'height' => 'integer',
        'verified_at' => 'datetime',
        'dataset_exported_at' => 'datetime',
    ];

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }

    public function verifiedSpecies()
    {
        return $this->belongsTo(Species::class, 'verified_species_id');
    }

    public function verifier()
    {
        return $this->belongsTo(User::class, 'verified_by');
    }
}
