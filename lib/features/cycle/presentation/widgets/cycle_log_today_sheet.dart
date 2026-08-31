// C-43, C-44: CycleLogTodaySheet
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:sqflite/sqflite.dart';

class CycleLogTodaySheet extends StatefulWidget {
  const CycleLogTodaySheet({
    super.key,
    required this.todayStr,
    required this.todayLog,
    required this.activePhaseColor,
    required this.onSaved,
    this.scrollController,
  });

  final String todayStr;
  final Map<String, dynamic>? todayLog;
  final Color activePhaseColor;
  final VoidCallback onSaved;
  final ScrollController? scrollController;

  static Future<void> show({
    required BuildContext context,
    required String todayStr,
    required Map<String, dynamic>? todayLog,
    required Color activePhaseColor,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: RitmoBreakpoints.sheetMaxHeight(ctx, factor: 0.94),
            ),
            child: CycleLogTodaySheet(
              todayStr: todayStr,
              todayLog: todayLog,
              activePhaseColor: activePhaseColor,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CycleLogTodaySheet> createState() => _CycleLogTodaySheetState();
}

class _CycleLogTodaySheetState extends State<CycleLogTodaySheet> {
  late String flowLevel;
  late String mood;
  late String energyTag;
  late List<String> symptoms;
  late TextEditingController noteController;
  bool showSuccessLottie = false;

  final symptomsList = [
    {'key': 'cramps', 'label': 'دل‌درد و انقباض'},
    {'key': 'headache', 'label': 'سردرد'},
    {'key': 'bloating', 'label': 'نفخ شکم'},
    {'key': 'fatigue', 'label': 'خستگی بدنی'},
    {'key': 'backache', 'label': 'کمردرد'},
    {'key': 'mood_swings', 'label': 'نوسانات خُلق'},
  ];

  @override
  void initState() {
    super.initState();
    flowLevel = widget.todayLog?['flowLevel'] as String? ?? 'NONE';
    mood = widget.todayLog?['mood'] as String? ?? 'HAPPY';
    energyTag = widget.todayLog?['energyTag'] as String? ?? 'MEDIUM';
    final note = widget.todayLog?['note'] as String? ?? '';
    noteController = TextEditingController(text: note);

    symptoms = [];
    if (widget.todayLog?['symptomsJson'] != null) {
      try {
        final parsed =
            jsonDecode(widget.todayLog!['symptomsJson'] as String)
                as List<dynamic>;
        symptoms = parsed.map((e) => e.toString()).toList();
      } catch (e, st) {
        RitmoLog.error(
          'CycleLogTodaySheet',
          'Failed to parse symptomsJson: $e',
          e,
          st,
        );
      }
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(
    IconData icon,
    String title,
    RitmoColors colors,
  ) {
    return Row(
      children: [
        Icon(icon, color: widget.activePhaseColor, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return RitmoCard.neumorphic(
      isSelected: isSelected,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: isSelected ? context.colors.primary : context.colors.textSecondary,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? context.colors.primary : context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (showSuccessLottie) {
      return RitmoGlassSheet(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.all(24),
        child: Container(
          height: 320,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Lottie.asset(
                  'assets/animations/workout_success.json',
                  repeat: false,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'احوال امروز با موفقیت ثبت شد 🌸',
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return RitmoGlassSheet(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + RitmoSpacing.lg,
        top: RitmoSpacing.sm,
        left: RitmoSpacing.lg,
        right: RitmoSpacing.lg,
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Symmetrical Header
            Row(
              children: [
                RitmoNeuButton(
                  padding: const EdgeInsets.all(8),
                  radius: 10,
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    'ثبت علائم و احوال امروز',
                    textAlign: TextAlign.center,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
                const SizedBox(width: 34),
              ],
            ),
            const SizedBox(height: 16),

            // Section 1: Flow
            _buildSectionHeader(
              CupertinoIcons.drop,
              'میزان خونریزی یا ترشح بدنی',
              colors,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                {'key': 'NONE', 'label': 'هیچ'},
                {'key': 'LIGHT', 'label': 'خفیف'},
                {'key': 'MEDIUM', 'label': 'متوسط'},
                {'key': 'HEAVY', 'label': 'شدید'},
              ].map((item) {
                final f = item['key']!;
                final label = item['label']!;
                final active = flowLevel == f;
                return _buildSelectableChip(
                  label: label,
                  isSelected: active,
                  onTap: () => setState(() => flowLevel = f),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Section 2: Mood
            _buildSectionHeader(
              CupertinoIcons.smiley,
              'حس و خُلق‌وخو',
              colors,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                {'key': 'HAPPY', 'label': 'عالی'},
                {'key': 'NEUTRAL', 'label': 'معمولی'},
                {'key': 'SAD', 'label': 'بی‌حوصله'},
                {'key': 'ANXIOUS', 'label': 'مضطرب'},
                {'key': 'IRRITABLE', 'label': 'کلافه'},
              ].map((item) {
                final m = item['key']!;
                final label = item['label']!;
                final active = mood == m;
                return _buildSelectableChip(
                  label: label,
                  isSelected: active,
                  onTap: () => setState(() => mood = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Section 3: Energy
            _buildSectionHeader(
              CupertinoIcons.bolt,
              'سطح انرژی بدنی',
              colors,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                {'key': 'HIGH', 'label': 'پرانرژی'},
                {'key': 'MEDIUM', 'label': 'معمولی'},
                {'key': 'LOW', 'label': 'نیاز به استراحت'},
              ].map((item) {
                final e = item['key']!;
                final label = item['label']!;
                final active = energyTag == e;
                return _buildSelectableChip(
                  label: label,
                  isSelected: active,
                  onTap: () => setState(() => energyTag = e),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Section 4: Symptoms
            _buildSectionHeader(
              CupertinoIcons.doc_plaintext,
              'علائم جسمی شایع (انتخاب چندگانه)',
              colors,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptomsList.map((s) {
                final key = s['key']!;
                final label = s['label']!;
                final active = symptoms.contains(key);

                var symIcon = CupertinoIcons.tag;
                if (key == 'cramps') {
                  symIcon = CupertinoIcons.bolt_horizontal_fill;
                } else if (key == 'headache') {
                  symIcon = CupertinoIcons.sparkles;
                } else if (key == 'bloating') {
                  symIcon = CupertinoIcons.wind;
                } else if (key == 'fatigue') {
                  symIcon = CupertinoIcons.battery_25;
                } else if (key == 'backache') {
                  symIcon = CupertinoIcons.arrow_down_right_arrow_up_left;
                } else if (key == 'mood_swings') {
                  symIcon = CupertinoIcons.heart_slash_fill;
                }

                return _buildSelectableChip(
                  label: label,
                  isSelected: active,
                  icon: symIcon,
                  onTap: () {
                    if (active) {
                      symptoms.remove(key);
                    } else {
                      symptoms.add(key);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Section 5: Notes
            _buildSectionHeader(
              CupertinoIcons.pencil,
              'یادداشت شخصی',
              colors,
            ),
            const SizedBox(height: 10),
            RitmoCard.neumorphicSunken(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: TextField(
                controller: noteController,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'جزئیات یا مشاهدات خود را بنویسید...',
                  hintStyle: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Action Button
            RitmoPrimaryButton(
              label: 'ذخیره احوال امروز',
              onPressed: () async {
                final nowMs = CycleClock.nowMillisecondsSinceEpoch;
                final logId = widget.todayLog != null
                    ? widget.todayLog!['id'] as String
                    : 'daylog_$nowMs';
                final symptomsJson = jsonEncode(symptoms);
                final db = await DatabaseHelper.instance.database;

                await db.insert(
                  'cycle_day_logs',
                  {
                    'id': logId,
                    'logDate': widget.todayStr,
                    'flowLevel': flowLevel,
                    'symptomsJson': symptomsJson,
                    'mood': mood,
                    'energyTag': energyTag,
                    'note': noteController.text.trim(),
                    'createdAt': nowMs,
                    'updatedAt': nowMs,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );

                CycleEngine().invalidate();

                RitmoEventBus().fire(
                  RitmoEvent(
                    type: 'CycleLogged',
                    payload: {'date': widget.todayStr},
                  ),
                );

                setState(() {
                  showSuccessLottie = true;
                });

                await Future.delayed(const Duration(milliseconds: 1400));

                if (context.mounted) {
                  Navigator.pop(context);
                }
                widget.onSaved();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
