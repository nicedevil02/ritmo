import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class BloodSugarSection extends StatefulWidget {
  const BloodSugarSection({
    super.key,
  });

  @override
  State<BloodSugarSection> createState() => _BloodSugarSectionState();
}

class _BloodSugarSectionState extends State<BloodSugarSection> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();

  List<BloodSugarLog> _logs = [];
  bool _isDiabetic = false;
  bool _isLoading = true;
  String _measurementType = 'FASTING';

  // Interactive filters
  String _selectedCategoryFilter = 'ALL'; // 'ALL' | 'FASTING' | 'AFTER_MEAL' | 'BEFORE_MEAL' | 'BEDTIME' | 'RANDOM'
  String _selectedTimeRange = '7D'; // '7D' | '14D' | '30D' | 'ALL'
  BloodSugarLog? _selectedLog;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  String _normalizeDigits(String input) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '٧', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var result = input;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], english[i]).replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  String _getMeasurementLabel(String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'FASTING':
        return l10n.bloodSugarFasting;
      case 'BEFORE_MEAL':
        return l10n.bloodSugarBeforeMeal;
      case 'AFTER_MEAL':
        return l10n.bloodSugarAfterMeal;
      case 'BEDTIME':
        return l10n.bloodSugarBedtime;
      case 'RANDOM':
      default:
        return l10n.bloodSugarRandom;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      // Load diabetes flag
      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key']! as String: s['value']! as String};
      final hasDiabetes = settingsMap['patient_has_diabetes'] == 'true';

      // Load blood sugar logs
      final results = await db.query('blood_sugar_logs', orderBy: 'loggedAt DESC', limit: 200);
      final logsList = results.map(BloodSugarLog.fromMap).toList();

      if (mounted) {
        setState(() {
          _isDiabetic = hasDiabetes;
          _logs = logsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blood sugar: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDiabetic(bool val) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'app_settings',
        {
          'key': 'patient_has_diabetes',
          'value': val.toString(),
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      setState(() {
        _isDiabetic = val;
      });
    } catch (e) {
      debugPrint('Error updating diabetes setting: $e');
    }
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    final normValStr = _normalizeDigits(_valueController.text.trim());
    final value = int.tryParse(normValStr);
    if (value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final log = BloodSugarLog(
      id: 'bs_$now',
      value: value,
      measurementType: _measurementType,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      loggedAt: now,
    );

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('blood_sugar_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      _valueController.clear();
      _noteController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();

      await _loadData();
    } catch (e) {
      debugPrint('Error saving blood sugar log: $e');
    }
  }

  Future<void> _deleteLog(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('blood_sugar_logs', where: 'id = ?', whereArgs: [id]);
      if (_selectedLog?.id == id) {
        setState(() {
          _selectedLog = null;
        });
      }
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting blood sugar log: $e');
    }
  }

  List<BloodSugarLog> _getFilteredLogs() {
    final now = DateTime.now().millisecondsSinceEpoch;
    var filtered = List<BloodSugarLog>.from(_logs);

    // Apply Time Range Filter
    if (_selectedTimeRange == '7D') {
      final cutoff = now - (7 * 24 * 60 * 60 * 1000);
      filtered = filtered.where((l) => l.loggedAt >= cutoff).toList();
    } else if (_selectedTimeRange == '14D') {
      final cutoff = now - (14 * 24 * 60 * 60 * 1000);
      filtered = filtered.where((l) => l.loggedAt >= cutoff).toList();
    } else if (_selectedTimeRange == '30D') {
      final cutoff = now - (30 * 24 * 60 * 60 * 1000);
      filtered = filtered.where((l) => l.loggedAt >= cutoff).toList();
    }

    // Apply Category Filter
    if (_selectedCategoryFilter != 'ALL') {
      filtered = filtered.where((l) => l.measurementType == _selectedCategoryFilter).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final filteredLogs = _getFilteredLogs();
    final stats = BloodSugarStats.compute(filteredLogs, isDiabetic: _isDiabetic);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Time Range Selector ───
            _buildTimeRangeSelector(),
            const SizedBox(height: 8),

            // ─── Category Filter Chips ───
            _buildCategoryFilterChips(),
            const SizedBox(height: 12),

            // ─── Multi-Line Chart ───
            if (filteredLogs.isNotEmpty) ...[
              _buildChartCard(filteredLogs),
              const SizedBox(height: 10),
            ] else ...[
              _buildEmptyChartCard(),
              const SizedBox(height: 10),
            ],

            // ─── Selected Point Details (Floating Card) ───
            if (_selectedLog != null) ...[
              _buildSelectedPointCard(_selectedLog!),
              const SizedBox(height: 12),
            ],

            // ─── Clinical Statistics & Time-In-Range Card ───
            if (stats != null) ...[
              _buildClinicalStatsCard(stats),
              const SizedBox(height: 16),
            ],

            // ─── Fast Add Log Card ───
            _buildAddLogCard(l10n),
            const SizedBox(height: 16),

            // ─── History List ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.bloodSugarHistory,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (filteredLogs.isNotEmpty)
                  Text(
                    '${_toPersianDigits(filteredLogs.length.toString())} سنجش',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              Center(child: CircularProgressIndicator(color: colors.primary))
            else
              _buildHistoryList(filteredLogs),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final colors = context.colors;
    final ranges = [
      {'id': '7D', 'label': '۷ روز'},
      {'id': '14D', 'label': '۱۴ روز'},
      {'id': '30D', 'label': '۳۰ روز'},
      {'id': 'ALL', 'label': 'همه سوابق'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((r) {
          final isSelected = _selectedTimeRange == r['id'];
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(
                r['label']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: colors.primary.withValues(alpha: 0.15),
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.5),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedTimeRange = r['id']!;
                    _selectedLog = null;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    final colors = context.colors;
    final categories = [
      {'id': 'ALL', 'label': 'همه (چندخطی)', 'color': colors.primary},
      {'id': 'FASTING', 'label': 'ناشتا', 'color': const Color(0xFF06B6D4)},
      {'id': 'AFTER_MEAL', 'label': 'بعد غذا', 'color': const Color(0xFFF59E0B)},
      {'id': 'BEFORE_MEAL', 'label': 'قبل غذا', 'color': const Color(0xFF6366F1)},
      {'id': 'BEDTIME', 'label': 'قبل خواب', 'color': const Color(0xFF8B5CF6)},
      {'id': 'RANDOM', 'label': 'تصادفی', 'color': const Color(0xFFEC4899)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final id = cat['id'] as String;
          final label = cat['label'] as String;
          final chipColor = cat['color'] as Color;
          final isSelected = _selectedCategoryFilter == id;

          // Count logs for this category
          final count = id == 'ALL'
              ? _logs.length
              : _logs.where((l) => l.measurementType == id).length;

          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              avatar: id == 'ALL'
                  ? null
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: chipColor,
                        shape: BoxShape.circle,
                      ),
                    ),
              label: Text(
                count > 0 ? '$label (${_toPersianDigits(count.toString())})' : label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? chipColor : colors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: chipColor.withValues(alpha: 0.15),
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? chipColor : colors.border.withValues(alpha: 0.5),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryFilter = id;
                  _selectedLog = null;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDiabetesStatusChip(RitmoColors colors) {
    return Tooltip(
      message: 'تغییر وضعیت دیابت و محدوده‌های هدف بالینی',
      child: InkWell(
        onTap: () {
          RitmoHaptics.selection();
          _toggleDiabetic(!_isDiabetic);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _isDiabetic ? colors.warning.withValues(alpha: 0.15) : colors.textPrimary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isDiabetic ? colors.warning.withValues(alpha: 0.5) : colors.textPrimary.withValues(alpha: 0.1),
              width: _isDiabetic ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isDiabetic ? '🩸' : '🩺',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 5),
              Text(
                _isDiabetic ? 'مبتلا به دیابت' : 'غیردیابتی',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _isDiabetic ? FontWeight.bold : FontWeight.w600,
                  color: _isDiabetic ? colors.warning : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(List<BloodSugarLog> logs) {
    final colors = context.colors;
    final chartLogs = logs.reversed.toList(); // Chronological (oldest to newest)

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.chart_bar_alt_fill, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'روند نوسانات قند خون',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                ],
              ),
              _buildDiabetesStatusChip(colors),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) {
                    final touched = _findTouchedPoint(details.localPosition, constraints.biggest, chartLogs);
                    setState(() {
                      _selectedLog = touched;
                    });
                  },
                  child: CustomPaint(
                    size: constraints.biggest,
                    painter: _BloodSugarMultiLineChartPainter(
                      logs: chartLogs,
                      isDiabetic: _isDiabetic,
                      selectedCategory: _selectedCategoryFilter,
                      selectedLogId: _selectedLog?.id,
                      colors: colors,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  BloodSugarLog? _findTouchedPoint(Offset localPos, Size size, List<BloodSugarLog> logs) {
    if (logs.isEmpty) return null;

    const paddingLeft = 35.0;
    const paddingRight = 15.0;
    const paddingTop = 20.0;
    const paddingBottom = 25.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    int minVal = logs.first.value;
    int maxVal = logs.first.value;
    for (final l in logs) {
      if (l.value < minVal) minVal = l.value;
      if (l.value > maxVal) maxVal = l.value;
    }

    final double yMin = math.min(40.0, (minVal - 15.0).toDouble());
    final double yMax = math.max(240.0, (maxVal + 25.0).toDouble());

    double getY(double val) {
      var pct = (val - yMin) / (yMax - yMin);
      pct = pct.clamp(0.0, 1.0);
      return size.height - paddingBottom - (pct * chartHeight);
    }

    double getX(int index, int total) {
      if (total <= 1) return paddingLeft + chartWidth / 2;
      return paddingLeft + (index * (chartWidth / (total - 1)));
    }

    BloodSugarLog? closestLog;
    double minDistance = 32.0; // Touch threshold in pixels

    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final pt = Offset(getX(i, logs.length), getY(log.value.toDouble()));
      final dist = (localPos - pt).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestLog = log;
      }
    }

    return closestLog;
  }

  Widget _buildEmptyChartCard() {
    final colors = context.colors;
    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.chart_bar_alt_fill, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'روند نوسانات قند خون',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                ],
              ),
              _buildDiabetesStatusChip(colors),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.chart_bar, size: 32, color: colors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'داده‌ای برای بازه یا دسته انتخابی یافت نشد',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPointCard(BloodSugarLog log) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final status = log.getStatus(_isDiabetic);
    final range = BloodSugarTargetRange.forCategory(log.measurementType, isDiabetic: _isDiabetic);

    Color badgeColor;
    String statusText;
    switch (status) {
      case 'LOW':
        badgeColor = colors.medicalRed;
        statusText = l10n.bloodSugarLow;
      case 'HIGH':
        badgeColor = colors.warning;
        statusText = l10n.bloodSugarHigh;
      case 'NORMAL':
      default:
        badgeColor = colors.success;
        statusText = l10n.bloodSugarInRange;
    }

    final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(log.loggedAt));
    final dt = DateTime.fromMillisecondsSinceEpoch(log.loggedAt);
    final dateStr = _toPersianDigits('${jalali.year}/${jalali.month}/${jalali.day}');
    final timeStr = _toPersianDigits('${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}');

    return RitmoCard.neumorphic(
      borderColor: log.categoryColor.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: log.categoryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              _toPersianDigits(log.value.toString()),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: log.categoryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _getMeasurementLabel(log.measurementType),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    RitmoCardBadge(
                      label: statusText,
                      color: badgeColor,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr ساعت $timeStr · هدف: ${_toPersianDigits(range.min.toString())}-${_toPersianDigits(range.max.toString())}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                if (log.note != null && log.note!.isNotEmpty)
                  Text(
                    log.note!,
                    style: TextStyle(fontSize: 11, color: colors.textPrimary, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(CupertinoIcons.xmark, size: 16, color: colors.textSecondary),
            onPressed: () {
              setState(() {
                _selectedLog = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalStatsCard(BloodSugarStats stats) {
    final colors = context.colors;

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RitmoCardHeader(
            title: 'تحلیل و وضعیت بالینی (TIR)',
            icon: CupertinoIcons.waveform_path_ecg,
            iconColor: colors.primary,
            trailing: stats.estimatedHbA1c != null
                ? RitmoCardBadge(
                    label: 'تخمین HbA1c: ${_toPersianDigits(stats.estimatedHbA1c!.toStringAsFixed(1))}٪',
                    color: colors.primary,
                  )
                : null,
          ),
          const RitmoCardDivider(),

          // Time in Range Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (stats.lowPercentage > 0)
                    Expanded(
                      flex: (stats.lowPercentage * 10).toInt(),
                      child: Container(color: colors.medicalRed),
                    ),
                  if (stats.inRangePercentage > 0)
                    Expanded(
                      flex: (stats.inRangePercentage * 10).toInt(),
                      child: Container(color: colors.success),
                    ),
                  if (stats.highPercentage > 0)
                    Expanded(
                      flex: (stats.highPercentage * 10).toInt(),
                      child: Container(color: colors.warning),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // TIR Legends
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(
                label: 'در محدوده هدف',
                val: '${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(0))}٪',
                color: colors.success,
              ),
              _buildStatMetric(
                label: 'بالاتر از هدف',
                val: '${_toPersianDigits(stats.highPercentage.toStringAsFixed(0))}٪',
                color: colors.warning,
              ),
              _buildStatMetric(
                label: 'افت قند خون',
                val: '${_toPersianDigits(stats.lowPercentage.toStringAsFixed(0))}٪',
                color: colors.medicalRed,
              ),
              _buildStatMetric(
                label: 'میانگین کل',
                val: _toPersianDigits(stats.averageGlucose.toStringAsFixed(0)),
                color: colors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({required String label, required String val, required Color color}) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildAddLogCard(AppLocalizations l10n) {
    final colors = context.colors;

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'ثبت قند خون جدید',
            icon: CupertinoIcons.pencil_ellipsis_rectangle,
            iconColor: colors.primary,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: RitmoTheme.inputDecoration(
                    context,
                    label: l10n.bloodSugarValue,
                    icon: CupertinoIcons.speedometer,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return l10n.bloodSugarEnterValue;
                    }
                    if (int.tryParse(_normalizeDigits(val.trim())) == null) {
                      return 'لطفاً یک عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _measurementType,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: RitmoTheme.inputDecoration(
                    context,
                    label: l10n.bloodSugarTitle,
                    icon: CupertinoIcons.tag,
                  ),
                  dropdownColor: colors.card,
                  items: [
                    DropdownMenuItem(
                      value: 'FASTING',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.sun_max, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(l10n.bloodSugarFasting),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'AFTER_MEAL',
                      child: Row(
                        children: [
                          Icon(Icons.restaurant, size: 16, color: colors.warning),
                          const SizedBox(width: 6),
                          Text(l10n.bloodSugarAfterMeal),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'BEFORE_MEAL',
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu, size: 16, color: colors.accent),
                          const SizedBox(width: 6),
                          Text(l10n.bloodSugarBeforeMeal),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'BEDTIME',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.moon, size: 16, color: colors.accent),
                          const SizedBox(width: 6),
                          Text(l10n.bloodSugarBedtime),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'RANDOM',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.shuffle, size: 16, color: colors.medicalRed),
                          const SizedBox(width: 6),
                          Text(l10n.bloodSugarRandom),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _measurementType = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            style: TextStyle(color: colors.textPrimary),
            decoration: RitmoTheme.inputDecoration(
              context,
              label: 'یادداشت (اختیاری)',
              icon: Icons.note_alt_outlined,
            ),
          ),
          const SizedBox(height: 12),
          RitmoNeuButton(
            onTap: _saveLog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.checkmark_seal_fill, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.bloodSugarSave,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<BloodSugarLog> logs) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'سابقه سنجشی وجود ندارد.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final typeLabel = _getMeasurementLabel(log.measurementType);
        final status = log.getStatus(_isDiabetic);

        Color badgeColor;
        String statusText;
        switch (status) {
          case 'LOW':
            badgeColor = colors.medicalRed;
            statusText = l10n.bloodSugarLow;
          case 'HIGH':
            badgeColor = colors.warning;
            statusText = l10n.bloodSugarHigh;
          case 'NORMAL':
          default:
            badgeColor = colors.success;
            statusText = l10n.bloodSugarInRange;
        }

        final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(log.loggedAt));
        final dt = DateTime.fromMillisecondsSinceEpoch(log.loggedAt);
        final dateStr = _toPersianDigits('${jalali.year}/${jalali.month}/${jalali.day}');
        final timeStr = _toPersianDigits('${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}');

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RitmoCard.neumorphic(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: log.categoryColor.withValues(alpha: 0.15),
                          radius: 14,
                          child: Text(
                            _toPersianDigits(log.value.toString()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: log.categoryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          typeLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        RitmoCardBadge(
                          label: statusText,
                          color: badgeColor,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.trash, size: 16, color: colors.medicalRed),
                      onPressed: () => _confirmDelete(log.id),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$dateStr ساعت $timeStr',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                if (log.note != null && log.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.note!,
                    style: TextStyle(fontSize: 11, color: colors.textPrimary, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String id) async {
    final res = await RitmoGlassDialog.show(
      context,
      title: 'حذف سنجش',
      content: 'آیا مطمئن هستید که می‌خواهید این سنجش قند خون را حذف کنید؟',
      confirmLabel: 'حذف دائمی',
      cancelLabel: 'انصراف',
      isDestructive: true,
      icon: CupertinoIcons.trash_fill,
    );
    if (res == true) {
      await _deleteLog(id);
    }
  }
}

class _BloodSugarMultiLineChartPainter extends CustomPainter {
  _BloodSugarMultiLineChartPainter({
    required this.logs,
    required this.isDiabetic,
    required this.selectedCategory,
    this.selectedLogId,
    required this.colors,
  });

  final List<BloodSugarLog> logs; // Chronological order (oldest to newest)
  final bool isDiabetic;
  final String selectedCategory;
  final String? selectedLogId;
  final RitmoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    final textPainter = TextPainter(
      textDirection: TextDirection.rtl,
    );

    // Padding
    const paddingLeft = 35.0;
    const paddingRight = 15.0;
    const paddingTop = 20.0;
    const paddingBottom = 25.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    // ─── Dynamic Y-Axis Bounds ───
    int minVal = logs.first.value;
    int maxVal = logs.first.value;
    for (final l in logs) {
      if (l.value < minVal) minVal = l.value;
      if (l.value > maxVal) maxVal = l.value;
    }

    final double yMin = math.min(40.0, (minVal - 15.0).toDouble());
    final double yMax = math.max(240.0, (maxVal + 25.0).toDouble());

    double getY(double val) {
      var pct = (val - yMin) / (yMax - yMin);
      pct = pct.clamp(0.0, 1.0);
      return size.height - paddingBottom - (pct * chartHeight);
    }

    double getX(int index, int total) {
      if (total <= 1) return paddingLeft + chartWidth / 2;
      return paddingLeft + (index * (chartWidth / (total - 1)));
    }

    // ─── 1. Target Range Band ───
    final targetRange = selectedCategory != 'ALL'
        ? BloodSugarTargetRange.forCategory(selectedCategory, isDiabetic: isDiabetic)
        : (isDiabetic
            ? const BloodSugarTargetRange(min: 80, max: 130)
            : const BloodSugarTargetRange(min: 70, max: 110));

    final targetTop = getY(targetRange.max.toDouble());
    final targetBottom = getY(targetRange.min.toDouble());

    final rangePaint = Paint()
      ..color = colors.success.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(paddingLeft, targetTop, size.width - paddingRight, targetBottom),
      rangePaint,
    );

    // Reference lines for target limits
    final refLinePaint = Paint()
      ..color = colors.success.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(paddingLeft, targetTop), Offset(size.width - paddingRight, targetTop), refLinePaint);
    canvas.drawLine(Offset(paddingLeft, targetBottom), Offset(size.width - paddingRight, targetBottom), refLinePaint);

    // Target range text labels
    textPainter.text = TextSpan(
      text: _toPersianDigits(targetRange.max.toString()),
      style: TextStyle(color: colors.success.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 4, targetTop - textPainter.height / 2));

    textPainter.text = TextSpan(
      text: _toPersianDigits(targetRange.min.toString()),
      style: TextStyle(color: colors.success.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 4, targetBottom - textPainter.height / 2));

    // ─── 2. Horizontal Grid Lines ───
    final gridPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final gridSteps = [50, 100, 150, 200, 250, 300];
    for (final val in gridSteps) {
      if (val < yMin || val > yMax) continue;
      if ((val - targetRange.min).abs() < 8 || (val - targetRange.max).abs() < 8) continue;

      final y = getY(val.toDouble());
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      textPainter.text = TextSpan(
        text: _toPersianDigits(val.toString()),
        style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 4, y - textPainter.height / 2));
    }

    // ─── 3. Group Logs By Category & Draw Multi-Lines ───
    final categories = ['FASTING', 'AFTER_MEAL', 'BEFORE_MEAL', 'BEDTIME', 'RANDOM'];

    for (final cat in categories) {
      if (selectedCategory != 'ALL' && selectedCategory != cat) continue;

      final catIndices = <int>[];
      for (var i = 0; i < logs.length; i++) {
        if (logs[i].measurementType == cat) {
          catIndices.add(i);
        }
      }

      if (catIndices.isEmpty) continue;

      final catColor = logs[catIndices.first].categoryColor;
      final linePaint = Paint()
        ..color = catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (selectedCategory == cat) ? 3.0 : 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (catIndices.length >= 2) {
        final path = Path();
        for (var k = 0; k < catIndices.length; k++) {
          final idx = catIndices[k];
          final x = getX(idx, logs.length);
          final y = getY(logs[idx].value.toDouble());
          if (k == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, linePaint);

        // Fill area gradient for single selected category
        if (selectedCategory == cat) {
          final fillPath = Path.from(path)
            ..lineTo(getX(catIndices.last, logs.length), size.height - paddingBottom)
            ..lineTo(getX(catIndices.first, logs.length), size.height - paddingBottom)
            ..close();

          final fillPaint = Paint()
            ..color = catColor.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill;
          canvas.drawPath(fillPath, fillPaint);
        }
      }
    }

    // ─── 4. Detect Same Day for Smart X-Axis Formatting ───
    bool isSameDay = true;
    if (logs.length > 1) {
      final firstJalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(logs.first.loggedAt));
      for (var i = 1; i < logs.length; i++) {
        final j = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(logs[i].loggedAt));
        if (j.year != firstJalali.year || j.month != firstJalali.month || j.day != firstJalali.day) {
          isSameDay = false;
          break;
        }
      }
    }

    // ─── 5. Draw Points, Value Badges, and X-Axis Labels ───
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      if (selectedCategory != 'ALL' && selectedCategory != log.measurementType) continue;

      final pt = Offset(getX(i, logs.length), getY(log.value.toDouble()));
      final isSelected = log.id == selectedLogId;

      // Point Halo for selected point
      if (isSelected) {
        canvas.drawCircle(
          pt,
          9,
          Paint()
            ..color = log.categoryColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      // Point shadow circle
      canvas.drawCircle(pt, 5.5, Paint()..color = colors.card);

      // Point inner circle
      canvas.drawCircle(
        pt,
        isSelected ? 5.0 : 4.0,
        Paint()..color = log.categoryColor,
      );

      // Value label text above dot
      textPainter.text = TextSpan(
        text: _toPersianDigits(log.value.toString()),
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: isSelected ? 11 : 9.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, pt.dy - 16));

      // X-Axis Label
      final dt = DateTime.fromMillisecondsSinceEpoch(log.loggedAt);
      final jalali = Jalali.fromDateTime(dt);

      String xLabel;
      if (isSameDay) {
        xLabel = _toPersianDigits(
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        );
      } else {
        xLabel = _toPersianDigits('${jalali.month}/${jalali.day}');
      }

      // Avoid X-axis label collision by checking stride if many points
      final shouldDrawXLabel = logs.length <= 8 || i == 0 || i == logs.length - 1 || i % (logs.length ~/ 6) == 0;
      if (shouldDrawXLabel) {
        textPainter.text = TextSpan(
          text: xLabel,
          style: TextStyle(
            color: colors.textSecondary.withValues(alpha: 0.8),
            fontSize: 8.5,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, size.height - paddingBottom + 4));
      }
    }
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _BloodSugarMultiLineChartPainter oldDelegate) {
    return oldDelegate.logs != logs ||
        oldDelegate.isDiabetic != isDiabetic ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.selectedLogId != selectedLogId ||
        oldDelegate.colors != colors;
  }
}

