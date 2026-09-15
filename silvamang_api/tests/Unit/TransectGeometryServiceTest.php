<?php

namespace Tests\Unit;

use App\Services\TransectGeometryService;
use PHPUnit\Framework\TestCase;

class TransectGeometryServiceTest extends TestCase
{
    public function test_it_calculates_an_eighty_five_meter_eastbound_polyline(): void
    {
        $summary = (new TransectGeometryService())->summarize([
            ['latitude' => 0.0, 'longitude' => 0.0],
            ['latitude' => 0.0, 'longitude' => 0.00038225],
            ['latitude' => 0.0, 'longitude' => 0.00076450],
        ]);

        $this->assertEqualsWithDelta(85.0, $summary['distance_m'], 0.25);
        $this->assertEqualsWithDelta(90.0, $summary['bearing_degrees'], 0.01);
        $this->assertSame('LineString', $summary['geometry']['type']);
        $this->assertCount(3, $summary['geometry']['coordinates']);
        $this->assertSame([0.0007645, 0.0], $summary['geometry']['coordinates'][2]);
    }
}
