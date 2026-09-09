<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Species;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SpeciesManagementController extends Controller
{
    public function index()
    {
        $query = Species::query()
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('scientific_name', 'like', "%{$search}%")
                        ->orWhere('common_name', 'like', "%{$search}%")
                        ->orWhere('family', 'like', "%{$search}%");
                });
            })
            ->when(request('family'), fn ($query, $family) => $query->where('family', $family))
            ->when(request('conservation_status'), fn ($query, $status) => $query->where('conservation_status', $status))
            ->when(request('status'), fn ($query, $status) => $query->where('status', $status));

        return view('admin.species.index', [
            'species' => $query->orderBy('scientific_name')->paginate(10)->withQueryString(),
            'families' => Species::whereNotNull('family')->distinct()->orderBy('family')->pluck('family'),
            'conservationStatuses' => Species::whereNotNull('conservation_status')->distinct()->orderBy('conservation_status')->pluck('conservation_status'),
            'statuses' => Species::whereNotNull('status')->distinct()->orderBy('status')->pluck('status'),
        ]);
    }

    public function create()
    {
        return view('admin.species.create', [
            'species' => new Species(['status' => 'active']),
        ]);
    }

    public function store(Request $request)
    {
        $species = Species::create($this->validatedData($request));

        return redirect()
            ->route('admin.species.show', $species)
            ->with('success', 'Species created successfully.');
    }

    public function show(Species $species)
    {
        $species->load([
            'externalObservations' => fn ($query) => $query
                ->latest('updated_at')
                ->latest('observed_date')
                ->limit(6),
        ]);

        return view('admin.species.show', [
            'species' => $species,
        ]);
    }

    public function edit(Species $species)
    {
        return view('admin.species.edit', [
            'species' => $species,
        ]);
    }

    public function update(Request $request, Species $species)
    {
        $species->update($this->validatedData($request, $species));

        return redirect()
            ->route('admin.species.show', $species)
            ->with('success', 'Species updated successfully.');
    }

    public function destroy(Species $species)
    {
        $species->delete();

        return redirect()
            ->route('admin.species.index')
            ->with('success', 'Species deleted successfully.');
    }

    private function validatedData(Request $request, ?Species $species = null): array
    {
        return $request->validate([
            'scientific_name' => [
                'required',
                'string',
                'max:255',
                Rule::unique('species', 'scientific_name')->ignore($species?->id),
            ],
            'common_name' => ['nullable', 'string', 'max:255'],
            'family' => ['nullable', 'string', 'max:255'],
            'genus' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'habitat' => ['nullable', 'string'],
            'distribution_notes' => ['nullable', 'string'],
            'ecological_role' => ['nullable', 'string'],
            'identification_notes' => ['nullable', 'string'],
            'conservation_status' => ['nullable', 'string', 'max:255'],
            'native_status' => ['nullable', 'string', 'max:255'],
            'max_height_m' => ['nullable', 'numeric', 'min:0'],
            'status' => ['required', 'string', 'max:50'],
        ]);
    }
}
