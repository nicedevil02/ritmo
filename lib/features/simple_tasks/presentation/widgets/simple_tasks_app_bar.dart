import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/search/presentation/global_search_screen.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';

class SimpleTasksAppBar extends StatelessWidget {
  const SimpleTasksAppBar({
    super.key,
    required this.sortMode,
    required this.hideCompleted,
    required this.onPreferencesChanged,
  });

  final TaskSortMode sortMode;
  final bool hideCompleted;
  final VoidCallback onPreferencesChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'کارها',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.search, color: colors.textSecondary, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(CupertinoIcons.ellipsis_vertical, color: colors.textSecondary, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: colors.card,
                onSelected: (value) async {
                  if (value == 'toggle_hide_completed') {
                    final current = await TaskPreferences.isHideCompleted();
                    await TaskPreferences.setHideCompleted(!current);
                    onPreferencesChanged();
                  } else if (value.startsWith('sort_')) {
                    final mode = value.replaceFirst('sort_', '');
                    await TaskPreferences.setSortMode(mode);
                    onPreferencesChanged();
                  }
                },
                itemBuilder: (ctx) {
                  return [
                    PopupMenuItem(
                      value: 'toggle_hide_completed',
                      child: Row(
                        children: [
                          Icon(
                            hideCompleted ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                            size: 18,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            hideCompleted ? 'نمایش کارهای انجام‌شده' : 'مخفی کردن کارهای انجام‌شده',
                            style: TextStyle(fontSize: 13, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: false,
                      child: Text('مرتب‌سازی براساس:', style: TextStyle(fontSize: 11, color: colors.textTertiary, fontWeight: FontWeight.bold)),
                    ),
                    PopupMenuItem(
                      value: 'sort_smart',
                      child: Row(
                        children: [
                          if (sortMode == TaskSortMode.smart) Icon(CupertinoIcons.checkmark, size: 16, color: colors.primary) else const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('هوشمند (پیش‌فرض)', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_dueDate',
                      child: Row(
                        children: [
                          if (sortMode == TaskSortMode.dueDate) Icon(CupertinoIcons.checkmark, size: 16, color: colors.primary) else const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('تاریخ سررسید', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_importance',
                      child: Row(
                        children: [
                          if (sortMode == TaskSortMode.importance) Icon(CupertinoIcons.checkmark, size: 16, color: colors.primary) else const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('اهمیت (ستاره)', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_alphabetical',
                      child: Row(
                        children: [
                          if (sortMode == TaskSortMode.alphabetical) Icon(CupertinoIcons.checkmark, size: 16, color: colors.primary) else const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('الفبا', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_createdAt',
                      child: Row(
                        children: [
                          if (sortMode == TaskSortMode.createdAt) Icon(CupertinoIcons.checkmark, size: 16, color: colors.primary) else const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('زمان ثبت', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
