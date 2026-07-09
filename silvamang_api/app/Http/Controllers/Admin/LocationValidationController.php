<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\LocationValidation;
use App\Models\Species;

class LocationValidationController extends Controller
{
    public function index()
    {
        $query = LocationValidation::query()
            ->with(['scanRecord', 'species'])
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('message', 'like', "%{$search}%")
                        ->orWhereHas('scanRecord', fn ($query) => $query->where('record_code', 'like', "%{$search}%"))
                        ->orWhereHas('species', fn ($query) => $query->where('scientific_name', 'like', "%{$search}%"));
                });
            })
            ->when(request('result'), fn ($query, $result) => $query->where('result', $result))
            ->when(request('species_id'), fn ($query, $speciesId) => $query->where('species_id', $speciesId));

        return view('admin.location-validations.index', [
            'validations' => $query->latest()->paginate(10)->withQueryString(),
            'results' => LocationValidation::whereNotNull('result')->distinct()->orderBy('result')->pluck('result'),
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name']),
        ]);
    }

    public function show(LocationValidation $locationValidation)
    {
        $locationValidation->load(['scanRecord.user', 'species']);

        return view('admin.location-validations.show', compact('locationValidation'));
    }
}
