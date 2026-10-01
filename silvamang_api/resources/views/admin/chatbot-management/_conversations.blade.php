        <div class="table-wrap">
            <table class="conversation-table">
                <thead>
                    <tr>
                        <th>User</th>
                        <th>Role</th>
                        <th>Question</th>
                        <th>Response</th>
                        <th>Source</th>
                        <th>Intent</th>
                        <th>Scan</th>
                        <th>Date / Time</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($recentLogs as $log)
                        <tr>
                            <td>{{ $log->user?->name ?? 'N/A' }}</td>
                            <td>{{ $log->user_role ?: ($log->user?->roles?->pluck('name')->join(', ') ?: 'N/A') }}</td>
                            <td>{{ ($fullHistory ?? false) ? $log->question : \Illuminate\Support\Str::limit($log->question, 80) }}</td>
                            <td>{{ ($fullHistory ?? false) ? $log->response : \Illuminate\Support\Str::limit($log->response, 90) }}</td>
                            <td>{{ $log->response_source ?? $log->source ?? 'N/A' }}</td>
                            <td>{{ $log->intent ?? 'N/A' }}</td>
                            <td>{{ $log->scanRecord?->record_code ?? 'N/A' }}</td>
                            <td>{{ $log->created_at?->format('M d, Y h:i A') }}</td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8">No conversations logged yet.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
