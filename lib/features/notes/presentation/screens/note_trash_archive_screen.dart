import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'سطل زباله و بایگانی',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
          ),
          actions: [
            if (_tabController.index == 0 && _trashedNotes.isNotEmpty)
              TextButton.icon(
                onPressed: _confirmPurgeAll,
                icon: Icon(CupertinoIcons.trash_slash, size: 16, color: colors.error),
                label: Text(
                  'تخلیه',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.error,
                      ),
                ),
              ),
            const SizedBox(width: RitmoSpacing.xs),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: colors.primary,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(text: 'سطل زباله (${PersianDigits.convert(_trashedNotes.length.toString())})'),
              Tab(text: 'بایگانی (${PersianDigits.convert(_archivedNotes.length.toString())})'),
            ],
          ),
        ),
        body: _isLoading
            ? const RitmoShimmerList(count: 4)
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Trashed Notes
                  _buildList(
                    items: _trashedNotes,
                    emptyText: 'سطل زباله خالی است',
                    isTrash: true,
                  ),

                  // Tab 2: Archived Notes
                  _buildList(
                    items: _archivedNotes,
                    emptyText: 'هیچ یادداشتی در بایگانی نیست',
                    isTrash: false,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildList({
    required List<Note> items,
    required String emptyText,
    required bool isTrash,
  }) {
    final colors = context.colors;

    if (items.isEmpty) {
      return RitmoEmptyState(
        icon: isTrash ? CupertinoIcons.trash : CupertinoIcons.archivebox,
        title: emptyText,
        description: isTrash ? 'یادداشت‌های حذف شده در اینجا قرار می‌گیرند.' : 'یادداشت‌های بایگانی‌شده در اینجا نمایش داده می‌شوند.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(RitmoSpacing.md),
        itemCount: items.length,
        itemBuilder: (ctx, idx) {
          final note = items[idx];
          final style = NoteUiHelper.getKindStyle(context, note.kind);

          return RitmoCard(
            margin: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
            padding: const EdgeInsets.all(RitmoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 14, color: style.accentColor),
                        const SizedBox(width: RitmoSpacing.xs),
                        Text(
                          note.title ?? 'بدون عنوان',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(note.trashedAt ?? note.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textTertiary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.xs),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isTrash) ...[
                      TextButton.icon(
                        onPressed: () => _restoreNote(note.id),
                        icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                        label: Text('بازیابی', style: Theme.of(context).textTheme.labelSmall),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmPermanentDelete(note),
                        icon: Icon(CupertinoIcons.delete, size: 14, color: colors.error),
                        label: Text(
                          'حذف قطعی',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.error,
                              ),
                        ),
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () => _unarchiveNote(note.id),
                        icon: const Icon(CupertinoIcons.arrow_up_doc, size: 14),
                        label: Text('خروج از بایگانی', style: Theme.of(context).textTheme.labelSmall),
                      ),
                      TextButton.icon(
                        onPressed: () => _trashNote(note.id),
                        icon: Icon(CupertinoIcons.trash, size: 14, color: colors.error),
                        label: Text(
                          'انتقال به زباله‌دان',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.error,
                              ),
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

