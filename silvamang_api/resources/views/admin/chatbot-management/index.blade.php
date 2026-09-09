@extends('admin.layouts.app')

@section('title', 'Chatbot Management')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Chatbot Management</h2>
            <p>Manage verified mangrove knowledge, review conversations, and test assistant responses.</p>
        </div>
        <div class="action-row">
            <a href="{{ route('admin.mangrove-knowledge.create') }}" class="primary-action">Add Knowledge</a>
            <a href="{{ route('admin.assistant-logs.index') }}" class="secondary-action">Assistant Logs</a>
        </div>
    </div>

    <section class="stats-grid chatbot-stats-grid">
        @include('admin.partials.stat-card', ['label' => 'Knowledge Entries', 'value' => $knowledgeCount, 'hint' => 'Total verified content', 'icon' => 'KB'])
        @include('admin.partials.stat-card', ['label' => 'Active Answers', 'value' => $activeKnowledgeCount, 'hint' => 'Available to chatbot', 'icon' => 'ON'])
        @include('admin.partials.stat-card', ['label' => 'Inactive Answers', 'value' => $inactiveKnowledgeCount, 'hint' => 'Hidden from chatbot', 'icon' => 'OFF'])
        @include('admin.partials.stat-card', ['label' => 'Conversations', 'value' => $logCount, 'hint' => 'Logged chatbot messages', 'icon' => 'LOG'])
        @include('admin.partials.stat-card', ['label' => 'Unanswered', 'value' => $unansweredQuestionCount, 'hint' => 'Needs admin answer', 'icon' => 'QA'])
    </section>

    <section class="dashboard-grid">
        <article class="panel admin-chat-panel">
            <div class="panel-header">
                <div>
                    <h3>Admin Chatbot</h3>
                    <span>Uses the same chatbot API response as the mobile app.</span>
                </div>
            </div>

            <div class="admin-chat-window" id="admin-chat-thread" aria-live="polite">
                <div class="admin-chat-message assistant">
                    <span>Silvi</span>
                    <p>Hi! Ask me any mangrove question, or choose a scan record to test result-context answers.</p>
                </div>
                @if ($testResponse && $testQuestion !== '')
                    <div class="admin-chat-message user">
                        <span>Admin</span>
                        <p>{{ $testQuestion }}</p>
                    </div>
                    <div class="admin-chat-message assistant">
                        <span>{{ str_replace('_', ' ', ucfirst($testResponse['source'] ?? 'assistant')) }}</span>
                        <p>{{ $testResponse['response'] ?? 'No response generated.' }}</p>
                        @if (! empty($testResponse['suggested_questions']))
                            <div class="chatbot-suggestion-row">
                                @foreach ($testResponse['suggested_questions'] as $suggestion)
                                    <button type="button" data-admin-chat-example="{{ $suggestion }}">{{ $suggestion }}</button>
                                @endforeach
                            </div>
                        @endif
                    </div>
                @endif
            </div>

            <div class="chatbot-suggestion-row admin-chat-examples">
                @foreach ($exampleQuestions as $exampleQuestion)
                    <button type="button" data-admin-chat-example="{{ $exampleQuestion }}">{{ $exampleQuestion }}</button>
                @endforeach
            </div>

            <form id="admin-chat-form" class="chatbot-test-form admin-chat-form">
                <label class="form-group">
                    Optional Scan Context
                    <select id="admin-chat-scan-record" name="scan_record_id">
                        <option value="">No linked scan record</option>
                        @foreach ($scanRecordOptions as $record)
                            <option value="{{ $record->id }}" @selected((string) request('scan_record_id') === (string) $record->id)>
                                {{ $record->record_code }} {{ $record->top_scientific_name ? ' - ' . $record->top_scientific_name : '' }}
                            </option>
                        @endforeach
                    </select>
                </label>
                <label class="form-group">
                    Message
                    <textarea id="admin-chat-input" name="message" rows="3" placeholder="Ask about species, ecology, conservation, identification, measurement, or location validation."></textarea>
                </label>
                <div class="admin-chat-actions">
                    <span id="admin-chat-status" class="admin-chat-status"></span>
                    <div class="action-row">
                        <button type="button" id="admin-chat-clear" class="secondary-action">Clear Chat</button>
                        <button type="submit" class="primary-action">Send</button>
                    </div>
                </div>
            </form>
        </article>

        <article class="panel">
            <div class="panel-header">
                <div>
                    <h3>Usage Statistics</h3>
                    <span>Grouped by response source.</span>
                </div>
            </div>
            @forelse ($usageBySource as $source)
                @include('admin.partials.progress-bar', [
                    'label' => $source->source ?? 'unknown',
                    'value' => $source->total,
                    'max' => max(1, $usageBySource->max('total')),
                    'suffix' => ' replies',
                ])
            @empty
                <div class="empty-card">No chatbot usage has been logged yet.</div>
            @endforelse
        </article>
    </section>

    <section class="dashboard-grid">
        <article class="panel">
            <div class="panel-header">
                <div>
                    <h3>Frequently Asked Questions</h3>
                    <span>Questions asked most often by users.</span>
                </div>
            </div>
            <div class="compact-list">
                @forelse ($frequentlyAskedQuestions as $question)
                    <div class="compact-list-row">
                        <strong>{{ $question->question }}</strong>
                        <span>{{ $question->total }} asks</span>
                    </div>
                @empty
                    <div class="empty-card">No frequent questions yet.</div>
                @endforelse
            </div>
        </article>

        <article class="panel">
            <div class="panel-header">
                <div>
                    <h3>Unanswered Questions</h3>
                    <span>Use these to improve the knowledge base.</span>
                </div>
                <a href="{{ route('admin.mangrove-knowledge.create') }}" class="icon-button">Add Answer</a>
            </div>
            <div class="compact-list">
                @forelse ($unansweredQuestions as $question)
                    <div class="compact-list-row">
                        <div>
                            <strong>{{ $question->question }}</strong>
                            <span>{{ $question->frequency }} asks / {{ $question->created_at?->format('M d, Y h:i A') }}</span>
                        </div>
                        <div class="action-row">
                            <a href="{{ route('admin.mangrove-knowledge.create', ['question' => $question->question]) }}" class="icon-button">Create Answer</a>
                            <form method="POST" action="{{ route('admin.chatbot-management.unanswered.resolve', $question) }}">
                                @csrf
                                @method('PATCH')
                                <button type="submit" class="icon-button">Mark Resolved</button>
                            </form>
                        </div>
                    </div>
                @empty
                    <div class="empty-card">No unanswered questions detected.</div>
                @endforelse
            </div>
        </article>
    </section>

    <article class="panel">
        <div class="panel-header">
            <div>
                <h3>Recently Updated Information</h3>
                <span>Knowledge entries recently changed by administrators.</span>
            </div>
            <a href="{{ route('admin.mangrove-knowledge.index') }}" class="icon-button">Manage Knowledge</a>
        </div>
        <div class="compact-list">
            @forelse ($recentKnowledgeItems as $item)
                <div class="compact-list-row">
                    <div>
                        <strong>{{ $item->question }}</strong>
                        <span>{{ str_replace('_', ' ', ucfirst($item->category)) }} / {{ $item->reference_source ?? 'No source listed' }}</span>
                    </div>
                    <span>{{ $item->updated_at?->format('M d, Y h:i A') }}</span>
                </div>
            @empty
                <div class="empty-card">No knowledge entries have been added yet.</div>
            @endforelse
        </div>
    </article>

    <article class="panel">
        <div class="panel-header">
            <div>
                <h3>Recent Conversations</h3>
                <span>Latest chatbot activity across users.</span>
            </div>
            <a href="{{ route('admin.assistant-logs.index') }}" class="icon-button">View Logs</a>
        </div>
        <div class="table-wrap">
            <table>
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
                            <td>{{ \Illuminate\Support\Str::limit($log->question, 80) }}</td>
                            <td>{{ \Illuminate\Support\Str::limit($log->response, 90) }}</td>
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
    </article>
