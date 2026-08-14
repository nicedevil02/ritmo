import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تخلیه کامل سطل زباله', style: TextStyle(fontFamily: 'Vazirmatn')),
        content: const Text(
          'آیا از حذف قطعی تمامی یادداشت‌های سطل زباله و فایل‌های پیوست آن‌ها اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('تخلیه کامل', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      RitmoHaptics.confirm();
      await NotesRepository.instance.purge(daysOld: 0);
      RitmoToast.show(context, 'سطل زباله پاکسازی شد 🧹');
      _loadData();
    }
  }

  Future<void> _confirmPermanentDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف دائمی یادداشت', style: TextStyle(fontFamily: 'Vazirmatn')),
        content: Text(
          'یادداشت «${note.title ?? "بدون عنوان"}» و پیوست‌های آن برای همیشه حذف خواهند شد.',
          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('حذف دائمی', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      RitmoHaptics.confirm();
      await NotesRepository.instance.permanentDelete(note.id);
      RitmoToast.show(context, 'یادداشت برای همیشه حذف شد');
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'سطل زباله و بایگانی 📦',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            if (_tabController.index == 0 && _trashedNotes.isNotEmpty)
              TextButton.icon(
                onPressed: _confirmPurgeAll,
                icon: const Icon(CupertinoIcons.trash_slash, size: 16, color: Colors.redAccent),
                label: const Text(
                  'تخلیه',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.redAccent),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: colors.primary,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            labelStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(text: 'سطل زباله (${PersianDigits.convert(_trashedNotes.length.toString())})'),
              Tab(text: 'بایگانی (${PersianDigits.convert(_archivedNotes.length.toString())})'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Trashed Notes
                  _buildList(
                    items: _trashedNotes,
                    emptyText: 'سطل زباله خالی است 🌿',
                    isTrash: true,
                  ),

                  // Tab 2: Archived Notes
                  _buildList(
                    items: _archivedNotes,
                    emptyText: 'هیچ یادداشتی در بایگانی نیست 📦',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isTrash ? CupertinoIcons.trash : CupertinoIcons.archivebox, size: 48, color: colors.textTertiary),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (ctx, idx) {
          final note = items[idx];
          final style = NoteUiHelper.getKindStyle(context, note.kind);

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: style.bgTint,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                      Text(
                        _formatDate(note.trashedAt ?? note.updatedAt),
                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: colors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isTrash) ...[
                        TextButton.icon(
                          onPressed: () async {
                            RitmoHaptics.selection();
                            await NotesRepository.instance.restore(note.id);
                            RitmoToast.show(context, 'یادداشت بازیابی شد 🔄');
                            _loadData();
                          },
                          icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                          label: const Text('بازیابی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmPermanentDelete(note),
                          icon: const Icon(CupertinoIcons.delete, size: 14, color: Colors.redAccent),
                          label: const Text('حذف قطعی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.redAccent)),
                        ),
                      ] else ...[
                        TextButton.icon(
                          onPressed: () async {
                            RitmoHaptics.selection();
                            await NotesRepository.instance.unarchive(note.id);
                            RitmoToast.show(context, 'از بایگانی خارج شد 📤');
                            _loadData();
                          },
                          icon: const Icon(CupertinoIcons.arrow_up_doc, size: 14),
                          label: const Text('خروج از بایگانی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            RitmoHaptics.selection();
                            await NotesRepository.instance.delete(note.id);
                            RitmoToast.show(context, 'به سطل زباله منتقل شد 🗑️');
                            _loadData();
                          },
                          icon: const Icon(CupertinoIcons.trash, size: 14, color: Colors.redAccent),
                          label: const Text('انتقال به زباله‌دان', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.redAccent)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
