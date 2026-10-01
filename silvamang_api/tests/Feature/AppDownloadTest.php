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
}
