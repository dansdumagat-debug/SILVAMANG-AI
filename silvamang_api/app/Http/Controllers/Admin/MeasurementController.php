<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Measurement;

class MeasurementController extends Controller
{
    public function index()
    {
        $query = Measurement::query()
            ->with('scanRecord')
            ->when(request('search'), function ($query, $search) {
                $query->whereHas('scanRecord', fn ($query) => $query->where('record_code', 'like', "%{$search}%"));
            })
            ->when(request('measurement_method'), fn ($query, $method) => $query->where('measurement_method', $method))
            ->when(request('date_from'), fn ($query, $date) => $query->whereDate('created_at', '>=', $date))
            ->when(request('date_to'), fn ($query, $date) => $query->whereDate('created_at', '<=', $date));

        return view('admin.measurements.index', [
            'measurements' => $query->latest()->paginate(10)->withQueryString(),
            'measurementMethods' => Measurement::whereNotNull('measurement_method')->distinct()->orderBy('measurement_method')->pluck('measurement_method'),
        ]);
    }

    public function show(Measurement $measurement)
    {
        $measurement->load(['scanRecord.species', 'scanRecord.user']);

        return view('admin.measurements.show', compact('measurement'));
    }
}
