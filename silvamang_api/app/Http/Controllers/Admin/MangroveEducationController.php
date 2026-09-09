<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\MangroveEducation;
use App\Models\Species;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class MangroveEducationController extends Controller
{
    public function index(Request $request): View
    {
        $query = MangroveEducation::query()
            ->with('species')
            ->when($request->query('search'), function ($query, string $search) {
                $query->where(function ($builder) use ($search) {
                    $builder
                        ->where('overview', 'like', "%{$search}%")
                        ->orWhere('history', 'like', "%{$search}%")
                        ->orWhere('scientific_study', 'like', "%{$search}%")
                        ->orWhereHas('species', function ($speciesQuery) use ($search) {
                            $speciesQuery
                                ->where('scientific_name', 'like', "%{$search}%")
                                ->orWhere('common_name', 'like', "%{$search}%")
                                ->orWhere('family', 'like', "%{$search}%");
                        });
                });
            })
            ->when($request->query('status'), fn ($query, string $status) => $query->where('status', $status))
            ->when($request->query('species_id'), fn ($query, string $speciesId) => $query->where('species_id', $speciesId));

        return view('admin.mangrove-education.index', [
            'educationItems' => $query->latest()->paginate(12)->withQueryString(),
            'speciesList' => $this->speciesList(),
            'statuses' => ['active', 'inactive'],
        ]);
    }

    public function create(Request $request): View
    {
        return view('admin.mangrove-education.create', [
            'education' => new MangroveEducation([
                'species_id' => $request->query('species_id'),
                'status' => 'active',
            ]),
            'speciesList' => $this->speciesList(),
            'statuses' => ['active', 'inactive'],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        MangroveEducation::create($this->validatedData($request));

        return redirect()
            ->route('admin.mangrove-education.index')
            ->with('success', 'Mangrove educational content created successfully.');
    }

    public function edit(MangroveEducation $mangroveEducation): View
    {
        return view('admin.mangrove-education.edit', [
            'education' => $mangroveEducation,
            'speciesList' => $this->speciesList(),
            'statuses' => ['active', 'inactive'],
        ]);
    }

    public function update(Request $request, MangroveEducation $mangroveEducation): RedirectResponse
    {
        $mangroveEducation->update($this->validatedData($request, $mangroveEducation));

        return redirect()
            ->route('admin.mangrove-education.index')
            ->with('success', 'Mangrove educational content updated successfully.');
    }

    public function destroy(MangroveEducation $mangroveEducation): RedirectResponse
    {
        $mangroveEducation->delete();

        return redirect()
            ->route('admin.mangrove-education.index')
            ->with('success', 'Mangrove educational content deleted successfully.');
    }

    private function speciesList()
    {
        return Species::query()
            ->orderBy('scientific_name')
            ->get(['id', 'scientific_name', 'common_name', 'family']);
    }

    /**
     * @return array<string, mixed>
     */
    private function validatedData(Request $request, ?MangroveEducation $education = null): array
    {
        $data = $request->validate([
            'species_id' => [
                'required',
                'exists:species,id',
                Rule::unique('mangrove_education', 'species_id')->ignore($education?->id),
            ],
            'overview' => ['nullable', 'string', 'max:30000'],
            'physical_characteristics' => ['nullable', 'string', 'max:30000'],
            'leaf_characteristics' => ['nullable', 'string', 'max:10000'],
            'root_characteristics' => ['nullable', 'string', 'max:10000'],
            'habitat' => ['nullable', 'string', 'max:30000'],
            'distribution' => ['nullable', 'string', 'max:30000'],
            'ecological_importance' => ['nullable', 'string', 'max:30000'],
            'history' => ['nullable', 'string', 'max:30000'],
            'scientific_study' => ['nullable', 'string', 'max:30000'],
            'conservation_information' => ['nullable', 'string', 'max:30000'],
            'interesting_facts' => ['nullable', 'string', 'max:30000'],
            'references' => ['nullable', 'string', 'max:30000'],
            'status' => ['required', 'in:active,inactive'],
        ]);

        foreach ([
            'physical_characteristics',
            'habitat',
            'distribution',
            'ecological_importance',
            'conservation_information',
            'interesting_facts',
            'references',
        ] as $listField) {
            $data[$listField] = $this->lineList($data[$listField] ?? null);
        }

        return $data;
    }

    /**
     * @return array<int, string>
     */
    private function lineList(?string $value): array
    {
        return collect(preg_split('/\r\n|\r|\n/', trim((string) $value)) ?: [])
            ->map(fn (string $item) => trim($item))
            ->filter()
            ->values()
            ->all();
    }
}
