import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class BloodPressureSection extends StatefulWidget {
  const BloodPressureSection({super.key});

  @override
  State<BloodPressureSection> createState() => _BloodPressureSectionState();
}

class _BloodPressureSectionState extends State<BloodPressureSection> {
  final _formKey = GlobalKey<FormState>();
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _pulseController = TextEditingController();
  final _noteController = TextEditingController();

  List<BloodPressureLog> _logs = [];
  bool _isLoading = true;

  String _arm = 'LEFT';
  String _position = 'SITTING';
  final Set<String> _selectedTags = {};

  // Interactive filters
  String _selectedTimeRange = '7D'; // '7D' | '14D' | '30D' | 'ALL'
  String _selectedStageFilter = 'ALL'; // 'ALL' | 'NORMAL' | 'ELEVATED' | 'STAGE_1' | 'STAGE_2' | 'CRISIS' | 'HYPOTENSION'
  BloodPressureLog? _selectedLog;

  final List<String> _quickTags = [
    '۵ دقیقه استراحت',
    'بعد مصرف دارو',
    'استرس / هیجان',
    'بعد فعالیت/ورزش',
    'بعد قهوه/چای',
    'ناشتا/صبحگاهی',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _sysController.addListener(() => setState(() {}));
    _diaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sysController.dispose();
    _diaController.dispose();
    _pulseController.dispose();
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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'blood_pressure_logs',
        orderBy: 'loggedAt DESC',
        limit: 200,
      );
      final logsList = results.map(BloodPressureLog.fromMap).toList();

