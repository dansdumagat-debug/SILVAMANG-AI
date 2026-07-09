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
    ];

    protected $casts = [
        'file_size' => 'integer',
        'width' => 'integer',
        'height' => 'integer',
    ];

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }
}
