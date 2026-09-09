import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/models/assistant_message_model.dart';
import '../controllers/assistant_controller.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key, this.scanRecordId, this.initialPrompt});

  final String? scanRecordId;
  final String? initialPrompt;

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sentInitialPrompt = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_applyInitialContext);
  }

  @override
  void didUpdateWidget(covariant AiAssistantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanRecordId != widget.scanRecordId ||
        oldWidget.initialPrompt != widget.initialPrompt) {
      _sentInitialPrompt = false;
      Future.microtask(_applyInitialContext);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty) {
      return;
    }

    _messageController.clear();
    await ref.read(assistantControllerProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  Future<void> _applyInitialContext() async {
    ref
        .read(assistantControllerProvider.notifier)
        .setScanRecordContext(widget.scanRecordId);

    final prompt = widget.initialPrompt?.trim();
    if (_sentInitialPrompt || prompt == null || prompt.isEmpty) {
      return;
    }

    _sentInitialPrompt = true;
    await ref
        .read(assistantControllerProvider.notifier)
        .sendQuickPrompt(prompt);
    _scrollToBottom();
  }

  Future<void> _sendQuickPrompt(String prompt) async {
    await ref
        .read(assistantControllerProvider.notifier)
        .sendQuickPrompt(prompt);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final canSend =
        _messageController.text.trim().isNotEmpty && !state.isLoading;
    final assistantModeLabel = _assistantModeLabel(state.messages);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(assistantControllerProvider.notifier)
                      .clearChat(),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPadding,
              AppSpacing.md,
              AppConstants.screenPadding,
              0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.eco_rounded,
                  color: AppColors.primaryDarkGreen,
                ),
                const SizedBox(width: AppSpacing.sm),
                SilvamangBadge(
                  label: assistantModeLabel,
                  type: assistantModeLabel == 'Offline Mangrove Guide'
                      ? SilvamangBadgeType.warning
                      : SilvamangBadgeType.info,
                ),
              ],
            ),
          ),
          if (state.activeScanRecordId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                AppSpacing.md,
                AppConstants.screenPadding,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SilvamangBadge(
                  label:
                      'Using scan record context #${state.activeScanRecordId}',
                  type: SilvamangBadgeType.info,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                AppSpacing.lg,
              ),
              itemCount: state.messages.length + (state.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.messages.length) {
                  return const _ThinkingBubble();
                }

                return _ChatBubble(
                  message: state.messages[index],
                  onPromptSelected: _sendQuickPrompt,
                );
              },
            ),
          ),
          _PromptChips(
            isEnabled: !state.isLoading,
            onPromptSelected: _sendQuickPrompt,
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: SilvamangCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: state.isLoading ? null : _sendMessage,
                      decoration: InputDecoration(
                        hintText: 'Ask about mangroves...',
                        border: InputBorder.none,
                        hintStyle: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: canSend
                        ? () => _sendMessage(_messageController.text)
                        : null,
                    icon: Icon(
                      Icons.send_rounded,
                      color: canSend
                          ? AppColors.primaryDarkGreen
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.onPromptSelected,
  });

  final AssistantMessageModel message;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final isAssistant = !message.isUser;
    final bubbleColor = message.isError
        ? AppColors.dangerRed.withValues(alpha: 0.10)
        : isAssistant
        ? AppColors.white
        : AppColors.primaryDarkGreen;
    final textColor = message.isError
        ? AppColors.dangerRed
        : isAssistant
        ? AppColors.textDark
        : AppColors.white;

    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isAssistant ? 6 : 22),
            bottomRight: Radius.circular(isAssistant ? 22 : 6),
          ),
          border: message.isError
              ? Border.all(color: AppColors.dangerRed.withValues(alpha: 0.25))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
            if (message.intent != null || message.source != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                  if (message.intent != null) _cleanLabel(message.intent!),
                  if (message.source != null) _cleanLabel(message.source!),
                ].join(' / '),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ],
            if (!message.isUser &&
                !message.isError &&
                message.suggestedQuestions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: message.suggestedQuestions.take(3).map((prompt) {
                  return ActionChip(
                    label: Text(prompt),
                    labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryDarkGreen,
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.mintBackground,
                    side: BorderSide.none,
                    onPressed: () => onPromptSelected(prompt),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Silvi is thinking...', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PromptChips extends StatelessWidget {
  const _PromptChips({required this.isEnabled, required this.onPromptSelected});

  final bool isEnabled;
  final ValueChanged<String> onPromptSelected;

  static const prompts = [
    _PromptChipData(
      label: 'Mangrove Basics',
      prompt: 'What are mangroves?',
      icon: Icons.eco_rounded,
    ),
    _PromptChipData(
      label: 'Ecosystem Benefits',
      prompt: 'What benefits do mangroves provide?',
      icon: Icons.waves_rounded,
    ),
    _PromptChipData(
      label: 'Species Information',
      prompt: 'What are common mangrove species in the Philippines?',
      icon: Icons.local_florist_rounded,
    ),
    _PromptChipData(
      label: 'Conservation',
      prompt: 'How can we protect mangrove ecosystems?',
      icon: Icons.shield_rounded,
    ),
    _PromptChipData(
      label: 'Learning',
      prompt: 'What is mangrove zonation?',
      icon: Icons.menu_book_rounded,
    ),
    _PromptChipData(
      label: 'Roots',
      prompt: 'Why do mangroves survive in salty water?',
      icon: Icons.grass_rounded,
    ),
    _PromptChipData(
      label: 'Scan Help',
      prompt: 'How do I capture better images?',
      icon: Icons.camera_alt_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPadding,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: prompts.map((entry) {
          return ActionChip(
            avatar: Icon(entry.icon, size: 16),
            label: Text(entry.label),
            backgroundColor: AppColors.white,
            side: BorderSide.none,
            onPressed: isEnabled ? () => onPromptSelected(entry.prompt) : null,
          );
        }).toList(),
      ),
    );
  }
}

class _PromptChipData {
  const _PromptChipData({
    required this.label,
    required this.prompt,
    required this.icon,
  });

  final String label;
  final String prompt;
  final IconData icon;
}

String _assistantModeLabel(List<AssistantMessageModel> messages) {
  for (final message in messages.reversed) {
    if (message.isUser) {
      continue;
    }
    final source = message.source?.trim().toLowerCase();
    if (source == 'offline_mangrove_guide') {
      return 'Offline Mangrove Guide';
    }
    if (source == 'offline' || source == 'offline_unavailable') {
      return 'Offline Mangrove Guide';
    }
    if (source == 'knowledge_base' ||
        source == 'laravel_rule_based_assistant') {
      return 'Verified Knowledge Base';
    }
    if (source == 'ai_api') {
      return 'AI Assisted Response';
    }
    if (source != null && source.isNotEmpty && source != 'local_greeting') {
      return 'Online AI Assistant';
    }
  }

  return 'Offline Mangrove Guide';
}

String _cleanLabel(String value) {
  final source = value.trim().toLowerCase();
  if (source == 'knowledge_base' || source == 'laravel_rule_based_assistant') {
    return 'Verified Knowledge Base';
  }
  if (source == 'ai_api') {
    return 'AI Assisted Response';
  }
  if (source == 'offline' ||
      source == 'offline_unavailable' ||
      source == 'offline_mangrove_guide') {
    return 'Offline Mangrove Guide';
  }

  final label = value.replaceAll('_', ' ').trim();
  if (label.isEmpty) {
    return '';
  }

  return label
      .split(' ')
      .map((word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
