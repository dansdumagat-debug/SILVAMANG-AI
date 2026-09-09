<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ExternalSpeciesObservation;
use App\Models\Species;
use App\Services\INaturalistService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class ExternalSpeciesObservationController extends Controller
{
    public function index(Request $request): View
    {
        $query = ExternalSpeciesObservation::query()
            ->with('species')
            ->when($this->filterValue($request, 'search'), function (Builder $query, string $search) {
                $query->where(function (Builder $builder) use ($search) {
                    $builder
                        ->where('source_observation_id', 'like', "%{$search}%")
                        ->orWhere('observer', 'like', "%{$search}%")
                        ->orWhere('location', 'like', "%{$search}%")
                        ->orWhereHas('species', function (Builder $speciesQuery) use ($search) {
                            $speciesQuery
                                ->where('scientific_name', 'like', "%{$search}%")
                                ->orWhere('common_name', 'like', "%{$search}%");
                        });
                });
            })
            ->when($this->filterValue($request, 'species_id'), fn (Builder $query, string $speciesId) => $query->where('species_id', $speciesId))
            ->when($this->filterValue($request, 'quality_grade'), fn (Builder $query, string $qualityGrade) => $query->where('quality_grade', $qualityGrade));

        return view('admin.external-biodiversity.index', [
            'observations' => $query
                ->latest('updated_at')
                ->latest('observed_date')
                ->paginate(12)
                ->withQueryString(),
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name', 'common_name']),
            'qualityGrades' => ExternalSpeciesObservation::query()
                ->whereNotNull('quality_grade')
                ->distinct()
                ->orderBy('quality_grade')
                ->pluck('quality_grade'),
            'totalObservations' => ExternalSpeciesObservation::count(),
            'speciesWithReferences' => ExternalSpeciesObservation::query()->distinct('species_id')->count('species_id'),
            'photosCached' => ExternalSpeciesObservation::whereNotNull('photo_url')->count(),
            'lastSyncedAt' => ExternalSpeciesObservation::latest('updated_at')->first()?->updated_at,
        ]);
    }

    public function refresh(Request $request, INaturalistService $service): RedirectResponse
    {
        $data = $request->validate([
            'species_id' => ['required', 'exists:species,id'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:20'],
        ]);

        $species = Species::findOrFail($data['species_id']);
        $result = $service->getSpeciesObservations(
            speciesName: $species->scientific_name,
            species: $species,
            limit: $data['limit'] ?? null,
            refresh: true,
        );

        $flashKey = ($result['status'] ?? 'error') === 'error' ? 'error' : 'success';

        return back()->with($flashKey, $result['message'] ?? 'External biodiversity references refreshed.');
    }

    public function clear(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'species_id' => ['nullable', 'exists:species,id'],
        ]);

        $query = ExternalSpeciesObservation::query();
        if (! empty($data['species_id'])) {
            $query->where('species_id', $data['species_id']);
        }

        $count = (clone $query)->count();
        $query->delete();

        return back()->with('success', "{$count} cached external biodiversity reference record(s) cleared.");
    }

    private function filterValue(Request $request, string $key): ?string
    {
        $value = trim((string) $request->query($key, ''));

        return $value === '' ? null : $value;
    }
}
