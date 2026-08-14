import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// Aggregation data structure for Doctor's Report (UX-07)
class PregnancyReportData {
  final String userName;
  final GestationalAge gestationalAge;
  final String eddJalali;
  final Map<String, int> symptomTrends;
  final List<Map<String, dynamic>> bpLogs;
  final List<Map<String, dynamic>> sugarLogs;
  final List<Map<String, dynamic>> kickSessions;
  final List<Map<String, dynamic>> completedCheckups;

  PregnancyReportData({
    required this.userName,
    required this.gestationalAge,
    required this.eddJalali,
    required this.symptomTrends,
    required this.bpLogs,
    required this.sugarLogs,
    required this.kickSessions,
    required this.completedCheckups,
  });
}

/// Pure data aggregator function for Doctor's Report with resilient fallback queries
Future<PregnancyReportData> aggregatePregnancyReportData({
  required String pregnancyId,
  required DateTime lmpDate,
}) async {
  final db = await DatabaseHelper.instance.database;

  // 1. User Name
  String userName = '';
  try {
    final settingsRows = await db.query('app_settings', where: 'key = ?', whereArgs: ['user_display_name'], limit: 1);
    if (settingsRows.isNotEmpty) {
      userName = settingsRows.first['value'] as String? ?? '';
    }
  } catch (_) {}

  // 2. Gestational Age & EDD
  final diffDays = DateTime.now().difference(lmpDate).inDays;
  final ga = GestationalAge.fromDays(diffDays);
  final eddDt = lmpDate.add(const Duration(days: 280));
  final eddJ = Jalali.fromDateTime(eddDt);
  final eddJalaliStr = '${eddJ.year}/${eddJ.month.toString().padLeft(2, '0')}/${eddJ.day.toString().padLeft(2, '0')}';

  // 3. 4-week symptom trends (pregnancy_symptoms: id, pregnancyId, date, symptom, severity, note)
  final symptomTrends = <String, int>{};
  try {
    final fourWeeksAgoStr = DateTime.now().subtract(const Duration(days: 28)).toIso8601String().substring(0, 10);
    final symRows = await db.query(
      'pregnancy_symptoms',
      where: 'pregnancyId = ? AND date >= ?',
      whereArgs: [pregnancyId, fourWeeksAgoStr],
    );
    for (final r in symRows) {
      final code = (r['symptom'] ?? r['symptomCode'] ?? '') as String;
      if (code.isNotEmpty) {
        symptomTrends[code] = (symptomTrends[code] ?? 0) + 1;
      }
    }
  } catch (_) {}

  // 4. Last 8 Blood Pressure logs (blood_pressure_logs: id, systolic, diastolic, loggedAt)
  List<Map<String, dynamic>> bpRows = [];
  try {
    bpRows = await db.query(
      'blood_pressure_logs',
      orderBy: 'loggedAt DESC',
      limit: 8,
    );
  } catch (_) {}

  // 5. Blood sugar logs in weeks 24-28 (blood_sugar_logs: id, value, measurementType, loggedAt)
  List<Map<String, dynamic>> sugarRows = [];
  try {
    final week24StartMs = lmpDate.add(const Duration(days: 24 * 7)).millisecondsSinceEpoch;
    final week28EndMs = lmpDate.add(const Duration(days: 28 * 7)).millisecondsSinceEpoch;
    sugarRows = await db.query(
      'blood_sugar_logs',
      where: 'loggedAt >= ? AND loggedAt <= ?',
      whereArgs: [week24StartMs, week28EndMs],
      orderBy: 'loggedAt DESC',
    );
  } catch (_) {}

  // 6. Last 7 Kick Sessions (kick_counts: id, pregnancyId, startTime, kickCount, loggedAt)
  List<Map<String, dynamic>> kickRows = [];
  try {
    kickRows = await db.query(
      'kick_counts',
      where: 'pregnancyId = ?',
      whereArgs: [pregnancyId],
      orderBy: 'startTime DESC',
      limit: 7,
    );
  } catch (_) {}

  // 7. Completed Checkups (pregnancy_checkups: id, pregnancyId, title, isCompleted)
  List<Map<String, dynamic>> checkupRows = [];
  try {
    checkupRows = await db.query(
      'pregnancy_checkups',
      where: 'pregnancyId = ? AND isCompleted = 1',
      whereArgs: [pregnancyId],
    );
  } catch (_) {}

  return PregnancyReportData(
    userName: userName,
    gestationalAge: ga,
    eddJalali: eddJalaliStr,
    symptomTrends: symptomTrends,
    bpLogs: bpRows,
    sugarLogs: sugarRows,
    kickSessions: kickRows,
    completedCheckups: checkupRows,
  );
}

