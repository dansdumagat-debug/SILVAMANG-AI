<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreScanImageRequest;
use App\Http\Resources\ScanImageResource;
use App\Models\ScanImage;
use App\Models\ScanRecord;
use App\Support\ApiAccess;
use App\Support\ApiId;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use InvalidArgumentException;

class ScanImageController extends Controller
{
    public function index(Request $request)
    {
        $scanRecordId = null;
        if ($request->filled('scan_record_id')) {
            try {
                $scanRecordId = ApiId::decodeOrFail($request->query('scan_record_id'));
            } catch (InvalidArgumentException) {
                abort(400, 'Invalid scan record ID.');
            }
        }

        $scanImages = ScanImage::query()
            ->with('scanRecord')
            ->whereHas('scanRecord', fn ($query) => ApiAccess::scopeScanRecords($query, Auth::user()))
            ->when($scanRecordId, fn ($query, int $id) => $query->where('scan_record_id', $id))
            ->when($request->query('plant_part'), fn ($query, $plantPart) => $query->where('plant_part', $plantPart))
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Scan image list retrieved successfully.',
            'data' => ScanImageResource::collection($scanImages),
        ]);
    }

    public function store(StoreScanImageRequest $request)
    {
        $data = $request->validated();
        $scanRecord = ScanRecord::findOrFail($data['scan_record_id']);
        ApiAccess::abortUnlessCanAccessScanRecord($scanRecord, Auth::user());

        $image = $request->file('image');
        $dimensions = @getimagesize($image->getRealPath());
        $path = $image->store("scan-images/{$scanRecord->id}", 'public');

        $scanImage = ScanImage::create([
            'scan_record_id' => $scanRecord->id,
            'plant_part' => $data['plant_part'],
            'image_path' => $path,
            'original_filename' => $image->getClientOriginalName(),
            'mime_type' => $image->getMimeType(),
            'file_size' => $image->getSize(),
            'width' => $dimensions[0] ?? null,
            'height' => $dimensions[1] ?? null,
            'local_uri' => $data['local_uri'] ?? null,
        ]);

        return response()->json([
            'message' => 'Scan image uploaded successfully.',
            'data' => new ScanImageResource($scanImage->load('scanRecord')),
        ], 201);
    }

    public function show(ScanImage $scanImage)
    {
        $scanImage->load('scanRecord');
        ApiAccess::abortUnlessCanAccessScanRecord($scanImage->scanRecord, Auth::user());

        return response()->json([
            'message' => 'Scan image retrieved successfully.',
            'data' => new ScanImageResource($scanImage->load('scanRecord')),
        ]);
    }

    public function destroy(ScanImage $scanImage)
    {
        $scanImage->load('scanRecord');
        ApiAccess::abortUnlessCanAccessScanRecord($scanImage->scanRecord, Auth::user());

        if ($scanImage->image_path && Storage::disk('public')->exists($scanImage->image_path)) {
            Storage::disk('public')->delete($scanImage->image_path);
        }

        $scanImage->delete();

        return response()->json([
            'message' => 'Scan image deleted successfully.',
        ]);
    }
}
