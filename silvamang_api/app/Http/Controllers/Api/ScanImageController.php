<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreScanImageRequest;
use App\Http\Resources\ScanImageResource;
use App\Models\ScanImage;
use App\Models\ScanRecord;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ScanImageController extends Controller
{
    public function index(Request $request)
    {
        $scanImages = ScanImage::query()
            ->with('scanRecord')
            ->when($request->query('scan_record_id'), fn ($query, $scanRecordId) => $query->where('scan_record_id', $scanRecordId))
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
        return response()->json([
            'message' => 'Scan image retrieved successfully.',
            'data' => new ScanImageResource($scanImage->load('scanRecord')),
        ]);
    }

    public function destroy(ScanImage $scanImage)
    {
        if ($scanImage->image_path && Storage::disk('public')->exists($scanImage->image_path)) {
            Storage::disk('public')->delete($scanImage->image_path);
        }

        $scanImage->delete();

        return response()->json([
            'message' => 'Scan image deleted successfully.',
        ]);
    }
}
