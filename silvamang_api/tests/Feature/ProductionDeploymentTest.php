<?php

namespace Tests\Feature;

use App\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Tests\TestCase;

class ProductionDeploymentTest extends TestCase
{
    public function test_trusted_proxy_preserves_https_urls_and_client_address(): void
    {
        config(['deployment.trusted_proxies' => '10.20.0.10']);
        $request = Request::create('http://silvamangai.online/login', 'GET', [], [], [], [
            'REMOTE_ADDR' => '10.20.0.10',
            'HTTP_X_FORWARDED_PROTO' => 'https',
            'HTTP_X_FORWARDED_PORT' => '443',
            'HTTP_X_FORWARDED_FOR' => '203.0.113.20',
        ]);

        (new TrustProxies())->handle($request, function (Request $request) {
            $this->assertTrue($request->isSecure());
            $this->assertSame('https://silvamangai.online/login', $request->url());
            $this->assertSame('203.0.113.20', $request->ip());

            return response('ok');
        });
    }

    public function test_untrusted_client_cannot_spoof_https(): void
    {
        config(['deployment.trusted_proxies' => '10.20.0.10']);
        $request = Request::create('http://silvamangai.online/login', 'GET', [], [], [], [
            'REMOTE_ADDR' => '203.0.113.20',
            'HTTP_X_FORWARDED_PROTO' => 'https',
        ]);

        (new TrustProxies())->handle($request, function (Request $request) {
            $this->assertFalse($request->isSecure());

            return response('ok');
        });
    }
}
