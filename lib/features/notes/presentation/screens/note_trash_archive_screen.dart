import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_dialog.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_empty_state.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';
import 'package:shamsi_date/shamsi_date.dart';

class NoteTrashArchiveScreen extends StatefulWidget {
  final int initialTabIndex; // 0 for Trash, 1 for Archive

  const NoteTrashArchiveScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<NoteTrashArchiveScreen> createState() => _NoteTrashArchiveScreenState();
}

class _NoteTrashArchiveScreenState extends State<NoteTrashArchiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Note> _trashedNotes = [];
  List<Note> _archivedNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trashed = await NotesRepository.instance.listTrashed();
    final archived = await NotesRepository.instance.listArchived();
    if (mounted) {
      setState(() {
        _trashedNotes = trashed;
        _archivedNotes = archived;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${PersianDigits.convert(j.year.toString())}/${PersianDigits.convert(j.month.toString().padLeft(2, '0'))}/${PersianDigits.convert(j.day.toString().padLeft(2, '0'))}';
  }

  Future<void> _confirmPurgeAll() async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'تخلیه کامل سطل زباله',
      content: 'آیا از حذف قطعی تمامی یادداشت‌های سطل زباله و فایل‌های پیوست آن‌ها اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
      confirmLabel: 'تخلیه کامل',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      RitmoHapticsPolicy.tap();
      await NotesRepository.instance.purge(daysOld: 0);
      if (mounted) {
        RitmoToast.show(context, 'سطل زباله پاکسازی شد 🧹');
        await _loadData();
      }
    }
  }

  Future<void> _confirmPermanentDelete(Note note) async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'حذف دائمی یادداشت',
      content: 'یادداشت «${note.title ?? "بدون عنوان"}» و پیوست‌های آن برای همیشه حذف خواهند شد.',
      confirmLabel: 'حذف دائمی',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      RitmoHapticsPolicy.tap();
      await NotesRepository.instance.permanentDelete(note.id);
      if (mounted) {
        RitmoToast.show(context, 'یادداشت برای همیشه حذف شد');
        await _loadData();
      }
    }
  }

  Future<void> _restoreNote(String id) async {
    RitmoHapticsPolicy.selection();
    await NotesRepository.instance.restore(id);
    if (!mounted) return;
    RitmoToast.show(context, 'یادداشت بازیابی شد 🔄');
    await _loadData();
  }

  Future<void> _unarchiveNote(String id) async {
    RitmoHapticsPolicy.selection();
    await NotesRepository.instance.unarchive(id);
    if (!mounted) return;
    RitmoToast.show(context, 'از بایگانی خارج شد 📤');
    await _loadData();
  }

  Future<void> _trashNote(String id) async {
    RitmoHapticsPolicy.selection();
    await NotesRepository.instance.delete(id);
    if (!mounted) return;
    RitmoToast.show(context, 'به سطل زباله منتقل شد 🗑️');
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Luxury App Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              RitmoHapticsPolicy.tap();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.surfaceSunken,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colors.border,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.arrow_right,
                                size: 18,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'سطل زباله و بایگانی',
                          style: TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            ),
                        ),
                      ],
                    ),
                    if (_tabController.index == 0 && _trashedNotes.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmPurgeAll,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.error.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.trash_slash, size: 14, color: colors.error),
                                const SizedBox(width: 4),
                                Text(
                                  'تخلیه کامل',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Segmented Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    labelColor: isDark ? colors.accent : colors.primary,
                    unselectedLabelColor: colors.textSecondary.withValues(alpha: 0.7),
                    labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: 'سطل زباله (${PersianDigits.convert(_trashedNotes.length.toString())})'),
                      Tab(text: 'بایگانی (${PersianDigits.convert(_archivedNotes.length.toString())})'),
                    ],
                  ),
                ),
              ),

              // Content View
              Expanded(
                child: _isLoading
                    ? const RitmoShimmerList(count: 4)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(
                            items: _trashedNotes,
                            emptyText: 'سطل زباله خالی است',
                            isTrash: true,
                            isDark: isDark,
                            colors: colors,
                          ),
                          _buildList(
                            items: _archivedNotes,
                            emptyText: 'هیچ یادداشتی در بایگانی نیست',
                            isTrash: false,
                            isDark: isDark,
                            colors: colors,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required List<Note> items,
    required String emptyText,
    required bool isTrash,
    required bool isDark,
    required RitmoColors colors,
  }) {
    if (items.isEmpty) {
      return RitmoEmptyState(
        icon: isTrash ? CupertinoIcons.trash : CupertinoIcons.archivebox,
        title: emptyText,
        description: isTrash
            ? 'یادداشت‌های حذف‌شده در اینجا قرار می‌گیرند.'
            : 'یادداشت‌های بایگانی‌شده در اینجا نمایش داده می‌شوند.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
        itemCount: items.length,
        itemBuilder: (ctx, idx) {
          final note = items[idx];
          final style = NoteUiHelper.getKindStyle(context, note.kind);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 14, color: style.accentColor),
                        const SizedBox(width: 6),
                        Text(
                          note.title ?? 'بدون عنوان',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(note.trashedAt ?? note.updatedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isTrash) ...[
                      TextButton.icon(
                        onPressed: () => _restoreNote(note.id),
                        icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 13),
                        label: const Text('بازیابی', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: colors.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _confirmPermanentDelete(note),
                        icon: const Icon(CupertinoIcons.delete, size: 13),
                        label: const Text('حذف قطعی', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: colors.error,
                        ),
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () => _unarchiveNote(note.id),
                        icon: const Icon(CupertinoIcons.arrow_up_doc, size: 13),
                        label: const Text('خروج از بایگانی', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _trashNote(note.id),
                        icon: const Icon(CupertinoIcons.trash, size: 13),
                        label: const Text('انتقال به سطل زباله', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: colors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
