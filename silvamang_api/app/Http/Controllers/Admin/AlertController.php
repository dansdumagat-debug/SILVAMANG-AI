<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Alert;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AlertController extends Controller
{
    public function index()
    {
        $query = Alert::query()
            ->with('relatedScanRecord')
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('title', 'like', "%{$search}%")
                        ->orWhere('message', 'like', "%{$search}%")
                        ->orWhereHas('relatedScanRecord', fn ($query) => $query->where('record_code', 'like', "%{$search}%"));
                });
            })
            ->when(request('severity'), fn ($query, $severity) => $query->where('severity', $severity))
            ->when(request('status'), fn ($query, $status) => $query->where('status', $status))
            ->when(request('alert_type'), fn ($query, $type) => $query->where('alert_type', $type))
            ->when(request('date_from'), fn ($query, $date) => $query->whereDate('created_at', '>=', $date))
            ->when(request('date_to'), fn ($query, $date) => $query->whereDate('created_at', '<=', $date));

        return view('admin.alerts.index', [
            'alerts' => $query->latest()->paginate(10)->withQueryString(),
            'severities' => Alert::whereNotNull('severity')->distinct()->orderBy('severity')->pluck('severity'),
            'statuses' => Alert::whereNotNull('status')->distinct()->orderBy('status')->pluck('status'),
            'alertTypes' => Alert::whereNotNull('alert_type')->distinct()->orderBy('alert_type')->pluck('alert_type'),
        ]);
    }

    public function show(Alert $alert)
    {
        $alert->load('relatedScanRecord');

        return view('admin.alerts.show', compact('alert'));
    }

    public function updateStatus(Request $request, Alert $alert)
    {
        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(['open', 'reviewed', 'resolved', 'dismissed'])],
        ]);

        $alert->update($data);

        return redirect()
            ->route('admin.alerts.show', $alert)
            ->with('success', 'Alert status updated successfully.');
    }
}
