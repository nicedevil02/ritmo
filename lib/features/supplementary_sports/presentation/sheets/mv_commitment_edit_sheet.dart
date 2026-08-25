import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import 'mv_kind_picker_sheet.dart';

/// Action Sheet: ساخت و ویرایش لنگر / تعهد هفتگی (S8-T2).
class MvCommitmentEditSheet extends StatefulWidget {
  final MvCommitment? commitment;
  final MvKindUseCase? kindUseCase;
  final Future<void> Function(MvCommitment commitment)? onSave;
  final Future<void> Function(int id)? onDelete;

  const MvCommitmentEditSheet({
    super.key,
    this.commitment,
    this.kindUseCase,
    this.onSave,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    MvCommitment? commitment,
    MvKindUseCase? kindUseCase,
    Future<void> Function(MvCommitment commitment)? onSave,
    Future<void> Function(int id)? onDelete,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvCommitmentEditSheet(
        commitment: commitment,
        kindUseCase: kindUseCase,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<MvCommitmentEditSheet> createState() => _MvCommitmentEditSheetState();
}

class _MvCommitmentEditSheetState extends State<MvCommitmentEditSheet> {
  late final MvKindUseCase _kindUseCase;
  late final TextEditingController _titleController;
  late final TextEditingController _venueController;

  MvMovementKind? _selectedKind;
  late int _selectedDaySat0;
  late TimeOfDay _selectedTime;
  late int _selectedDurationMinutes;
  late CommitmentRecurrence _selectedRecurrence;
  late int _selectedReminderMinutes;
  bool _isLoadingKinds = true;

  static const List<int> _durations = [30, 45, 60, 90, 120];
  static const List<int> _reminders = [0, 30, 120, 1440];

  @override
  void initState() {
    super.initState();
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();

    final c = widget.commitment;
    _selectedDaySat0 = c?.dayOfWeekSat0 ?? 0;
    _selectedDurationMinutes = c?.durationMinutes ?? 60;
    _selectedRecurrence = c?.recurrence ?? CommitmentRecurrence.weekly;
    _selectedReminderMinutes = 120;

    if (c != null && c.startTime.contains(':')) {
      final parts = c.startTime.split(':');
      _selectedTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 18,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    } else {
      _selectedTime = const TimeOfDay(hour: 18, minute: 0);
    }

    _titleController = TextEditingController(text: c?.titleFa ?? '');
    _venueController = TextEditingController(text: c?.venueNote ?? '');

    _loadInitialKind();
  }

  Future<void> _loadInitialKind() async {
    final kindCode = widget.commitment?.kindCode ?? MvKindCodes.walking;
    final allKinds = await _kindUseCase.getAllKinds();
    if (!mounted) return;

    setState(() {
      if (allKinds.isNotEmpty) {
        _selectedKind = allKinds.firstWhere(
          (k) => k.code == kindCode,
          orElse: () => allKinds.first,
        );
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = _selectedKind!.titleFa;
        }
      }
      _isLoadingKinds = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _dayLabel(int sat0) {
    switch (sat0) {
      case 0:
        return 'شنبه';
      case 1:
        return '۱شنبه';
      case 2:
        return '۲شنبه';
      case 3:
        return '۳شنبه';
      case 4:
        return '۴شنبه';
      case 5:
        return '۵شنبه';
      case 6:
        return 'جمعه';
      default:
        return '';
    }
  }

  String _recurrenceLabel(CommitmentRecurrence r) {
    switch (r) {
      case CommitmentRecurrence.weekly:
        return 'هفتگی';
      case CommitmentRecurrence.biweekly:
        return 'دوهفته‌یک‌بار';
      case CommitmentRecurrence.once:
        return 'یک‌بار';
    }
  }

  String _reminderLabel(int minutes) {
    switch (minutes) {
      case 0:
        return 'بدون';
      case 30:
        return '۳۰ دقیقه';
      case 120:
        return '۲ ساعت';
      case 1440:
        return '۱ روز';
      default:
        return '$minutes دقیقه';
    }
  }

  Future<void> _pickKind() async {
    final chosen = await MvKindPickerSheet.show(
      context: context,
      useCase: _kindUseCase,
      initialCode: _selectedKind?.code,
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedKind = chosen;
        if (_titleController.text.trim().isEmpty ||
            _titleController.text == _selectedKind?.titleFa) {
          _titleController.text = chosen.titleFa;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    final kindCode = _selectedKind?.code ?? MvKindCodes.walking;
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_selectedKind?.titleFa ?? 'ورزش');

    final c = MvCommitment(
      id: widget.commitment?.id,
      kindCode: kindCode,
      titleFa: title,
      dayOfWeekSat0: _selectedDaySat0,
      startTime: _formatTimeOfDay(_selectedTime),
      durationMinutes: _selectedDurationMinutes,
      recurrence: _selectedRecurrence,
      venueNote: _venueController.text.trim().isNotEmpty
          ? _venueController.text.trim()
          : null,
      isActive: widget.commitment?.isActive ?? true,
      isFlexible: false,
      startDateIso: widget.commitment?.startDateIso ??
          MvCalendar.formatDateIso(DateTime.now()),
    );

    if (widget.onSave != null) {
      await widget.onSave!(c);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleDelete() async {
    final id = widget.commitment?.id;
    if (id != null && widget.onDelete != null) {
      await widget.onDelete!(id);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final isEdit = widget.commitment != null;

    final title = isEdit ? l10n.mv_commitment_edit : l10n.mv_commitment_add;

    return MvSheetScaffold(
      title: title,
      body: _isLoadingKinds
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.spaceMd,
                vertical: metrics.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. نوع ورزش (تراشه + دکمه بیشتر)
                  Text(
                    l10n.mv_library_tab_kinds,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Row(
                    children: [
                      if (_selectedKind != null)
                        MvChip(
                          label: '${_selectedKind!.emoji} ${_selectedKind!.titleFa}',
                          isSelected: true,
                          onTap: _pickKind,
                        ),
                      SizedBox(width: metrics.spaceSm),
                      MvChip(
                        key: const ValueKey('mv_commitment_pick_kind'),
                        label: 'بیشتر...',
                        isSelected: false,
                        onTap: _pickKind,
                      ),
                    ],
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 2. عنوان (TextField)
                  TextField(
                    key: const ValueKey('mv_commitment_title_field'),
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: l10n.mv_custom_kind_name,
                      filled: true,
                      fillColor: colors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(metrics.radiusField),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: textTheme.bodyLarge,
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 3. روز هفته (۷ تراشه شنبه=۰)
                  Text(
                    l10n.mv_commitment_day_label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Wrap(
                    spacing: metrics.spaceXs,
                    runSpacing: metrics.spaceXs,
                    children: List.generate(7, (sat0) {
                      final selected = _selectedDaySat0 == sat0;
                      return MvChip(
                        key: ValueKey('mv_day_chip_$sat0'),
                        label: _dayLabel(sat0),
                        isSelected: selected,
                        onTap: () {
                          setState(() => _selectedDaySat0 = sat0);
                        },
                      );
                    }),
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 4. ساعت شروع (TimePicker)
                  Text(
                    l10n.mv_commitment_time_label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  InkWell(
                    key: const ValueKey('mv_commitment_time_picker_btn'),
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceMd,
                        vertical: metrics.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(metrics.radiusField),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: metrics.iconSm,
                            color: colors.accent,
                          ),
                          SizedBox(width: metrics.spaceSm),
                          Text(
                            _formatTimeOfDay(_selectedTime),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 5. مدت (دقیقه) (۳۰/۴۵/۶۰/۹۰/۱۲۰)
                  Text(
                    l10n.mv_commitment_duration_label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Wrap(
                    spacing: metrics.spaceXs,
                    runSpacing: metrics.spaceXs,
                    children: _durations.map((d) {
                      final selected = _selectedDurationMinutes == d;
                      return MvChip(
                        key: ValueKey('mv_duration_chip_$d'),
                        label: '$d دقیقه',
                        isSelected: selected,
                        onTap: () {
                          setState(() => _selectedDurationMinutes = d);
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 6. تکرار (هفتگی / دوهفته‌یک‌بار / یک‌بار)
                  Text(
                    l10n.mv_commitment_recurrence_label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Wrap(
                    spacing: metrics.spaceXs,
                    runSpacing: metrics.spaceXs,
                    children: CommitmentRecurrence.values.map((r) {
                      final selected = _selectedRecurrence == r;
                      return MvChip(
                        key: ValueKey('mv_recurrence_chip_${r.name}'),
                        label: _recurrenceLabel(r),
                        isSelected: selected,
                        onTap: () {
                          setState(() => _selectedRecurrence = r);
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 7. محل تمرین (TextField)
                  TextField(
                    key: const ValueKey('mv_commitment_venue_field'),
                    controller: _venueController,
                    decoration: InputDecoration(
                      labelText: l10n.mv_commitment_venue_label,
                      filled: true,
                      fillColor: colors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(metrics.radiusField),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: textTheme.bodyLarge,
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 8. یادآوری (بدون / ۳۰ دقیقه / ۲ ساعت / ۱ روز)
                  Text(
                    l10n.mv_commitment_reminder_label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Wrap(
                    spacing: metrics.spaceXs,
                    runSpacing: metrics.spaceXs,
                    children: _reminders.map((rem) {
                      final selected = _selectedReminderMinutes == rem;
                      return MvChip(
                        key: ValueKey('mv_reminder_chip_$rem'),
                        label: _reminderLabel(rem),
                        isSelected: selected,
                        onTap: () {
                          setState(() => _selectedReminderMinutes = rem);
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: metrics.spaceLg),
                ],
              ),
            ),
      bottomAction: Row(
        children: [
          if (isEdit) ...[
            IconButton(
              key: const ValueKey('mv_commitment_delete_btn'),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colors.error,
                size: metrics.iconMd,
              ),
              tooltip: l10n.mv_commitment_delete,
              onPressed: _handleDelete,
            ),
            SizedBox(width: metrics.spaceSm),
          ],
          Expanded(
            child: ElevatedButton(
              key: const ValueKey('mv_commitment_save_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: metrics.spaceMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(metrics.radiusCard),
                ),
              ),
              onPressed: _handleSave,
              child: Text(
                'ذخیره',
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
