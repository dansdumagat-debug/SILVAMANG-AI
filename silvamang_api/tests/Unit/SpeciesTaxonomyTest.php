<?php

namespace Tests\Unit;

use App\Support\SpeciesTaxonomy;
use PHPUnit\Framework\TestCase;

class SpeciesTaxonomyTest extends TestCase
{
    public function test_requested_aliases_and_spelling_variants_are_canonicalized(): void
    {
        $aliases = [
            'Avicennia_marina_var_rumphiana' => 'Avicennia rumphiana',
            'Bruguiera gymnorhiza' => 'Bruguiera gymnorrhiza',
            'Bruguiera sexangola' => 'Bruguiera sexangula',
            'Camptostemon phillipinensis' => 'Camptostemon philippinensis',
            'Scyphiphora hydrophyllacea' => 'Scyphiphora hydrophylacea',
            'Xylocarpus moluccensis' => 'Xylocarpus rumphii',
        ];

        foreach ($aliases as $alias => $canonical) {
            $this->assertSame($canonical, SpeciesTaxonomy::canonicalName($alias));
            $this->assertSame(
                SpeciesTaxonomy::lookupKey($canonical),
                SpeciesTaxonomy::lookupKey($alias)
            );
        }
    }

    public function test_catalog_names_are_normalized_without_changing_taxa(): void
    {
        $this->assertSame(
            'Acanthus ebracteatus',
            SpeciesTaxonomy::canonicalName('  acanthus__ebracteatus  ')
        );
        $this->assertSame(
            'Bruguiera cylindrica',
            SpeciesTaxonomy::canonicalName('Bruguiera   cylindrica')
        );
    }
}
