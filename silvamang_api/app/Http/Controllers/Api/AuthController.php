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
    public function googleRedirect(Request $request)
    {
        if (! config('services.google.client_id') || ! config('services.google.client_secret')) {
            return redirect()->route('login')->withErrors(['google' => 'Google sign-in is not configured yet. Please use your email and password.']);
        }
        $state = bin2hex(random_bytes(32));
        $verifier = bin2hex(random_bytes(32));
        $request->session()->forget('google.link');
        $request->session()->put('google.oauth', ['state' => $state, 'verifier' => $verifier, 'expires' => time() + 600]);
        return redirect()->away('https://accounts.google.com/o/oauth2/v2/auth?'.http_build_query([
            'client_id' => config('services.google.client_id'),
            'redirect_uri' => config('services.google.redirect'),
            'response_type' => 'code', 'scope' => 'openid email profile',
            'state' => $state, 'prompt' => 'select_account',
            'code_challenge' => rtrim(strtr(base64_encode(hash('sha256', $verifier, true)), '+/', '-_'), '='),
            'code_challenge_method' => 'S256',
        ]));
    }

    public function googleCallback(Request $request)
    {
        $attempt = $request->session()->pull('google.oauth');
        $fail = fn ($message) => redirect()->route('login')->withErrors(['google' => $message]);
        if (! is_array($attempt) || ($attempt['expires'] ?? 0) < time()
            || ! is_string($request->query('state'))
            || ! hash_equals($attempt['state'], $request->query('state'))) {
            return $fail('Google sign-in expired. Please try again.');
        }
        if ($request->has('error') || ! is_string($request->query('code'))) {
            return $fail('Google sign-in was cancelled. You can try again or use your password.');
        }
        try {
            $token = \Illuminate\Support\Facades\Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token', [
                'client_id' => config('services.google.client_id'),
                'client_secret' => config('services.google.client_secret'),
                'redirect_uri' => config('services.google.redirect'),
                'grant_type' => 'authorization_code', 'code' => $request->query('code'),
                'code_verifier' => $attempt['verifier'],
            ])->throw()->json();
            if (! is_string($token['access_token'] ?? null)) {
                return $fail('Google sign-in could not be verified. Please try again.');
            }
            $profile = \Illuminate\Support\Facades\Http::withToken($token['access_token'])->timeout(10)
                ->get('https://openidconnect.googleapis.com/v1/userinfo')->throw()->json();
            if (($profile['email_verified'] ?? false) !== true || ! is_string($profile['sub'] ?? null)
                || $profile['sub'] === '' || strlen($profile['sub']) > 255
                || ! filter_var($profile['email'] ?? '', FILTER_VALIDATE_EMAIL)) {
                return $fail('A verified Google email address is required.');
            }
            $user = User::where('google_subject', $profile['sub'])->first();
            if (! $user) {
                $email = strtolower($profile['email']);
                $user = User::whereRaw('LOWER(email) = ?', [$email])->first();
                if (! $user || $user->google_subject) {
                    return $fail('Please ask your administrator to set up access for this Google account.');
                }
                // Require proof of the existing local account before linking identities.
                $request->session()->put('google.link', [
                    'subject' => $profile['sub'], 'user_id' => $user->id,
                    'email' => $email, 'expires' => time() + 600,
                ]);
                return $fail('Enter your existing password once to link this Google account. After that, you can continue with Google.')
                    ->withInput(['email' => $user->email]);
            }
            \Illuminate\Support\Facades\Auth::login($user);
            $request->session()->regenerate();
            return redirect()->intended(route('admin.dashboard'));
        } catch (\Throwable) {
            return $fail('Google sign-in could not be completed. Please try again or use your password.');
        }
    }

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
        $user = User::query()
            ->whereRaw('LOWER(email) = ?', [strtolower($data['email'])])
            ->first();

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
