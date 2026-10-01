<?php

namespace Tests\Feature;

use App\Models\ChatbotLog;
use App\Models\Role;
use App\Models\Transect;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PanelPaginationTest extends TestCase
{
    use RefreshDatabase;

    public function test_empty_species_and_real_model_form_remain_accessible(): void
    {
        $admin = User::factory()->create();
        $role = Role::create(['name' => 'admin', 'display_name' => 'Admin', 'status' => 'active']);
        $admin->roles()->attach($role);
        $this->actingAs($admin)->get('/admin/species')->assertOk()
            ->assertSee('No species records yet')->assertSee(route('admin.species.create'));
        $this->get('/admin/species?search=Missing')->assertOk()->assertSee('No matching species');
        $this->get('/admin/species/create')->assertOk();
        $this->get('/admin/ai-models/create')->assertOk()
            ->assertSee('It does not upload, train, or deploy a model.')->assertSee(route('admin.ai-models.store'));
    }

    public function test_transect_pages_preserve_scope_filters_totals_and_legacy_sync(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        foreach (range(1, 12) as $index) {
            Transect::create([
                'user_id' => $user->id, 'transect_code' => 'PAGE-'.$index,
                'transect_name' => 'Coastal '.$index, 'mode' => 'manual_points',
                'start_latitude' => 10, 'start_longitude' => 124,
                'end_latitude' => 10.001, 'end_longitude' => 124,
                'total_distance_m' => 100, 'recorded_at' => '2026-01-01 00:00:00',
            ]);
        }
        $foreign = Transect::first()->replicate();
        $foreign->user_id = $other->id;
        $foreign->transect_code = 'PRIVATE';
        $foreign->save();
        Sanctum::actingAs($user);
        $this->getJson('/api/transects?scope=all&page=1&per_page=10&search=Coastal')
            ->assertOk()->assertJsonCount(10, 'data')->assertJsonPath('meta.total', 12)
            ->assertJsonPath('data.0.transect_name', 'Coastal 12')->assertJsonPath('scope', 'mine');
        $this->getJson('/api/transects?page=2&per_page=10&search=Coastal')
            ->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('data.0.transect_name', 'Coastal 2');
        $this->getJson('/api/transects')->assertOk()->assertJsonCount(12, 'data');
        $this->getJson('/api/transects?per_page=101')->assertUnprocessable();
        $this->actingAs($user)->get('/admin/transects?search=Coastal&page=2')
            ->assertOk()->assertSee('Page 2 of 2')->assertSee('search=Coastal', false)
            ->assertViewHas('totalDistanceM', 1200.0)
            ->assertViewHas('transects', fn ($rows) => $rows->count() === 2 && $rows->total() === 12);
        $this->assertDatabaseCount('transects', 13);
    }

    public function test_conversations_have_limited_preview_paginated_history_and_access_control(): void
    {
        $admin = User::factory()->create();
        $role = Role::create(['name' => 'admin', 'display_name' => 'Admin', 'status' => 'active']);
        $admin->roles()->attach($role);
        foreach (range(1, 12) as $index) {
            ChatbotLog::create(['user_id' => $admin->id, 'question' => 'Mangrove question '.$index,
                'response' => 'Saved answer', 'source' => 'knowledge_base']);
        }
        $this->actingAs($admin)->get('/admin/chatbot-management')->assertOk()
            ->assertViewHas('recentLogs', fn ($logs) => $logs->count() === 5 && $logs->first()->question === 'Mangrove question 12');
        $this->get('/admin/chatbot-management/conversations?search=Mangrove&page=2')
            ->assertOk()->assertSee('Page 2 of 2')->assertSee('search=Mangrove', false)
            ->assertViewHas('recentLogs', fn ($logs) => $logs->count() === 2 && $logs->total() === 12);
        $this->actingAs(User::factory()->create())->get('/admin/chatbot-management/conversations')->assertRedirect(route('admin.dashboard'));
        $this->getJson('/admin/chatbot-management/conversations')->assertForbidden();
        $this->assertDatabaseCount('chatbot_logs', 12);
    }
}
