<?php

namespace Database\Seeders;

use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $roles = [
            [
                'name' => 'super_admin',
                'display_name' => 'Super Admin',
                'description' => 'Full system access',
            ],
            [
                'name' => 'admin',
                'display_name' => 'Admin',
                'description' => 'Admin dashboard access',
            ],
            [
                'name' => 'researcher',
                'display_name' => 'Researcher',
                'description' => 'Research and monitoring access',
            ],
            [
                'name' => 'mobile_user',
                'display_name' => 'Mobile User',
                'description' => 'Standard mobile application user',
            ],
        ];

        foreach ($roles as $role) {
            Role::updateOrCreate(
                ['name' => $role['name']],
                $role + ['status' => 'active']
            );
        }
    }
}
