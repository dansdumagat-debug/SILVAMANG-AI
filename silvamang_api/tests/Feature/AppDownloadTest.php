<?php

namespace Tests\Feature;

use Tests\TestCase;

class AppDownloadTest extends TestCase
{
    private string $downloadStorage;

    protected function setUp(): void
    {
        parent::setUp();
        $this->downloadStorage = sys_get_temp_dir().'/silvamang-download-'.bin2hex(random_bytes(8));
        mkdir($this->downloadStorage.'/app/releases', 0777, true);
        $this->app->useStoragePath($this->downloadStorage);
    }

    protected function tearDown(): void
    {
        @unlink($this->downloadStorage.'/app/releases/silvamang-ai.apk');
        @unlink($this->downloadStorage.'/app/releases/release.json');
        @rmdir($this->downloadStorage.'/app/releases');
        @rmdir($this->downloadStorage.'/app');
        @rmdir($this->downloadStorage);
        parent::tearDown();
    }

    public function test_missing_release_shows_coming_soon_and_cannot_be_downloaded(): void
    {
        $this->get('/download')->assertOk()->assertSee('Download coming soon')->assertDontSee('Download Android APK');
        $this->get('/download/android')->assertNotFound();
    }

    public function test_existing_release_is_downloadable_without_authentication(): void
    {
        file_put_contents($this->downloadStorage.'/app/releases/silvamang-ai.apk', 'apk-download-fixture');
        $this->get('/download')->assertOk()->assertSee('Download Android APK')->assertDontSee('Download coming soon');
        $this->get('/download/android')->assertOk()->assertDownload('silvamang-ai.apk')
            ->assertHeader('Content-Type', 'application/vnd.android.package-archive');
    }

    public function test_release_details_are_escaped_and_update_instructions_are_visible(): void
    {
        file_put_contents($this->downloadStorage.'/app/releases/silvamang-ai.apk', 'apk-download-fixture');
        file_put_contents($this->downloadStorage.'/app/releases/release.json', json_encode([
            'version' => '1.2.0', 'build' => '12', 'notes' => '<script>alert(1)</script>',
        ]));
        $this->get('/download')->assertOk()->assertSee('Version 1.2.0')->assertSee('Build 12')
            ->assertSee('Confirm the update')->assertSee('&lt;script&gt;', false)
            ->assertDontSee('<script>alert(1)</script>', false)->assertHeader('Cache-Control', 'no-store, private');
    }

    public function test_invalid_metadata_does_not_break_download_page(): void
    {
        file_put_contents($this->downloadStorage.'/app/releases/silvamang-ai.apk', 'apk-download-fixture');
        file_put_contents($this->downloadStorage.'/app/releases/release.json', '{broken');
        $this->get('/download')->assertOk()->assertSee('Download Android APK');
    }
}
