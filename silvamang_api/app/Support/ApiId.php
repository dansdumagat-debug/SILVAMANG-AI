<?php

namespace App\Support;

use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Support\Facades\Crypt;
use InvalidArgumentException;

class ApiId
{
    public static function encode(mixed $id): ?string
    {
        if ($id === null || $id === '') {
            return null;
        }

        $encrypted = Crypt::encryptString((string) $id);

        return rtrim(strtr(base64_encode($encrypted), '+/', '-_'), '=');
    }

    public static function decode(mixed $value, bool $allowPlainNumeric = false): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        if ((is_int($value) || ctype_digit((string) $value)) && $allowPlainNumeric) {
            return (int) $value;
        }

        $text = (string) $value;
        $payload = strtr($text, '-_', '+/');
        $payload .= str_repeat('=', (4 - strlen($payload) % 4) % 4);
        $encrypted = base64_decode($payload, true);

        if ($encrypted === false) {
            $encrypted = $text;
        }

        try {
            $decrypted = Crypt::decryptString($encrypted);
        } catch (DecryptException) {
            throw new InvalidArgumentException('Invalid encrypted ID.');
        }

        if (! ctype_digit($decrypted)) {
            throw new InvalidArgumentException('Invalid encrypted ID.');
        }

        return (int) $decrypted;
    }

    public static function decodeOrFail(mixed $value, bool $allowPlainNumeric = false): int
    {
        $id = self::decode($value, $allowPlainNumeric);

        if ($id === null || $id <= 0) {
            throw new InvalidArgumentException('Invalid encrypted ID.');
        }

        return $id;
    }
}
