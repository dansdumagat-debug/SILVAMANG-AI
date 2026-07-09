<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AssistantLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'scan_record_id',
        'question',
        'response',
        'intent',
        'source',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }
}
