<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Login - SILVAMANG AI</title>
    <link rel="stylesheet" href="{{ asset('css/admin.css') }}">
</head>
<body class="login-page">
    <main class="login-shell">
        <section class="login-story">
            <div class="login-story-content">
                <a href="{{ url('/') }}" class="login-story-brand">
                    <span class="public-logo light"><span></span></span>
                    <div><strong>SILVAMANG AI</strong><p>Smart Mangrove Monitoring Platform</p></div>
                </a>
                <div class="login-divider"></div>
                <h1>AI-Powered Mangrove Monitoring & Protection</h1>
                <p>Identify species, validate locations, and uncover biodiversity insights with intelligent technology built for a healthier future.</p>
                <div class="login-feature-list">
                    <article><span>AI</span><div><strong>AI Species Identification</strong><p>Instantly identify mangrove species with high-accuracy AI models.</p></div></article>
                    <article><span>GPS</span><div><strong>Location Validation</strong><p>Validate sites and monitor habitat health with precise geolocation.</p></div></article>
                    <article><span>REP</span><div><strong>Biodiversity Insights</strong><p>Track trends, generate reports, and make data-driven decisions.</p></div></article>
                </div>
                <div class="login-security-note"><span>SEC</span><div><strong>Secure. Intelligent. Sustainable.</strong><p>Technology that protects our mangroves and our future.</p></div></div>
            </div>
            <div class="login-phone-preview" aria-hidden="true">
                <div class="phone-screen image-screen"></div>
                <div class="phone-result">Rhizophora mucronata <span>93% Match</span></div>
                <div class="phone-map-card"></div>
            </div>
        </section>

        <section class="login-form-side">
            <form method="POST" action="{{ route('login.store') }}" class="login-card">
                @csrf
                <div class="login-icon"><span></span></div>
                <h2>Welcome Back</h2>
                <p>Sign in to access the SILVAMANG AI platform.</p>
                @if ($errors->any())
                    <div class="form-error">{{ $errors->first() }}</div>
                @endif
                <label>Email address<span class="login-input-wrap"><i>@</i><input type="email" name="email" value="{{ old('email') }}" placeholder="Enter your email" required autofocus></span></label>
                <label>Password<span class="login-input-wrap has-action"><i>*</i><input id="login-password" type="password" name="password" placeholder="Enter your password" required><button type="button" class="password-toggle" aria-label="Show password" aria-controls="login-password">Show</button></span></label>
                <div class="login-options">
                    <label class="checkbox-row"><input type="checkbox" name="remember" value="1"> Remember me</label>
                    <a href="{{ route('login') }}">Forgot password?</a>
                </div>
                <button type="submit" class="login-submit">Sign In</button>
                <div class="login-or"><span></span>or<span></span></div>
                <button type="button" class="google-button">G Continue with Google</button>
                <div class="staff-note"><strong>Admin and Field Staff Access</strong><span>Authorized personnel only.</span></div>
            </form>
        </section>
    </main>
    <script>
        const passwordInput = document.getElementById('login-password');
        const passwordToggle = document.querySelector('.password-toggle');

        passwordToggle?.addEventListener('click', () => {
            const shouldShow = passwordInput.type === 'password';
            passwordInput.type = shouldShow ? 'text' : 'password';
            passwordToggle.textContent = shouldShow ? 'Hide' : 'Show';
            passwordToggle.setAttribute('aria-label', shouldShow ? 'Hide password' : 'Show password');
        });
    </script>
</body>
</html>
