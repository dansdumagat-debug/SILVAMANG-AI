<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Demo passwords must be changed before deployment.
        $users = [
            [
                'name' => 'Super Admin',
                'email' => 'admin@silvamang.test',
                'role' => 'super_admin',
            ],
            [
                'name' => 'Researcher User',
                'email' => 'researcher@silvamang.test',
                'role' => 'researcher',
            ],
            [
                'name' => 'Mobile User',
                'email' => 'user@silvamang.test',
                'role' => 'mobile_user',
            ],
        ];

        foreach ($users as $userData) {
            $user = User::updateOrCreate(
                ['email' => $userData['email']],
                [
                    'name' => $userData['name'],
                    'password' => Hash::make('password'),
                ]
            );

            $user->assignRole($userData['role']);
        }
    }
}
