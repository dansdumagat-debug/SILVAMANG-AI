<?php

namespace App\Support;

use Illuminate\Support\Str;

final class SpeciesTaxonomy
{
    /** @var array<string, true> */
    private const GUIDE_ONLY_NAMES = [
        'aegiceras floridum' => true,
    ];

    /**
     * Philippine catalog aliases and known legacy labels.
     *
     * @var array<string, string>
     */
    private const CANONICAL_NAMES = [
        'acanthus ebracteatus' => 'Acanthus ebracteatus',
        'acanthus ilicifolius' => 'Acanthus ilicifolius',
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
        'xylocarpus granatum' => 'Xylocarpus granatum',
        'xylocarpus moluccensis' => 'Xylocarpus moluccensis',
        'xylocarpus rumphii' => 'Xylocarpus moluccensis',
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

    public static function isKnownName(mixed $value): bool
    {
        return array_key_exists(self::rawLookupKey($value), self::CANONICAL_NAMES);
    }

    public static function isGuideOnlyName(mixed $value): bool
    {
        return array_key_exists(self::lookupKey($value), self::GUIDE_ONLY_NAMES);
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