@endsection

@push('scripts')
    <script>
        (() => {
            const form = document.getElementById('admin-chat-form');
            const input = document.getElementById('admin-chat-input');
            const scanRecordSelect = document.getElementById('admin-chat-scan-record');
            const thread = document.getElementById('admin-chat-thread');
            const status = document.getElementById('admin-chat-status');
            const clearButton = document.getElementById('admin-chat-clear');
            const endpoint = @json(route('admin.chatbot-management.message'));
            const csrfToken = @json(csrf_token());
            const history = [];
            const storageKey = 'silvamang_admin_chatbot_state_v1';
            const maxSavedMessages = 40;
            let savedMessages = [];

            const welcomeMessage = {
                role: 'assistant',
                text: 'Hi! Ask me any mangrove question, or choose a scan record to test result-context answers.',
                meta: 'Silvi',
                suggestions: [],
            };

            const scrollThread = () => {
                thread.scrollTop = thread.scrollHeight;
            };

            const normalizedSuggestions = (suggestions) => {
                if (! Array.isArray(suggestions)) {
                    return [];
                }

                return suggestions
                    .map((suggestion) => String(suggestion || '').trim())
                    .filter((suggestion) => suggestion !== '');
            };

            const persistState = () => {
                try {
                    window.localStorage.setItem(storageKey, JSON.stringify({
                        messages: savedMessages.slice(-maxSavedMessages),
                        scanRecordId: scanRecordSelect.value,
                    }));
                } catch (error) {
                    // Browser storage can be disabled; the chat still works for this page load.
                }
            };

            const pushHistory = (role, text) => {
                if (role.includes('error')) {
                    return;
                }

                history.push({
                    role: role.includes('user') ? 'user' : 'assistant',
                    content: text,
                });
            };

            const displaySource = (source, provider = '') => {
                const normalizedSource = String(source || '').toLowerCase();
                const normalizedProvider = String(provider || '').trim();

                if (normalizedSource === 'ai_api') {
                    return normalizedProvider !== '' ? normalizedProvider : 'AI Assistant';
                }

                if (normalizedSource === 'knowledge_base') {
                    return 'Knowledge Base';
                }

                if (normalizedSource === 'laravel_rule_based_assistant') {
                    return 'Silvi';
                }

                return source || 'Silvi';
            };

            const appendMessage = (
                role,
                text,
                meta = '',
                suggestions = [],
                trackHistory = true,
                saveMessage = true
            ) => {
                const cleanText = String(text || '').trim();
                const cleanSuggestions = normalizedSuggestions(suggestions);

                if (cleanText === '') {
                    return;
                }

                const message = document.createElement('div');
                message.className = `admin-chat-message ${role}`;

                const label = document.createElement('span');
                label.textContent = meta || (role === 'user' ? 'Admin' : 'Silvi');

                const body = document.createElement('p');
                body.textContent = cleanText;

                message.append(label, body);

                if (cleanSuggestions.length > 0) {
                    const suggestionRow = document.createElement('div');
                    suggestionRow.className = 'chatbot-suggestion-row';

                    cleanSuggestions.forEach((suggestion) => {
                        const button = document.createElement('button');
                        button.type = 'button';
                        button.textContent = suggestion;
                        button.dataset.adminChatExample = suggestion;
                        suggestionRow.appendChild(button);
                    });

                    message.appendChild(suggestionRow);
                }

                thread.appendChild(message);

                if (trackHistory) {
                    pushHistory(role, cleanText);
                }

                if (saveMessage) {
                    savedMessages.push({
                        role,
                        text: cleanText,
                        meta: label.textContent,
                        suggestions: cleanSuggestions,
                    });
                    savedMessages = savedMessages.slice(-maxSavedMessages);
                    persistState();
                }

                scrollThread();
            };

            const readServerRenderedMessages = () => {
                savedMessages = Array.from(thread.querySelectorAll('.admin-chat-message'))
                    .map((message) => {
                        const role = message.classList.contains('user')
                            ? 'user'
                            : (message.classList.contains('error') ? 'assistant error' : 'assistant');
                        const label = message.querySelector('span');
                        const body = message.querySelector('p');
                        const suggestions = Array.from(message.querySelectorAll('[data-admin-chat-example]'))
                            .map((button) => button.textContent);

                        return {
                            role,
                            text: body ? body.textContent.trim() : '',
                            meta: label ? label.textContent.trim() : '',
                            suggestions: normalizedSuggestions(suggestions),
                        };
                    })
                    .filter((message) => message.text !== '')
                    .slice(-maxSavedMessages);
            };

            const renderSavedMessages = () => {
                thread.innerHTML = '';
                history.length = 0;

                savedMessages.forEach((message) => {
                    appendMessage(
                        message.role || 'assistant',
                        message.text || '',
                        message.meta || '',
                        message.suggestions || [],
                        true,
                        false
                    );
                });

                scrollThread();
            };

            const restoreState = () => {
                try {
                    const rawState = window.localStorage.getItem(storageKey);

                    if (! rawState) {
                        return false;
                    }

                    const state = JSON.parse(rawState);
                    const messages = Array.isArray(state.messages) ? state.messages : [];

                    if (typeof state.scanRecordId === 'string') {
                        const optionExists = Array.from(scanRecordSelect.options)
                            .some((option) => option.value === state.scanRecordId);

                        if (optionExists) {
                            scanRecordSelect.value = state.scanRecordId;
                        }
                    }

                    if (messages.length === 0) {
                        return false;
                    }

                    savedMessages = messages
                        .map((message) => ({
                            role: String(message.role || 'assistant'),
                            text: String(message.text || '').trim(),
                            meta: String(message.meta || ''),
                            suggestions: normalizedSuggestions(message.suggestions || []),
                        }))
                        .filter((message) => message.text !== '')
                        .slice(-maxSavedMessages);

                    renderSavedMessages();

                    return savedMessages.length > 0;
                } catch (error) {
                    return false;
                }
            };

            const resetConversation = () => {
                savedMessages = [welcomeMessage];
                persistState();
                renderSavedMessages();
                input.value = '';
                input.focus();
            };

            const setLoading = (isLoading) => {
                form.querySelector('button[type="submit"]').disabled = isLoading;
                clearButton.disabled = isLoading;
                input.disabled = isLoading;
                status.textContent = isLoading ? 'Waiting for chatbot response...' : '';
            };

            const sendMessage = async (message) => {
                const cleanMessage = message.trim();

                if (! cleanMessage) {
                    return;
                }

                const priorHistory = history.slice(-10);
                appendMessage('user', cleanMessage);
                input.value = '';
                setLoading(true);

                try {
                    const body = { message: cleanMessage };
                    if (scanRecordSelect.value) {
                        body.scan_record_id = scanRecordSelect.value;
                    }
                    if (priorHistory.length > 0) {
                        body.history = priorHistory;
                    }

                    const response = await fetch(endpoint, {
                        method: 'POST',
                        headers: {
                            'Accept': 'application/json',
                            'Content-Type': 'application/json',
                            'X-CSRF-TOKEN': csrfToken,
                        },
                        body: JSON.stringify(body),
                    });

                    const payload = await response.json().catch(() => ({}));

                    if (! response.ok) {
                        throw new Error(payload.message || 'Chatbot request failed.');
                    }

                    const data = payload.data || payload;
                    appendMessage(
                        'assistant',
                        data.answer || data.response || 'No response generated.',
                        displaySource(data.source, data.provider),
                        data.suggested_questions || []
                    );
                } catch (error) {
                    appendMessage('assistant error', error.message || 'Unable to get chatbot response.', 'Error');
                } finally {
                    setLoading(false);
                    input.focus();
                }
            };

            input.addEventListener('keydown', (event) => {
                if (event.key === 'Enter' && ! event.shiftKey && ! event.isComposing) {
                    event.preventDefault();
                    form.requestSubmit();
                }
            });

            scanRecordSelect.addEventListener('change', persistState);

            clearButton.addEventListener('click', resetConversation);

            form.addEventListener('submit', (event) => {
                event.preventDefault();
                sendMessage(input.value);
            });

            document.addEventListener('click', (event) => {
                const target = event.target.closest('[data-admin-chat-example]');
                if (! target) {
                    return;
                }

                sendMessage(target.dataset.adminChatExample || target.textContent || '');
            });

            if (! restoreState()) {
                readServerRenderedMessages();
                persistState();
                history.length = 0;
                savedMessages.forEach((message) => pushHistory(message.role, message.text));
            }

            window.addEventListener('beforeunload', persistState);
            scrollThread();
        })();
    </script>
@endpush
