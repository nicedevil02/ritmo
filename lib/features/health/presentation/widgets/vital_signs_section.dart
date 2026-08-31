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

class VitalSignsSection extends StatefulWidget {
  const VitalSignsSection({super.key});

  @override
  State<VitalSignsSection> createState() => _VitalSignsSectionState();
}

class _VitalSignsSectionState extends State<VitalSignsSection> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();

  List<VitalSignLog> _logs = [];
  double? _height; // in cm
  bool _isLoading = true;

  String _vitalType = 'WEIGHT'; // 'WEIGHT' | 'TEMPERATURE' | 'SPO2' | 'WAIST'
  String _selectedTimeRange = '7D'; // '7D' | '14D' | '30D' | 'ALL'
  final Set<String> _selectedTags = {};

  final Map<String, List<String>> _contextTags = {
    'WEIGHT': ['ناشتا/صبحگاهی', 'بعد از غذا', 'بعد ورزش', 'با لباس سبک'],
    'TEMPERATURE': ['سنجش دهانی', 'سنجش زیربغلی', 'پیشانی/مادون قرمز', 'بعد پاشویه/دارو', 'همراه لرز'],
    'SPO2': ['در حال استراحت', 'بعد فعالیت', 'همراه تنگی نفس', 'با پالس‌اکسی‌متر'],
    'WAIST': ['صبح ناشتا', 'روی خط ناف', 'تنگی شکم'],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _valueController.addListener(() => setState(() {}));
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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Load height from medical_profile
      final profileResult = await db.query(
        'medical_profile',
        where: "profileKey = 'height'",
      );
      if (profileResult.isNotEmpty) {
        final heightStr = profileResult.first['profileValue']! as String;
        _height = double.tryParse(heightStr);
      }

      // 2. Load vitals logs
      final results = await db.query('vital_signs_logs', orderBy: 'loggedAt DESC', limit: 300);
      final logsList = results.map(VitalSignLog.fromMap).toList();

      if (mounted) {
        setState(() {
          _logs = logsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vital signs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveHeight(double heightVal) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'medical_profile',
        {
          'id': 'mp_height',
          'profileKey': 'height',
          'profileValue': heightVal.toString(),
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      setState(() => _height = heightVal);
      await _loadData();
    } catch (e) {
      debugPrint('Error saving height: $e');
    }
  }

  String _getUnit(String type) {
    switch (type) {
      case 'WEIGHT':
        return 'کیلوگرم';
      case 'TEMPERATURE':
        return '°C';
      case 'SPO2':
        return '%';
      case 'WAIST':
      default:
        return 'سانتی‌متر';
    }
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    final normValStr = _normalizeDigits(_valueController.text.trim());
    final value = double.tryParse(normValStr);
    if (value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Combine tags with notes
    final tagsString = _selectedTags.isNotEmpty ? _selectedTags.map((t) => '#$t').join(' ') : '';
    final customNote = _noteController.text.trim();
    final combinedNote = [tagsString, customNote].where((s) => s.isNotEmpty).join(' - ');

    final log = VitalSignLog(
      id: 'vs_${_vitalType}_$now',
      vitalType: _vitalType,
      value: value,
      unit: _getUnit(_vitalType),
      note: combinedNote.isEmpty ? null : combinedNote,
      loggedAt: now,
    );

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('vital_signs_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      _valueController.clear();
      _noteController.clear();
      _selectedTags.clear();

      if (!mounted) return;
      FocusScope.of(context).unfocus();

      RitmoToast.show(
        context,
        'سنجش علامت حیاتی با موفقیت ثبت شد',
        icon: CupertinoIcons.checkmark_seal_fill,
        iconColor: context.colors.success,
      );

      await _loadData();
    } catch (e) {
      debugPrint('Error saving vital log: $e');
    }
  }

  Future<void> _deleteLog(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('vital_signs_logs', where: 'id = ?', whereArgs: [id]);
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting vital log: $e');
    }
  }

  List<VitalSignLog> _getFilteredLogs(String type) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var filtered = _logs.where((l) => l.vitalType == type).toList();

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

    return filtered;
  }

  void _copyDoctorReport() {
    final weightLogs = _getFilteredLogs('WEIGHT');
    final tempLogs = _getFilteredLogs('TEMPERATURE');
    final spo2Logs = _getFilteredLogs('SPO2');
    final waistLogs = _getFilteredLogs('WAIST');

    final weightStats = VitalSignsStats.compute(weightLogs, 'WEIGHT', heightCm: _height);
    final tempStats = VitalSignsStats.compute(tempLogs, 'TEMPERATURE');
    final spo2Stats = VitalSignsStats.compute(spo2Logs, 'SPO2');
    final waistStats = VitalSignsStats.compute(waistLogs, 'WAIST', heightCm: _height);

    final buffer = StringBuffer();
    buffer.writeln('📋 گزارش تخصصی علائم حیاتی و شاخص‌های آنتروپومتریک - ریتمو');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (_height != null) {
      buffer.writeln('🔹 قد ثبت‌شده کاربر: ${_toPersianDigits(_height!.toStringAsFixed(0))} سانتی‌متر');
    }

    if (weightStats != null && weightLogs.isNotEmpty) {
      final latest = weightLogs.first;
      final bmi = latest.calculateBmi(_height);
      buffer.writeln('\n⚖️ وضعیت وزن و ترکیب بدنی:');
      buffer.writeln(' • آخرین وزن: ${_toPersianDigits(latest.value.toStringAsFixed(1))} کیلوگرم');
      if (bmi != null) {
        buffer.writeln(' • شاخص توده بدنی (BMI): ${_toPersianDigits(bmi.toStringAsFixed(1))} (${latest.getBmiLabel(_height)})');
      }
      final idealW = VitalSignLog.getIdealWeight(_height);
      if (idealW != null) {
        buffer.writeln(' • وزن ایده‌آل Devine: ${_toPersianDigits(idealW.toStringAsFixed(1))} کیلوگرم');
      }
      if (weightStats.delta != null && weightStats.totalCount > 1) {
        final sign = weightStats.delta! > 0 ? '+' : '';
        buffer.writeln(' • نوسان در دوره ($_selectedTimeRange): ${_toPersianDigits('$sign${weightStats.delta!.toStringAsFixed(1)}')} کیلوگرم');
      }
    }

    if (tempStats != null && tempLogs.isNotEmpty) {
      final latest = tempLogs.first;
      buffer.writeln('\n🌡️ وضعیت دمای بدن و تب:');
      buffer.writeln(' • آخرین دما: ${_toPersianDigits(latest.value.toStringAsFixed(1))} °C (${latest.tempLabel})');
      buffer.writeln(' • میانگین دوره: ${_toPersianDigits(tempStats.average.toStringAsFixed(1))} °C');
      buffer.writeln(' • حداکثر ثبت‌شده: ${_toPersianDigits(tempStats.max.toStringAsFixed(1))} °C');
    }

    if (spo2Stats != null && spo2Logs.isNotEmpty) {
      final latest = spo2Logs.first;
      buffer.writeln('\n🫁 وضعیت اشباع اکسیژن خون (SpO2):');
      buffer.writeln(' • آخرین سنجش: %${_toPersianDigits(latest.value.toStringAsFixed(0))} (${latest.spo2Label})');
      buffer.writeln(' • میانگین دوره: %${_toPersianDigits(spo2Stats.average.toStringAsFixed(1))}');
      buffer.writeln(' • حداقل اکسیژن: %${_toPersianDigits(spo2Stats.min.toStringAsFixed(0))}');
    }

    if (waistStats != null && waistLogs.isNotEmpty) {
      final latest = waistLogs.first;
      final whtr = latest.calculateWhtr(_height);
      buffer.writeln('\n📏 وضعیت دور کمر و چربی احشایی:');
      buffer.writeln(' • دور کمر: ${_toPersianDigits(latest.value.toStringAsFixed(1))} سانتی‌متر');
      if (whtr != null) {
        buffer.writeln(' • نسبت دور کمر به قد (WHtR): ${_toPersianDigits(whtr.toStringAsFixed(2))} (${latest.getWaistLabel(_height)})');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    RitmoToast.show(
      context,
      'گزارش بالینی علائم حیاتی در کلیپ‌بورد کپی شد 📋',
      icon: CupertinoIcons.doc_on_clipboard_fill,
      iconColor: context.colors.success,
    );
  }

  void _showHeightDialog() {
    final heightTextCtrl = TextEditingController(
      text: _height != null ? _height!.toStringAsFixed(0) : '',
    );
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('تنظیم قد کاربر', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'جهت محاسبه دقیق شاخص‌های BMI، وزن ایده‌آل و نسبت دور کمر به قد، لطفاً قد خود را بر حسب سانتی‌متر وارد کنید:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: heightTextCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                decoration: RitmoTheme.inputDecoration(
                  context,
                  label: 'قد (سانتی‌متر)',
                  icon: Icons.height,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                final clean = _normalizeDigits(heightTextCtrl.text.trim());
                final parsed = double.tryParse(clean);
                if (parsed != null && parsed > 50 && parsed < 260) {
                  _saveHeight(parsed);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: const Text('ذخیره قد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  VitalSignLog? _calculateLivePreview() {
    final normValStr = _normalizeDigits(_valueController.text.trim());
    final value = double.tryParse(normValStr);
    if (value == null) return null;
    return VitalSignLog(
      id: 'preview',
      vitalType: _vitalType,
      value: value,
      unit: _getUnit(_vitalType),
      loggedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final filteredLogs = _getFilteredLogs(_vitalType);
    final stats = VitalSignsStats.compute(filteredLogs, _vitalType, heightCm: _height);
    final latestLog = filteredLogs.isNotEmpty ? filteredLogs.first : null;
    final livePreview = _calculateLivePreview();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_logs.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
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
              ),
            const SizedBox(height: 8),

            // ─── 4 Vital Categories Selector Bar ───
            _buildVitalTypePills(colors, l10n),
            const SizedBox(height: 12),

            // ─── Time Horizon Filter Selector ───
            _buildTimeRangeSelector(colors),
            const SizedBox(height: 14),

            // ─── Hero Overview Card ───
            if (latestLog != null && stats != null)
              _buildHeroCard(context, latestLog, stats, colors),

            // ─── 4-Biomarker Clinical Grid ───
            if (stats != null) ...[
              const SizedBox(height: 14),
              _buildBiomarkersGrid(context, latestLog, stats, colors),
            ],

            const SizedBox(height: 16),

            // ─── Target Safety Corridor Chart ───
            if (filteredLogs.isNotEmpty) ...[
              _buildChartCard(context, filteredLogs, colors),
              const SizedBox(height: 16),
            ],

            // ─── Smart Quick Log Card ───
            _buildQuickLogCard(context, livePreview, colors, l10n),
            const SizedBox(height: 20),

            // ─── History Header & List ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تاریخچه ${_getVitalTitle(_vitalType, l10n)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_toPersianDigits(filteredLogs.length.toString())} سنجش',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              Center(child: CircularProgressIndicator(color: colors.primary))
            else
              _buildHistoryList(filteredLogs, colors),
          ],
        ),
      ),
    );
  }

  String _getVitalTitle(String type, AppLocalizations l10n) {
    switch (type) {
      case 'WEIGHT':
        return 'وزن و ترکیب بدنی';
      case 'TEMPERATURE':
        return 'دمای بدن';
      case 'SPO2':
        return 'اکسیژن خون (SpO2)';
      case 'WAIST':
      default:
        return 'دور کمر و چربی احشایی';
    }
  }

  Widget _buildVitalTypePills(RitmoColors colors, AppLocalizations l10n) {
    final vitals = [
      {'key': 'WEIGHT', 'label': 'وزن و BMI', 'icon': CupertinoIcons.gauge},
      {'key': 'TEMPERATURE', 'label': 'دما و تب', 'icon': CupertinoIcons.thermometer},
      {'key': 'SPO2', 'label': 'اکسیژن SpO2', 'icon': CupertinoIcons.wind},
      {'key': 'WAIST', 'label': 'دور کمر', 'icon': CupertinoIcons.circle_lefthalf_fill},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: vitals.map((v) {
          final isSelected = _vitalType == v['key'];
          final count = _logs.where((l) => l.vitalType == v['key']).length;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _vitalType = v['key']! as String;
                  _selectedTags.clear();
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      v['icon']! as IconData,
                      size: 15,
                      color: isSelected ? Colors.white : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      v['label']! as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _toPersianDigits(count.toString()),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : colors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: colors.primary,
              backgroundColor: colors.surface,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    VitalSignLog latest,
    VitalSignsStats stats,
    RitmoColors colors,
  ) {
    Color stageColor = colors.primary;
    String stageLabel = 'ثبت‌شده';

    switch (_vitalType) {
      case 'WEIGHT':
        stageColor = latest.getBmiColor(_height);
        stageLabel = latest.getBmiLabel(_height);
      case 'TEMPERATURE':
        stageColor = latest.tempColor;
        stageLabel = latest.tempLabel;
      case 'SPO2':
        stageColor = latest.spo2Color;
        stageLabel = latest.spo2Label;
      case 'WAIST':
        stageColor = latest.getWaistColor(_height);
        stageLabel = latest.getWaistLabel(_height);
    }

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
            title: 'آخرین سنجش ($dateStr $timeStr)',
            icon: CupertinoIcons.heart_fill,
            iconColor: stageColor,
            trailing: RitmoCardBadge(
              label: stageLabel,
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
                          _toPersianDigits(latest.value.toStringAsFixed(_vitalType == 'SPO2' ? 0 : 1)),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          latest.unit,
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
                        if (_vitalType == 'WEIGHT') ...[
                          if (latest.calculateBmi(_height) != null)
                            _metricBadge('BMI: ${_toPersianDigits(latest.calculateBmi(_height)!.toStringAsFixed(1))}', stageColor),
                          if (VitalSignLog.getIdealWeight(_height) != null)
                            _metricBadge('وزن ایده‌آل: ${_toPersianDigits(VitalSignLog.getIdealWeight(_height)!.toStringAsFixed(1))} kg', colors.success),
                        ],
                        if (_vitalType == 'WAIST' && latest.calculateWhtr(_height) != null)
                          _metricBadge('WHtR: ${_toPersianDigits(latest.calculateWhtr(_height)!.toStringAsFixed(2))}', stageColor),
                        if (_vitalType == 'TEMPERATURE')
                          _metricBadge('میانگین: ${_toPersianDigits(stats.average.toStringAsFixed(1))} °C', colors.primary),
                        if (_vitalType == 'SPO2')
                          _metricBadge('حداقل: %${_toPersianDigits(stats.min.toStringAsFixed(0))}', colors.accent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Side Metric / Quick Height Button
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _showHeightDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _height != null ? 'قد: ${_toPersianDigits(_height!.toStringAsFixed(0))} cm' : 'تنظیم قد ✏️',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stats.delta != null && stats.totalCount > 1
                              ? '${stats.delta! >= 0 ? '+' : ''}${_toPersianDigits(stats.delta!.toStringAsFixed(1))}'
                              : '%${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(0))}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stats.delta != null && stats.totalCount > 1 ? 'نوسان دوره' : 'درصد نرمال',
                          style: TextStyle(fontSize: 9.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
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

  Widget _buildBiomarkersGrid(
    BuildContext context,
    VitalSignLog? latest,
    VitalSignsStats stats,
    RitmoColors colors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;

        if (_vitalType == 'WEIGHT') {
          final bmi = latest?.calculateBmi(_height);
          final idealW = VitalSignLog.getIdealWeight(_height);
          final deltaToIdeal = (latest != null && idealW != null) ? latest.value - idealW : null;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _biomarkerCard(
                title: 'شاخص توده بدنی (BMI)',
                value: bmi != null ? _toPersianDigits(bmi.toStringAsFixed(1)) : '--',
                unit: 'kg/m²',
                subtitle: latest != null ? latest.getBmiLabel(_height) : 'نیاز به ثبت قد',
                icon: CupertinoIcons.gauge,
                color: latest?.getBmiColor(_height) ?? colors.primary,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'وزن ایده‌آل (Devine)',
                value: idealW != null ? _toPersianDigits(idealW.toStringAsFixed(1)) : '--',
                unit: 'kg',
                subtitle: deltaToIdeal != null
                    ? '${deltaToIdeal >= 0 ? '+' : ''}${_toPersianDigits(deltaToIdeal.toStringAsFixed(1))} kg تا هدف'
                    : 'محاسبه بر اساس قد',
                icon: CupertinoIcons.scope,
                color: colors.success,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'میانگین وزن دوره',
                value: _toPersianDigits(stats.average.toStringAsFixed(1)),
                unit: 'kg',
                subtitle: 'دامنه ${_toPersianDigits(stats.min.toStringAsFixed(1))} تا ${_toPersianDigits(stats.max.toStringAsFixed(1))}',
                icon: CupertinoIcons.waveform_path,
                color: colors.accent,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'تغییرات وزن (Δ)',
                value: stats.delta != null ? '${stats.delta! >= 0 ? '+' : ''}${_toPersianDigits(stats.delta!.toStringAsFixed(1))}' : '--',
                unit: 'kg',
                subtitle: stats.delta != null
                    ? (stats.delta! < 0 ? 'کاهش وزن در بازه' : (stats.delta! > 0 ? 'افزایش وزن در بازه' : 'وزن پایدار'))
                    : 'نیاز به سنجش‌های بیشتر',
                icon: CupertinoIcons.arrow_up_down,
                color: colors.primary,
                width: itemWidth,
                colors: colors,
              ),
            ],
          );
        } else if (_vitalType == 'TEMPERATURE') {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _biomarkerCard(
                title: 'آخرین دمای بدن',
                value: latest != null ? _toPersianDigits(latest.value.toStringAsFixed(1)) : '--',
                unit: '°C',
                subtitle: latest != null ? latest.tempLabel : 'نرمال: ۳۶.۰ تا ۳۷.۲',
                icon: CupertinoIcons.thermometer,
                color: latest?.tempColor ?? colors.primary,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'میانگین دمای دوره',
                value: _toPersianDigits(stats.average.toStringAsFixed(1)),
                unit: '°C',
                subtitle: stats.average <= 37.2 ? 'ریتم دمایی بدون تب' : 'میانگین با سابقه تب',
                icon: CupertinoIcons.waveform_path_ecg,
                color: colors.success,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'حداکثر دما (پیک تب)',
                value: _toPersianDigits(stats.max.toStringAsFixed(1)),
                unit: '°C',
                subtitle: stats.max > 38.0 ? 'سابقه تب بااهمیت بالینی' : 'پیک در محدوده فیزیولوژیک',
                icon: CupertinoIcons.flame_fill,
                color: stats.max > 38.0 ? colors.medicalRed : colors.warning,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'پایداری دمای نرمال',
                value: '%${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(0))}',
                unit: '',
                subtitle: '${_toPersianDigits(stats.inRangeCount.toString())} از ${_toPersianDigits(stats.totalCount.toString())} سنجش در بازه امن',
                icon: CupertinoIcons.shield_lefthalf_fill,
                color: colors.primary,
                width: itemWidth,
                colors: colors,
              ),
            ],
          );
        } else if (_vitalType == 'SPO2') {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _biomarkerCard(
                title: 'اشباع اکسیژن خون',
                value: latest != null ? '%${_toPersianDigits(latest.value.toStringAsFixed(0))}' : '--',
                unit: '',
                subtitle: latest != null ? latest.spo2Label : 'هدف: بالای ۹۵٪',
                icon: CupertinoIcons.wind,
                color: latest?.spo2Color ?? colors.primary,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'میانگین اکسیژن دوره',
                value: '%${_toPersianDigits(stats.average.toStringAsFixed(1))}',
                unit: '',
                subtitle: stats.average >= 95.0 ? 'اکسیژن‌رسانی بافتی عالی' : 'نیازمند بررسی تنفسی',
                icon: CupertinoIcons.sparkles,
                color: colors.success,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'حداقل اکسیژن (Drop)',
                value: '%${_toPersianDigits(stats.min.toStringAsFixed(0))}',
                unit: '',
                subtitle: stats.min < 92.0 ? 'هشدار افت اکسیژن' : 'بدون افت نگران‌کننده',
                icon: CupertinoIcons.exclamationmark_shield,
                color: stats.min < 92.0 ? colors.medicalRed : colors.warning,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'درصد اشباع ایمن',
                value: '%${_toPersianDigits(stats.inRangePercentage.toStringAsFixed(0))}',
                unit: '',
                subtitle: 'سنجش‌های بالاتر از ۹۵٪',
                icon: CupertinoIcons.checkmark_seal_fill,
                color: colors.primary,
                width: itemWidth,
                colors: colors,
              ),
            ],
          );
        } else {
          // WAIST
          final whtr = latest?.calculateWhtr(_height);
          final halfHeight = _height != null ? _height! * 0.5 : null;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _biomarkerCard(
                title: 'نسبت دور کمر به قد (WHtR)',
                value: whtr != null ? _toPersianDigits(whtr.toStringAsFixed(2)) : '--',
                unit: '',
                subtitle: latest != null ? latest.getWaistLabel(_height) : 'استاندارد: کمتر از ۰.۵',
                icon: CupertinoIcons.circle_lefthalf_fill,
                color: latest?.getWaistColor(_height) ?? colors.primary,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'سقف سلامت کمر (نصف قد)',
                value: halfHeight != null ? _toPersianDigits(halfHeight.toStringAsFixed(1)) : '--',
                unit: 'cm',
                subtitle: (latest != null && halfHeight != null)
                    ? (latest.value <= halfHeight ? 'محیط کمتر از نصف قد ✓' : 'فراتر از حد مجاز ⚠️')
                    : 'محاسبه از روی قد',
                icon: CupertinoIcons.bandage_fill,
                color: colors.success,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'میانگین دور کمر',
                value: _toPersianDigits(stats.average.toStringAsFixed(1)),
                unit: 'cm',
                subtitle: 'دامنه ${_toPersianDigits(stats.min.toStringAsFixed(1))} تا ${_toPersianDigits(stats.max.toStringAsFixed(1))}',
                icon: CupertinoIcons.waveform_path,
                color: colors.accent,
                width: itemWidth,
                colors: colors,
              ),
              _biomarkerCard(
                title: 'تغییرات اندازه (Δ)',
                value: stats.delta != null ? '${stats.delta! >= 0 ? '+' : ''}${_toPersianDigits(stats.delta!.toStringAsFixed(1))}' : '--',
                unit: 'cm',
                subtitle: stats.delta != null
                    ? (stats.delta! < 0 ? 'کاهش سایز شکمی' : (stats.delta! > 0 ? 'افزایش سایز شکمی' : 'سایز بدون تغییر'))
                    : 'نیاز به سنجش بیشتر',
                icon: CupertinoIcons.arrow_up_down,
                color: colors.primary,
                width: itemWidth,
                colors: colors,
              ),
            ],
          );
        }
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
    List<VitalSignLog> filteredLogs,
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
                'روند تغییرات ${_getVitalTitle(_vitalType, AppLocalizations.of(context)!)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getUnit(_vitalType),
                    style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _VitalSignsChartPainter(
                logs: filteredLogs.take(14).toList().reversed.toList(),
                type: _vitalType,
                heightCm: _height,
                colors: colors,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLogCard(
    BuildContext context,
    VitalSignLog? livePreview,
    RitmoColors colors,
    AppLocalizations l10n,
  ) {
    Color previewColor = colors.primary;
    String previewLabel = '';

    if (livePreview != null) {
      switch (_vitalType) {
        case 'WEIGHT':
          previewColor = livePreview.getBmiColor(_height);
          previewLabel = livePreview.getBmiLabel(_height);
        case 'TEMPERATURE':
          previewColor = livePreview.tempColor;
          previewLabel = livePreview.tempLabel;
        case 'SPO2':
          previewColor = livePreview.spo2Color;
          previewLabel = livePreview.spo2Label;
        case 'WAIST':
          previewColor = livePreview.getWaistColor(_height);
          previewLabel = livePreview.getWaistLabel(_height);
      }
    }

    final currentTags = _contextTags[_vitalType] ?? [];

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'ثبت سریع ${_getVitalTitle(_vitalType, l10n)}',
            icon: CupertinoIcons.pencil_ellipsis_rectangle,
            iconColor: colors.primary,
            trailing: (livePreview != null && previewLabel.isNotEmpty)
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: previewColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: previewColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      previewLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: previewColor,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
            decoration: RitmoTheme.inputDecoration(
              context,
              label: 'مقدار عددی (${_getUnit(_vitalType)})',
              icon: CupertinoIcons.speedometer,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'لطفاً مقدار را وارد کنید';
              if (double.tryParse(_normalizeDigits(val.trim())) == null) return 'عدد معتبر وارد کنید';
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Context Tags
          Text(
            'شرایط و وضعیت اندازه‌گیری:',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: currentTags.map((tag) {
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
            style: TextStyle(color: colors.textPrimary),
            decoration: RitmoTheme.inputDecoration(
              context,
              label: 'یادداشت دلخواه (اختیاری)',
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
                  l10n.vitalSignsSave,
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

  Widget _buildHistoryList(
    List<VitalSignLog> filteredLogs,
    RitmoColors colors,
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

        Color stageColor = colors.primary;
        String stageText = '';

        switch (_vitalType) {
          case 'WEIGHT':
            stageColor = log.getBmiColor(_height);
            stageText = log.getBmiLabel(_height);
          case 'TEMPERATURE':
            stageColor = log.tempColor;
            stageText = log.tempLabel;
          case 'SPO2':
            stageColor = log.spo2Color;
            stageText = log.spo2Label;
          case 'WAIST':
            stageColor = log.getWaistColor(_height);
            stageText = log.getWaistLabel(_height);
        }

        final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(log.loggedAt));
        final dateStr = _toPersianDigits('${jalali.year}/${jalali.month}/${jalali.day}');
        final timeStr = _toPersianDigits(
          '${DateTime.fromMillisecondsSinceEpoch(log.loggedAt).hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(log.loggedAt).minute.toString().padLeft(2, '0')}',
        );

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
                          _toPersianDigits(log.value.toStringAsFixed(_vitalType == 'SPO2' ? 0 : 1)),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          log.unit,
                          style: TextStyle(fontSize: 10, color: colors.textSecondary),
                        ),
                        if (stageText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          RitmoCardBadge(
                            label: stageText,
                            color: stageColor,
                          ),
                        ],
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

  Future<void> _confirmDelete(String id) async {
    final res = await RitmoGlassDialog.show(
      context,
      title: 'حذف سنجش',
      content: 'آیا مطمئن هستید که می‌خواهید این سنجش علامت حیاتی را حذف کنید؟',
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

class _VitalSignsChartPainter extends CustomPainter {
  _VitalSignsChartPainter({
    required this.logs,
    required this.type,
    this.heightCm,
    required this.colors,
  });

  final List<VitalSignLog> logs;
  final String type;
  final double? heightCm;
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

    double minVal = 0;
    double maxVal = 100;
    List<double> gridLevels = [];
    double? safeBandMin;
    double? safeBandMax;

    switch (type) {
      case 'WEIGHT':
        minVal = 30.0;
        maxVal = 150.0;
        gridLevels = [40, 60, 80, 100, 120, 140];
        if (heightCm != null && heightCm! > 100) {
          final hM = heightCm! / 100.0;
          safeBandMin = 18.5 * hM * hM;
          safeBandMax = 24.9 * hM * hM;
        }
      case 'TEMPERATURE':
        minVal = 35.0;
        maxVal = 41.0;
        gridLevels = [35.5, 36.5, 37.5, 38.5, 39.5, 40.5];
        safeBandMin = 36.0;
        safeBandMax = 37.2;
      case 'SPO2':
        minVal = 85.0;
        maxVal = 100.0;
        gridLevels = [88, 92, 95, 98, 100];
        safeBandMin = 95.0;
        safeBandMax = 100.0;
      case 'WAIST':
        minVal = 50.0;
        maxVal = 140.0;
        gridLevels = [60, 80, 100, 120];
        if (heightCm != null && heightCm! > 100) {
          safeBandMin = 50.0;
          safeBandMax = heightCm! * 0.5;
        }
    }

    double getY(double val) {
      final pct = ((val - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
      return size.height - paddingBottom - (pct * chartHeight);
    }

    double getX(int index, int total) {
      if (total <= 1) return paddingLeft + chartWidth / 2;
      return paddingLeft + (index * (chartWidth / (total - 1)));
    }

    // ─── Target Safe Corridor Band ───
    if (safeBandMin != null && safeBandMax != null) {
      final safeY1 = getY(safeBandMax);
      final safeY2 = getY(safeBandMin);
      final corridorPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.09)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(paddingLeft, safeY1, size.width - paddingRight, safeY2),
        corridorPaint,
      );
    }

    // ─── Horizontal Grid Lines ───
    final gridPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final val in gridLevels) {
      final y = getY(val);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      textPainter.text = TextSpan(
        text: _toPersianDigits(val.toStringAsFixed(type == 'TEMPERATURE' ? 1 : 0)),
        style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 4, y - textPainter.height / 2));
    }

    // ─── Path & Line ───
    final linePath = Path();
    for (var i = 0; i < logs.length; i++) {
      final x = getX(i, logs.length);
      final y = getY(logs[i].value);

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // ─── Dots and Labels ───
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final x = getX(i, logs.length);
      final y = getY(log.value);

      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = colors.surface);
      canvas.drawCircle(Offset(x, y), 3.0, Paint()..color = colors.primary);

      textPainter.text = TextSpan(
        text: _toPersianDigits(log.value.toStringAsFixed(type == 'SPO2' ? 0 : 1)),
        style: TextStyle(color: colors.textPrimary, fontSize: 9, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 14));

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
  bool shouldRepaint(covariant _VitalSignsChartPainter oldDelegate) {
    return oldDelegate.logs != logs ||
        oldDelegate.type != type ||
        oldDelegate.heightCm != heightCm ||
        oldDelegate.colors != colors;
  }
}
