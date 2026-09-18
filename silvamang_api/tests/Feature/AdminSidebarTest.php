<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminSidebarTest extends TestCase
{
    use RefreshDatabase;

    public function test_current_group_opens_and_admin_links_remain_role_restricted(): void
    {
        $researcherRole = Role::create([
            'name' => 'researcher',
            'display_name' => 'Researcher',
            'status' => 'active',
        ]);
        $researcher = User::factory()->create();
        $researcher->roles()->attach($researcherRole);

        $speciesPage = $this->actingAs($researcher)
            ->get('/admin/species')
            ->assertOk()
            ->assertSee('Species & Learning')
            ->assertSee('Species Management')
            ->assertDontSee('Chatbot Management');
        $this->assertMatchesRegularExpression(
            '/<details class="sidebar-group"\s+open\s*>\s*<summary class="group-active">Species &amp; Learning/s',
            $speciesPage->getContent()
        );

        $mobileRole = Role::create([
            'name' => 'mobile_user',
            'display_name' => 'Mobile User',
            'status' => 'active',
        ]);
        $mobileUser = User::factory()->create();
        $mobileUser->roles()->attach($mobileRole);

        $this->actingAs($mobileUser)
            ->get('/admin/dashboard')
            ->assertOk()
            ->assertSee('My Map')
            ->assertDontSee('Species Management')
            ->assertDontSee('AI & System');
    }
}
