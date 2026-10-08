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
        $book = \PhpOffice\PhpSpreadsheet\IOFactory::load(resource_path('export-templates/mangrove-monitoring.xlsx'));
        $vegetation = $book->createSheet()->setTitle('Vegetation Data');
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
            ['Legacy DBH-only records retain DBH in Raw Scans; measured GBH is blank when absent.'],
            ['Existing tree-volume calculation: basal area * height * 0.5 (reference-workbook form factor).'],
            ['Density and stand values require a supplied positive plot area, applied uniformly to exported observations.'],
            ['Averages use available positive finite values only; all-missing groups are blank. Missing measurements are not zero.'],
            ['One row per observation within each transect; recorder is the observation user, not the transect owner.'],
            ['Plot No is a field identifier on the observation; no separate Plot entity existed in this system.'],
            ['Survey fields are exported from recorded ecological details; unknown values remain blank. System-generated scan notes are not field observations.'],
        ], null, 'A1');
        $notes->getColumnDimension('A')->setWidth(120);
        $notes->getStyle('A1:A12')->getAlignment()->setWrapText(true);
        $seenScans = [];
        $plotKeys = [];
        $row = 2;
        $summaryRow = 2;
        $speciesRow = 2;
        foreach ($transects->unique('id') as $transect) {
            $scans = $transect->observations->unique('id')->filter(function ($scan) use (&$seenScans) {
                if (isset($seenScans[$scan->id])) {
                    return false;
                }
                $seenScans[$scan->id] = true;

                return true;
            });
            $groups = collect();
            foreach ($scans as $scan) {
                $plotKeys[$row] = $scan->plot_no !== null && $scan->plot_no !== '' ? json_encode([$transect->id, $scan->plot_no]) : null;
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
                    $date, $scan->user?->name, $scan->survey_location ?: ($scan->location_name ?: $transect->location_name),
                    $transect->transect_code ?: $transect->transect_name, $scan->plot_no, $name,
                    $scan->ecological_category, $scan->count_mg ?? 1, $factor, $gbh, $gbh !== null ? $gbh / 100 : null, $dbh, $dbhM,
                    $basal, $factor !== null && $basal !== null ? $basal * $factor : null, $height,
                    $volume, $factor !== null && $volume !== null ? $volume * $factor : null,
                    $c1, $c2, $width, $scan->substrate, $scan->associated_flora, $scan->associated_fauna, $scan->anthropogenic_activity, $scan->impact, $scan->other_observations,
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
        $this->populateReference($book, $vegetation, $plotKeys, $plotAreaM2);
        $book->removeSheetByIndex($book->getIndex($vegetation));
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

    private function populateReference(Spreadsheet $book, $source, array $plotKeys, ?float $area): void
    {
        $rows = [];
        for ($r = 2; $r <= $source->getHighestDataRow(); $r++) {
            $rows[] = ['row' => $r, 'date' => $source->getCell('A'.$r)->getValue()];
        }
        $days = collect($rows)->groupBy(fn ($record) => $record['date'] === null ? 'undated' : (string) floor((float) $record['date']))->sortKeys();
        $number = 1;
        foreach ($days as $records) {
            $name = 'VEGETATION DATA DAY '.$number++;
            $sheet = $book->getSheetByName($name);
            if (! $sheet) {
                $sheet = clone $book->getSheetByName('VEGETATION DATA DAY 4');
                $sheet->setTitle($name);
                $book->addSheet($sheet);
                foreach ($sheet->getCellCollection()->getCoordinates() as $coord) {
                    if ($sheet->getCell($coord)->getRow() > 1) {
                        $sheet->setCellValue($coord, null);
                    }
                }
            }
            $this->fillReferenceSheet($sheet, $source, $records->values()->all(), $plotKeys, $area, false);
        }
        // Retain all four daily layouts, even when fewer survey dates were selected.
        for ($day = $number; $day <= 4; $day++) {
            $this->fillReferenceSheet($book->getSheetByName('VEGETATION DATA DAY '.$day), $source, [], $plotKeys, $area, false);
        }
        $this->fillReferenceSheet($book->getSheetByName('VEGETATION DATA '), $source, $rows, $plotKeys, $area, true);
        $notes = $book->getSheetByName('Export Notes');
        $notes->setCellValue('A13', 'Reference daily and combined layouts retained. DBH units corrected to meters. Formula results are blank when source data is absent.');
        $notes->setCellValue('A14', 'Stand totals use selected observations grouped by physical transect and plot, with supplied uniform plot area. Partial selections are not a complete plot census.');
        $notes->setCellValue('A15', 'Original pivot/IVI/RF/relative dominance/density report layouts are retained blank: complete census coverage and sampling effort are not established. Original survey records and cached analyses are excluded.');
        $notes->setCellValue('A16', 'Combined-sheet canopy calculations preserve reference methodology: corrected second dimension = Canopy 2 / 2; average diameter = mean(Canopy 1, corrected dimension); crown cover = 0.7854 * average diameter squared. These do not overwrite recorded canopy width.');
        $notes->setCellValue('A17', 'Count-MG uses the recorded census count, otherwise one individual observation per scan. Historical DBH remains available in Raw Scans; the vegetation DBH formula requires measured GBH.');
        $notes->getStyle('A1:A17')->getAlignment()->setWrapText(true);
        $sampling = $book->getSheetByName('Sampling Areas');
        $raw = $book->getSheetByName('Raw Scans');
        foreach ($rows as $index => $record) {
            $r = $record['row'];
            $target = $index + 2;
            foreach (['A' => 'C', 'B' => 'D', 'C' => 'E'] as $to => $from) {
                $sampling->setCellValueExplicit($to.$target, (string) $source->getCell($from.$r)->getValue(), DataType::TYPE_STRING);
            }
            foreach (['D' => 'F', 'E' => 'G'] as $to => $from) {
                $sampling->setCellValue($to.$target, $raw->getCell($from.$r)->getValue());
            }
        }
        $composition = $book->getSheetByName('Species Composition');
        $speciesSummary = $book->getSheetByName('Species Summary');
        $seenSpecies = [];
        $speciesRow = 2;
        for ($r = 2; $r <= $speciesSummary->getHighestDataRow(); $r++) {
            $name = (string) $speciesSummary->getCell('A'.$r)->getValue();
            if ($name === '' || isset($seenSpecies[$name])) {
                continue;
            }
            $seenSpecies[$name] = true;
            foreach (['A' => 'C', 'B' => 'A', 'C' => 'B'] as $to => $from) {
                $composition->setCellValueExplicit($to.$speciesRow, (string) $speciesSummary->getCell($from.$r)->getValue(), DataType::TYPE_STRING);
            }
            $speciesRow++;
        }
        $composition->freezePane('A2');
        $composition->setAutoFilter('A1:E'.max(2, $speciesRow - 1));
        $sampling->freezePane('A2');
        $sampling->setAutoFilter('A1:G'.max(2, count($rows) + 1));
    }

    private function fillReferenceSheet($sheet, $source, array $records, array $plotKeys, ?float $area, bool $combined): void
    {
        usort($records, fn ($a, $b) => strcmp($plotKeys[$a['row']] ?? '', $plotKeys[$b['row']] ?? '') ?: ($a['row'] <=> $b['row']));
        $end = $combined ? 'AC' : 'Y';
        $groups = [];
        foreach ($records as $index => $record) {
            $key = $plotKeys[$record['row']] ?? null;
            if ($key !== null) {
                $groups[$key][] = $index + 2;
            }
        }
        foreach ($records as $index => $record) {
            $r = $index + 2;
            $old = $record['row'];
            $sheet->duplicateStyle($sheet->getStyle('A2:'.$end.'2'), 'A'.$r.':'.$end.$r);
            $map = $combined
                ? ['A' => 'A', 'B' => 'B', 'C' => 'C', 'D' => 'D', 'E' => 'E', 'F' => 'F', 'G' => 'G', 'H' => 'H', 'J' => 'J', 'P' => 'P', 'S' => 'S', 'T' => 'T', 'X' => 'V', 'Y' => 'W', 'Z' => 'X', 'AA' => 'Y', 'AB' => 'Z', 'AC' => 'AA']
                : ['A' => 'A', 'B' => 'B', 'C' => 'C', 'D' => 'D', 'E' => 'E', 'F' => 'F', 'G' => 'G', 'H' => 'H', 'J' => 'J', 'O' => 'P', 'R' => 'S', 'S' => 'T', 'T' => 'V', 'U' => 'W', 'V' => 'X', 'W' => 'Y', 'X' => 'Z', 'Y' => 'AA'];
            foreach ($map as $to => $from) {
                $cell = $source->getCell($from.$old);
                $sheet->setCellValueExplicit($to.$r, $cell->getValue(), $cell->getDataType());
            }
            $sheet->getStyle('A'.$r)->getNumberFormat()->setFormatCode('mmmm dd, yyyy');
            $formula = fn ($column, $value) => $sheet->setCellValue($column.$r, $value);
            $formula('K', '=IF(J'.$r.'="","",J'.$r.'/100)');
            $formula('L', '=IF(J'.$r.'="","",J'.$r.'/PI()/100)');
            $formula('M', '=IF(L'.$r.'="","",PI()*(L'.$r.'/2)^2)');
            $height = $combined ? 'P' : 'O';
            $volume = $combined ? 'Q' : 'P';
            $stand = $combined ? 'O' : 'N';
            $standVolume = $combined ? 'R' : 'Q';
            $formula($volume, '=IF(OR(M'.$r.'="",'.$height.$r.'=""),"",M'.$r.'*'.$height.$r.'*0.5)');
            $factor = $area !== null && $area > 0 ? 10000 / $area : null;
            $formula('I', $factor === null ? '=""' : '=IF(H'.$r.'="","",H'.$r.'*'.$factor.')');
            $key = $plotKeys[$old] ?? null;
            $members = $key !== null ? ($groups[$key] ?? []) : [];
            foreach ([$stand => 'M', $standVolume => $volume] as $to => $from) {
                $cells = $members ? $from.min($members).':'.$from.max($members) : '';
                $formula($to, $factor === null || ! $members ? '=""' : '=IF(COUNT('.$cells.')<'.count($members).',"",SUM('.$cells.')*'.$factor.')');
            }
            if ($combined) {
                $formula('N', $factor === null ? '=""' : '=IF(M'.$r.'="","",M'.$r.'*'.$factor.')');
                $formula('U', '=IF(T'.$r.'="","",T'.$r.'/2)');
                $formula('V', '=IF(OR(S'.$r.'="",U'.$r.'=""),"",AVERAGE(S'.$r.',U'.$r.'))');
                $formula('W', '=IF(V'.$r.'="","",0.7854*V'.$r.'^2)');
            }
            $sheet->getStyle('I'.$r.':'.($combined ? 'W' : 'S').$r)->getNumberFormat()->setFormatCode('0.########');
        }
        $last = max(2, count($records) + 1);
        if ($sheet->getHighestRow() > $last) {
            $sheet->removeRow($last + 1, $sheet->getHighestRow() - $last);
        }
        // Keep template headers/sheets, but make recorded rows readable in Excel and WPS.
        $sheet->getStyle('A2:'.$end.$last)->getFont()->setBold(false)->setSize(11);
        $sheet->getStyle('A2:'.$end.$last)->getAlignment()->setVertical(Alignment::VERTICAL_CENTER);
        $sheet->getStyle('F2:F'.$last)->getFont()->setItalic(true);
        $sheet->getStyle('H2:H'.$last)->getNumberFormat()->setFormatCode('0');
        $sheet->getStyle('I2:I'.$last)->getNumberFormat()->setFormatCode('0.####');
        $sheet->getStyle('A1:'.$end.'1')->getAlignment()->setWrapText(true);
        $sheet->getRowDimension(1)->setRowHeight(34);
        foreach (range(1, Coordinate::columnIndexFromString($end)) as $col) {
            $letter = Coordinate::stringFromColumnIndex($col);
            $sheet->getColumnDimension($letter)->setWidth(19);
        }
        foreach (['A' => 23, 'B' => 26, 'C' => 30, 'D' => 27, 'E' => 12, 'F' => 33, 'G' => 14, 'H' => 12] as $col => $width) {
            $sheet->getColumnDimension($col)->setWidth($width);
        }
        $sheet->getColumnDimension($combined ? 'O' : 'N')->setWidth(26);
        for ($col = Coordinate::columnIndexFromString($combined ? 'X' : 'T'); $col <= Coordinate::columnIndexFromString($end); $col++) {
            $letter = Coordinate::stringFromColumnIndex($col);
            $sheet->getColumnDimension($letter)->setWidth(30);
            $sheet->getStyle($letter.'2:'.$letter.$last)->getAlignment()->setWrapText(true);
        }
        $sheet->freezePane('A2');
        $sheet->setAutoFilter('A1:'.$end.max(2, count($records) + 1));
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
