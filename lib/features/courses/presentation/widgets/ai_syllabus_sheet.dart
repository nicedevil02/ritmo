import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

class AiSyllabusSheet extends StatefulWidget {
  const AiSyllabusSheet({
    super.key,
    required this.onImported,
  });

  final VoidCallback onImported;

  @override
  State<AiSyllabusSheet> createState() => _AiSyllabusSheetState();
}

class _AiSyllabusSheetState extends State<AiSyllabusSheet> {
  final _titleController = TextEditingController(text: 'دوره جدید با سرفصل AI');
  final _inputController = TextEditingController();

  List<CourseSession> _draftSessions = [];
  bool _isParsed = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _parseSyllabusText() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      RitmoToast.show(context, 'لطفاً متن سرفصل یا JSON را وارد کنید.', iconColor: Colors.amber);
      return;
    }

    final drafts = <CourseSession>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      // Try parsing as JSON array
      final decoded = jsonDecode(text);
      if (decoded is List) {
        for (var i = 0; i < decoded.length; i++) {
          final item = decoded[i];
          // Support the two most common AI outputs: a list of plain strings
          // (["جلسه ۱: ..."]) and a list of objects ([{"title": ...}]).
          if (item is String) {
            final t = item.trim();
            if (t.isNotEmpty) {
              drafts.add(CourseSession(
                id: 'draft_$i',
                courseId: '',
                sessionNumber: i + 1,
                sessionTitle: t,
                estimatedDurationMinutes: 45,
                createdAt: nowMs,
                updatedAt: nowMs,
              ));
            }
            continue;
          }
          if (item is Map) {
            drafts.add(CourseSession(
              id: 'draft_$i',
              courseId: '',
              sessionNumber: i + 1,
              sessionTitle: item['title']?.toString() ?? 'جلسه ${i + 1}',
              sectionTitle: item['section']?.toString(),
              learningObjective: item['objective']?.toString(),
              estimatedDurationMinutes: int.tryParse(item['duration']?.toString() ?? '45') ?? 45,
              difficulty: int.tryParse(item['difficulty']?.toString() ?? '3') ?? 3,
              createdAt: nowMs,
              updatedAt: nowMs,
            ));
          }
        }
      }
    } catch (_) {
      // Fallback line-by-line parsing
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (var i = 0; i < lines.length; i++) {
        drafts.add(CourseSession(
          id: 'draft_$i',
          courseId: '',
          sessionNumber: i + 1,
          sessionTitle: lines[i].trim(),
          estimatedDurationMinutes: 45,
          createdAt: nowMs,
          updatedAt: nowMs,
        ));
      }
    }

    if (drafts.isEmpty) {
      RitmoToast.show(context, 'امکان استخراج سرفصل از متن وارد شده وجود نداشت.', iconColor: Colors.amber);
      return;
    }

    setState(() {
      _draftSessions = drafts;
      _isParsed = true;
    });
  }

  Future<void> _saveCourseAndSessions() async {
    if (_draftSessions.isEmpty || _isSaving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      RitmoToast.show(context, 'عنوان دوره را وارد کنید.', iconColor: Colors.amber);
      return;
    }

    setState(() => _isSaving = true);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final course = Course(
        id: 'course_${nowMs}_${title.hashCode}',
        title: title,
        totalSessions: _draftSessions.length,
        sessionDurationMinutes: 45,
        courseType: CourseType.video,
        preferredDays: const [6, 1, 3],
        createdAt: nowMs,
        updatedAt: nowMs,
      );

      await CoursesRepository.instance.createCourseWithSessions(course, _draftSessions);

      widget.onImported();
      if (mounted) {
        RitmoToast.show(context, 'دوره "$title" با ${_draftSessions.length} جلسه ثبت شد! 🎉', iconColor: Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving AI syllabus: $e');
      if (mounted) {
        RitmoToast.show(
          context,
          'خطا در ذخیره دوره. لطفاً دوباره تلاش کنید.',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Canonical Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Leading (Right in RTL): Circular Tactile Close (X) Button
                GestureDetector(
                  onTap: () {
                    RitmoHapticsPolicy.tap();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceElevated.withValues(alpha: 0.85)
                          : colors.textPrimary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? colors.border.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.15),
                        width: 0.85,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                // Center: Title
                Text(
                  'ایجاد دوره با سرفصل هوشمند',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),

                // Trailing (Left in RTL): Symmetrical Spacer
                const SizedBox(width: 34, height: 34),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 8),

            if (!_isParsed) ...[
              TextField(
                controller: _titleController,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'عنوان دوره آموزشی',
                  labelStyle: TextStyle(color: colors.textSecondary, fontSize: 11),
                  fillColor: colors.surfaceSunken,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'متن سرفصل، فهرست عناوین، یا فرمت JSON تولیدشده توسط AI را اینجا پیست کنید...\nمثال:\nجلسه ۱: مقدمه و نصب فلاتر\nجلسه ۲: متغیرها و انواع داده\nجلسه ۳: ساخت اولین ویجت',
                    hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 11.5),
                    fillColor: colors.surfaceSunken,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _parseSyllabusText,
                icon: const Icon(CupertinoIcons.sparkles, size: 18),
                label: Text('استخراج سرفصل‌ها و پیش‌نمایش', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.onPrimary)),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'پیش‌نمایش ${_draftSessions.length} جلسه استخراج‌شده:',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isParsed = false),
                    child: Text('ویرایش متن ورودی', style: TextStyle(fontSize: 12, color: colors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _draftSessions.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _draftSessions.removeAt(oldIndex);
                      _draftSessions.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final session = _draftSessions[index];
                    return Container(
                      key: ValueKey(session.id),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text('${index + 1}. ', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              session.sessionTitle ?? 'جلسه ${index + 1}',
                              style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: Icon(CupertinoIcons.trash, color: colors.error, size: 18),
                            onPressed: () {
                              setState(() {
                                _draftSessions.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.success,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _saveCourseAndSessions,
                child: _isSaving
                    ? CupertinoActivityIndicator(color: colors.onPrimary)
                    : Text('تأیید و ساخت دوره آموزشی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.onPrimary)),
              ),
            ],
          ],
        ),
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
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
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
    );
  }
}
