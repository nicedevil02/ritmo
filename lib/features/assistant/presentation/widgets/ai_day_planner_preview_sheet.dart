// lib/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/logic/assistant_action_registry.dart';
import 'package:ritmo/features/assistant/logic/day_plan_template_service.dart';
import 'package:ritmo/features/assistant/logic/day_plan_validator.dart';
import 'package:ritmo/features/assistant/models/assistant_models.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum DayPlannerMode { standaloneCommit, draftOnly }

class AiDayPlannerPreviewSheet extends StatefulWidget {
  const AiDayPlannerPreviewSheet({
    super.key,
    required this.initialDraft,
    required this.onSaved,
    this.mode = DayPlannerMode.standaloneCommit,
  });
  final DayPlanDraft initialDraft;
  final VoidCallback onSaved;
  final DayPlannerMode mode;

  static void show(
    BuildContext context, {
    required DayPlanDraft initialDraft,
    required VoidCallback onSaved,
    DayPlannerMode mode = DayPlannerMode.standaloneCommit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiDayPlannerPreviewSheet(
        initialDraft: initialDraft,
        onSaved: onSaved,
        mode: mode,
      ),
    );
  }

  static Future<DayPlanDraft?> showForResult(
    BuildContext context, {
    required DayPlanDraft initialDraft,
    DayPlannerMode mode = DayPlannerMode.standaloneCommit,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet<DayPlanDraft?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiDayPlannerPreviewSheet(
        initialDraft: initialDraft,
        onSaved: onSaved ?? () {},
        mode: mode,
      ),
    );
  }

  @override
  State<AiDayPlannerPreviewSheet> createState() =>
      _AiDayPlannerPreviewSheetState();
}

