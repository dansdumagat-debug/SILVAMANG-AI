<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Alert extends Model
{
    use HasFactory;

    protected $fillable = [
        'alert_type',
        'severity',
        'title',
        'message',
        'related_scan_record_id',
        'status',
    ];

    public function relatedScanRecord()
    {
        return $this->belongsTo(ScanRecord::class, 'related_scan_record_id');
    }
}
