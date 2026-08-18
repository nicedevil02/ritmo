// C-43, C-44: CycleLogTodaySheet
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';
import 'package:sqflite/sqflite.dart';

class CycleLogTodaySheet extends StatefulWidget {
  const CycleLogTodaySheet({
    super.key,
    required this.todayStr,
    required this.todayLog,
    required this.activePhaseColor,
    required this.onSaved,
  });

  final String todayStr;
  final Map<String, dynamic>? todayLog;
  final Color activePhaseColor;
  final VoidCallback onSaved;

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
      builder: (ctx) => CycleLogTodaySheet(
        todayStr: todayStr,
        todayLog: todayLog,
        activePhaseColor: activePhaseColor,
        onSaved: onSaved,
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
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, color: widget.activePhaseColor, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (showSuccessLottie) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: RitmoSheetGlassCard(
          child: Container(
            height: 350,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Lottie.asset(
                    'assets/animations/workout_success.json',
                    repeat: false,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'احوال امروز با موفقیت ثبت شد 🌸',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoSheetGlassCard(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ثبت علائم و احوال امروز',
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 1: Flow
                _buildSectionHeader(
                  CupertinoIcons.drop,
                  'میزان خونریزی یا ترشح بدنی',
                  colors,
                  isDark,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        {'key': 'NONE', 'label': 'هیچ'},
                        {'key': 'LIGHT', 'label': 'خفیف'},
                        {'key': 'MEDIUM', 'label': 'متوسط'},
                        {'key': 'HEAVY', 'label': 'شدید'},
                      ].map((item) {
                        final f = item['key']!;
                        final label = item['label']!;
                        final active = flowLevel == f;
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: active
                                  ? Colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                          selected: active,
                          selectedColor: widget.activePhaseColor,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : colors.surface,
                          checkmarkColor: Colors.white,
                          side: BorderSide(color: colors.border),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => flowLevel = f);
                            }
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // Section 2: Mood
                _buildSectionHeader(
                  CupertinoIcons.smiley,
                  'حس و خُلق‌وخو',
                  colors,
                  isDark,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      [
                        {'key': 'HAPPY', 'label': 'عالی'},
                        {'key': 'NEUTRAL', 'label': 'معمولی'},
                        {'key': 'SAD', 'label': 'بی‌حوصله'},
                        {'key': 'ANXIOUS', 'label': 'مضطرب'},
                        {'key': 'IRRITABLE', 'label': 'کلافه'},
                      ].map((item) {
                        final m = item['key']!;
                        final label = item['label']!;
                        final active = mood == m;
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: active
                                  ? Colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                          selected: active,
                          selectedColor: widget.activePhaseColor,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : colors.surface,
                          checkmarkColor: Colors.white,
                          side: BorderSide(color: colors.border),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => mood = m);
                            }
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // Section 3: Energy
                _buildSectionHeader(
                  CupertinoIcons.bolt,
                  'سطح انرژی بدنی',
                  colors,
                  isDark,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        {'key': 'HIGH', 'label': 'پرانرژی'},
                        {'key': 'MEDIUM', 'label': 'معمولی'},
                        {'key': 'LOW', 'label': 'نیاز به استراحت'},
                      ].map((item) {
                        final e = item['key']!;
                        final label = item['label']!;
                        final active = energyTag == e;
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: active
                                  ? Colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                          selected: active,
                          selectedColor: widget.activePhaseColor,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : colors.surface,
                          checkmarkColor: Colors.white,
                          side: BorderSide(color: colors.border),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => energyTag = e);
                            }
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // Section 4: Symptoms
                _buildSectionHeader(
                  CupertinoIcons.doc_plaintext,
                  'علائم جسمی شایع (انتخاب چندگانه)',
                  colors,
                  isDark,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: symptomsList.map((s) {
                    final key = s['key']!;
                    final label = s['label']!;
                    final active = symptoms.contains(key);

                    var activeColor = colors.primary;
                    var symIcon = CupertinoIcons.tag;
                    if (key == 'cramps') {
                      activeColor = colors.error;
                      symIcon = CupertinoIcons.bolt_horizontal_fill;
                    } else if (key == 'headache') {
                      activeColor = colors.accent;
                      symIcon = CupertinoIcons.sparkles;
                    } else if (key == 'bloating') {
                      activeColor = colors.success;
                      symIcon = CupertinoIcons.wind;
                    } else if (key == 'fatigue') {
                      activeColor = colors.accent;
                      symIcon = CupertinoIcons.battery_25;
                    } else if (key == 'backache') {
                      activeColor = colors.warning;
                      symIcon = CupertinoIcons.arrow_down_right_arrow_up_left;
                    } else if (key == 'mood_swings') {
                      activeColor = colors.primary;
                      symIcon = CupertinoIcons.heart_slash_fill;
                    }

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (active) {
                            symptoms.remove(key);
                          } else {
                            symptoms.add(key);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? activeColor.withValues(alpha: 0.12)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : colors.surface),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active ? activeColor : colors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              symIcon,
                              color: active
                                  ? activeColor
                                  : colors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: active
                                    ? activeColor
                                    : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Section 5: Notes
                _buildSectionHeader(
                  CupertinoIcons.pencil,
                  'یادداشت شخصی',
                  colors,
                  isDark,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'جزئیات یا مشاهدات خود را بنویسید...',
                    hintStyle: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.activePhaseColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
                    child: const Text(
                      'ذخیره احوال امروز',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
