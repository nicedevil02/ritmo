import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
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

  final List<String> _promptPresets = const [
    'چگونه تمرین امروز را سبک‌تر کنم؟',
    'حرکات مناسب بدون صدا برای آپارتمان چیه؟',
    'برای رفع گرفتگی عضلات چه حرکتی خوبه؟',
    'چطور انگیزهٔ ورزشی‌ام را حفظ کنم؟',
  ];

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
            headlineFa: 'ورزش',
            createdAt: 0,
            updatedAt: 0,
          ),
    );
    _messages.add({
      'role': 'assistant',
      'text': 'سلام! من مربی هوشمند ریتمو هستم. ${initialTip.value.textFa}',
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': query});
    });
    _textController.clear();

    // Instant smart response based on keywords
    String reply;
    if (query.contains('سبک') || query.contains('خسته')) {
      reply =
          'می‌توانی از گزینهٔ «حداقل مؤثر ۱۰ دقیقه‌ای» استفاده کنی تا بدون خستگی، پیوستگی تمرینت حفظ شود.';
    } else if (query.contains('آپارتمان') || query.contains('صدا')) {
      reply =
          'در تنظیمات کلید «حالت همسایه‌پسند» را روشن کن تا تمام حرکات پرشی و پرصدا به‌طور خودکار فیلتر شوند.';
    } else if (query.contains('گرفتگی') || query.contains('کشش')) {
      reply =
          'کشش ۵ دقیقه‌ای عضلات همسترینگ و پشت همراه با نوشیدن آب به کاهش اسید لاکتیک کمک زیادی می‌کند.';
    } else {
      reply =
          'مهم‌ترین اصل در ورزش پیوستگی است؛ حتی ۵ دقیقه فعالیت سبک بهتر از انجام ندادن است.';
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'مربی هوشمند ریتمو',
      subtitle: 'راهنما و همراه تمرینی تو (قواعد ایمنی و علمی)',
      headerActions: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.spaceSm,
            vertical: metrics.spaceXs,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.primary, size: metrics.iconSm),
              SizedBox(width: metrics.spaceXs),
              Text(
                'AI Coach',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
                separatorBuilder: (_, _) => SizedBox(height: metrics.spaceSm),
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment: isUser
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      padding: EdgeInsets.all(metrics.spaceMd),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? colors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(metrics.radiusCard),
                        border: isUser
                            ? null
                            : Border.all(color: colors.border),
                      ),
                      child: Text(
                        msg['text']!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: isUser ? colors.onPrimary : colors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: metrics.spaceSm),

            // Quick Prompts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _promptPresets.map((p) {
                  return Padding(
                    padding: EdgeInsets.only(left: metrics.spaceSm),
                    child: ActionChip(
                      label: Text(p, style: textTheme.labelSmall),
                      onPressed: () => _sendMessage(p),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: metrics.spaceSm),

            // Input Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'سؤالت از مربی...',
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          metrics.radiusField,
                        ),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceMd,
                        vertical: metrics.spaceSm,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                SizedBox(width: metrics.spaceSm),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary,
                    minimumSize: Size(metrics.touchTarget, metrics.touchTarget),
                  ),
                  icon: Icon(
                    Icons.send_rounded,
                    color: colors.onPrimary,
                    size: metrics.iconMd,
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
