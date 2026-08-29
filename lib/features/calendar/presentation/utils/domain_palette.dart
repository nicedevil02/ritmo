import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

Color kindColor(BuildContext context, AgendaItemKind kind) {
  final modules = context.modules;
  switch (kind) {
    case AgendaItemKind.routine:
      return modules.byModuleId('routines');
    case AgendaItemKind.reminder:
      return const Color(0xFFF59E0B);
    case AgendaItemKind.task:
      return context.colors.primary;
    case AgendaItemKind.reflection:
      return const Color(0xFF8B5CF6);
    case AgendaItemKind.event:
      return modules.byModuleId('planner');
    case AgendaItemKind.session:
      return modules.byModuleId('study');
    case AgendaItemKind.dose:
      return modules.byModuleId('health');
    case AgendaItemKind.practice:
      return modules.byModuleId('worship');
  }
}

Color domainColor(
  BuildContext context,
  AgendaDomain domain, {
  AgendaItemKind? kind,
}) {
  if (kind != null && domain == AgendaDomain.routine) {
    return kindColor(context, kind);
  }
  final modules = context.modules;
  switch (domain) {
    case AgendaDomain.routine:
      return modules.byModuleId('routines');
    case AgendaDomain.prayer:
    case AgendaDomain.mustahab:
    case AgendaDomain.worshipDebt:
      return modules.byModuleId('worship');
    case AgendaDomain.course:
    case AgendaDomain.konkur:
      return modules.byModuleId('study');
    case AgendaDomain.goalStep:
      return modules.byModuleId('goals');
    case AgendaDomain.cycle:
    case AgendaDomain.medicine:
      return modules.byModuleId('health');
    case AgendaDomain.sport:
      return modules.byModuleId('sports');
    case AgendaDomain.event:
      return modules.byModuleId('planner');
    case AgendaDomain.task:
      return context.colors.primary;
    case AgendaDomain.commitment:
    case AgendaDomain.appointment:
      return modules.byModuleId('planner');
  }
}

Color domainContainerColor(
  BuildContext context,
  AgendaDomain domain, {
  AgendaItemKind? kind,
}) {
  final baseColor = domainColor(context, domain, kind: kind);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final alpha = isDark ? 0.16 : 0.10;
  return baseColor.withValues(alpha: alpha);
}

IconData kindIcon(AgendaItemKind kind) {
  switch (kind) {
    case AgendaItemKind.routine:
      return Icons.repeat_rounded;
    case AgendaItemKind.reminder:
      return Icons.notifications_active_rounded;
    case AgendaItemKind.task:
      return CupertinoIcons.checkmark_square;
    case AgendaItemKind.reflection:
      return Icons.psychology_alt_rounded;
    case AgendaItemKind.event:
      return Icons.event_rounded;
    case AgendaItemKind.session:
      return Icons.school_rounded;
    case AgendaItemKind.dose:
      return Icons.medication_rounded;
    case AgendaItemKind.practice:
      return Icons.mosque_rounded;
  }
}

IconData domainIcon(AgendaDomain domain, {AgendaItemKind? kind}) {
  if (kind != null && domain == AgendaDomain.routine) {
    return kindIcon(kind);
  }
  switch (domain) {
    case AgendaDomain.routine:
      return Icons.repeat_rounded;
    case AgendaDomain.prayer:
      return Icons.mosque_rounded;
    case AgendaDomain.mustahab:
      return Icons.auto_awesome_rounded;
    case AgendaDomain.worshipDebt:
      return Icons.history_edu_rounded;
    case AgendaDomain.course:
      return Icons.school_rounded;
    case AgendaDomain.konkur:
      return Icons.menu_book_rounded;
    case AgendaDomain.goalStep:
      return Icons.flag_rounded;
    case AgendaDomain.cycle:
      return Icons.water_drop_rounded;
    case AgendaDomain.sport:
      return Icons.fitness_center_rounded;
    case AgendaDomain.medicine:
      return Icons.medication_rounded;
    case AgendaDomain.event:
      return Icons.event_rounded;
    case AgendaDomain.task:
      return CupertinoIcons.checkmark_square;
    case AgendaDomain.commitment:
      return Icons.handshake_rounded;
    case AgendaDomain.appointment:
      return Icons.calendar_today_rounded;
  }
}

String kindLabelFa(AgendaItemKind kind) {
  switch (kind) {
    case AgendaItemKind.routine:
      return 'روتین';
    case AgendaItemKind.reminder:
      return 'یادآور';
    case AgendaItemKind.task:
      return 'کار';
    case AgendaItemKind.reflection:
      return 'تأمل';
    case AgendaItemKind.event:
      return 'رویداد';
    case AgendaItemKind.session:
      return 'جلسه';
    case AgendaItemKind.dose:
      return 'نوبت دارو';
    case AgendaItemKind.practice:
      return 'عبادت';
  }
}

String domainLabelFa(AgendaDomain domain, {AgendaItemKind? kind}) {
  if (kind != null && domain == AgendaDomain.routine) {
    return kindLabelFa(kind);
  }
  switch (domain) {
    case AgendaDomain.routine:
      return 'روتین';
    case AgendaDomain.prayer:
      return 'نماز';
    case AgendaDomain.mustahab:
      return 'مستحب';
    case AgendaDomain.worshipDebt:
      return 'قضا';
    case AgendaDomain.course:
      return 'دوره آموزشی';
    case AgendaDomain.konkur:
      return 'کنکور';
    case AgendaDomain.goalStep:
      return 'گام هدف';
    case AgendaDomain.cycle:
      return 'چرخهٔ سلامتی';
    case AgendaDomain.sport:
      return 'ورزش';
    case AgendaDomain.medicine:
      return 'دارو';
    case AgendaDomain.event:
      return 'رویداد';
    case AgendaDomain.task:
      return 'کار';
    case AgendaDomain.commitment:
      return 'تعهد';
    case AgendaDomain.appointment:
      return 'قرار';
  }
}

