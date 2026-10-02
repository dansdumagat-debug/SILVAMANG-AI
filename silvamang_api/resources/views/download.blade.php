<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Download SILVAMANG AI for Android. Identify mangroves, record field observations, and connect to your online account.">
    <title>Download or Update the App | SILVAMANG AI</title>
    <link rel="stylesheet" href="{{ asset('css/admin.css') }}">
    <link rel="stylesheet" href="{{ asset('css/download.css') }}">
</head>
<body class="landing-page download-page">
    <header class="landing-nav">
        <a href="{{ url('/') }}" class="landing-brand"><span class="public-logo" aria-hidden="true"><span></span></span><strong>SILVAMANG AI</strong></a>
        <nav aria-label="Main navigation"><a href="{{ url('/') }}">Home</a><a href="{{ route('app.download') }}" class="active" aria-current="page">Download</a></nav>
        <div class="landing-actions"><a href="{{ route('login') }}" class="outline-public-button">Sign In</a></div>
    </header>
    <main class="download-main">
        <section class="download-hero" aria-labelledby="download-title">
            <div>
                <p class="download-eyebrow">SILVAMANG AI FOR ANDROID</p>
                <h1 id="download-title">Take mangrove monitoring into the field.</h1>
                <p class="download-intro">Identify mangroves, record your observations, and keep your field work connected to your SILVAMANG AI account.</p>
                <ul class="download-features">
                    <li>Photo-based species identification</li>
                    <li>Field records, measurements, and maps</li>
                    <li>Offline identification and online sync</li>
                </ul>
                <a href="{{ url('/') }}" class="download-back">Explore SILVAMANG AI &rarr;</a>
            </div>
            <aside class="download-card" aria-labelledby="android-title">
                <span class="download-platform">ANDROID</span>
                <h2 id="android-title">Download or update</h2>
                @if ($available)
                    <p>Download the Android installation file directly to your phone.</p>
                    <a class="solid-public-button download-button" href="{{ route('app.download.android') }}" download="silvamang-ai.apk">Download Android APK</a>
                    <p class="download-detail">APK file &middot; {{ $size }} MB</p>
                    @if (!empty($release['version']))
                        <p class="download-detail">Version {{ $release['version'] }}@if (!empty($release['build'])) &middot; Build {{ $release['build'] }}@endif</p>
                    @endif
                    @if (!empty($release['published_at']))
                        <p class="download-detail">Released {{ $release['published_at'] }}</p>
                    @endif
                @else
                    <p>The Android download is being prepared. Check back here for the installation file.</p>
                    <p class="download-unavailable" role="status">Download coming soon</p>
                @endif
                <p class="download-detail">Android phones only. An iPhone download is not currently available.</p>
                <a href="#update-title" class="download-back">Already have the app? Update instructions &darr;</a>
            </aside>
        </section>
        <section class="download-install" aria-labelledby="update-title">
            <p class="download-eyebrow">KEEP YOUR APP UP TO DATE</p>
            <h2 id="update-title">Already using SILVAMANG AI?</h2>
            <ol class="download-steps">
                <li><h3>Check your version</h3><p>On your phone, open Settings, then Apps, then SILVAMANG AI to find the installed version. Compare it with the release shown above.</p></li>
                <li><h3>Download the latest APK</h3><p>Sync any pending field records first. Use the same download button above to get the latest published release.</p></li>
                <li><h3>Confirm the update</h3><p>Open the downloaded APK and follow Android's update prompt. Keep the existing app installed to preserve its local data.</p></li>
            </ol>
            <p class="download-note">This website provides manual updates. It cannot check your installed version or silently update your phone. If Android refuses the update, contact your administrator before uninstalling.</p>
            @if (!empty($release['notes']))
                <div class="download-card"><h3>What's new</h3><p style="white-space: pre-line">{{ $release['notes'] }}</p></div>
            @endif
        </section>
        <section class="download-install" aria-labelledby="install-title">
            <p class="download-eyebrow">GETTING STARTED</p>
            <h2 id="install-title">Install in three steps</h2>
            <ol class="download-steps">
                <li><h3>Download on your phone</h3><p>Open this page on your Android phone and download the APK when it becomes available.</p></li>
                <li><h3>Open the APK</h3><p>Tap the downloaded file. If Android asks, allow your browser to install this app. You can turn that permission off afterward.</p></li>
                <li><h3>Sign in and start exploring</h3><p>Open SILVAMANG AI and sign in or create an account. Allow camera and location access when using those features.</p></li>
            </ol>
            <p class="download-note">If Android reports that the app cannot be installed, keep your current app and field records. Contact your administrator before uninstalling it.</p>
        </section>
    </main>
    <footer class="download-footer">SILVAMANG AI &middot; Identify. Measure. Protect.</footer>
</body>
</html>
