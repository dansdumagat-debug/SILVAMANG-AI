<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MangroveKnowledge extends Model
{
    use HasFactory;

    protected $table = 'mangrove_knowledge';

    protected $fillable = [
        'category',
        'question',
        'answer',
        'species_name',
        'related_species',
        'reference_source',
        'keywords',
        'status',
    ];
}
