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
        'Date', 'Recorder', 'Location', 'Transect', 'Plot No', 'Species',
        'Category', 'Count-MG', 'Density', 'GBH (cm)', 'GBH (m)', 'DBH (m)',
        'Basal Area (m2)', 'Dominance', 'Stand Basal Area (m2/ha)',
        'Height (m)', 'Tree Volume', 'Stand Tree Volume', 'Canopy 1 (m)',
        'Canopy 2 (m)', 'Canopy 2 cor', 'Ave CD', 'Crown Cover', 'Substrate',
        'Associated Flora', 'Associated Fauna', 'Anthropogenic Activity',
        'Impact', 'Other Observations',
    ];

    /** @param Collection<int, \App\Models\Transect> $transects */
    public function create(Collection $transects, ?float $plotAreaM2 = null): string
    {
        $book = new Spreadsheet;
        $vegetation = $book->getActiveSheet();
        $vegetation->setTitle('Vegetation Data');
        $raw = $book->createSheet();
        $raw->setTitle('Raw Scans');
        $notes = $book->createSheet();
        $notes->setTitle('Export Notes');

        $vegetation->fromArray(self::HEADERS, null, 'A1');
        $raw->fromArray([
            'Transect ID', 'Transect Name', 'Scan ID', 'Recorder', 'Captured At',
            'Latitude', 'Longitude', 'DBH (cm)', 'Height (m)', 'Canopy Width (m)',
            'Confidence', 'Capture Mode',
        ], null, 'A1');

        $notes->setCellValue('A1', 'Vegetation export notes');
        $notes->setCellValue('A3', 'Source');
        $notes->setCellValue('B3', 'SilvaMang linked transect scans');
        $notes->setCellValue('A4', 'Plot area (m2)');
        if ($plotAreaM2 !== null) {
            $notes->setCellValue('B4', $plotAreaM2);
        }
        $notes->setCellValue('A6', 'One exported row represents one linked scan; Count-MG is 1.');
        $notes->setCellValue('A7', 'Plot number, category, substrate, canopy 2, and associated field notes are blank when not collected.');
        $notes->setCellValue('A8', 'Density and per-hectare values require a plot area in B4. Enter the actual sampled area.');
        $notes->setCellValue('A9', 'GBH is derived from measured DBH; basal area uses DBH in meters.');
        $notes->setCellValue('A10', 'Tree volume uses the source workbook form factor 0.5.');
        $notes->setCellValue('A11', 'Canopy 1 is the recorded width. Canopy 2 remains blank unless measured separately.');
        $notes->setCellValue('A12', 'Dominance requires a plot number entered in column E.');
        $notes->getColumnDimension('A')->setWidth(100);
        $notes->getColumnDimension('B')->setWidth(36);
        $notes->getStyle('A1')->getFont()->setBold(true)->setSize(16);
        $notes->getStyle('B4')->getNumberFormat()->setFormatCode('0.00');

        $row = 2;
        foreach ($transects as $transect) {
            foreach ($transect->observations as $scan) {
                $measurement = $scan->measurement;
                $height = $scan->height_m ?? $measurement?->height_m;
                $width = $scan->canopy_width_m ?? $measurement?->canopy_width_m;
                $dbh = $measurement?->dbh_cm;
                $date = $scan->captured_at ?? $transect->recorded_at ?? $transect->created_at;
                $recorder = $scan->user?->name ?? $transect->user?->name;

                $this->text($raw, "A$row", $transect->transect_code);
                $this->text($raw, "B$row", $transect->transect_name);
                $this->text($raw, "C$row", $scan->record_code);
                $this->text($raw, "D$row", $recorder);
                $this->text($raw, "E$row", $date?->toIso8601String());
                $this->number($raw, "F$row", $scan->latitude);
                $this->number($raw, "G$row", $scan->longitude);
                $this->number($raw, "H$row", $dbh);
                $this->number($raw, "I$row", $height);
                $this->number($raw, "J$row", $width);
                $this->number($raw, "K$row", $scan->confidence);
                $this->text($raw, "L$row", $scan->capture_mode);

                $this->text($vegetation, "A$row", $date?->format('F d, Y'));
                $this->text($vegetation, "B$row", $recorder);
                $this->text($vegetation, "C$row", $scan->location_name ?: $transect->location_name);
                $this->text($vegetation, "D$row", $transect->transect_code ?: $transect->transect_name);
                $this->text($vegetation, "F$row", $scan->top_scientific_name ?: $scan->species?->scientific_name);
                $vegetation->setCellValue("H$row", 1);
                $vegetation->setCellValue("I$row", "=IF(OR(H$row=\"\",'Export Notes'!\$B\$4=\"\"),\"\",H$row*10000/'Export Notes'!\$B\$4)");
                $vegetation->setCellValue("J$row", "=IF('Raw Scans'!H$row=\"\",\"\",'Raw Scans'!H$row*PI())");
                $vegetation->setCellValue("K$row", "=IF(J$row=\"\",\"\",J$row/100)");
                $vegetation->setCellValue("L$row", "=IF(K$row=\"\",\"\",K$row/PI())");
                $vegetation->setCellValue("M$row", "=IF(L$row=\"\",\"\",PI()*(L$row/2)^2)");
                $vegetation->setCellValue("O$row", "=IF(OR(M$row=\"\",'Export Notes'!\$B\$4=\"\"),\"\",M$row*10000/'Export Notes'!\$B\$4)");
                $this->number($vegetation, "P$row", $height);
                $vegetation->setCellValue("Q$row", "=IF(OR(M$row=\"\",P$row=\"\"),\"\",M$row*P$row*0.5)");
                $vegetation->setCellValue("R$row", "=IF(OR(Q$row=\"\",'Export Notes'!\$B\$4=\"\"),\"\",Q$row*10000/'Export Notes'!\$B\$4)");
                $this->number($vegetation, "S$row", $width);
                $vegetation->setCellValue("U$row", "=IF(T$row=\"\",\"\",T$row/2)");
                $vegetation->setCellValue("V$row", "=IF(S$row=\"\",\"\",IF(U$row=\"\",S$row,AVERAGE(S$row,U$row)))");
                $vegetation->setCellValue("W$row", "=IF(V$row=\"\",\"\",PI()/4*V$row^2)");
                $this->text($vegetation, "AC$row", $scan->notes);
                $row++;
            }
        }

        $lastRow = max(2, $row - 1);
        for ($current = 2; $current < $row; $current++) {
            $vegetation->setCellValue("N$current", "=IF(OR(E$current=\"\",M$current=\"\"),\"\",IFERROR(M$current/SUMIFS(\$M\$2:\$M\$$lastRow,\$D\$2:\$D\$$lastRow,D$current,\$E\$2:\$E\$$lastRow,E$current)*100,\"\"))");
        }

        $this->styleSheet($vegetation, 'AC', $lastRow);
        $this->styleSheet($raw, 'L', $lastRow);
        $vegetation->getColumnDimension('F')->setWidth(27);
        $vegetation->getColumnDimension('AC')->setWidth(48);
        $raw->getColumnDimension('B')->setWidth(30);
        $raw->getColumnDimension('C')->setWidth(27);
        $raw->getColumnDimension('E')->setWidth(28);
        $vegetation->getStyle("I2:W$lastRow")->getNumberFormat()->setFormatCode('0.0000');
        $raw->getStyle("F2:J$lastRow")->getNumberFormat()->setFormatCode('0.0000');

        $book->setActiveSheetIndex(0);
        $path = tempnam(sys_get_temp_dir(), 'silvamang-vegetation-');
        if ($path === false) {
            throw new \RuntimeException('Unable to create the Excel export.');
        }
        try {
            $writer = new Xlsx($book);
            $writer->setPreCalculateFormulas(false);
            $writer->save($path);
        } catch (\Throwable $error) {
            @unlink($path);
            throw $error;
        } finally {
            $book->disconnectWorksheets();
        }

        return $path;
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
