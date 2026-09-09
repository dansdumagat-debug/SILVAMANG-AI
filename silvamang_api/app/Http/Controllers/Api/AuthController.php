<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ChangePasswordRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Requests\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(RegisterRequest $request)
    {
        $data = $request->validated();
        $roleName = 'mobile_user';

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
        ]);

        $user->assignRole($roleName);
        $token = $user->createToken('silvamang-api-token')->plainTextToken;

        return response()->json($this->authResponse('Registration successful.', $user, $token), 201);
    }

    public function login(LoginRequest $request)
    {
        $data = $request->validated();
        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return response()->json([
                'message' => 'Invalid login credentials.',
            ], 401);
        }

        $token = $user->createToken('silvamang-api-token')->plainTextToken;

        return response()->json($this->authResponse('Login successful.', $user, $token));
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json([
            'message' => 'Logout successful.',
        ]);
    }

    public function me(Request $request)
    {
        $user = $request->user()->load('roles');

        return response()->json([
            'message' => 'Authenticated user retrieved successfully.',
            'data' => [
                'user' => new UserResource($user),
                'roles' => $user->roles->pluck('name')->values(),
            ],
        ]);
    }

    public function updateProfile(UpdateProfileRequest $request)
    {
        $user = $request->user();
        $user->update($request->validated());

        return response()->json([
            'message' => 'Profile updated successfully.',
            'data' => [
                'user' => new UserResource($user->load('roles')),
                'roles' => $user->roles->pluck('name')->values(),
            ],
        ]);
    }

    public function changePassword(ChangePasswordRequest $request)
    {
        $user = $request->user();

        if (! Hash::check($request->validated('current_password'), $user->password)) {
            return response()->json([
                'message' => 'Current password is incorrect.',
            ], 422);
        }

        $user->update([
            'password' => $request->validated('password'),
        ]);

        return response()->json([
            'message' => 'Password changed successfully.',
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function authResponse(string $message, User $user, string $token): array
    {
        $user->load('roles');
        $roles = $user->roles->pluck('name')->values();
        $userResource = new UserResource($user);

        return [
            'message' => $message,
            'token' => $token,
            'user' => $userResource,
            'data' => [
                'user' => $userResource,
                'roles' => $roles,
                'token' => $token,
            ],
        ];
    }
}
