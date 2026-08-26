import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/rituals/zone_ritual.dart';

/// Interactive bottom sheet for realm transition rituals (F-14).
///
/// Designed to be quick (~30 seconds) and strictly dismissible/skippable.
class ZoneRitualSheet extends StatefulWidget {
  const ZoneRitualSheet({
    super.key,
    required this.realm,
    required this.ritual,
    this.isExit = true,
    this.pendingTasks = const [],
    this.onComplete,
    this.onSkip,
  });

  final RealmData realm;
  final ZoneRitualConfig ritual;
  final bool isExit;
  final List<String> pendingTasks;
  final void Function(String? noteForTomorrow, List<String> deferredTasks)?
      onComplete;
  final VoidCallback? onSkip;

  static Future<void> show(
    BuildContext context, {
    required RealmData realm,
    required ZoneRitualConfig ritual,
    bool isExit = true,
    List<String> pendingTasks = const [],
    void Function(String? noteForTomorrow, List<String> deferredTasks)?
        onComplete,
    VoidCallback? onSkip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ZoneRitualSheet(
        realm: realm,
        ritual: ritual,
        isExit: isExit,
        pendingTasks: pendingTasks,
        onComplete: onComplete,
        onSkip: onSkip,
      ),
    );
  }

  @override
  State<ZoneRitualSheet> createState() => _ZoneRitualSheetState();
}

class _ZoneRitualSheetState extends State<ZoneRitualSheet> {
  final TextEditingController _noteController = TextEditingController();
  final Set<String> _deferredTasks = {};

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final realmColor = widget.realm.parseColor();

    final title = widget.isExit
        ? 'آیین پایان «${widget.realm.name}»'
        : 'آیین ورود به «${widget.realm.name}»';

    final subtitle = widget.isExit
        ? '۳۰ ثانیه برای جمع‌بندی ذهن و جلوگیری از سرریز به قلمرو بعدی'
        : 'لحظه‌ای کوتاه برای حضور ذهن و شروع متمرکز';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: realmColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.realm.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.ritual.isDismissible)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSkip?.call();
                    },
                    tooltip: 'رد کردن',
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Pending tasks triage (if any)
            if (widget.ritual.reviewPendingTasks &&
                widget.pendingTasks.isNotEmpty) ...[
              Text(
                'کارهای نیمه‌تمام (${widget.pendingTasks.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.pendingTasks.map((task) {
                final isDeferred = _deferredTasks.contains(task);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: isDeferred
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(
                          isDeferred ? Icons.undo : Icons.schedule,
                          size: 16,
                        ),
                        label: Text(
                          isDeferred ? 'لغو انتقال' : 'انتقال به فردا',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            if (isDeferred) {
                              _deferredTasks.remove(task);
                            } else {
                              _deferredTasks.add(task);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Note for tomorrow
            if (widget.ritual.promptNoteForTomorrow) ...[
              Text(
                'یادداشت برای فردا',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'یک جمله یادداشت برای شروع آرام و پرانرژی فردا...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Row(
              children: [
                if (widget.ritual.isDismissible)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSkip?.call();
                      },
                      child: const Text('رد کردن'),
                    ),
                  ),
                if (widget.ritual.isDismissible) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: realmColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final note = _noteController.text.trim();
                      Navigator.of(context).pop();
                      widget.onComplete?.call(
                        note.isEmpty ? null : note,
                        _deferredTasks.toList(),
                      );
                    },
                    child: const Text(
                      'پایان گذار',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
