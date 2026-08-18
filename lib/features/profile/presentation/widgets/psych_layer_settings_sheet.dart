import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';

class PsychLayerSettingsSheet extends StatefulWidget {
  const PsychLayerSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return RitmoSheetScaffold.present(
      context: context,
      title: 'لایهٔ عادت و اجرا',
      subtitle: 'تنظیمات روان‌شناختی رفتاری و کنترل ویژگی‌های هوشمند',
      builder: (_) => const PsychLayerSettingsSheet(),
    );
  }

  @override
  State<PsychLayerSettingsSheet> createState() => _PsychLayerSettingsSheetState();
}

class _PsychLayerSettingsSheetState extends State<PsychLayerSettingsSheet> {
  bool _isLoading = true;
  final Map<String, bool> _settings = {
    'motivation_diagnosis_enabled': true,
    'daily_budget_warning_enabled': true,
    'wip_limit_enabled': true,
    'cognitive_routing_enabled': false,
    'fresh_start_enabled': true,
    'capture_inbox_enabled': true,
    'mastery_pleasure_sampling_enabled': false,
    'mastery_decay_enabled': true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      for (final k in _settings.keys) {
        _settings[k] = SettingsService.instance.get<bool>(k);
      }
      _isLoading = false;
    });
  }

  Future<void> _toggleSetting(String key, bool val) async {
    setState(() => _settings[key] = val);
    await SettingsService.instance.set(key, val);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final labels = [
      {
        'key': 'motivation_diagnosis_enabled',
        'title': 'عارضه‌یابی انگیزشی (شیت چرا نشد؟)',
        'desc': 'شناسایی علت انجام نشدن روتین‌ها و پیشنهاد راهکار'
      },
      {
        'key': 'daily_budget_warning_enabled',
        'title': 'هشدار بودجهٔ روزانه',
        'desc': 'کارت هشدار ظرفیت بیش از حد در داشبورد امروز'
      },
      {
        'key': 'wip_limit_enabled',
        'title': 'سقف کار در جریان اهداف (WIP)',
        'desc': 'مدیریت اهداف فعال همزمان و پیشنهاد پارک'
      },
      {
        'key': 'cognitive_routing_enabled',
        'title': 'مسیریابی بار شناختی',
        'desc': 'تطبیق روتین‌های تحلیلی/اداری با سطح انرژی روزانه'
      },
      {
        'key': 'fresh_start_enabled',
        'title': 'نقاط شروع تازه',
        'desc': 'شناسایی نشانه‌های شروع مجدد در اول ماه، فصل یا تولد'
      },
      {
        'key': 'capture_inbox_enabled',
        'title': 'صندوق ثبت سریع (Open-Loop)',
        'desc': 'صندوق دریافت افکار و تصمیم‌گیری سه‌گانه'
      },
      {
        'key': 'mastery_pleasure_sampling_enabled',
        'title': 'نمونه‌گیری تسلط و لذت',
        'desc': 'پرسش درباره اثر روتین روی حس تسلط و لذت'
      },
      {
        'key': 'mastery_decay_enabled',
        'title': 'افت افتراقی تسلط',
        'desc': 'محاسبه زمان مرور بر اساس تاریخچه تمرین و مرور'
      },
    ];

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(RitmoSpacing.xl),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: labels.map((item) {
        final key = item['key']!;
        final title = item['title']!;
        final desc = item['desc']!;
        final isChecked = _settings[key] ?? false;

        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isChecked,
          activeThumbColor: colors.primary,
          title: Text(
            title,
            style: RitmoTextStyles.titleMedium(colors.textPrimary),
          ),
          subtitle: Text(
            desc,
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          onChanged: (val) => _toggleSetting(key, val),
        );
      }).toList(),
    );
  }
}
