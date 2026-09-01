import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/observability/privacy_error_sink.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';

class CrashReportsScreen extends StatefulWidget {
  const CrashReportsScreen({super.key});

  @override
  State<CrashReportsScreen> createState() => _CrashReportsScreenState();
}

class _CrashReportsScreenState extends State<CrashReportsScreen> {
  List<File> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final reports = await PrivacyErrorSink.getCrashReports();
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAll() async {
    await PrivacyErrorSink.clearAllReports();
    await _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: RitmoGlassHeader(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'گزارش خطاهای سیستم',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      if (_reports.isNotEmpty)
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                          onPressed: _clearAll,
                          tooltip: 'حذف همه لاگ‌ها',
                        )
                      else
                        const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _reports.isEmpty
                        ? const Center(
                            child: RitmoNeuEmptyCard(
                              icon: CupertinoIcons.checkmark_shield_fill,
                              title: 'هیچ خطایی ثبت نشده است 🌿',
                              subtitle: 'عملکرد سیستم در وضعیت پایدار و ایمن قرار دارد.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                            itemCount: _reports.length,
                            itemBuilder: (context, index) {
                              final file = _reports[index];
                              final filename = file.path.split(Platform.pathSeparator).last;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: RitmoCard.neumorphic(
                                  onTap: () async {
                                    final text = await file.readAsString();
                                    if (context.mounted) {
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => RitmoCustomDialog(
                                          title: filename,
                                          icon: CupertinoIcons.doc_text,
                                          content: SingleChildScrollView(
                                            child: SelectableText(
                                              text,
                                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                            ),
                                          ),
                                          actions: [
                                            RitmoSecondaryButton(
                                              label: 'بستن',
                                              onPressed: () => Navigator.pop(ctx),
                                            ),
                                            const SizedBox(width: 10),
                                            RitmoPrimaryButton(
                                              label: 'کپی متن',
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: text));
                                                Navigator.pop(ctx);
                                                RitmoToast.show(context, 'گزارش در حافظه کپی شد');
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    title: Text(filename, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                                    trailing: const Icon(CupertinoIcons.doc_text, size: 20),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
