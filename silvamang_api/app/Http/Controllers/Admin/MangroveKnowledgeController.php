<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\MangroveKnowledge;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\View\View;

class MangroveKnowledgeController extends Controller
{
    public function index(Request $request): View
    {
        $query = MangroveKnowledge::query();

        if ($search = trim((string) $request->query('search', ''))) {
            $hasRelatedSpecies = Schema::hasColumn('mangrove_knowledge', 'related_species');
            $hasReferenceSource = Schema::hasColumn('mangrove_knowledge', 'reference_source');
            $query->where(function ($builder) use ($search, $hasRelatedSpecies, $hasReferenceSource) {
                $builder
                    ->where('question', 'like', "%{$search}%")
                    ->orWhere('answer', 'like', "%{$search}%")
                    ->orWhere('species_name', 'like', "%{$search}%")
                    ->orWhere('keywords', 'like', "%{$search}%");

                if ($hasRelatedSpecies) {
                    $builder->orWhere('related_species', 'like', "%{$search}%");
                }

                if ($hasReferenceSource) {
                    $builder->orWhere('reference_source', 'like', "%{$search}%");
                }
            });
        }

        if ($category = trim((string) $request->query('category', ''))) {
            $query->where('category', $category);
        }

        if (
            Schema::hasColumn('mangrove_knowledge', 'status')
            && ($status = trim((string) $request->query('status', '')))
        ) {
            $query->where('status', $status);
        }

        return view('admin.mangrove-knowledge.index', [
            'knowledgeItems' => $query->latest()->paginate(12)->withQueryString(),
            'categories' => $this->categories(),
            'statuses' => ['active', 'inactive'],
        ]);
    }

    public function create(Request $request): View
    {
        return view('admin.mangrove-knowledge.create', [
            'knowledge' => new MangroveKnowledge([
                'category' => $request->query('category', 'environmental_education'),
                'question' => $request->query('question', ''),
                'keywords' => $request->query('keywords', ''),
                'status' => 'active',
            ]),
            'categories' => $this->categories(),
            'statuses' => ['active', 'inactive'],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        MangroveKnowledge::create($this->validated($request));

        return redirect()
            ->route('admin.mangrove-knowledge.index')
            ->with('success', 'Knowledge entry created successfully.');
    }

    public function edit(MangroveKnowledge $mangroveKnowledge): View
    {
        return view('admin.mangrove-knowledge.edit', [
            'knowledge' => $mangroveKnowledge,
            'categories' => $this->categories(),
            'statuses' => ['active', 'inactive'],
        ]);
    }

    public function update(Request $request, MangroveKnowledge $mangroveKnowledge): RedirectResponse
    {
        $mangroveKnowledge->update($this->validated($request));

        return redirect()
            ->route('admin.mangrove-knowledge.index')
            ->with('success', 'Knowledge entry updated successfully.');
    }

    public function destroy(MangroveKnowledge $mangroveKnowledge): RedirectResponse
    {
        $mangroveKnowledge->delete();

        return redirect()
            ->route('admin.mangrove-knowledge.index')
            ->with('success', 'Knowledge entry deleted successfully.');
    }

    /**
     * @return array<int, string>
     */
    private function categories(): array
    {
        return [
            'species_information',
            'mangrove_species',
            'ecology',
            'ecological_importance',
            'habitat',
            'distribution',
            'identification_guide',
            'mangrove_biology',
            'mangrove_zonation',
            'zonation',
            'conservation',
            'measurement',
            'location_information',
            'environmental_education',
            'field_guidance',
            'environmental_questions',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function validated(Request $request): array
    {
        $data = $request->validate([
            'category' => ['required', 'string', 'max:120'],
            'question' => ['required', 'string', 'max:2000'],
            'answer' => ['required', 'string', 'max:10000'],
            'species_name' => ['nullable', 'string', 'max:255'],
            'related_species' => ['nullable', 'string', 'max:2000'],
            'reference_source' => ['nullable', 'string', 'max:2000'],
            'keywords' => ['nullable', 'string', 'max:2000'],
            'status' => ['nullable', 'in:active,inactive'],
        ]);

        foreach (['related_species', 'reference_source', 'status'] as $column) {
            if (! Schema::hasColumn('mangrove_knowledge', $column)) {
                unset($data[$column]);
            }
        }

        return $data;
    }
}
