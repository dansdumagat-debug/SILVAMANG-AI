<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SILVAMANG AI - Mangrove Monitoring Platform</title>
    <link rel="stylesheet" href="{{ asset('css/admin.css') }}">
</head>
<body class="landing-page">
    <header class="landing-nav">
        <a href="{{ url('/') }}" class="landing-brand"><span class="public-logo"><span></span></span><strong>SILVAMANG AI</strong></a>
        <nav><a href="#home" class="active">Home</a><a href="#features">Features</a><a href="#solutions">Solutions</a><a href="#contact">Contact</a></nav>
        <div class="landing-actions"><a href="{{ route('login') }}" class="outline-public-button">Sign In</a><a href="{{ route('login') }}" class="solid-public-button">Get Started</a></div>
    </header>

    <main id="home">
        <section class="landing-hero">
            <div class="mangrove-visual" aria-hidden="true"><div class="mangrove-canopy"></div><div class="mangrove-roots"></div></div>
            <div class="hero-copy">
                <h1>AI-Powered Mangrove Monitoring & Species Identification</h1>
                <p>SILVAMANG AI combines advanced image recognition, real-time field data, and intelligent analytics to protect mangrove ecosystems and support data-driven conservation.</p>
                <div class="hero-buttons"><a href="{{ route('login') }}" class="solid-public-button large">Get Started</a><a href="#features" class="outline-public-button large">View Demo</a></div>
                <div class="hero-checks"><span>AI-Powered Accuracy</span><span>Field-Ready Tools</span><span>Secure & Reliable</span></div>
            </div>
            <div class="product-preview" aria-label="SILVAMANG AI dashboard and mobile previews">
                <div class="dashboard-preview">
                    <aside><strong>SILVAMANG AI</strong><span>Dashboard</span><span>Species Management</span><span>Scan Records</span><span>Reports & Analytics</span></aside>
                    <section><div class="preview-topbar"></div><h3>Dashboard Overview</h3><div class="preview-stats"><span>34,120</span><span>80</span><span>91.7%</span></div><div class="preview-chart"><i style="height:45%"></i><i style="height:72%"></i><i style="height:56%"></i><i style="height:80%"></i><i style="height:90%"></i></div></section>
                </div>
                <div class="phone-preview phone-one"><div class="phone-screen image-screen"></div><div class="phone-result">Rhizophora mucronata <span>93% Match</span></div></div>
                <div class="phone-preview phone-two"><div class="phone-screen map-screen"></div><div class="phone-tools"><span></span><span></span><span></span></div></div>
            </div>
        </section>

        <section id="features" class="feature-strip">
            <article><span>CAM</span><strong>AI Image Recognition</strong><p>High-accuracy species identification using advanced AI models.</p></article>
            <article><span>GPS</span><strong>GPS Tracking</strong><p>Precise geotagging and location validation for every observation.</p></article>
            <article><span>LIVE</span><strong>Real-time Detection</strong><p>Instant field results with offline support and smart sync.</p></article>
            <article><span>DB</span><strong>Secure Database</strong><p>Encrypted storage, role-based access, and reliable records.</p></article>
            <article><span>REP</span><strong>Biodiversity Insights</strong><p>Interactive dashboards and reports for data-driven decisions.</p></article>
        </section>

        <section class="landing-metrics">
            <div><strong>34,120+</strong><span>Scans Completed</span></div><div><strong>80+</strong><span>Species Identified</span></div><div><strong>250+</strong><span>Monitoring Sites</span></div><div><strong>91.7%</strong><span>AI Validation Accuracy</span></div><div><strong>120+</strong><span>Active Field Users</span></div>
        </section>

        <section class="landing-lower-grid">
            <div>
                <h2 class="section-kicker">Built for Every Conservation Champion</h2>
                <section id="solutions" class="solution-grid">
                    <article><div class="solution-photo researchers"></div><strong>Researchers</strong><p>Access accurate data, identify species, and monitor trends with advanced analytics.</p><a href="{{ route('login') }}">Learn more</a></article>
                    <article><div class="solution-photo government"></div><strong>LGUs & Government</strong><p>Make informed decisions with real-time dashboards and reports.</p><a href="{{ route('login') }}">Learn more</a></article>
                    <article><div class="solution-photo teams"></div><strong>Environmental Teams</strong><p>Collaborate, validate data, and drive conservation initiatives.</p><a href="{{ route('login') }}">Learn more</a></article>
                    <article><div class="solution-photo officers"></div><strong>Field Officers</strong><p>Collect field data, identify species instantly, even offline.</p><a href="{{ route('login') }}">Learn more</a></article>
                </section>
            </div>

            <aside class="trusted-panel">
                <h2 class="section-kicker">Trusted by Environmental Leaders</h2>
                <div class="trusted-grid">
                    <span>DENR<br><small>Philippines</small></span>
                    <span>BFAR<br><small>Philippines</small></span>
                    <span>WWF<br><small>Philippines</small></span>
                    <span>IUCN<br><small>Member</small></span>
                    <span>Haribon<br><small>Foundation</small></span>
                </div>
            </aside>
        </section>

        <section id="contact" class="landing-cta">
            <div><h2>Ready to Protect Our Mangroves?</h2><p>Join teams using AI and field data to conserve blue-green ecosystems.</p></div>
            <div><a href="{{ route('login') }}" class="solid-public-button large">Get Started Now</a><a href="{{ route('login') }}" class="outline-public-button light large">Request a Demo</a></div>
        </section>
    </main>

    <footer class="landing-footer">
        <div><a href="{{ url('/') }}" class="landing-brand footer-brand"><span class="public-logo"><span></span></span><strong>SILVAMANG AI</strong></a><p>Smart Technology for Stronger Mangrove Ecosystems.</p></div>
        <div><strong>Product</strong><span>Features</span><span>Security</span><span>Integrations</span></div>
        <div><strong>Solutions</strong><span>Researchers</span><span>LGUs & Government</span><span>Field Officers</span></div>
        <div><strong>Support</strong><span>Help Center</span><span>Documentation</span><span>Contact Us</span></div>
    </footer>
</body>
</html>
