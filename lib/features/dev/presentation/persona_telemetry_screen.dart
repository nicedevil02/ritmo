import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/personas/persona_telemetry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// صفحهٔ بازرس تله‌متری پرسونا (PSN-48)
class PersonaTelemetryScreen extends StatefulWidget {
  const PersonaTelemetryScreen({super.key});

  @override
  State<PersonaTelemetryScreen> createState() => _PersonaTelemetryScreenState();
}

class _PersonaTelemetryScreenState extends State<PersonaTelemetryScreen> {
  void _refresh() {
    setState(() {});
  }

  void _clear() {
    PersonaTelemetryCollector.instance.clear();
    setState(() {});
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final records = PersonaTelemetryCollector.instance.records.reversed
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('تله‌متری دستیارهای هوشمند'),
          backgroundColor: colors.surface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.trash),
              tooltip: 'پاک‌سازی',
              onPressed: records.isEmpty ? null : _clear,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.refresh),
              tooltip: 'تازه‌سازی',
              onPressed: _refresh,
            ),
          ],
        ),
        body: records.isEmpty
            ? Center(
                child: Text(
                  'هیچ رکورد تله‌متری ثبت نشده است.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final r = records[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'پرسونا: ${r.personaId}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                            Text(
                              _formatTime(r.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textTertiary,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (r.selectedSkill != null)
                              _buildChip(
                                'مهارت: ${r.selectedSkill}',
                                colors.primary,
                                colors,
                              ),
                            if (r.finalConfidence != null)
                              _buildChip(
                                'اطمینان: ${r.finalConfidence}',
                                colors.accent,
                                colors,
                              ),
                            if (r.validationSeverity != null)
                              _buildChip(
                                'اعتبارسنجی: ${r.validationSeverity}',
                                colors.warning,
                                colors,
                              ),
                            if (r.violatedRuleId != null)
                              _buildChip(
                                'قاعده: ${r.violatedRuleId}',
                                colors.error,
                                colors,
                              ),
                            if (r.droppedCommandsCount > 0)
                              _buildChip(
                                'فرمان حذفی: ${r.droppedCommandsCount}',
                                colors.error,
                                colors,
                              ),
                          ],
                        ),
                        if (r.incompleteDomains.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'دامنه‌های ناقص: ${r.incompleteDomains.join("، ")}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.warning,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildChip(String text, Color accent, RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          color: colors.textPrimary,
          fontFamily: 'Vazirmatn',
        ),
      ),
    );
  }
}
