<?php
namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SettingsStatusTest extends TestCase
{
    use RefreshDatabase;

    private function userWithRole(string $role): User
    {
        $user = User::factory()->create(['password' => Hash::make('old-password')]);
        $user->roles()->attach(Role::firstOrCreate(['name' => $role], ['display_name' => $role, 'status' => 'active']));
        return $user;
    }

    public function test_admin_can_save_preferences_and_they_affect_the_console(): void
    {
        Http::fake();
        $this->actingAs($this->userWithRole('admin'));
        $this->put(route('admin.settings.update'), ['console_name' => 'Field Admin', 'support_email' => 'help@example.com', 'records_per_page' => 25])->assertRedirect();
        $this->assertDatabaseHas('system_settings', ['key' => 'records_per_page', 'value' => '25']);
        $this->get(route('admin.settings.index'))->assertOk()->assertSee('Field Admin')->assertSee('help@example.com')->assertSee('Change Password')->assertDontSee('CNN classifier');
        Http::assertNothingSent();
        $this->get(route('admin.users.index'))->assertOk()->assertViewHas('users', fn ($users) => $users->perPage() === 25);
    }

    public function test_non_admin_cannot_access_or_change_system_settings(): void
    {
        foreach (['researcher', 'mobile_user'] as $role) {
            $this->actingAs($this->userWithRole($role));
            $this->getJson(route('admin.settings.index'))->assertForbidden();
            $this->putJson(route('admin.settings.update'), ['console_name' => 'Bad'])->assertForbidden();
            $this->patchJson(route('admin.settings.password'), [])->assertForbidden();
        }
    }

    public function test_invalid_preferences_are_not_saved(): void
    {
        $this->actingAs($this->userWithRole('super_admin'));
        $this->put(route('admin.settings.update'), ['console_name' => '', 'support_email' => 'bad', 'records_per_page' => 999])->assertSessionHasErrors(['console_name', 'support_email', 'records_per_page']);
        $this->assertDatabaseCount('system_settings', 0);
    }

    public function test_account_and_password_changes_require_current_password(): void
    {
        $user = $this->userWithRole('admin');
        $this->actingAs($user);
        $this->patch(route('admin.settings.account'), ['name' => 'Updated Admin', 'email' => 'updated@example.com', 'current_password' => 'wrong'])->assertSessionHasErrors('current_password');
        $this->assertNotSame('updated@example.com', $user->fresh()->email);
        $this->patch(route('admin.settings.account'), ['name' => 'Updated Admin', 'email' => 'updated@example.com', 'current_password' => 'old-password'])->assertSessionHasNoErrors();
        $this->assertSame('updated@example.com', $user->fresh()->email);
        $this->patch(route('admin.settings.password'), ['current_password' => 'wrong', 'password' => 'new-password', 'password_confirmation' => 'new-password'])->assertSessionHasErrors('current_password');
        $this->assertTrue(Hash::check('old-password', $user->fresh()->password));
        $this->patch(route('admin.settings.password'), ['current_password' => 'old-password', 'password' => 'new-password', 'password_confirmation' => 'new-password'])->assertSessionHasNoErrors();
        $this->assertTrue(Hash::check('new-password', $user->fresh()->password));
    }
}
