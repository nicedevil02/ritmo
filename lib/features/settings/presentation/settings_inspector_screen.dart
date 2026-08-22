import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/features/assistant/presentation/day_plan_template_management_screen.dart';
import 'package:ritmo/features/dev/presentation/data_health_screen.dart';
import 'package:ritmo/features/dev/presentation/persona_telemetry_screen.dart';

/// صفحهٔ بازرس تنظیمات — ویژه حالت دیباگ (`kDebugMode`)
/// فراهم‌کننده دید ۳۶۰ درجه از ردیف‌های یتیم، کلیدهای پیش‌فرض، مقادیر کش و وضعیت پایگاه داده
class SettingsInspectorScreen extends StatefulWidget {
  const SettingsInspectorScreen({super.key});

  /// قالب‌بندی امن مقادیر: تضمین مطلق عدم افشای رازها در رابط کاربری
  static String safeDisplayValue(SettingDescriptor? desc, Object? value) {
    if (desc != null && (desc.scope == SettingScope.secure ||
        desc.key.toLowerCase().contains('pin') ||
        desc.key.toLowerCase().contains('password') ||
        desc.key.toLowerCase().contains('api_key') ||
        desc.key.toLowerCase().contains('secret'))) {
      return '[محرمانه - غیرقابل نمایش]';
    }
    if (value == null) return '(خالی / null)';
    return value.toString();
  }

  /// قالب‌بندی امن برای خروجی کلیپ‌بورد: جایگزینی صریح رازها با [REDACTED_SECRET]
  static String safeExportValue(SettingDescriptor? desc, Object? value) {
    if (desc != null && (desc.scope == SettingScope.secure ||
        desc.key.toLowerCase().contains('pin') ||
        desc.key.toLowerCase().contains('password') ||
        desc.key.toLowerCase().contains('api_key') ||
        desc.key.toLowerCase().contains('secret'))) {
      return '[REDACTED_SECRET]';
    }
    return value?.toString() ?? 'null';
  }

  @override
  State<SettingsInspectorScreen> createState() => _SettingsInspectorScreenState();
}

