<article class="stat-card">
    <div class="stat-icon">{{ $icon ?? 'AI' }}</div>
    <span>{{ $label }}</span>
    <strong>{{ $value }}</strong>
    @isset($hint)
        <small>{{ $hint }}</small>
    @endisset
</article>
