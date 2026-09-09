<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MangroveEducation extends Model
{
    use HasFactory;

    protected $table = 'mangrove_education';

    protected $fillable = [
        'species_id',
        'overview',
        'physical_characteristics',
        'leaf_characteristics',
        'root_characteristics',
        'habitat',
        'distribution',
        'ecological_importance',
        'history',
        'scientific_study',
        'conservation_information',
        'interesting_facts',
        'references',
        'status',
    ];

    protected $casts = [
        'physical_characteristics' => 'array',
        'habitat' => 'array',
        'distribution' => 'array',
        'ecological_importance' => 'array',
        'conservation_information' => 'array',
        'interesting_facts' => 'array',
        'references' => 'array',
    ];

    public function species()
    {
        return $this->belongsTo(Species::class);
    }
}
