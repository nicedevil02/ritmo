import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';

/// Sheet 6: "مربی هوشمند" (Section 5.9 & 7.10).
class MvAiCoachSheet extends StatefulWidget {
  final MvUserProfile profile;
  final MvSlot? currentSlot;

  const MvAiCoachSheet({super.key, required this.profile, this.currentSlot});

  static Future<void> show({
    required BuildContext context,
    required MvUserProfile profile,
    MvSlot? currentSlot,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) =>
          MvAiCoachSheet(profile: profile, currentSlot: currentSlot),
    );
  }

  @override
  State<MvAiCoachSheet> createState() => _MvAiCoachSheetState();
}

class _MvAiCoachSheetState extends State<MvAiCoachSheet> {
  static const _engine = CoachEngine();
  final List<Map<String, String>> _messages = [];
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initial welcome tip from CoachEngine
    final initialTip = _engine.generateTip(
      profile: widget.profile,
      slot:
          widget.currentSlot ??
          const MvSlot(
            id: '0',
            dateIso: '',
            headlineFa: 'Workout',
            createdAt: 0,
            updatedAt: 0,
          ),
    );
    _messages.add({
      'role': 'assistant',
      'text': initialTip.value.textFa,
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage(String query) {
    if (query.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _messages.add({'role': 'user', 'text': query});
    });
    _textController.clear();

    // Instant smart response based on keywords
    String reply;
    final qLower = query.toLowerCase();
    if (qLower.contains('light') ||
        qLower.contains('tired') ||
        qLower.contains('\u0633\u0628\u06a9') ||
        qLower.contains('\u062e\u0633\u062a\u0647')) {
      reply = l10n?.mv_coach_reply_light ??
          'You can use the 10-minute minimum effective dose option to maintain streak without fatigue.';
    } else if (qLower.contains('apartment') ||
        qLower.contains('noise') ||
        qLower.contains('\u0622\u067e\u0627\u0631\u062a\u0645\u0627\u0646') ||
        qLower.contains('\u0635\u062f\u062f\u0627')) {
      reply = l10n?.mv_coach_reply_noise ??
          'Turn on Neighbor Friendly mode in settings to automatically filter out noisy and jump movements.';
    } else if (qLower.contains('stretch') ||
        qLower.contains('cramp') ||
        qLower.contains('\u06af\u0631\u0641\u062a\u06af\u06cc') ||
        qLower.contains('\u06a9\u0634\u0634')) {
      reply = l10n?.mv_coach_reply_stretch ??
          'A 5-minute hamstring and back stretch combined with water helps reduce lactic acid.';
    } else {
      reply = l10n?.mv_coach_reply_general ??
          'The most important principle in fitness is consistency; even 5 minutes of light movement is better than none.';
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'text': reply});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final promptPresets = [
      l10n?.mv_coach_preset_light ?? 'How to make today workout lighter?',
      l10n?.mv_coach_preset_noise ?? 'Noisy movements for apartment?',
      l10n?.mv_coach_preset_stretch ?? 'What is good for muscle cramps?',
      l10n?.mv_coach_preset_general ?? 'How to stay motivated?',
    ];

    return MvSheetScaffold(
      title: l10n?.mv_coach_title ?? 'Ritmo AI Coach',
      subtitle: l10n?.mv_coach_subtitle ?? 'Your training guide and workout companion',
      headerActions: [
        RitmoCardBadge(
          label: 'AI Coach',
          icon: Icons.auto_awesome_rounded,
          color: colors.primary,
        ),
      ],
      body: SizedBox(
        height: 380,
        child: Column(
          children: [
            // Chat Messages
            Expanded(
              child: ListView.separated(
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment: isUser
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: isUser
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg['text']!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onPrimary,
                              ),
                            ),
                          )
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: RitmoCard.neumorphic(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                msg['text']!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Quick Prompts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: promptPresets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ActionChip(
                      label: Text(p, style: textTheme.labelSmall),
                      onPressed: () => _sendMessage(p),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Input Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: l10n?.mv_coach_input_hint ?? 'Ask coach...',
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: colors.onPrimary,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
