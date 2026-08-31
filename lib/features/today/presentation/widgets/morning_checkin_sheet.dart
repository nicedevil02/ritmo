import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:sqflite/sqflite.dart';

/// Modal bottom sheet for morning mood & energy check-in.
class MorningCheckinSheet extends StatefulWidget {
  /// Constructs a [MorningCheckinSheet].
  const MorningCheckinSheet({required this.onSaved, super.key});
  /// Callback triggered when the check-in is saved.
  final VoidCallback onSaved;

  @override
  State<MorningCheckinSheet> createState() => _MorningCheckinSheetState();
}

class _MorningCheckinSheetState extends State<MorningCheckinSheet> {
  String _selectedMood = 'NORMAL';
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  final List<Map<String, dynamic>> _moods = [
    {
      'key': 'TIRED',
      'label': 'خسته و بی‌انرژی',
      'icon': CupertinoIcons.clear_circled_solid,
      'color': Colors.redAccent,
      'energy': 'LOW',
    },
    {
      'key': 'NORMAL',
      'label': 'عادی و آرام',
      'icon': CupertinoIcons.checkmark_circle,
      'color': Colors.blueAccent,
      'energy': 'MEDIUM',
    },
    {
      'key': 'GOOD',
      'label': 'پرانرژی و خوب',
      'icon': CupertinoIcons.checkmark_circle_fill,
      'color': Colors.greenAccent,
      'energy': 'HIGH',
    },
    {
      'key': 'GREAT',
      'label': 'بسیار عالی و فوق‌العاده',
      'icon': CupertinoIcons.star_circle_fill,
      'color': Colors.amber,
      'energy': 'HIGH',
    },
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveCheckin() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Perform Upsert on daily_checkins (Using INSERT OR REPLACE)
      await db.insert(
        'daily_checkins',
        {
          'id': 'checkin_$todayStr',
          'date': todayStr,
          'mood': _selectedMood,
          'note':
              _noteController.text.isNotEmpty ? _noteController.text : null,
          'createdAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Map mood to energy level and log it in energy_logs
      final moodItem = _moods.firstWhere((m) => m['key'] == _selectedMood);
      final energyLevel = moodItem['energy'] as String;

      await db.insert(
        'energy_logs',
        {
          'id': 'energy_$nowMs',
          'energyLevel': energyLevel,
          'note': 'ثبت شده از ارزیابی صبحگاهی: ${moodItem['label']}',
          'loggedAt': nowMs,
        },
      );

      // 3. Update app settings current default energy level
      await db.insert(
        'app_settings',
        {
          'key': 'default_energy_level',
          'value': energyLevel,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await HapticFeedback.mediumImpact();
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ارزیابی صبحگاهی شما با موفقیت ثبت شد 🌿',
              style: TextStyle(),
            ),
            backgroundColor: Color(0xff10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving morning check-in: $e');
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoGlassSheet(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  RitmoNeuButton(
                    onTap: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      CupertinoIcons.xmark,
                      color: colors.textSecondary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ارزیابی و چک‌این صبحگاهی',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36), // Symmetrical spacer
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'ریتم و وضعیت امروز خود را ثبت کنید تا سطح انرژی شما کالیبره شود.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Mood Selection List
              ..._moods.map((mood) {
                final isSelected = _selectedMood == mood['key'];
                final mColor = mood['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: RitmoCard.neumorphic(
                    isSelected: isSelected,
                    onTap: () async {
                      await HapticFeedback.selectionClick();
                      setState(() {
                        _selectedMood = mood['key'] as String;
                      });
                    },
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          mood['icon'] as IconData,
                          color: isSelected ? mColor : colors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mood['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            CupertinoIcons.checkmark_alt,
                            color: mColor,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              // Optional note text field
              RitmoCard.neumorphicSunken(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _noteController,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  ),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'یادداشت کوتاه از احساس امروز (اختیاری)',
                    hintStyle: TextStyle(
                      color: colors.textTertiary.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Save button
              RitmoPrimaryButton(
                label: 'تایید و ثبت وضعیت',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveCheckin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
