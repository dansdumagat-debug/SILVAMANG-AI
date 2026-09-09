<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ScanImage;
use App\Models\Species;
use App\Services\DatasetExportService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DatasetVerificationController extends Controller
{
    private const DATASET_STATUSES = ['pending', 'verified', 'rejected', 'exported'];

    private const IMAGE_QUALITIES = ['good', 'acceptable', 'reject'];

    private const PLANT_PARTS = ['leaves', 'bark', 'roots', 'flowers', 'canopy', 'full_tree', 'other'];

    public function index(Request $request)
    {
        $query = ScanImage::query()
            ->with(['scanRecord.species', 'verifiedSpecies', 'verifier'])
            ->when($request->query('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('original_filename', 'like', "%{$search}%")
                        ->orWhere('plant_part', 'like', "%{$search}%")
                        ->orWhereHas('scanRecord', fn ($query) => $query->where('record_code', 'like', "%{$search}%"))
                        ->orWhereHas('scanRecord.species', fn ($query) => $query->where('scientific_name', 'like', "%{$search}%"))
                        ->orWhereHas('verifiedSpecies', fn ($query) => $query->where('scientific_name', 'like', "%{$search}%"));
                });
            })
            ->when($request->query('dataset_status'), fn ($query, $status) => $query->where('dataset_status', $status))
            ->when($request->query('image_quality'), fn ($query, $quality) => $query->where('image_quality', $quality))
            ->when($request->query('verified_species_id'), fn ($query, $speciesId) => $query->where('verified_species_id', $speciesId))
            ->when($request->query('verified_plant_part'), fn ($query, $plantPart) => $query->where('verified_plant_part', $plantPart));

        return view('admin.dataset-verification.index', [
            'scanImages' => $query->latest()->paginate(12)->withQueryString(),
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name', 'common_name']),
            'datasetStatuses' => self::DATASET_STATUSES,
            'imageQualities' => self::IMAGE_QUALITIES,
            'plantParts' => self::PLANT_PARTS,
            'pendingCount' => ScanImage::where('dataset_status', 'pending')->count(),
            'verifiedCount' => ScanImage::where('dataset_status', 'verified')->count(),
            'exportedCount' => ScanImage::where('dataset_status', 'exported')->count(),
            'rejectedCount' => ScanImage::where('dataset_status', 'rejected')->count(),
        ]);
    }

    public function show(ScanImage $scanImage)
    {
        $scanImage->load(['scanRecord.species', 'scanRecord.user', 'verifiedSpecies', 'verifier']);

        return view('admin.dataset-verification.show', [
            'scanImage' => $scanImage,
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name', 'common_name']),
            'datasetStatuses' => self::DATASET_STATUSES,
            'imageQualities' => self::IMAGE_QUALITIES,
            'plantParts' => self::PLANT_PARTS,
            'imageUrl' => $this->publicImageUrl($scanImage),
        ]);
    }

    public function update(Request $request, ScanImage $scanImage)
    {
        $data = $request->validate([
            'verified_species_id' => ['nullable', 'exists:species,id'],
            'verified_plant_part' => ['nullable', Rule::in(self::PLANT_PARTS)],
            'dataset_status' => ['required', Rule::in(self::DATASET_STATUSES)],
            'image_quality' => ['nullable', Rule::in(self::IMAGE_QUALITIES)],
            'rejection_reason' => ['nullable', 'string'],
            'dataset_notes' => ['nullable', 'string'],
        ]);

        if (in_array($data['dataset_status'], ['verified', 'exported'], true)) {
            if (empty($data['verified_species_id'])) {
                throw ValidationException::withMessages([
                    'verified_species_id' => 'Verified species is required when marking an image as verified or exported.',
                ]);
            }

            if (empty($data['verified_plant_part'])) {
                throw ValidationException::withMessages([
                    'verified_plant_part' => 'Verified plant part is required when marking an image as verified or exported.',
                ]);
            }
        }

        if ($data['dataset_status'] === 'verified') {
            if (($data['image_quality'] ?? null) === 'reject') {
                throw ValidationException::withMessages([
                    'image_quality' => 'Rejected image quality cannot be used for verified dataset images.',
                ]);
            }

            if (empty($data['image_quality'])) {
                throw ValidationException::withMessages([
                    'image_quality' => 'Image quality is required when marking an image as verified.',
                ]);
            }

            $data['verified_by'] = Auth::id();
            $data['verified_at'] = now();
        }

        if ($data['dataset_status'] === 'rejected') {
            $data['verified_by'] = Auth::id();
            $data['verified_at'] = now();
        }

        if ($data['dataset_status'] === 'pending') {
            $data['verified_by'] = null;
            $data['verified_at'] = null;
        }

        $scanImage->update($data);

        return redirect()
            ->route('admin.dataset-verification.show', $scanImage)
            ->with('success', 'Dataset verification updated successfully.');
    }

    public function exportVerified(DatasetExportService $exportService)
    {
        $summary = $exportService->exportVerifiedImages();
        $message = "Dataset export completed. Exported {$summary['exported_count']} image(s), skipped {$summary['skipped_count']} image(s).";
        $redirect = redirect()
            ->route('admin.dataset-verification.index')
            ->with('success', $message);

        if (! empty($summary['errors'])) {
            $errorPreview = implode(' ', array_slice($summary['errors'], 0, 2));

            return $redirect->with('warning', 'Some images were skipped. ' . $errorPreview);
        }

        return $redirect;
    }

    private function publicImageUrl(ScanImage $scanImage): ?string
    {
        if (! $scanImage->image_path || ! Storage::disk('public')->exists($scanImage->image_path)) {
            return null;
        }

        return asset('storage/' . $scanImage->image_path);
    }
}
