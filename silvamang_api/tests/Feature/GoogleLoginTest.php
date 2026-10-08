<?php
namespace Tests\Feature;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;
class GoogleLoginTest extends TestCase
{
    use RefreshDatabase;
    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_id'=>'test-client','services.google.client_secret'=>'test-secret','services.google.redirect'=>'https://silvamangai.online/auth/google/callback']);
    }
    private function attempt(): array { return ['state'=>'test-state','verifier'=>'test-verifier','expires'=>time()+600]; }
    private function fakeProfile(bool $verified = true): void
    {
        Http::fake([
            'oauth2.googleapis.com/token'=>Http::response(['access_token'=>'test-token']),
            'openidconnect.googleapis.com/v1/userinfo'=>Http::response(['sub'=>'google-123','email'=>'staff@example.com','email_verified'=>$verified]),
        ]);
    }
    public function test_button_starts_state_protected_google_flow(): void
    {
        $response=$this->get(route('auth.google'));
        $response->assertRedirect();
        parse_str(parse_url($response->headers->get('Location'),PHP_URL_QUERY),$query);
        $this->assertSame('S256',$query['code_challenge_method']);
        $this->assertSame(session('google.oauth.state'),$query['state']);
        $this->assertSame('test-client',$query['client_id']);
    }
    public function test_invalid_state_is_rejected_without_contacting_google(): void
    {
        Http::fake();
        $this->withSession(['google.oauth'=>$this->attempt()])->get('/auth/google/callback?state=wrong&code=code')->assertRedirect(route('login'))->assertSessionHasErrors('google');
        Http::assertNothingSent();$this->assertGuest();
    }
    public function test_linked_google_account_can_log_in(): void
    {
        $user=User::factory()->create(['email'=>'staff@example.com']);
        $user->forceFill(['google_subject'=>'google-123'])->save();
        $this->fakeProfile();
        $this->withSession(['google.oauth'=>$this->attempt()])->get('/auth/google/callback?state=test-state&code=code')->assertRedirect(route('admin.dashboard'));
        $this->assertAuthenticatedAs($user);
    }
    public function test_existing_account_requires_password_before_linking(): void
    {
        $user=User::factory()->create(['email'=>'staff@example.com','password'=>'local-password']);
        $this->fakeProfile();
        $this->withSession(['google.oauth'=>$this->attempt()])->get('/auth/google/callback?state=test-state&code=code')->assertRedirect(route('login'));
        $this->assertGuest();$this->assertNull($user->fresh()->google_subject);
        $this->post(route('login.store'),['email'=>'staff@example.com','password'=>'wrong'])->assertSessionHasErrors('email');
        $this->assertNull($user->fresh()->google_subject);
        $this->post(route('login.store'),['email'=>'staff@example.com','password'=>'local-password'])->assertRedirect();
        $this->assertAuthenticatedAs($user);$this->assertSame('google-123',$user->fresh()->google_subject);
    }
    public function test_unverified_or_unknown_google_account_does_not_gain_access(): void
    {
        $this->fakeProfile(false);
        $this->withSession(['google.oauth'=>$this->attempt()])->get('/auth/google/callback?state=test-state&code=code')->assertSessionHasErrors('google');
        $this->assertGuest();
        $this->fakeProfile();
        $this->withSession(['google.oauth'=>$this->attempt()])->get('/auth/google/callback?state=test-state&code=code')->assertSessionHasErrors('google');
        $this->assertDatabaseCount('users',0);
    }
    public function test_missing_credentials_reports_setup_needed(): void
    {
        config(['services.google.client_secret'=>null]);
        $this->get(route('auth.google'))->assertRedirect(route('login'))->assertSessionHasErrors('google');
    }
}
