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
    <p id="export-matches" role="status"></p>
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
    function populateOptions(id, key, label, source) {
        const select = document.getElementById(id);
        const previous = select.value;
        while (select.options.length > 1) select.remove(1);
        const options = new Map(source.filter(g => g[key]).map(g => [g[key],g[label]]));
        const entries = [...options];
        if (id === 'export-transect') entries.sort(([a], [b]) =>
            a === 'unrecorded' ? 1 : b === 'unrecorded' ? -1 : Number(a) - Number(b));
        for (const [value, text] of entries) select.add(new Option(text, value));
        select.value = options.has(previous) ? previous : '';
    }
    const filters = [['export-user','user'],['export-transect','transect_number'],['export-date','date'],['export-location','location']];
    const matches = group => filters.every(([id, key]) => !document.getElementById(id).value || group[key] === document.getElementById(id).value);
    function updateMatches() {
        const count = new Set(groups.filter(matches).flatMap(g => g.records)).size;
        document.getElementById('export-matches').textContent = count ? `${count} matching observations available to add.` : 'No records match these filters.';
        document.getElementById('add-export').disabled = count === 0;
    }
    function updateUserOptions() {
        const user = document.getElementById('export-user').value;
        const userGroups = groups.filter(g => !user || g.user === user);
        populateOptions('export-transect', 'transect_number', 'transect', userGroups);
        populateOptions('export-location', 'location', 'location', userGroups);
        updateMatches();
    }
    populateOptions('export-user', 'user', 'recorder', groups);
    document.getElementById('export-user').addEventListener('change', updateUserOptions);
    for (const id of ['export-transect', 'export-date', 'export-location']) document.getElementById(id).addEventListener('change', updateMatches);
    updateUserOptions();
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
        groups.forEach((g,i) => { if (matches(g)) selected.add(i); });
        render();
    });
    render();
})();
</script>
@endpush
