<?php
namespace Tests\Feature;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
class GoogleLoginTest extends TestCase
{
    use RefreshDatabase;
    public function test_login_only_offers_password_and_google_routes_are_removed(): void
    {
        $this->get('/login')->assertOk()->assertDontSee('Continue with Google')->assertSee('Sign In');
        $this->get('/auth/google')->assertNotFound();
        $this->get('/auth/google/callback')->assertNotFound();
    }
    public function test_password_login_still_works_and_does_not_link_pending_google_identity(): void
    {
        $user = User::factory()->create(['password' => 'local-password']);
        $this->withSession(['google.link' => ['subject' => 'old-subject', 'user_id' => $user->id, 'email' => $user->email, 'expires' => time()+600]])
            ->post(route('login.store'), ['email' => $user->email, 'password' => 'local-password'])->assertRedirect();
        $this->assertAuthenticatedAs($user);
        $this->assertNull($user->fresh()->google_subject);
    }
}
