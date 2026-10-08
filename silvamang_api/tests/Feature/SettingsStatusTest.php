<?php

namespace Tests\Feature;

use App\Http\Controllers\Admin\SettingController;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SettingsStatusTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        DB::shouldReceive('connection->getPdo')->andReturn(null);
        config(['services.ai_service.url' => 'http://ai.test']);
        view()->share('errors', new \Illuminate\Support\ViewErrorBag());
    }

    public function test_live_models_replace_old_planned_labels(): void
    {
        Http::fake(['ai.test/ai/health' => Http::response([
            'service' => 'online', 'models' => ['cnn' => true, 'yolov8' => true, 'segmentation' => true],
        ])]);
        $view = app(SettingController::class)->index();
        $data = $view->getData();
        $this->assertSame('Ready', $data['aiConfiguration']['CNN classifier']);
        $this->assertSame('Ready', $data['buildStatus']['AI model readiness']);
        $html = $view->render();
        $this->assertStringNotContainsString('Not Yet Integrated', $html);
        $this->assertStringNotContainsString('planned in Flutter', $html);
        $this->assertStringContainsString('PHT', $html);
        Http::assertSentCount(1);
    }

    public function test_service_failure_does_not_claim_models_are_ready(): void
    {
        Http::fake(['*' => Http::response([], 503)]);
        $data = app(SettingController::class)->index()->getData();
        $this->assertSame('Unavailable', $data['aiConfiguration']['Python AI service']);
        $this->assertSame('Unverified', $data['aiConfiguration']['CNN classifier']);
        $this->assertSame('Needs attention', $data['buildStatus']['AI model readiness']);
    }

    public function test_partial_model_failure_is_visible(): void
    {
        Http::fake(['*' => Http::response([
            'service' => 'online', 'models' => ['cnn' => true, 'yolov8' => false, 'segmentation' => true],
        ])]);
        $data = app(SettingController::class)->index()->getData();
        $this->assertSame('Connected', $data['aiConfiguration']['Python AI service']);
        $this->assertSame('Unavailable', $data['aiConfiguration']['YOLOv8 detector']);
        $this->assertSame('Needs attention', $data['buildStatus']['AI model readiness']);
    }
}
