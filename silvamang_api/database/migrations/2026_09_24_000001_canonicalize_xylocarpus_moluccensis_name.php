<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const XYLOCARPUS_CANONICAL = 'Xylocarpus moluccensis';

    private const XYLOCARPUS_ALIASES = [
        'Xylocarpus rumphii',
        'Xylocarpus_rumphii',
        'Xylocarpus_moluccensis',
    ];

    private const AVICENNIA_CANONICAL = 'Avicennia rumphiana';

    private const AVICENNIA_ALIASES = [
        'Avicennia marina var. rumphiana',
        'Avicennia marina var rumphiana',
        'Avicennia_marina_var_rumphiana',
        'Avicennia_rumphiana',
    ];

    /** @var array<string, string> */
    private const XYLOCARPUS_NARRATIVE_REPLACEMENTS = [
        'historically reported in Philippine guides as Xylocarpus moluccensis.' => 'represented in this catalog as Xylocarpus moluccensis.',
        'Keep Xylocarpus moluccensis as a searchable historical alias' => 'Keep Xylocarpus rumphii as a searchable legacy alias',
        'David Mabberley published the accepted combination in 1982. The name honors the Malesian naturalist Georg Eberhard Rumphius.' => 'This catalog uses Xylocarpus moluccensis as the canonical name and retains Xylocarpus rumphii as a legacy alias for existing records.',
        'Current Philippine flora treats older Philippine use of Xylocarpus moluccensis as a misapplied name for this species.' => 'Field records and training data should use Xylocarpus moluccensis consistently while continuing to recognize the legacy Xylocarpus rumphii label.',
        'Older Philippine sources may call it Xylocarpus moluccensis.' => 'Some existing SILVAMANG records may use the legacy name Xylocarpus rumphii.',
    ];

    public function up(): void
    {
        DB::transaction(function (): void {
            $xylocarpusId = $this->canonicalizeSpeciesRows(
                self::XYLOCARPUS_CANONICAL,
                self::XYLOCARPUS_ALIASES
            );
            $this->replaceExactNames(
                self::XYLOCARPUS_ALIASES,
                self::XYLOCARPUS_CANONICAL
            );
            $this->refreshXylocarpusNarrative($xylocarpusId);

            $this->canonicalizeSpeciesRows(
                self::AVICENNIA_CANONICAL,
                self::AVICENNIA_ALIASES
            );
            $this->replaceExactNames(
                self::AVICENNIA_ALIASES,
                self::AVICENNIA_CANONICAL
            );
        });
    }

    public function down(): void
    {
        // Intentionally irreversible. The up migration can merge duplicate
        // species rows and their relationships, so recreating the removed row
        // during rollback would invent IDs and risk separating valid records.
    }

    /**
     * Rename the existing species row in place. If duplicate canonical and
     * legacy rows exist, retain the canonical row and move every relationship
     * to it before removing the duplicate.
     */
    private function canonicalizeSpeciesRows(string $canonicalName, array $legacyNames): ?int
    {
        if (! Schema::hasTable('species')) {
            return null;
        }

        $canonical = DB::table('species')
            ->where('scientific_name', $canonicalName)
            ->first();

        foreach ($legacyNames as $legacyName) {
            $legacy = DB::table('species')
                ->where('scientific_name', $legacyName)
                ->first();

            if (! $legacy) {
                continue;
            }

            if (! $canonical) {
                $payload = ['scientific_name' => $canonicalName];
                if (Schema::hasColumn('species', 'updated_at')) {
                    $payload['updated_at'] = now();
                }

                DB::table('species')->where('id', $legacy->id)->update($payload);
                $canonical = DB::table('species')->where('id', $legacy->id)->first();

                continue;
            }

            if ((int) $legacy->id === (int) $canonical->id) {
                continue;
            }

            $this->mergeSpeciesRows((int) $legacy->id, (int) $canonical->id);
            $canonical = DB::table('species')->where('id', $canonical->id)->first();
        }

        return $canonical ? (int) $canonical->id : null;
    }

    private function mergeSpeciesRows(int $legacyId, int $canonicalId): void
    {
        $this->mergeSpeciesAttributes($legacyId, $canonicalId);
        $this->mergeMangroveEducation($legacyId, $canonicalId);

        foreach ($this->speciesForeignKeys() as [$table, $column]) {
            if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $column)) {
                continue;
            }

            DB::table($table)
                ->where($column, $legacyId)
                ->update([$column => $canonicalId]);
        }

        DB::table('species')->where('id', $legacyId)->delete();
    }

    private function mergeSpeciesAttributes(int $legacyId, int $canonicalId): void
    {
        $legacy = DB::table('species')->where('id', $legacyId)->first();
        $canonical = DB::table('species')->where('id', $canonicalId)->first();

        if (! $legacy || ! $canonical) {
            return;
        }

        $excluded = ['id', 'scientific_name', 'created_at', 'updated_at', 'deleted_at'];
        $payload = [];

        foreach (Schema::getColumnListing('species') as $column) {
            if (in_array($column, $excluded, true)) {
                continue;
            }

            $canonicalValue = $canonical->{$column} ?? null;
            $legacyValue = $legacy->{$column} ?? null;

            if (! $this->hasStoredValue($canonicalValue) && $this->hasStoredValue($legacyValue)) {
                $payload[$column] = $legacyValue;
            }
        }

        if (Schema::hasColumn('species', 'cnn_supported')) {
            $payload['cnn_supported'] = (bool) ($canonical->cnn_supported ?? false)
                || (bool) ($legacy->cnn_supported ?? false);
        }

        if (
            Schema::hasColumn('species', 'deleted_at')
            && ($canonical->deleted_at ?? null) !== null
            && ($legacy->deleted_at ?? null) === null
        ) {
            $payload['deleted_at'] = null;
        }

        if ($payload !== []) {
            if (Schema::hasColumn('species', 'updated_at')) {
                $payload['updated_at'] = now();
            }

            DB::table('species')->where('id', $canonicalId)->update($payload);
        }
    }

    private function mergeMangroveEducation(int $legacyId, int $canonicalId): void
    {
        if (! Schema::hasTable('mangrove_education')) {
            return;
        }

        $legacy = DB::table('mangrove_education')->where('species_id', $legacyId)->first();
        if (! $legacy) {
            return;
        }

        $canonical = DB::table('mangrove_education')->where('species_id', $canonicalId)->first();
        if (! $canonical) {
            DB::table('mangrove_education')
                ->where('id', $legacy->id)
                ->update(['species_id' => $canonicalId]);

            return;
        }

        $jsonColumns = [
            'physical_characteristics',
            'habitat',
            'distribution',
            'ecological_importance',
            'conservation_information',
            'interesting_facts',
            'references',
        ];
        $textColumns = [
            'overview',
            'leaf_characteristics',
            'root_characteristics',
            'history',
            'scientific_study',
        ];
        $payload = [];

        foreach ($jsonColumns as $column) {
            if (Schema::hasColumn('mangrove_education', $column)) {
                $payload[$column] = $this->mergeJsonValues(
                    $canonical->{$column} ?? null,
                    $legacy->{$column} ?? null
                );
            }
        }

        foreach ($textColumns as $column) {
            if (Schema::hasColumn('mangrove_education', $column)) {
                $payload[$column] = $this->mergeTextValues(
                    $canonical->{$column} ?? null,
                    $legacy->{$column} ?? null
                );
            }
        }

        if (Schema::hasColumn('mangrove_education', 'status')) {
            $payload['status'] = ($canonical->status ?? null) === 'active'
                || ($legacy->status ?? null) === 'active'
                    ? 'active'
                    : ($canonical->status ?? $legacy->status);
        }

        if (Schema::hasColumn('mangrove_education', 'updated_at')) {
            $payload['updated_at'] = now();
        }

        DB::table('mangrove_education')->where('id', $canonical->id)->update($payload);
        DB::table('mangrove_education')->where('id', $legacy->id)->delete();
    }

    private function replaceExactNames(array $legacyNames, string $canonicalName): void
    {
        foreach ([
            ['scan_records', 'top_scientific_name'],
            ['predictions', 'scientific_name'],
            ['mangrove_knowledge', 'species_name'],
            ['mangrove_knowledge', 'related_species'],
        ] as [$table, $column]) {
            if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $column)) {
                continue;
            }

            DB::table($table)
                ->whereIn($column, $legacyNames)
                ->update([$column => $canonicalName]);
        }

        $this->replaceTextValues(
            'mangrove_knowledge',
            ['question', 'keywords', 'related_species'],
            array_combine(
                $legacyNames,
                array_fill(0, count($legacyNames), $canonicalName)
            ) ?: []
        );
    }

    private function refreshXylocarpusNarrative(?int $speciesId): void
    {
        if ($speciesId === null) {
            return;
        }

        $this->replaceTextValues(
            'species',
            ['description', 'identification_notes'],
            self::XYLOCARPUS_NARRATIVE_REPLACEMENTS,
            ['id' => $speciesId]
        );
        $this->replaceTextValues(
            'mangrove_education',
            [
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
            ],
            self::XYLOCARPUS_NARRATIVE_REPLACEMENTS,
            ['species_id' => $speciesId]
        );
        $this->replaceTextValues(
            'mangrove_knowledge',
            ['answer'],
            self::XYLOCARPUS_NARRATIVE_REPLACEMENTS,
            ['species_name' => self::XYLOCARPUS_CANONICAL]
        );
    }

    private function replaceTextValues(
        string $table,
        array $columns,
        array $replacements,
        array $conditions = []
    ): void {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, 'id')) {
            return;
        }

        $columns = array_values(array_filter(
            $columns,
            fn (string $column): bool => Schema::hasColumn($table, $column)
        ));
        if ($columns === [] || $replacements === []) {
            return;
        }

        $query = DB::table($table)->select(array_merge(['id'], $columns));
        foreach ($conditions as $column => $value) {
            $query->where($column, $value);
        }

        foreach ($query->get() as $row) {
            $payload = [];

            foreach ($columns as $column) {
                $current = $row->{$column} ?? null;
                if (! is_string($current) || $current === '') {
                    continue;
                }

                $updated = str_replace(
                    array_keys($replacements),
                    array_values($replacements),
                    $current
                );

                if ($updated !== $current) {
                    $payload[$column] = $updated;
                }
            }

            if ($payload !== []) {
                if (Schema::hasColumn($table, 'updated_at')) {
                    $payload['updated_at'] = now();
                }

                DB::table($table)->where('id', $row->id)->update($payload);
            }
        }
    }

    /** @return array<int, array{string, string}> */
    private function speciesForeignKeys(): array
    {
        return [
            ['species_images', 'species_id'],
            ['species_distributions', 'species_id'],
            ['scan_records', 'species_id'],
            ['predictions', 'species_id'],
            ['location_validations', 'species_id'],
            ['scan_images', 'verified_species_id'],
            ['external_species_observations', 'species_id'],
        ];
    }

    private function hasStoredValue(mixed $value): bool
    {
        return $value !== null && $value !== '';
    }

    private function mergeTextValues(mixed $canonical, mixed $legacy): ?string
    {
        $canonical = trim((string) ($canonical ?? ''));
        $legacy = trim((string) ($legacy ?? ''));

        if ($canonical === '') {
            return $legacy !== '' ? $legacy : null;
        }

        if ($legacy === '' || str_contains($canonical, $legacy)) {
            return $canonical;
        }

        return $canonical."\n\n".$legacy;
    }

    private function mergeJsonValues(mixed $canonical, mixed $legacy): ?string
    {
        if (! $this->hasStoredValue($canonical)) {
            return $this->hasStoredValue($legacy) ? (string) $legacy : null;
        }

        if (! $this->hasStoredValue($legacy)) {
            return (string) $canonical;
        }

        $canonicalDecoded = json_decode((string) $canonical, true);
        if (json_last_error() !== JSON_ERROR_NONE || ! is_array($canonicalDecoded)) {
            return (string) $canonical;
        }

        $legacyDecoded = json_decode((string) $legacy, true);
        $legacyIsValidArray = json_last_error() === JSON_ERROR_NONE && is_array($legacyDecoded);
        if (! $legacyIsValidArray || array_is_list($canonicalDecoded) !== array_is_list($legacyDecoded)) {
            return (string) $canonical;
        }

        if (array_is_list($canonicalDecoded)) {
            $values = array_merge($canonicalDecoded, $legacyDecoded);

            $unique = [];
            foreach ($values as $value) {
                $unique[serialize($value)] = $value;
            }

            return json_encode(
                array_values($unique),
                JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
            ) ?: (string) $canonical;
        }

        $canonicalDecoded = array_replace_recursive($legacyDecoded, $canonicalDecoded);

        $encoded = json_encode(
            $canonicalDecoded,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
        );
        if ($encoded === false) {
            return (string) $canonical;
        }

        return $encoded;
    }
};
