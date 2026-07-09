@php
    $chartMax = max(1, (int) $items->max('count'));
@endphp

@if ($items->sum('count') === 0)
    <div class="empty-card">No scan activity for this period.</div>
@else
    <div class="mini-bar-chart">
        @foreach ($items as $item)
            @php
                $height = max(8, ((int) $item['count'] / $chartMax) * 100);
            @endphp
            <div class="mini-bar-item">
                <div class="mini-bar-value">{{ $item['count'] }}</div>
                <div class="mini-bar-track">
                    <span style="height: {{ $height }}%"></span>
                </div>
                <small>{{ $item['label'] }}</small>
            </div>
        @endforeach
    </div>
@endif