class _AiDayPlannerPreviewSheetState extends State<AiDayPlannerPreviewSheet> {
  late DayPlanDraft _currentDraft;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentDraft = widget.initialDraft;
    // Initial validation pass
    _reValidate();
  }

  Future<void> _reValidate() async {
    final enriched = await DayPlanValidator.validateAndEnrich(
      draft: _currentDraft,
    );
    if (mounted) {
      setState(() {
        _currentDraft = enriched;
      });
    }
  }

  String _getFarsiDate() {
    final dt = DateTime.tryParse(_currentDraft.planDate) ?? DateTime.now();
    final j = Jalali.fromDateTime(dt);
    return '${j.day} ${j.formatter.mN} ${j.year}';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return CupertinoIcons.briefcase;
      case 'fitness':
        return CupertinoIcons.sportscourt;
      case 'health':
        return CupertinoIcons.heart;
      case 'study':
        return CupertinoIcons.book;
      case 'worship':
        return CupertinoIcons.moon_stars;
      case 'personal':
      default:
        return CupertinoIcons.person;
    }
  }

  Color _getCategoryColor(String category, RitmoColors colors) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'fitness':
        return Colors.green;
      case 'health':
        return colors.primary;
      case 'study':
        return Colors.purple;
      case 'worship':
        return const Color(0xffD4A843);
      case 'personal':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final scaffoldContent = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: colors.textSecondary.withValues(alpha: 0.6),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colors.border.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Text(
                          'پیش‌نمایش برنامه روز ${_getFarsiDate()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          Expanded(
            child: _currentDraft.items.isEmpty
                ? Center(
                    child: Text(
                      'هیچ فعالیتی در برنامه وجود ندارد.',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: _currentDraft.items.length,
                    itemBuilder: (context, index) {
                      final item = _currentDraft.items[index];
                      return _buildTimelineItem(
                        context,
                        item,
                        index,
                        colors,
                      );
                    },
                  ),
          ),
          if (_currentDraft.suggestions.isNotEmpty)
            _buildSuggestionsBlock(colors),
          _buildFooter(colors),
        ],
      ),
    );

    final wrappedContent = Container(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
      ),
      child: scaffoldContent,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: !isGlass
            ? Container(
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: sheetRadius,
                  border: Border.all(
                    color: isDark ? colors.border : colors.divider,
                    width: 1.0,
                  ),
                ),
                child: wrappedContent,
              )
            : ClipRRect(
                borderRadius: sheetRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.glassTint,
                      borderRadius: sheetRadius,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.70),
                        width: 1.0,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: sheetRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.08 : 0.20,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.45],
                        ),
                      ),
                      child: wrappedContent,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    DayPlanItemDraft item,
    int index,
    RitmoColors colors,
  ) {
    final categoryColor = _getCategoryColor(item.category, colors);
    final hasConflict = item.note?.contains('⚠️') ?? false;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Node and Track
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: categoryColor, width: 1.5),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  size: 16,
                  color: categoryColor,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: index == _currentDraft.items.length - 1
                      ? Colors.transparent
                      : colors.border.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          // Content Card
          Expanded(
            child: InkWell(
              onTap: () => _editItemDialog(item, index),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasConflict
                      ? Colors.amber.withValues(alpha: 0.08)
                      : colors.card.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasConflict
                        ? Colors.amber.withValues(alpha: 0.3)
                        : colors.border.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.trash,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentDraft.items.removeAt(index);
                            });
                            _reValidate();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.resolvedTime ?? 'نامشخص',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          CupertinoIcons.hourglass,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.durationMin != null
                              ? '${item.durationMin} دقیقه'
                              : 'تخمین زده نشده',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (item.durationSource != 'none' &&
                            item.durationSource != 'user') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'حدسی',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.note != null && item.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasConflict
                              ? Colors.amber[800]
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBlock(RitmoColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.lightbulb, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'پیشنهادهای هوشمند Ritmo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._currentDraft.suggestions.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${s.text}',
                style: TextStyle(fontSize: 12, color: colors.textPrimary),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _saveAsTemplateDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return RitmoCustomDialog(
          title: 'ذخیره به عنوان قالب',
          icon: Icons.bookmarks_outlined,
          content: TextField(
            controller: nameController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'نام قالب (مثلاً: روز کاری، روز تعطیل)',
            ),
          ),
          actions: [
            RitmoSecondaryButton(
              label: 'انصراف',
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(width: 10),
            RitmoPrimaryButton(
              label: 'ذخیره',
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await DayPlanTemplateService.instance.saveTemplate(
                    name: name,
                    items: _currentDraft.items,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    RitmoToast.show(ctx, 'قالب با موفقیت ذخیره شد 💾');
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    RitmoToast.show(ctx, 'خطا در ذخیره قالب ❌');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooter(RitmoColors colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'انصراف',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: colors.goldAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saveAsTemplateDialog,
                child: Text(
                  'قالب روز',
                  style: TextStyle(fontSize: 14, color: colors.goldAccent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveDayPlan,
                child: _isSaving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        widget.mode == DayPlannerMode.draftOnly
                            ? 'ذخیره در پیش‌نویس هفته'
                            : 'تأیید و ثبت',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editItemDialog(DayPlanItemDraft item, int index) {
    final titleController = TextEditingController(text: item.title);
    final durationController = TextEditingController(
      text: item.durationMin?.toString() ?? '30',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return RitmoCustomDialog(
          title: 'ویرایش آیتم',
          icon: CupertinoIcons.pencil,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'عنوان'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'مدت (دقیقه)'),
              ),
            ],
          ),
          actions: [
            RitmoSecondaryButton(
              label: 'انصراف',
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(width: 10),
            RitmoPrimaryButton(
              label: 'ثبت',
              onPressed: () {
                final newTitle = titleController.text.trim();
                final newDuration =
                    int.tryParse(durationController.text) ?? item.durationMin;
                if (newTitle.isNotEmpty) {
                  setState(() {
                    _currentDraft.items[index] = item.copyWith(
                      title: newTitle,
                      durationMin: newDuration,
                    );
                  });
                  _reValidate();
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDayPlan() async {
    if (widget.mode == DayPlannerMode.draftOnly) {
      Navigator.pop(context, _currentDraft);
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      final action = AssistantAction(
        type: AssistantActionType.applyDayPlan,
        title: 'ثبت برنامه روزانه',
        payload: _currentDraft.toJson(),
      );

      await AssistantActionRegistry.executeAction(context, action, () {
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
        }
      });
    } catch (e) {
      debugPrint('[AiDayPlannerPreviewSheet] Save day plan failed: $e');
      if (mounted) {
        RitmoToast.show(context, 'خطا در ذخیره‌سازی برنامه ❌');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