Color domainIconColor(
  BuildContext context,
  AgendaDomain domain, {
  AgendaItemKind? kind,
}) {
  if (domain == AgendaDomain.cycle) {
    return const Color(0xFFEF4444);
  }
  return domainColor(context, domain, kind: kind);
}

IconData itemIcon(AgendaItem item) {
  final tLower = item.title.toLowerCase();
  if (item.domain == AgendaDomain.prayer ||
      item.domain == AgendaDomain.mustahab ||
      item.domain == AgendaDomain.worshipDebt ||
      tLower.contains('نماز') ||
      tLower.contains('قرآن') ||
      tLower.contains('دعا') ||
      tLower.contains('زیارت') ||
      tLower.contains('اذان') ||
      tLower.contains('مسجد') ||
      tLower.contains('ذکر')) {
    return Icons.mosque_rounded;
  }
  if (item.domain == AgendaDomain.sport ||
      tLower.contains('ورزش') ||
      tLower.contains('تمرین') ||
      tLower.contains('باشگاه') ||
      tLower.contains('دویدن') ||
      tLower.contains('شنا')) {
    return CupertinoIcons.flame_fill;
  }
  if (item.domain == AgendaDomain.medicine ||
      tLower.contains('دارو') ||
      tLower.contains('قرص') ||
      tLower.contains('شربت') ||
      tLower.contains('انسولین') ||
      tLower.contains('پزشک')) {
    return CupertinoIcons.bandage_fill;
  }
  if (item.domain == AgendaDomain.course ||
      item.domain == AgendaDomain.konkur ||
      tLower.contains('درس') ||
      tLower.contains('مطالعه') ||
      tLower.contains('کتاب') ||
      tLower.contains('کنکور')) {
    return CupertinoIcons.book_fill;
  }
  if (item.domain == AgendaDomain.task ||
      item.domain == AgendaDomain.commitment ||
      tLower.contains('کار') ||
      tLower.contains('پروژه') ||
      tLower.contains('کد') ||
      tLower.contains('جلسه')) {
    return CupertinoIcons.briefcase_fill;
  }
  if (tLower.contains('خواب') || tLower.contains('استراحت')) {
    return CupertinoIcons.moon_fill;
  }
  return domainIcon(item.domain, kind: item.kind);
}

Color itemColor(BuildContext context, AgendaItem item) {
  final tLower = item.title.toLowerCase();
  if (item.domain == AgendaDomain.prayer ||
      item.domain == AgendaDomain.mustahab ||
      item.domain == AgendaDomain.worshipDebt ||
      tLower.contains('نماز') ||
      tLower.contains('قرآن') ||
      tLower.contains('دعا') ||
      tLower.contains('زیارت') ||
      tLower.contains('اذان') ||
      tLower.contains('مسجد') ||
      tLower.contains('ذکر')) {
    return const Color(0xFF10B981); // Emerald Worship
  }
  if (item.domain == AgendaDomain.sport ||
      tLower.contains('ورزش') ||
      tLower.contains('تمرین') ||
      tLower.contains('باشگاه') ||
      tLower.contains('دویدن') ||
      tLower.contains('شنا') ||
      tLower.contains('پیاده‌روی')) {
    return const Color(0xFFF97316); // Exercise Orange
  }
  if (item.domain == AgendaDomain.medicine ||
      tLower.contains('دارو') ||
      tLower.contains('قرص') ||
      tLower.contains('شربت') ||
      tLower.contains('انسولین') ||
      tLower.contains('پزشک')) {
    return const Color(0xFFEF4444); // Medical Red
  }
  if (item.domain == AgendaDomain.course ||
      item.domain == AgendaDomain.konkur ||
      tLower.contains('درس') ||
      tLower.contains('مطالعه') ||
      tLower.contains('کتاب') ||
      tLower.contains('کنکور')) {
    return const Color(0xFF8B5CF6); // Purple Learning
  }
  if (item.domain == AgendaDomain.task ||
      item.domain == AgendaDomain.commitment ||
      tLower.contains('کار') ||
      tLower.contains('پروژه') ||
      tLower.contains('کد') ||
      tLower.contains('جلسه')) {
    return const Color(0xFF2563EB); // Royal Focus Blue
  }
  if (tLower.contains('خواب') || tLower.contains('استراحت')) {
    return const Color(0xFF6366F1); // Night Indigo
  }
  return domainColor(context, item.domain, kind: item.kind);
}

Color itemIconColor(BuildContext context, AgendaItem item) {
  if (item.domain == AgendaDomain.cycle) {
    return const Color(0xFFEF4444);
  }
  return itemColor(context, item);
}

Color itemContainerColor(BuildContext context, AgendaItem item) {
  final baseColor = itemColor(context, item);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final alpha = isDark ? 0.16 : 0.10;
  return baseColor.withValues(alpha: alpha);
}

String itemLabelFa(AgendaItem item) =>
    domainLabelFa(item.domain, kind: item.kind);

