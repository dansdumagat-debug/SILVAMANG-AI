<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Species extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'scientific_name',
        'common_name',
        'family',
        'genus',
        'description',
        'habitat',
        'distribution_notes',
        'ecological_role',
        'identification_notes',
        'conservation_status',
        'native_status',
        'max_height_m',
        'status',
    ];

    protected $casts = [
        'max_height_m' => 'decimal:2',
    ];

    public function images()
    {
        return $this->hasMany(SpeciesImage::class);
    }

    public function distributions()
    {
        return $this->hasMany(SpeciesDistribution::class);
    }

    public function scanRecords()
    {
        return $this->hasMany(ScanRecord::class);
    }

    public function predictions()
    {
        return $this->hasMany(Prediction::class);
    }

    public function locationValidations()
    {
        return $this->hasMany(LocationValidation::class);
    }
}
