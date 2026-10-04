@extends('admin.layouts.app')
@section('title', 'Select Export Records')
@section('content')
<div class="page-heading"><div><h2>Select Export Records</h2><p>Combine observations by recorder, transect, plot and survey date.</p></div><a class="secondary-action" href="{{ route('admin.transects.index') }}">Back</a></div>
<article class="panel">
    <div class="filter-toolbar" style="display:flex;flex-wrap:wrap;gap:16px">
        <label>User<select id="export-user"><option value="">All users</option></select></label>
        <label>Transect<select id="export-transect"><option value="">All transects</option></select></label>
        <label>Date<input id="export-date" type="date"></label>
        <label>Location<select id="export-location"><option value="">All locations</option></select></label>
        <button type="button" class="primary-action" id="add-export">Add to Export</button>
    </div>
    <p id="export-count" role="status"></p>
    <h3>Selected Export Records</h3>
    <form method="POST" action="{{ route('admin.transects.export-selected') }}">
        @csrf
        <div id="export-records"></div>
        <label>Sampled plot area (m2), applied to each selected plot<input type="number" name="plot_area_m2" min="0.01" max="1000000" step="any" placeholder="Optional"></label>
        <p>Leave plot area blank when unknown; density and stand calculations will remain blank.</p>
        <button class="primary-action" id="export-submit" disabled>Export to Excel</button>
    </form>
</article>
@endsection
@push('scripts')
<script>
(() => {
    const groups = @json($groups);
    const selected = new Set();
    for (const [id, key, label] of [['export-user','user','recorder'],['export-transect','transect_id','transect'],['export-location','location','location']]) {
        const select = document.getElementById(id);
        const options = new Map(groups.filter(g => g[key]).map(g => [g[key],g[label]]));
        for (const [value, text] of options) select.add(new Option(text, value));
    }
    function render() {
        const container = document.getElementById('export-records');
        container.replaceChildren();
        const recordIds = new Set();
        for (const index of selected) {
            const group = groups[index];
            const row = document.createElement('div');
            row.className = 'panel';
            const label = document.createElement('p');
            label.textContent = `${group.recorder} | ${group.transect} | Plot ${group.plot || '(not recorded)'} | ${group.date} | ${group.location} | ${group.records.length} observations`;
            const remove = document.createElement('button');
            remove.type = 'button'; remove.className = 'secondary-action'; remove.textContent = 'Remove';
            remove.addEventListener('click', () => { selected.delete(index); render(); });
            row.append(label, remove); container.append(row);
            group.records.forEach(id => recordIds.add(id));
        }
        for (const id of recordIds) {
            const input = document.createElement('input');
            input.type = 'hidden'; input.name = 'selection[]'; input.value = id;
            container.append(input);
        }
        document.getElementById('export-count').textContent = `${selected.size} groups selected; ${recordIds.size} observations.`;
        document.getElementById('export-submit').disabled = recordIds.size === 0;
    }
    document.getElementById('add-export').addEventListener('click', () => {
        const filters = [['export-user','user'],['export-transect','transect_id'],['export-date','date'],['export-location','location']];
        groups.forEach((g,i) => { if (filters.every(([id,key]) => !document.getElementById(id).value || g[key] === document.getElementById(id).value)) selected.add(i); });
        render();
    });
    render();
})();
</script>
@endpush
