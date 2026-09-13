<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MapScanRecordResource;
use App\Models\ScanRecord;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ScanMapController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $scope = $request->query('scope') === 'all' ? 'all' : 'mine';
        $request->user()->loadMissing('roles');
        $userId = $request->user()->id;

        $allRecords = ScanRecord::query();
        $myRecords = ScanRecord::query()->where('user_id', $userId);

        $query = ScanRecord::query()
            ->with(['user:id,name', 'species', 'measurement', 'locationValidation', 'images'])
            ->when($scope === 'mine', fn (Builder $builder) => $builder->where('user_id', $userId));

        $records = $this->withMapCoordinates($query)
            ->orderByRaw('COALESCE(captured_at, created_at) desc')
            ->limit(1000)
            ->get();

        return response()->json([
            'message' => 'Scan map records retrieved successfully.',
            'scope' => $scope,
            'counts' => [
                'my_scans' => (clone $myRecords)->count(),
                'my_pins' => $this->withMapCoordinates(clone $myRecords)->count(),
                'all_scans' => (clone $allRecords)->count(),
                'all_pins' => $this->withMapCoordinates(clone $allRecords)->count(),
                'returned_pins' => $records->count(),
            ],
            'data' => MapScanRecordResource::collection($records),
        ]);
    }

    private function withMapCoordinates(Builder $query): Builder
    {
        return $query->where(function (Builder $builder) {
            $builder
                ->where(function (Builder $scanCoordinates) {
                    $scanCoordinates->whereNotNull('latitude')->whereNotNull('longitude');
                })
                ->orWhereHas('locationValidation', function (Builder $validationCoordinates) {
                    $validationCoordinates->whereNotNull('latitude')->whereNotNull('longitude');
                });
        });
    }
}