/// UX-07 Shareable Doctor's Report Widget and Export Handler
class PregnancyReportScreen extends StatefulWidget {
  const PregnancyReportScreen({
    super.key,
    required this.pregnancyId,
    required this.lmpDate,
  });

  final String pregnancyId;
  final DateTime lmpDate;

  static Future<void> show(BuildContext context, {required String pregnancyId, required DateTime lmpDate}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PregnancyReportScreen(pregnancyId: pregnancyId, lmpDate: lmpDate),
      ),
    );
  }

  @override
  State<PregnancyReportScreen> createState() => _PregnancyReportScreenState();
}

class _PregnancyReportScreenState extends State<PregnancyReportScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  PregnancyReportData? _data;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final aggregated = await aggregatePregnancyReportData(
        pregnancyId: widget.pregnancyId,
        lmpDate: widget.lmpDate,
      );
      if (mounted) {
        setState(() {
          _data = aggregated;
        });
      }
    } catch (e, st) {
      debugPrint('[PregnancyReportScreen] Error loading report: $e\n$st');
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در بارگذاری گزارش: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportAndShare() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'pregnancy_report_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await Share.shareXFiles([xFile], text: 'گزارش دوره بارداری جهت ارائه به پزشک متخصص زنان');
    } catch (e) {
      debugPrint('[PregnancyReport] Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disclaimer = l10n?.pregnancyMedicalDisclaimer ??
        'این اطلاعات فقط جهت آگاهی ارائه می‌شود و جایگزین تشخیص، تجویز یا درمان پزشکی نیست.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش ویژه پزشک زنان', style: TextStyle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: (_isLoading || _data == null) ? null : _exportAndShare,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_errorMessage != null || _data == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage ?? 'خطا در بارگذاری گزارش',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadReport,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تلاش مجدد', style: TextStyle()),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RepaintBoundary(
                        key: _boundaryKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'گزارش مراقبت‌های بارداری',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      if (_data!.userName.isNotEmpty)
                                        Text(
                                          'نام بیمار: ${_data!.userName}',
                                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                                        ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.pink.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'سن: هفته ${_data!.gestationalAge.weeks} + ${_data!.gestationalAge.days} روز',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink.shade700, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('تاریخ تقریبی زایمان: ${_data!.eddJalali}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const Divider(height: 24),

                              // 1. Blood Pressure Section
                              _buildSectionTitle('آخرین سوابق فشار خون'),
                              if (_data!.bpLogs.isEmpty)
                                _buildEmptyRow('رکوردی ثبت نشده است')
                              else
                                ..._data!.bpLogs.take(5).map((bp) {
                                  final sys = bp['systolic'];
                                  final dia = bp['diastolic'];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• فشار خون: $sys / $dia mmHg', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  );
                                }),
                              const SizedBox(height: 14),

                              // 2. Blood Sugar (Weeks 24-28)
                              _buildSectionTitle('تست قند خون (هفته ۲۴ تا ۲۸)'),
                              if (_data!.sugarLogs.isEmpty)
                                _buildEmptyRow('تست قند در این بازه ثبت نشده است')
                              else
                                ..._data!.sugarLogs.map((sg) {
                                  final val = sg['value'] ?? sg['sugarValue'];
                                  final type = sg['type'] ?? sg['measurementType'] ?? 'تست قند';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• $type: $val mg/dL', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  );
                                }),
                              const SizedBox(height: 14),

                              // 3. Kick Sessions
                              _buildSectionTitle('۷ جلسه اخیر لگدشماری'),
                              if (_data!.kickSessions.isEmpty)
                                _buildEmptyRow('جلسه‌ای ثبت نشده است')
                              else
                                ..._data!.kickSessions.map((ks) {
                                  final count = ks['kickCount'];
                                  final date = ks['date'] ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• تاریخ $date: $count حرکت ثبت شد', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  );
                                }),
                              const SizedBox(height: 14),

                              // 4. Completed Checkups
                              _buildSectionTitle('مراقبتهای انجام شده'),
                              if (_data!.completedCheckups.isEmpty)
                                _buildEmptyRow('مراقبتی تکمیل نشده است')
                              else
                                ..._data!.completedCheckups.map((chk) {
                                  final title = chk['titleFa'] ?? chk['title'] ?? 'مراقبت بارداری';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('✓ $title', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                                  );
                                }),
                              const SizedBox(height: 18),

                              // Disclaimer Footer
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  disclaimer,
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('اشتراک‌گذاری تصویر گزارش جهت ارائه به پزشک', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _exportAndShare,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo),
      ),
    );
  }

  Widget _buildEmptyRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic)),
    );
  }
}
