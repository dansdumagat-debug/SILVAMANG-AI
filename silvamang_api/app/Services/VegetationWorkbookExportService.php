<?php

namespace App\Services;

use Illuminate\Support\Collection;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class VegetationWorkbookExportService
{
    private const HEADERS = [
        'Date', 'Recorder', 'Location', 'Transect', 'Plot No', 'Species', 'Category',
        'Count-MG', 'Density', 'GBH (cm)', 'GBH (m)', 'DBH (cm)', 'DBH (m)',
        'Basal Area (m2)', 'Stand Basal Area (m2/ha)', 'Height (m)', 'Tree Volume',
        'Stand Tree Volume', 'Canopy 1 (m)', 'Canopy 2 (m)', 'Canopy Width (m)',
        'Substrate', 'Associated Flora', 'Associated Fauna', 'Anthropogenic Activity',
        'Impact', 'Other Observations',
    ];

    public function create(Collection $transects, ?float $plotAreaM2 = null): string
    {
        $book = new Spreadsheet;
        $vegetation = $book->getActiveSheet()->setTitle('Vegetation Data');
        $raw = $book->createSheet()->setTitle('Raw Scans');
        $summary = $book->createSheet()->setTitle('Transect Summary');
        $speciesSheet = $book->createSheet()->setTitle('Species Summary');
        $notes = $book->createSheet()->setTitle('Export Notes');
        $vegetation->fromArray(self::HEADERS, null, 'A1');
        $raw->fromArray(['Transect ID', 'Transect Name', 'Scan ID', 'Recorder', 'Captured At',
            'Latitude', 'Longitude', 'DBH (cm)', 'Height (m)', 'Canopy Width (m)',
            'Confidence', 'Capture Mode', 'Plot No', 'GBH (cm)', 'GBH (m)', 'DBH (m)',
            'Basal Area (m2)', 'Canopy 1 (m)', 'Canopy 2 (m)'], null, 'A1');
        $summary->fromArray(['Transect ID', 'Transect Name', 'Location', 'Date', 'Start Latitude',
            'Start Longitude', 'End Latitude', 'End Longitude', 'Total Transect Distance (m)',
            'Number of Plots', 'Number of Observations', 'Number of Species', 'Recorded Users'], null, 'A1');
        $speciesSheet->fromArray(['Scientific Name', 'Common Name', 'Family', 'Transect', 'Plot',
            'Number of Observations', 'Average Height (m)', 'Average GBH (cm)', 'Average DBH (cm)',
            'Average Canopy 1 (m)', 'Average Canopy 2 (m)', 'Average Canopy Width (m)'], null, 'A1');
        $notes->fromArray([
            ['Structural measurement methodology'],
            ['GBH is measured circumference in cm; GBH_m = GBH_cm / 100.'],
            ['Existing workbook relationship: DBH_cm = GBH_cm / PI(); DBH_m = DBH_cm / 100.'],
            ['Existing basal-area calculation: PI() * (DBH_m / 2)^2, in square meters.'],
            ['Separate canopy axes and recorded canopy width are exported independently; no width is inferred from either axis.'],
            ['Legacy DBH-only records retain DBH; measured GBH is blank when absent.'],
            ['Existing tree-volume calculation: basal area * height * 0.5 (source-workbook form factor).'],
            ['Density and stand values require a supplied positive plot area, applied uniformly to exported observations.'],
            ['Averages use available positive finite values only; all-missing groups are blank. Missing measurements are not zero.'],
            ['One row per observation within each transect; recorder is the observation user, not the transect owner.'],
            ['Plot No is a field identifier on the observation; no separate Plot entity existed in this system.'],
            ['Uncollected category, substrate, flora, fauna, anthropogenic activity and impact remain blank.'],
        ], null, 'A1');
        $notes->getColumnDimension('A')->setWidth(120);
        $notes->getStyle('A1:A12')->getAlignment()->setWrapText(true);
        $row = 2;
        $summaryRow = 2;
        $speciesRow = 2;
        foreach ($transects->unique('id') as $transect) {
            $scans = $transect->observations->unique('id');
            $groups = collect();
            foreach ($scans as $scan) {
                $m = $scan->measurement;
                $height = $this->positive($m?->height_m ?? $scan->height_m);
                $width = $this->positive($m?->canopy_width_m ?? $scan->canopy_width_m);
                $gbh = $this->positive($m?->gbh_cm);
                $dbh = $this->positive($m?->dbh_cm);
                $dbhM = $dbh !== null ? $dbh / 100 : null;
                $basal = $dbhM !== null ? pi() * ($dbhM / 2) ** 2 : null;
                $c1 = $this->positive($m?->canopy_1_m);
                $c2 = $this->positive($m?->canopy_2_m);
                $volume = $basal !== null && $height !== null ? $basal * $height * 0.5 : null;
                $factor = $plotAreaM2 !== null && $plotAreaM2 > 0 ? 10000 / $plotAreaM2 : null;
                $date = $scan->captured_at;
                $name = $scan->top_scientific_name ?: $scan->species?->scientific_name;
                $this->writeRow($vegetation, $row, [
                    $date, $scan->user?->name, $scan->location_name ?: $transect->location_name,
                    $transect->transect_code ?: $transect->transect_name, $scan->plot_no, $name,
                    null, 1, $factor, $gbh, $gbh !== null ? $gbh / 100 : null, $dbh, $dbhM,
                    $basal, $factor !== null && $basal !== null ? $basal * $factor : null, $height,
                    $volume, $factor !== null && $volume !== null ? $volume * $factor : null,
                    $c1, $c2, $width, null, null, null, null, null, $scan->notes,
                ]);
                $this->writeRow($raw, $row, [$transect->transect_code, $transect->transect_name,
                    $scan->record_code, $scan->user?->name, $date, $this->positiveOrZero($scan->latitude),
                    $this->positiveOrZero($scan->longitude), $dbh, $height, $width,
                    $this->positiveOrZero($scan->confidence), $scan->capture_mode, $scan->plot_no,
                    $gbh, $gbh !== null ? $gbh / 100 : null, $dbhM, $basal, $c1, $c2]);
                $groups->push(['name' => $name, 'common' => $scan->species?->common_name ?? $scan->top_common_name,
                    'family' => $scan->species?->family, 'plot' => $scan->plot_no,
                    'height' => $height, 'gbh' => $gbh, 'dbh' => $dbh, 'c1' => $c1, 'c2' => $c2, 'width' => $width]);
                $row++;
            }
            $this->writeRow($summary, $summaryRow++, [$transect->transect_code, $transect->transect_name,
                $transect->location_name, $transect->recorded_at,
                $this->positiveOrZero($transect->start_latitude), $this->positiveOrZero($transect->start_longitude),
                $this->positiveOrZero($transect->end_latitude), $this->positiveOrZero($transect->end_longitude),
                $this->positiveOrZero($transect->total_distance_m),
                $scans->pluck('plot_no')->filter(fn ($v) => $v !== null && $v !== '')->unique()->count() ?: null,
                $scans->count(), $groups->pluck('name')->filter()->unique()->count(),
                $scans->pluck('user.name')->filter()->unique()->implode('; ')]);
            foreach ($groups->groupBy(fn ($g) => json_encode([$g['name'], $g['plot']])) as $members) {
                $first = $members->first();
                $averages = [];
                foreach (['height', 'gbh', 'dbh', 'c1', 'c2', 'width'] as $key) {
                    $values = $members->pluck($key)->filter(fn ($v) => $v !== null);
                    $averages[] = $values->isEmpty() ? null : $values->avg();
                }
                $this->writeRow($speciesSheet, $speciesRow++, [$first['name'], $first['common'], $first['family'],
                    $transect->transect_code ?: $transect->transect_name, $first['plot'], $members->count(), ...$averages]);
            }
        }
        $last = max(2, $row - 1);
        $this->styleSheet($vegetation, 'AA', $last);
        $this->styleSheet($raw, 'S', $last);
        $this->styleSheet($summary, 'M', max(2, $summaryRow - 1));
        $this->styleSheet($speciesSheet, 'L', max(2, $speciesRow - 1));
        $vegetation->getColumnDimension('F')->setWidth(30);
        $vegetation->getColumnDimension('AA')->setWidth(45);
        $vegetation->getStyle("I2:U$last")->getNumberFormat()->setFormatCode('0.0000');
        $raw->getStyle("F2:G$last")->getNumberFormat()->setFormatCode('0.0000000');
        $raw->getStyle("H2:S$last")->getNumberFormat()->setFormatCode('0.0000');
        $summary->getStyle('E2:H'.max(2, $summaryRow - 1))->getNumberFormat()->setFormatCode('0.0000000');
        $speciesSheet->getStyle('G2:L'.max(2, $speciesRow - 1))->getNumberFormat()->setFormatCode('0.0000');
        $book->setActiveSheetIndex(0);
        $path = tempnam(sys_get_temp_dir(), 'silvamang-vegetation-');
        if ($path === false) {
            throw new \RuntimeException('Unable to create Excel export.');
        }
        try {
            (new Xlsx($book))->save($path);
        } catch (\Throwable $error) {
            @unlink($path);
            throw $error;
        } finally {
            $book->disconnectWorksheets();
        }

        return $path;
    }

    private function positive(mixed $value): ?float
    {
        $number = $this->positiveOrZero($value);

        return $number !== null && $number > 0 ? $number : null;
    }

    private function positiveOrZero(mixed $value): ?float
    {
        return $value !== null && is_numeric($value) && is_finite((float) $value) ? (float) $value : null;
    }

    private function writeRow($sheet, int $row, array $values): void
    {
        foreach ($values as $index => $value) {
            $cell = Coordinate::stringFromColumnIndex($index + 1).$row;
            if ($value instanceof \DateTimeInterface) {
                $sheet->setCellValue($cell, \PhpOffice\PhpSpreadsheet\Shared\Date::PHPToExcel($value));
                $sheet->getStyle($cell)->getNumberFormat()->setFormatCode('yyyy-mm-dd hh:mm');
            } elseif (is_int($value) || is_float($value)) {
                $this->number($sheet, $cell, $value);
            } elseif ($value !== null) {
                $this->text($sheet, $cell, (string) $value);
            }
        }
    }

    private function text($sheet, string $cell, ?string $value): void
    {
        if ($value !== null && trim($value) !== '') {
            $sheet->setCellValueExplicit($cell, $value, DataType::TYPE_STRING);
        }
    }

    private function number($sheet, string $cell, mixed $value): void
    {
        if ($value !== null && is_numeric($value)) {
            $sheet->setCellValue($cell, (float) $value);
        }
    }

    private function styleSheet($sheet, string $endColumn, int $lastRow): void
    {
        $sheet->freezePane('A2');
        $sheet->setAutoFilter("A1:{$endColumn}{$lastRow}");
        $sheet->getRowDimension(1)->setRowHeight(34);
        $sheet->getStyle("A1:{$endColumn}1")->applyFromArray([
            'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => '184E3A']],
            'alignment' => ['vertical' => Alignment::VERTICAL_CENTER, 'wrapText' => true],
        ]);
        for ($index = 1; $index <= Coordinate::columnIndexFromString($endColumn); $index++) {
            $column = Coordinate::stringFromColumnIndex($index);
            $sheet->getColumnDimension($column)->setWidth(18);
        }
    }
}
