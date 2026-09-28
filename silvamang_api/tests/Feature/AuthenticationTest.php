<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase;

    public function test_api_login_matches_email_without_case_sensitivity(): void
    {
        User::factory()->create([
            'email' => 'researcher@silvamang.test',
            'password' => 'correct-password',
        ]);

        $this->postJson('/api/login', [
            'email' => '  Researcher@SilvaMang.Test  ',
            'password' => 'correct-password',
        ])->assertOk()
            ->assertJsonPath('message', 'Login successful.')
            ->assertJsonPath('data.user.email', 'researcher@silvamang.test')
            ->assertJsonStructure(['data' => ['token']]);
    }

    public function test_registration_stores_a_normalized_email_address(): void
    {
        Role::create([
            'name' => 'mobile_user',
            'display_name' => 'Mobile User',
            'status' => 'active',
        ]);

        $this->postJson('/api/register', [
            'name' => 'Field User',
            'email' => '  Field.User@Example.COM  ',
            'password' => 'correct-password',
            'password_confirmation' => 'correct-password',
        ])->assertCreated()
            ->assertJsonPath('data.user.email', 'field.user@example.com');

        $this->assertDatabaseHas('users', [
            'email' => 'field.user@example.com',
        ]);
    }

    public function test_web_login_matches_email_without_case_sensitivity(): void
    {
        $user = User::factory()->create([
            'email' => 'admin@silvamang.test',
            'password' => 'correct-password',
        ]);

        $this->post('/login', [
            'email' => 'Admin@SilvaMang.Test',
            'password' => 'correct-password',
        ])->assertRedirect('/admin/dashboard');

        $this->assertAuthenticatedAs($user);
    }
}
