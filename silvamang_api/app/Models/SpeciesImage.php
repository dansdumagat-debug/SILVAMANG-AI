<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SpeciesImage extends Model
{
    use HasFactory;

    protected $fillable = [
        'species_id',
        'image_path',
        'image_type',
        'caption',
        'is_primary',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
    ];

    public function species()
    {
        return $this->belongsTo(Species::class);
    }
}
