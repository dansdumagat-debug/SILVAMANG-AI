<?php

namespace App\Support;

use Illuminate\Support\Str;

final class SpeciesTaxonomy
{
    /**
     * Philippine catalog aliases and known legacy labels.
     *
     * @var array<string, string>
     */
    private const CANONICAL_NAMES = [
        'acanthus ebracteatus' => 'Acanthus ebracteatus',
        'acanthus ilicifolius' => 'Acanthus ilicifolius',
        'acanthus volubilis' => 'Acanthus volubilis',
        'aegiceras corniculatum' => 'Aegiceras corniculatum',
        'aegiceras floridum' => 'Aegiceras floridum',
        'avicennia alba' => 'Avicennia alba',
        'avicennia marina' => 'Avicennia marina',
        'avicennia marina var rumphiana' => 'Avicennia rumphiana',
        'avicennia officinalis' => 'Avicennia officinalis',
        'avicennia rumphiana' => 'Avicennia rumphiana',
        'bruguiera cylindrica' => 'Bruguiera cylindrica',
        'bruguiera gymnorhiza' => 'Bruguiera gymnorrhiza',
        'bruguiera gymnorrhiza' => 'Bruguiera gymnorrhiza',
        'bruguiera sexangola' => 'Bruguiera sexangula',
        'bruguiera sexangula' => 'Bruguiera sexangula',
        'camptostemon philippinense' => 'Camptostemon philippinensis',
        'camptostemon phillipinensis' => 'Camptostemon philippinensis',
        'camptostemon philippinensis' => 'Camptostemon philippinensis',
        'ceriops tagal' => 'Ceriops tagal',
        'ceriops zippeliana' => 'Ceriops zippeliana',
        'excoecaria agallocha' => 'Excoecaria agallocha',
        'heritiera littoralis' => 'Heritiera littoralis',
        'lumnitzera littorea' => 'Lumnitzera littorea',
        'lumnitzera racemosa' => 'Lumnitzera racemosa',
        'nypa fruticans' => 'Nypa fruticans',
        'osbornia octodonta' => 'Osbornia octodonta',
        'pemphis acidula' => 'Pemphis acidula',
        'rhizophora apiculata' => 'Rhizophora apiculata',
        'rhizophora mucronata' => 'Rhizophora mucronata',
        'rhizophora stylosa' => 'Rhizophora stylosa',
        'scyphiphora hydrophyllacea' => 'Scyphiphora hydrophylacea',
        'scyphiphora hydrophylacea' => 'Scyphiphora hydrophylacea',
        'sonneratia alba' => 'Sonneratia alba',
        'sonneratia ovata' => 'Sonneratia ovata',
        // Older Philippine references applied this name to Xylocarpus rumphii.
        'xylocarpus granatum' => 'Xylocarpus granatum',
        'xylocarpus moluccensis' => 'Xylocarpus rumphii',
        'xylocarpus rumphii' => 'Xylocarpus rumphii',
    ];

    public static function canonicalName(mixed $value): string
    {
        $displayName = self::displayName($value);

        return self::CANONICAL_NAMES[self::rawLookupKey($displayName)] ?? $displayName;
    }

    public static function lookupKey(mixed $value): string
    {
        return self::rawLookupKey(self::canonicalName($value));
    }

    private static function displayName(mixed $value): string
    {
        $name = trim(str_replace('_', ' ', (string) $value));

        return preg_replace('/\s+/', ' ', $name) ?? '';
    }

    private static function rawLookupKey(mixed $value): string
    {
        return Str::of(self::displayName($value))
            ->lower()
            ->replaceMatches('/[^a-z0-9]+/', ' ')
            ->squish()
            ->toString();
    }
}
