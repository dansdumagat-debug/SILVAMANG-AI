<article class="analytics-card">
    <div class="analytics-icon">{{ $icon ?? 'AI' }}</div>
    <span>{{ $label }}</span>
    <strong>{{ $value }}</strong>
    @isset($hint)
        <small>{{ $hint }}</small>
    @endisset
</article>