class _SettingsInspectorScreenState extends State<SettingsInspectorScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rawDbRows = [];
  List<String> _orphanKeys = [];
  List<SettingDescriptor> _unwrittenDescriptors = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    try {
      final rows = await SettingsService.instance.getRawDatabaseRows();
      final dbKeys = rows.map((r) => r['key'] as String).toSet();

      final orphans = <String>[];
      for (final r in rows) {
        final key = r['key'] as String;
        if (SettingsRegistry.find(key) == null) {
          orphans.add(key);
        }
      }

      final unwritten = SettingsRegistry.all
          .where((d) => d.scope == SettingScope.db && !dbKeys.contains(d.key))
          .toList();

      if (mounted) {
        setState(() {
          _rawDbRows = rows;
          _orphanKeys = orphans;
          _unwrittenDescriptors = unwritten;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyDiagnosticDump() async {
    final schemaVersion = SettingsService.instance.get<int>('settings_schema_version');
    final loadState = SettingsService.instance.loadState.name;
    final revision = SettingsService.instance.revision.value;
    final cachedCount = SettingsService.instance.cachedCount;

    final dbDump = <String, dynamic>{};
    for (final r in _rawDbRows) {
      final key = r['key'] as String;
      final desc = SettingsRegistry.find(key);
      dbDump[key] = {
        'value': SettingsInspectorScreen.safeExportValue(desc, r['value']),
        'updated_at': r['updated_at'] ?? 'null',
        'isOrphan': desc == null,
      };
    }

    final dumpData = {
      'report': 'Ritmo Settings Diagnostic Dump',
      'generated_at': DateTime.now().toIso8601String(),
      'service_status': {
        'load_state': loadState,
        'schema_version': schemaVersion,
        'revision': revision,
        'cached_keys_count': cachedCount,
      },
      'orphan_keys_count': _orphanKeys.length,
      'orphan_keys': _orphanKeys,
      'unwritten_keys_count': _unwrittenDescriptors.length,
      'unwritten_keys': _unwrittenDescriptors.map((d) => d.key).toList(),
      'database_rows_count': _rawDbRows.length,
      'database_rows': dbDump,
    };

    const encoder = JsonEncoder.withIndent('  ');
    final jsonText = encoder.convert(dumpData);

    await Clipboard.setData(ClipboardData(text: jsonText));
    if (mounted) {
      RitmoToast.show(context, 'گزارش تشخیصی تنظیمات در کلیپ‌بورد کپی شد.');
    }
  }

  Future<void> _confirmCleanOrphans() async {
    if (_orphanKeys.isEmpty) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('پاک‌سازی ردیف‌های یتیم'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'آیا از حذف دائمی ${toPersianDigits(_orphanKeys.length)} ردیف یتیم زیر مطمئنید؟\n\n${_orphanKeys.join('\n')}',
            textAlign: TextAlign.right,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف دائمی'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deletedCount = await SettingsService.instance.deleteOrphanKeys(_orphanKeys);
      await _loadDiagnostics();
      if (mounted) {
        RitmoToast.show(context, '${toPersianDigits(deletedCount)} ردیف یتیم با موفقیت پاک‌سازی شد.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // بازرس تنظیمات فقط در حالت kDebugMode در دسترس است
    if (!kDebugMode) {
      return const RitmoPageScaffold(
        appBar: RitmoModuleAppBar(title: 'دسترسی محدود'),
        body: Center(
          child: Text('این بخش فقط در نسخهٔ توسعه و عیب‌یابی در دسترس است.'),
        ),
      );
    }

    final colors = context.colors;
    final schemaVersion = SettingsService.instance.get<int>('settings_schema_version');
    final loadState = SettingsService.instance.loadState;
    final revision = SettingsService.instance.revision.value;
    final cachedCount = SettingsService.instance.cachedCount;

    final filteredDbRows = _rawDbRows.where((r) {
      if (_searchQuery.isEmpty) return true;
      final key = r['key'] as String;
      return key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return RitmoPageScaffold(
      appBar: RitmoModuleAppBar(
        title: 'بازرس تنظیمات (Debug)',
        actions: [
          IconButton(
            tooltip: 'رونویسی گزارش تشخیص',
            icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 20),
            onPressed: _copyDiagnosticDump,
          ),
          IconButton(
            tooltip: 'تازه‌سازی',
            icon: const Icon(CupertinoIcons.refresh, size: 20),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: _loadDiagnostics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── ۰. ابزارهای تشخیصی و مانیتورینگ سیستم ──
                    _buildSectionHeader('ابزارهای تشخیصی و مانیتورینگ', CupertinoIcons.wrench_fill, colors),
                    const SizedBox(height: 8),
                    _buildCard(
                      colors: colors,
                      child: Column(
                        children: [
                          _buildToolTile(
                            title: 'تله‌متری هوش مصنوعی و پرسوناها',
                            subtitle: 'پایش زنده مصرف توکن، مهارت‌ها و اعتبارسنجی پاسخ‌ها',
                            icon: CupertinoIcons.sparkles,
                            iconColor: colors.primary,
                            colors: colors,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PersonaTelemetryScreen()),
                            ),
                          ),
                          const Divider(height: 16),
                          _buildToolTile(
                            title: 'ممیزی سلامت پایگاه داده (Data Health)',
                            subtitle: 'بررسی رکوردهای تکراری، ناهماهنگی و سلامت جداول SQLite',
                            icon: CupertinoIcons.circle_grid_hex_fill,
                            iconColor: colors.warning,
                            colors: colors,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DataHealthScreen()),
                            ),
                          ),
                          const Divider(height: 16),
                          _buildToolTile(
                            title: 'مدیریت قالب‌های برنامهٔ روزانه',
                            subtitle: 'قالب‌های از پیش تعریف‌شده برای روزهای کاری و استراحت',
                            icon: CupertinoIcons.square_list_fill,
                            iconColor: colors.accent,
                            colors: colors,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DayPlanTemplateManagementScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── ۱. کارت وضعیت سرویس تنظیمات ──
                    _buildSectionHeader('وضعیت سلامت سرویس', CupertinoIcons.waveform_path_ecg, colors),
                    const SizedBox(height: 8),
                    _buildCard(
                      colors: colors,
                      child: Column(
                        children: [
                          _buildStatusRow(
                            'وضعیت بارگذاری',
                            loadState == SettingsLoadState.loaded
                                ? 'آماده و لود شده ✅'
                                : (loadState == SettingsLoadState.degraded ? 'حالت تخریب‌شده ⚠️' : 'بارگذاری نشده ❌'),
                            loadState == SettingsLoadState.loaded ? colors.accent : colors.warning,
                            colors,
                          ),
                          const Divider(height: 16),
                          _buildStatusRow(
                            'نسخهٔ طرحواره (Schema)',
                            'نسخهٔ ${toPersianDigits(schemaVersion)}',
                            colors.primary,
                            colors,
                          ),
                          const Divider(height: 16),
                          _buildStatusRow(
                            'کلیدهای فعال در کش',
                            '${toPersianDigits(cachedCount)} کلید',
                            colors.textPrimary,
                            colors,
                          ),
                          const Divider(height: 16),
                          _buildStatusRow(
                            'شمارندهٔ اصلاحات (Revision)',
                            '#${toPersianDigits(revision)}',
                            colors.textPrimary,
                            colors,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── ۲. ردیف‌های یتیم در دیتابیس ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('ردیف‌های یتیم (Orphan Rows)', CupertinoIcons.exclamationmark_triangle_fill, colors),
                        if (_orphanKeys.isNotEmpty)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            color: colors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: _confirmCleanOrphans,
                            child: Text(
                              'پاک‌سازی یتیم‌ها (${toPersianDigits(_orphanKeys.length)})',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.warning),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCard(
                      colors: colors,
                      child: _orphanKeys.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.checkmark_seal_fill, color: colors.accent, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'پایگاه داده تمیز است — هیچ ردیف یتیمی یافت نشد.',
                                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (int i = 0; i < _orphanKeys.length; i++) ...[
                                  if (i > 0) const Divider(height: 12),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(CupertinoIcons.trash, color: Colors.orange, size: 20),
                                    title: Text(_orphanKeys[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: const Text('کلید در رجیستری تعریف نشده است', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ── ۳. کلیدهای نوشته‌نشده (Default Fallback) ──
                    _buildSectionHeader('کلیدهای نوشته‌نشده (در حال استفاده از پیش‌فرض)', CupertinoIcons.arrow_2_circlepath_circle, colors),
                    const SizedBox(height: 8),
                    _buildCard(
                      colors: colors,
                      child: _unwrittenDescriptors.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('تمام کلیدهای دیتابیس دارای ردیف ذخیره‌شده هستند.', style: TextStyle(color: colors.textSecondary)),
                            )
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${toPersianDigits(_unwrittenDescriptors.length)} کلید در رجیستری وجود دارد که ردیفی در جدول ندارند و از مقدار پیش‌فرض استفاده می‌کنند.',
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ),
                                const Divider(height: 16),
                                for (int i = 0; i < _unwrittenDescriptors.length && i < 15; i++) ...[
                                  if (i > 0) const Divider(height: 12),
                                  _buildUnwrittenRow(_unwrittenDescriptors[i], colors),
                                ],
                                if (_unwrittenDescriptors.length > 15) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'و ${toPersianDigits(_unwrittenDescriptors.length - 15)} کلید دیگر...',
                                    style: TextStyle(fontSize: 11, color: colors.textTertiary, fontStyle: FontStyle.italic),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ── ۴. تمام مقادیر دیتابیس ──
                    _buildSectionHeader('تمام ردیف‌های پایگاه داده (${toPersianDigits(_rawDbRows.length)})', CupertinoIcons.tray_full_fill, colors),
                    const SizedBox(height: 8),
                    CupertinoSearchTextField(
                      placeholder: 'جستجو در کلیدهای دیتابیس...',
                      style: TextStyle(color: colors.textPrimary),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    _buildCard(
                      colors: colors,
                      child: filteredDbRows.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(child: Text('موردی یافت نشد.', style: TextStyle(color: colors.textSecondary))),
                            )
                          : Column(
                              children: [
                                for (int i = 0; i < filteredDbRows.length; i++) ...[
                                  if (i > 0) const Divider(height: 16),
                                  _buildDbRowItem(filteredDbRows[i], colors),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, RitmoColors colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildCard({required RitmoColors colors, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor, RitmoColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildUnwrittenRow(SettingDescriptor desc, RitmoColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(desc.labelFa, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            SettingsInspectorScreen.safeDisplayValue(desc, desc.defaultValue),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildDbRowItem(Map<String, dynamic> row, RitmoColors colors) {
    final key = row['key'] as String;
    final rawVal = row['value'];
    final desc = SettingsRegistry.find(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            if (desc == null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('یتیم', style: TextStyle(fontSize: 10, color: colors.warning, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(desc.type.name, style: TextStyle(fontSize: 10, color: colors.accent, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('مقدار:', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                SettingsInspectorScreen.safeDisplayValue(desc, rawVal),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required RitmoColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_left,
              size: 14,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
