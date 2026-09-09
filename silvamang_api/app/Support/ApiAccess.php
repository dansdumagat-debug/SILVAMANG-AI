<?php

namespace App\Support;

use App\Models\ScanRecord;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

class ApiAccess
{
    public static function canViewAllRecords(?User $user): bool
    {
        return $user?->hasAnyRole(['super_admin', 'admin', 'researcher']) ?? false;
    }

    public static function scopeScanRecords(Builder $query, ?User $user): Builder
    {
        if (self::canViewAllRecords($user)) {
            return $query;
        }

        return $query->where('user_id', $user?->id);
    }

    public static function abortUnlessCanAccessScanRecord(?ScanRecord $scanRecord, ?User $user): void
    {
        if (! $scanRecord) {
            abort(404);
        }

        if (self::canViewAllRecords($user)) {
            return;
        }

        if ($scanRecord->user_id !== $user?->id) {
            abort(404);
        }
    }
}
