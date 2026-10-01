<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ProductionRolesTest extends TestCase
{
    use RefreshDatabase;

    public function test_restoring_roles_preserves_accounts_and_allows_a_researcher_to_be_created(): void
    {
        $adminRole = Role::create(['name' => 'super_admin', 'display_name' => 'Super Admin', 'status' => 'active']);
        $admin = User::factory()->create();
        $admin->roles()->attach($adminRole);
        $passwordHash = $admin->password;

        $this->seed(RoleSeeder::class);
        $this->seed(RoleSeeder::class);

        $this->assertDatabaseCount('roles', 4);
        $this->assertDatabaseCount('users', 1);
        $this->assertSame($passwordHash, $admin->fresh()->password);
        $this->assertSame([$adminRole->id], $admin->roles()->pluck('roles.id')->all());
        $this->actingAs($admin)->get(route('admin.users.create'))
            ->assertOk()
            ->assertSee('Researcher')
            ->assertSee('Mobile User')
            ->assertSee('Admin')
            ->assertSee('Super Admin');

        $researcherRole = Role::where('name', 'researcher')->firstOrFail();
        $this->post(route('admin.users.store'), [
            'name' => 'Researcher',
            'email' => 'researcher@example.test',
            'password' => 'Test-only-password-42',
            'password_confirmation' => 'Test-only-password-42',
            'roles' => [$researcherRole->id],
        ])->assertSessionHasNoErrors()->assertRedirect(route('admin.users.index'));

        $researcher = User::where('email', 'researcher@example.test')->firstOrFail();
        $this->assertTrue(Hash::check('Test-only-password-42', $researcher->password));
        $this->assertSame(['researcher'], $researcher->roles()->pluck('name')->all());
        $this->actingAs($researcher)->get(route('admin.users.create'))
            ->assertRedirect(route('admin.dashboard'));
    }
}
