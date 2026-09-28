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
            'Avicennia_rumphiana' => 'Avicennia rumphiana',
            'Bruguiera gymnorhiza' => 'Bruguiera gymnorrhiza',
            'Bruguiera sexangola' => 'Bruguiera sexangula',
            'Camptostemon phillipinensis' => 'Camptostemon philippinensis',
            'Scyphiphora hydrophyllacea' => 'Scyphiphora hydrophylacea',
            'Xylocarpus rumphii' => 'Xylocarpus moluccensis',
            'Xylocarpus_rumphii' => 'Xylocarpus moluccensis',
            'Xylocarpus_moluccensis' => 'Xylocarpus moluccensis',
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

    public function test_retired_acanthus_volubilis_is_not_a_known_catalog_name(): void
    {
        $this->assertFalse(SpeciesTaxonomy::isKnownName('Acanthus volubilis'));
        $this->assertFalse(SpeciesTaxonomy::isKnownName('Acanthus_volubilis'));
    }

    public function test_aegiceras_floridum_is_known_but_guide_only(): void
    {
        $this->assertTrue(SpeciesTaxonomy::isKnownName('Aegiceras floridum'));
        $this->assertTrue(SpeciesTaxonomy::isGuideOnlyName('Aegiceras_floridum'));
        $this->assertFalse(SpeciesTaxonomy::isGuideOnlyName('Aegiceras corniculatum'));
    }
}
