<?php

namespace App\Services;

use App\Models\ScanRecord;
use Illuminate\Support\Str;

class MangroveQuestionScopeService
{
    public const ALLOWED = 'allowed';

    public const SOCIAL = 'social';

    public const OUT_OF_SCOPE = 'out_of_scope';

    private const DIRECT_MANGROVE_TERMS = [
        'mangrove',
        'mangroves',
        'mangrove forest',
        'bakawan',
        'api api',
        'bungalon',
        'pagatpat',
        'piapi',
        'nipa',
        'nilad',
        'tangal',
        'pototan',
        'rhizophora',
        'avicennia',
        'bruguiera',
        'ceriops',
        'sonneratia',
        'xylocarpus',
        'excoecaria',
        'lumnitzera',
        'acanthus',
        'aegiceras',
        'aegialitis',
        'scyphiphora',
        'heritiera',
        'pemphis',
        'camptostemon',
        'osbornia',
        'nypa fruticans',
        'gapas gapas',
        'sasa',
        'kulasi',
        'tabao',
        'bantigi',
        'pedada',
        'dungon late',
        'piagao',
        'bunot bunot',
        'saging saging',
        'tinduk tindukan',
        'malatangal',
        'diluario',
        'pneumatophore',
        'pneumatophores',
        'prop root',
        'prop roots',
        'stilt root',
        'stilt roots',
        'breathing root',
        'breathing roots',
        'propagule',
        'propagules',
        'mangrove propagule',
        'mangrove propagules',
        'mangrove zonation',
        'blue carbon',
        'silvamang',
        'transect',
        'transects',
        'location validation',
        'mangrove scan',
        'scan record',
        'field observation',
        'species identification',
        'identification result',
        'confidence score',
        'plant part',
        'tree height',
        'canopy width',
        'diameter at breast height',
        'dbh',
        'basal area',
        'mangrove gps',
        'transect gps',
        'field gps',
        'mangrove barangay',
        'mangrove measurement',
        'silvamang measurement',
    ];

    private const RECORD_REFERENCE_TERMS = [
        'this result',
        'this scan',
        'this record',
        'this observation',
        'this species',
        'the result',
        'the scan',
        'identified species',
        'what species is this',
        'what did the app identify',
        'how confident is this',
        'where was it found',
        'its height',
        'its canopy',
        'its roots',
        'its leaves',
        'its habitat',
    ];

    private const FOLLOW_UP_PHRASES = [
        'more',
        'tell me more',
        'tell me more about it',
        'tell me more about that',
        'explain more',
        'more details',
        'more information',
        'continue',
        'continue this',
        'go on',
        'why is it important',
        'how does it work',
        'how does it reproduce',
        'where is it found',
        'how can i identify it',
        'what about its roots',
        'what about its leaves',
        'what about its habitat',
        'can you explain that',
        'sabihin pa',
        'paliwanag pa',
        'dagdag na impormasyon',
        'paano ito',
        'bakit ito mahalaga',
        'saan ito matatagpuan',
        'ano ang tirahan nito',
        'ano naman ang ugat nito',
    ];

    private const SOCIAL_PHRASES = [
        'hi',
        'hello',
        'hey',
        'good morning',
        'good afternoon',
        'good evening',
        'thank you',
        'thanks',
        'salamat',
        'maraming salamat',
        'kumusta',
        'bye',
        'goodbye',
        'who are you',
        'what can you do',
        'help',
    ];

    /**
     * @param  array<int, array{role?: string, content?: string}>  $history
     */
    public function classify(
        string $question,
        ?ScanRecord $scanRecord = null,
        ?string $context = null,
        array $history = []
    ): string {
        $normalized = $this->normalize($question);

        if ($this->isSocialMessage($normalized)) {
            return self::SOCIAL;
        }

        if ($this->hasDirectMangroveAnchor($normalized)) {
            return self::ALLOWED;
        }

        if ($scanRecord instanceof ScanRecord && $this->containsAnyPhrase($normalized, self::RECORD_REFERENCE_TERMS)) {
            return self::ALLOWED;
        }

        if ($this->isFollowUp($normalized) && $this->hasMangroveConversationContext($scanRecord, $context, $history)) {
            return self::ALLOWED;
        }

        return self::OUT_OF_SCOPE;
    }

    public function outOfScopeMessage(): string
    {
        return 'I can only answer questions about mangroves and SILVAMANG fieldwork, including species identification, ecology, conservation, transects, measurements, and location validation. Please ask a mangrove-related question.';
    }

    public function socialMessage(): string
    {
        return 'Hello! I am the SILVAMANG AI Assistant. Ask me about mangrove species, identification, ecology, conservation, transects, measurements, or location validation.';
    }

    private function isSocialMessage(string $question): bool
    {
        return in_array($question, self::SOCIAL_PHRASES, true);
    }

    private function isFollowUp(string $question): bool
    {
        if (in_array($question, self::FOLLOW_UP_PHRASES, true)) {
            return true;
        }

        return preg_match(
            '/^(?:(?:and|at)\s+)?(?:what|how|why|where|when|can|ano|paano|bakit|saan|kailan|maaari)\b.{0,80}\b(?:it|its|that|this|they|their|those|ito|iyon|yan|niya|nito|nila)\b/u',
            $question
        ) === 1;
    }

    /**
     * @param  array<int, array{role?: string, content?: string}>  $history
     */
    private function hasMangroveConversationContext(
        ?ScanRecord $scanRecord,
        ?string $context,
        array $history
    ): bool {
        if ($scanRecord instanceof ScanRecord) {
            return true;
        }

        if ($context !== null && $this->hasDirectMangroveAnchor($this->normalize($context))) {
            return true;
        }

        foreach (array_slice($history, -6) as $item) {
            if (! is_array($item)) {
                continue;
            }

            $content = $this->normalize((string) ($item['content'] ?? ''));
            if ($this->hasDirectMangroveAnchor($content)) {
                return true;
            }
        }

        return false;
    }

    private function hasDirectMangroveAnchor(string $question): bool
    {
        return $this->containsAnyPhrase($question, self::DIRECT_MANGROVE_TERMS);
    }

    /** @param array<int, string> $phrases */
    private function containsAnyPhrase(string $value, array $phrases): bool
    {
        foreach ($phrases as $phrase) {
            $pattern = '/(?<![\pL\pN])'.preg_quote($phrase, '/').'(?![\pL\pN])/u';
            if (preg_match($pattern, $value) === 1) {
                return true;
            }
        }

        return false;
    }

    private function normalize(string $value): string
    {
        $value = Str::lower($value);
        $value = str_replace(
            ['manggroves', 'manggrovess', 'manggrove', 'mangroove', 'mangrooves', 'api-api'],
            ['mangroves', 'mangroves', 'mangrove', 'mangrove', 'mangroves', 'api api'],
            $value
        );
        $value = preg_replace('/[^\pL\pN]+/u', ' ', $value) ?? $value;

        return Str::squish($value);
    }
}
