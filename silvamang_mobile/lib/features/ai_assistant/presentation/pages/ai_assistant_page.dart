import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_card.dart';

class AiAssistantPage extends StatelessWidget {
  const AiAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                AppSpacing.lg,
              ),
              children: const [
                _ChatBubble(
                  text:
                      "Hi! I'm Silvi, your mangrove AI assistant. I can help you understand this species and its importance.",
                  isAssistant: true,
                ),
                _ChatBubble(
                  text: 'What is the ecological role of Rhizophora apiculata?',
                  isAssistant: false,
                ),
                _ChatBubble(
                  text:
                      'Rhizophora apiculata helps protect coastlines from erosion, provides habitat for marine life, and stores significant amounts of carbon.',
                  isAssistant: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPadding,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                _PromptChip(label: 'Ecological Role'),
                _PromptChip(label: 'Conservation'),
                _PromptChip(label: 'Fun Fact'),
              ],
            ),
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
                      decoration: InputDecoration(
                        hintText: 'Ask something...',
                        border: InputBorder.none,
                        hintStyle: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.primaryDarkGreen,
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
  const _ChatBubble({required this.text, required this.isAssistant});

  final String text;
  final bool isAssistant;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isAssistant ? AppColors.white : AppColors.primaryDarkGreen,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isAssistant ? 6 : 22),
            bottomRight: Radius.circular(isAssistant ? 22 : 6),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isAssistant ? AppColors.textDark : AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(label),
      backgroundColor: AppColors.white,
      side: BorderSide.none,
    );
  }
}
