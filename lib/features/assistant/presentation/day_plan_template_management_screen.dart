import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/logic/day_plan_template_service.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';

class DayPlanTemplateManagementScreen extends StatefulWidget {
  const DayPlanTemplateManagementScreen({super.key});

  @override
  State<DayPlanTemplateManagementScreen> createState() =>
      _DayPlanTemplateManagementScreenState();
}

class _DayPlanTemplateManagementScreenState
    extends State<DayPlanTemplateManagementScreen> {
  List<DayPlanTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await DayPlanTemplateService.instance.getTemplates();
      setState(() {
        _templates = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        RitmoToast.show(context, 'خطا در بارگذاری قالب‌ها ❌');
      }
    }
  }

  void _renameTemplate(DayPlanTemplate template) {
    final controller = TextEditingController(text: template.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return RitmoCustomDialog(
          title: 'تغییر نام قالب',
          icon: CupertinoIcons.pencil,
          content: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(hintText: 'نام جدید قالب'),
          ),
          actions: [
            RitmoSecondaryButton(
              label: 'انصراف',
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(width: 10),
            RitmoPrimaryButton(
              label: 'ثبت',
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                try {
                  await DayPlanTemplateService.instance.renameTemplate(
                    template.id,
                    newName,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    await _loadTemplates();
                    if (mounted) {
                      RitmoToast.show(context, 'نام قالب تغییر یافت ✏️');
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    RitmoToast.show(context, 'خطا در تغییر نام ❌');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteTemplate(DayPlanTemplate template) async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'حذف قالب',
      content: 'آیا از حذف قالب "${template.name}" مطمئن هستید؟ این عمل غیرقابل بازگشت است.',
      confirmLabel: 'حذف',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await DayPlanTemplateService.instance.deleteTemplate(
          template.id,
        );
        if (mounted) {
          await _loadTemplates();
          if (mounted) {
            RitmoToast.show(context, 'قالب با موفقیت حذف شد 🗑️');
          }
        }
      } catch (e) {
        if (mounted) {
          RitmoToast.show(context, 'خطا در حذف قالب ❌');
        }
      }
    }
  }

  void _viewTemplateItems(DayPlanTemplate template) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final colors = ctx.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'جزئیات قالب: ${template.name}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: template.items.length,
                      itemBuilder: (context, index) {
                        final item = template.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RitmoCard.neumorphic(
                            child: ListTile(
                              leading: Icon(
                                item.targetModule == 'worship'
                                    ? CupertinoIcons.moon_stars
                                    : item.targetModule == 'sleep'
                                    ? CupertinoIcons.bed_double
                                    : CupertinoIcons.check_mark_circled,
                                color: colors.goldAccent,
                              ),
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'زمان: ${item.startKind == 'clock'
                                    ? (item.startTime ?? '')
                                    : item.startKind == 'anchor'
                                    ? 'لنگر ${item.anchorEvent}'
                                    : 'بعد از فعالیت قبلی'} • مدت: ${item.durationMin ?? 30} دقیقه',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: RitmoGlassHeader(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'قالب‌های برنامه‌ریز روز',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _templates.isEmpty
                        ? const Center(
                            child: RitmoNeuEmptyCard(
                              icon: Icons.bookmarks_outlined,
                              title: 'هیچ قالبی ذخیره نشده است 💾',
                              subtitle: 'می‌توانید برنامه‌های روزانه خود را به عنوان قالب ذخیره کنید.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _templates.length,
                            itemBuilder: (context, index) {
                              final template = _templates[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: RitmoCard.neumorphic(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      template.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'شامل ${template.items.length} فعالیت • تعداد استفاده: ${template.useCount}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.visibility_outlined,
                                            color: colors.textSecondary,
                                            size: 20,
                                          ),
                                          onPressed: () => _viewTemplateItems(template),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: colors.textSecondary,
                                            size: 20,
                                          ),
                                          onPressed: () => _renameTemplate(template),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () => _deleteTemplate(template),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