      if (mounted) {
        setState(() {
          _logs = logsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blood pressure: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    final sysVal = int.tryParse(_normalizeDigits(_sysController.text.trim()));
    final diaVal = int.tryParse(_normalizeDigits(_diaController.text.trim()));
    final pulseVal = _pulseController.text.trim().isNotEmpty
        ? int.tryParse(_normalizeDigits(_pulseController.text.trim()))
        : null;

    if (sysVal == null || diaVal == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Combine custom note with tags
    final tagsString = _selectedTags.isNotEmpty ? _selectedTags.map((t) => '#$t').join(' ') : '';
    final customNote = _noteController.text.trim();
    final combinedNote = [tagsString, customNote].where((s) => s.isNotEmpty).join(' - ');

    final log = BloodPressureLog(
      id: 'bp_$now',
      systolic: sysVal,
      diastolic: diaVal,
      pulse: pulseVal,
      arm: _arm,
      position: _position,
      note: combinedNote.isEmpty ? null : combinedNote,
      loggedAt: now,
    );

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('blood_pressure_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      _sysController.clear();
      _diaController.clear();
      _pulseController.clear();
      _noteController.clear();
      _selectedTags.clear();

      if (!mounted) return;
      FocusScope.of(context).unfocus();

      RitmoToast.show(
        context,
        'سنجش فشار خون با موفقیت ثبت شد',
        icon: CupertinoIcons.checkmark_seal_fill,
        iconColor: context.colors.success,
      );

      await _loadData();
    } catch (e) {
      debugPrint('Error saving blood pressure log: $e');
    }
  }

  Future<void> _deleteLog(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('blood_pressure_logs', where: 'id = ?', whereArgs: [id]);
      if (_selectedLog?.id == id) {
        setState(() => _selectedLog = null);
      }
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting blood pressure log: $e');
    }
  }

  List<BloodPressureLog> _getFilteredLogs() {
    final now = DateTime.now().millisecondsSinceEpoch;
    var filtered = List<BloodPressureLog>.from(_logs);

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

    // Apply Stage Category Filter
    if (_selectedStageFilter != 'ALL') {
      filtered = filtered.where((l) => l.category.name.toUpperCase() == _selectedStageFilter).toList();
    }

    return filtered;
  }

  void _copyDoctorReport() {
    final filteredLogs = _getFilteredLogs();
    final stats = BloodPressureStats.compute(filteredLogs);

    if (stats == null) {
      RitmoToast.show(context, 'داده‌ای برای تهیه گزارش وجود ندارد');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 گزارش تخصصی پایش فشار خون - اپلیکیشن ریتمو');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔹 تعداد کل سنجش‌ها: ${_toPersianDigits(stats.totalCount.toString())} مورد (${_selectedTimeRange == 'ALL' ? 'کل دوره' : 'بازه $_selectedTimeRange'})');
    buffer.writeln('🔹 میانگین فشار خون: ${_toPersianDigits(stats.averageSystolic.toStringAsFixed(0))}/${_toPersianDigits(stats.averageDiastolic.toStringAsFixed(0))} mmHg');
    if (stats.averagePulse != null) {
      buffer.writeln('🔹 میانگین ضربان قلب: ${_toPersianDigits(stats.averagePulse!.toStringAsFixed(0))} bpm');
    }
    buffer.writeln('🔹 میانگین فشار شریانی (MAP): ${_toPersianDigits(stats.averageMAP.toStringAsFixed(1))} mmHg');
    buffer.writeln('🔹 فشار نبض (Pulse Pressure): ${_toPersianDigits(stats.averagePulsePressure.toStringAsFixed(0))} mmHg');
    buffer.writeln('🔹 درصد کنترل هدف (Control Rate): %${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(1))}');
    buffer.writeln('🔹 دامنه سیستول: ${_toPersianDigits(stats.minSystolic.toString())} تا ${_toPersianDigits(stats.maxSystolic.toString())} mmHg');
    buffer.writeln('🔹 دامنه دیاستول: ${_toPersianDigits(stats.minDiastolic.toString())} تا ${_toPersianDigits(stats.maxDiastolic.toString())} mmHg');
    buffer.writeln('🔹 نوسان‌پذیری سیستولیک (SD): ${_toPersianDigits(stats.systolicVariabilitySD.toStringAsFixed(1))} mmHg');

    if (stats.morningSurgeDetected) {
      buffer.writeln('⚠️ هشدار بالینی: پرفشاری صبحگاهی (Morning Surge) شناسایی شد.');
    }

    buffer.writeln('\n📊 توزیع مراحل AHA/ACC:');
    buffer.writeln(' • نرمال و پیش‌فشار: %${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(0))}');
    buffer.writeln(' • مرحله ۱: %${_toPersianDigits(stats.stage1Percentage.toStringAsFixed(0))}');
    buffer.writeln(' • مرحله ۲: %${_toPersianDigits(stats.stage2Percentage.toStringAsFixed(0))}');
    if (stats.crisisPercentage > 0) {
      buffer.writeln(' • بحران فشار خون: %${_toPersianDigits(stats.crisisPercentage.toStringAsFixed(0))}');
    }

    buffer.writeln('\n📝 آخرین سنجش‌های ثبت‌شده:');
    for (final log in filteredLogs.take(5)) {
      final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(log.loggedAt));
      final dateStr = '${jalali.year}/${jalali.month}/${jalali.day}';
      final timeStr = '${DateTime.fromMillisecondsSinceEpoch(log.loggedAt).hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(log.loggedAt).minute.toString().padLeft(2, '0')}';
      buffer.writeln(' • ${_toPersianDigits('$dateStr $timeStr')}: ${_toPersianDigits('${log.systolic}/${log.diastolic}')} (${log.stageLabel}) ${log.note ?? ''}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    RitmoToast.show(
      context,
      'گزارش بالینی فشار خون در کلیپ‌بورد کپی شد 📋',
      icon: CupertinoIcons.doc_on_clipboard_fill,
      iconColor: context.colors.success,
    );
  }

  BloodPressureLog? _calculateLivePreview() {
    final sys = int.tryParse(_normalizeDigits(_sysController.text.trim()));
    final dia = int.tryParse(_normalizeDigits(_diaController.text.trim()));
    if (sys == null || dia == null) return null;
    return BloodPressureLog(
      id: 'preview',
      systolic: sys,
      diastolic: dia,
      loggedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final filteredLogs = _getFilteredLogs();
    final stats = BloodPressureStats.compute(filteredLogs);
    final latestLog = _logs.isNotEmpty ? _logs.first : null;
    final livePreview = _calculateLivePreview();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header & Export Action ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.heart_circle_fill,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.bloodPressureTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_logs.isNotEmpty)
                  TextButton.icon(
                    onPressed: _copyDoctorReport,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: colors.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(CupertinoIcons.doc_text_fill, size: 14),
                    label: const Text(
                      'گزارش پزشک',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ─── Time Horizon Filter Pills ───
            _buildTimeRangeSelector(colors),
            const SizedBox(height: 14),

            // ─── Hero Overview Card ───
            if (latestLog != null && stats != null)
              _buildHeroCard(context, latestLog, stats, colors),

            // ─── Morning Surge Warning Banner ───
            if (stats != null && stats.morningSurgeDetected)
              _buildMorningSurgeAlert(colors),

            // ─── 4-Biomarker Clinical Grid ───
            if (stats != null) ...[
              const SizedBox(height: 14),
              _buildBiomarkersGrid(context, stats, colors),
            ],

            const SizedBox(height: 16),

            // ─── Dual-Line Multi-Parametric Chart ───
            if (filteredLogs.isNotEmpty) ...[
              _buildChartCard(context, filteredLogs, colors),
              const SizedBox(height: 16),
            ],

            // ─── Smart Quick Log Card ───
            _buildQuickLogCard(context, livePreview, colors, l10n),
            const SizedBox(height: 20),

            // ─── History Header & Category Filter ───
            _buildHistoryHeader(colors, l10n),
            const SizedBox(height: 8),

            // ─── History List ───
            if (_isLoading)
              Center(child: CircularProgressIndicator(color: colors.primary))
            else
              _buildHistoryList(filteredLogs, colors, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(RitmoColors colors) {
    final ranges = [
      {'key': '7D', 'label': '۷ روز'},
      {'key': '14D', 'label': '۱۴ روز'},
      {'key': '30D', 'label': '۳۰ روز'},
      {'key': 'ALL', 'label': 'همه سنجش‌ها'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((r) {
          final isSelected = _selectedTimeRange == r['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(
                r['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : colors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: colors.primary,
              backgroundColor: colors.surface,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? colors.primary : colors.border,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTimeRange = r['key']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    BloodPressureLog latest,
    BloodPressureStats stats,
    RitmoColors colors,
  ) {
    final stageColor = latest.stageColor;
    final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(latest.loggedAt));
    final dateStr = _toPersianDigits('${jalali.month}/${jalali.day}');
    final timeStr = _toPersianDigits(
      '${DateTime.fromMillisecondsSinceEpoch(latest.loggedAt).hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(latest.loggedAt).minute.toString().padLeft(2, '0')}',
    );

    return RitmoCard.neumorphic(
      borderColor: stageColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RitmoCardHeader(
            title: 'آخرین سنجش ثبت‌شده ($dateStr $timeStr)',
            icon: CupertinoIcons.heart_circle_fill,
            iconColor: stageColor,
            trailing: RitmoCardBadge(
              label: latest.stageLabel,
              color: stageColor,
            ),
          ),
          const RitmoCardDivider(),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _toPersianDigits('${latest.systolic}/${latest.diastolic}'),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'mmHg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _metricBadge(
                          'MAP: ${_toPersianDigits(latest.meanArterialPressure.toStringAsFixed(1))}',
                          latest.mapColor,
                        ),
                        _metricBadge(
                          'فشار نبض: ${_toPersianDigits(latest.pulsePressure.toString())}',
                          latest.pulsePressureColor,
                        ),
                        if (latest.pulse != null)
                          _metricBadge(
                            'ضربان: ${_toPersianDigits(latest.pulse.toString())} bpm',
                            colors.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Circular Control Gauge
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'درصد کنترل',
                        style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '%${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(0))}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: stats.inRangePercentage >= 70
                              ? colors.success
                              : (stats.inRangePercentage >= 50 ? colors.warning : colors.error),
                        ),
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (stats.inRangePercentage / 100.0).clamp(0.0, 1.0),
                          backgroundColor: colors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            stats.inRangePercentage >= 70
                                ? colors.success
                                : (stats.inRangePercentage >= 50 ? colors.warning : colors.error),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMorningSurgeAlert(RitmoColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: colors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هشدار الگوی پرفشاری صبحگاهی (Morning Surge)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'میانگین فشار سیستولیک صبحگاهی شما بیش از ۱۵ واحد بالاتر از عصر است که نیازمند توجه است.',
                  style: TextStyle(fontSize: 10.5, color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomarkersGrid(
    BuildContext context,
    BloodPressureStats stats,
    RitmoColors colors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _biomarkerCard(
              title: 'میانگین فشار خون',
              value: '${_toPersianDigits(stats.averageSystolic.toStringAsFixed(0))}/${_toPersianDigits(stats.averageDiastolic.toStringAsFixed(0))}',
              unit: 'mmHg',
              subtitle: stats.averageSystolic < 120 && stats.averageDiastolic < 80
                  ? 'محدوده بهینه و نرمال'
                  : (stats.averageSystolic < 130 ? 'کمی افزایش یافته' : 'نیازمند مراقبت'),
              icon: CupertinoIcons.waveform_path_ecg,
              color: colors.primary,
              width: itemWidth,
              colors: colors,
            ),
            _biomarkerCard(
              title: 'میانگین شریانی (MAP)',
              value: _toPersianDigits(stats.averageMAP.toStringAsFixed(1)),
              unit: 'mmHg',
              subtitle: stats.averageMAP >= 70 && stats.averageMAP <= 100
                  ? 'خون‌رسانی بهینه بافت‌ها'
                  : 'خارج از محدوده استاندارد',
              icon: CupertinoIcons.drop_fill,
              color: colors.primary,
              width: itemWidth,
              colors: colors,
            ),
            _biomarkerCard(
              title: 'فشار نبض (PP)',
              value: _toPersianDigits(stats.averagePulsePressure.toStringAsFixed(0)),
              unit: 'mmHg',
              subtitle: stats.averagePulsePressure <= 50
                  ? 'انعطاف عروقی ایده‌آل'
                  : (stats.averagePulsePressure <= 60 ? 'سفتی عروق مرزی' : 'احتمال سفتی عروق بالا'),
              icon: CupertinoIcons.sparkles,
              color: colors.accent,
              width: itemWidth,
              colors: colors,
            ),
            _biomarkerCard(
              title: 'میانگین ضربان قلب',
              value: stats.averagePulse != null ? _toPersianDigits(stats.averagePulse!.toStringAsFixed(0)) : '--',
              unit: 'bpm',
              subtitle: stats.averagePulse != null && stats.averagePulse! >= 60 && stats.averagePulse! <= 100
                  ? 'ریتم سینوسی نرمال'
                  : 'پایش ریتم پیشنهاد می‌شود',
              icon: CupertinoIcons.heart_fill,
              color: colors.medicalRed,
              width: itemWidth,
              colors: colors,
            ),
          ],
        );
      },
    );
  }

  Widget _biomarkerCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required RitmoColors colors,
  }) {
    return SizedBox(
      width: width,
      child: RitmoCard.neumorphic(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    List<BloodPressureLog> filteredLogs,
    RitmoColors colors,
  ) {
    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'روند نوسانات فشار خون',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _legendItem('سیستول', colors.primary),
                  const SizedBox(width: 8),
                  _legendItem('دیاستول', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _BloodPressureChartPainter(
                logs: filteredLogs.take(14).toList().reversed.toList(),
                colors: colors,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickLogCard(
    BuildContext context,
    BloodPressureLog? livePreview,
    RitmoColors colors,
    AppLocalizations l10n,
  ) {
    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'ثبت سریع اندازه‌گیری جدید',
            icon: CupertinoIcons.pencil_ellipsis_rectangle,
            iconColor: colors.primary,
            trailing: livePreview != null
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: livePreview.stageColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: livePreview.stageColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      livePreview.stageLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: livePreview.stageColor,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _sysController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Vazirmatn'),
                  decoration: RitmoTheme.inputDecoration(
                    context,
                    label: 'سیستول (SYS)',
                    icon: CupertinoIcons.heart_fill,
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'اجباری';
                    if (int.tryParse(_normalizeDigits(val.trim())) == null) return 'نامعتبر';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _diaController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Vazirmatn'),
                  decoration: RitmoTheme.inputDecoration(
                    context,
                    label: 'دیاستول (DIA)',
                    icon: CupertinoIcons.drop_fill,
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'اجباری';
                    if (int.tryParse(_normalizeDigits(val.trim())) == null) return 'نامعتبر';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pulseController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13, fontFamily: 'Vazirmatn'),
                  decoration: RitmoTheme.inputDecoration(
                    context,
                    label: 'ضربان (Pulse)',
                    icon: CupertinoIcons.waveform_path_ecg,
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _arm,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13, fontFamily: 'Vazirmatn'),
                  decoration: RitmoTheme.inputDecoration(
                    context,
                    label: l10n.bloodPressureArm,
                    icon: Icons.accessibility_new,
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  dropdownColor: colors.surface,
                  items: [
                    DropdownMenuItem(value: 'LEFT', child: Text(l10n.bloodPressureArmLeft, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'RIGHT', child: Text(l10n.bloodPressureArmRight, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _arm = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _position,
            isDense: true,
            isExpanded: true,
            style: TextStyle(color: colors.textPrimary, fontSize: 13, fontFamily: 'Vazirmatn'),
            decoration: RitmoTheme.inputDecoration(
              context,
              label: l10n.bloodPressurePosition,
              icon: Icons.airline_seat_recline_normal,
            ).copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            dropdownColor: colors.surface,
            items: [
              DropdownMenuItem(value: 'SITTING', child: Text(l10n.bloodPressurePositionSitting, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'STANDING', child: Text(l10n.bloodPressurePositionStanding, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'LYING', child: Text(l10n.bloodPressurePositionLying, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _position = val);
            },
          ),
          const SizedBox(height: 10),

          // Contextual Tags
          Text(
            'شرایط و فاکتورهای اندازه‌گیری:',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                ),
                selected: isSelected,
                selectedColor: colors.primary.withValues(alpha: 0.15),
                backgroundColor: colors.surfaceSunken,
                checkmarkColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _noteController,
            style: TextStyle(color: colors.textPrimary, fontSize: 13, fontFamily: 'Vazirmatn'),
            decoration: RitmoTheme.inputDecoration(
              context,
              label: 'یادداشت دلخواه (اختیاری)',
              icon: Icons.note_alt_outlined,
            ).copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saveLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white, size: 18),
            label: Text(
              l10n.bloodPressureSave,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(RitmoColors colors, AppLocalizations l10n) {
    final stages = [
      {'key': 'ALL', 'label': 'همه'},
      {'key': 'NORMAL', 'label': 'نرمال'},
      {'key': 'ELEVATED', 'label': 'افزایش‌یافته'},
      {'key': 'STAGE_1', 'label': 'مرحله ۱'},
      {'key': 'STAGE_2', 'label': 'مرحله ۲'},
      {'key': 'CRISIS', 'label': 'بحران'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bloodPressureHistory,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stages.map((s) {
              final isSelected = _selectedStageFilter == s['key'];
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(
                    s['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: colors.primary.withValues(alpha: 0.15),
                  backgroundColor: colors.surface,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? colors.primary : colors.border,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedStageFilter = s['key']!);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList(
    List<BloodPressureLog> filteredLogs,
    RitmoColors colors,
    AppLocalizations l10n,
  ) {
    if (filteredLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(CupertinoIcons.heart, size: 36, color: colors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                'سابقه سنجشی در این بازه یافت نشد.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        final stageColor = log.stageColor;

        final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(log.loggedAt));
        final dateStr = _toPersianDigits('${jalali.year}/${jalali.month}/${jalali.day}');
        final timeStr = _toPersianDigits(
          '${DateTime.fromMillisecondsSinceEpoch(log.loggedAt).hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(log.loggedAt).minute.toString().padLeft(2, '0')}',
        );

        var posText = '';
        switch (log.position) {
          case 'LYING':
            posText = l10n.bloodPressurePositionLying;
          case 'STANDING':
            posText = l10n.bloodPressurePositionStanding;
          case 'SITTING':
          default:
            posText = l10n.bloodPressurePositionSitting;
        }

        final armText = log.arm == 'LEFT' ? l10n.bloodPressureArmLeft : l10n.bloodPressureArmRight;

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
                          radius: 14,
                          backgroundColor: stageColor.withValues(alpha: 0.15),
                          child: Icon(CupertinoIcons.heart_fill, color: stageColor, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _toPersianDigits('${log.systolic}/${log.diastolic}'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'mmHg',
                          style: TextStyle(fontSize: 10, color: colors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        RitmoCardBadge(
                          label: log.stageLabel,
                          color: stageColor,
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
                Row(
                  children: [
                    Text(
                      '$dateStr ساعت $timeStr · $armText ($posText)',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                    if (log.pulse != null) ...[
                      const Spacer(),
                      Text(
                        'ضربان: ${_toPersianDigits(log.pulse.toString())} bpm',
                        style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'MAP: ${_toPersianDigits(log.meanArterialPressure.toStringAsFixed(1))} (${log.mapLabel})',
                      style: TextStyle(fontSize: 10, color: log.mapColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PP: ${_toPersianDigits(log.pulsePressure.toString())} (${log.pulsePressureLabel})',
                      style: TextStyle(fontSize: 10, color: log.pulsePressureColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (log.note != null && log.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.note!,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String id) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('حذف سنجش', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('آیا مطمئن هستید که می‌خواهید این سنجش فشار خون را حذف کنید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteLog(id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.error),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloodPressureChartPainter extends CustomPainter {
  _BloodPressureChartPainter({
    required this.logs,
    required this.colors,
  });

  final List<BloodPressureLog> logs;
  final RitmoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    const paddingLeft = 35.0;
    const paddingRight = 15.0;
    const paddingTop = 20.0;
    const paddingBottom = 25.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    const minVal = 40.0;
    const maxVal = 200.0;

    double getY(double val) {
      final pct = ((val - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
      return size.height - paddingBottom - (pct * chartHeight);
    }

    double getX(int index, int total) {
      if (total <= 1) return paddingLeft + chartWidth / 2;
      return paddingLeft + (index * (chartWidth / (total - 1)));
    }

    // ─── Target Safe Corridor Band (80-120 mmHg) ───
    final safeCorridorY1 = getY(120);
    final safeCorridorY2 = getY(80);
    final corridorPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(paddingLeft, safeCorridorY1, size.width - paddingRight, safeCorridorY2),
      corridorPaint,
    );

    // ─── Grid lines (horizontal) at 60, 90, 120, 150, 180 ───
    final gridPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final val in [60, 90, 120, 150, 180]) {
      final y = getY(val.toDouble());
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      textPainter.text = TextSpan(
        text: _toPersianDigits(val.toString()),
        style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 4, y - textPainter.height / 2));
    }

    // ─── Build Paths for Systolic & Diastolic ───
    final sysPath = Path();
    final diaPath = Path();

    for (var i = 0; i < logs.length; i++) {
      final x = getX(i, logs.length);
      final sysY = getY(logs[i].systolic.toDouble());
      final diaY = getY(logs[i].diastolic.toDouble());

      if (i == 0) {
        sysPath.moveTo(x, sysY);
        diaPath.moveTo(x, diaY);
      } else {
        sysPath.lineTo(x, sysY);
        diaPath.lineTo(x, diaY);
      }
    }

    // Draw lines
    final sysLinePaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final diaLinePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(sysPath, sysLinePaint);
    canvas.drawPath(diaPath, diaLinePaint);

    // Draw dots and value labels
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final x = getX(i, logs.length);
      final sysY = getY(log.systolic.toDouble());
      final diaY = getY(log.diastolic.toDouble());

      // Systolic Dot
      canvas.drawCircle(Offset(x, sysY), 4.5, Paint()..color = colors.surface);
      canvas.drawCircle(Offset(x, sysY), 3.0, Paint()..color = colors.primary);

      textPainter.text = TextSpan(
        text: _toPersianDigits(log.systolic.toString()),
        style: TextStyle(color: colors.textPrimary, fontSize: 9, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, sysY - 14));

      // Diastolic Dot
      canvas.drawCircle(Offset(x, diaY), 4.5, Paint()..color = colors.surface);
      canvas.drawCircle(Offset(x, diaY), 3.0, Paint()..color = const Color(0xFF10B981));

      textPainter.text = TextSpan(
        text: _toPersianDigits(log.diastolic.toString()),
        style: TextStyle(color: colors.textPrimary, fontSize: 9, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, diaY + 4));

      // X-Axis Date label
      final dt = DateTime.fromMillisecondsSinceEpoch(log.loggedAt);
      final jalali = Jalali.fromDateTime(dt);
      final dateLabel = _toPersianDigits('${jalali.month}/${jalali.day}');
      textPainter.text = TextSpan(
        text: dateLabel,
        style: TextStyle(color: colors.textSecondary, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - paddingBottom + 4));
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
  bool shouldRepaint(covariant _BloodPressureChartPainter oldDelegate) {
    return oldDelegate.logs != logs || oldDelegate.colors != colors;
  }
}

