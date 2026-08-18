import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';

/// Screen for displaying real-time diagnostics, selector health,
/// and event trace logs for the ChatGPT Web Bridge (A-39).
class WebBridgeDiagnosticsScreen extends StatefulWidget {
  const WebBridgeDiagnosticsScreen({super.key});

  @override
  State<WebBridgeDiagnosticsScreen> createState() => _WebBridgeDiagnosticsScreenState();
}

class _WebBridgeDiagnosticsScreenState extends State<WebBridgeDiagnosticsScreen> {
  bool _isHarvesting = false;
  bool _isRebooting = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final manager = ChatGptWebBridgeManager.instance;

    return RitmoPageScaffold(
      appBar: RitmoModuleAppBar(
        title: 'تشخیص پل هوش مصنوعی وب',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تازه‌سازی',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ValueListenableBuilder<ChatGptBridgeStatus>(
        valueListenable: manager.statusNotifier,
        builder: (context, status, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. وضعیت لحظه‌ای پل
                Text(
                  'وضعیت لحظه‌ای پل',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                RitmoCard(
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  child: Column(
                    children: [
                      _buildStatusRow(
                        context,
                        label: 'وضعیت پل:',
                        value: status.name,
                        icon: _getStatusIcon(status),
                        valueColor: _getStatusColor(status, colors),
                      ),
                      const Divider(height: RitmoSpacing.md),
                      _buildStatusRow(
                        context,
                        label: 'نسخهٔ اسکریپت پل:',
                        value: 'v${toPersianDigits(ChatGptJsInjector.bridgeVersion.toString())}',
                        icon: Icons.code_rounded,
                      ),
                      const Divider(height: RitmoSpacing.md),
                      _buildStatusRow(
                        context,
                        label: 'شناسهٔ درخواست جاری:',
                        value: manager.currentRequestId ?? '—',
                        icon: Icons.tag_rounded,
                      ),
                      const Divider(height: RitmoSpacing.md),
                      _buildStatusRow(
                        context,
                        label: 'منبع قفل‌شده:',
                        value: manager.lockedSource?.name ?? '—',
                        icon: Icons.lock_outline_rounded,
                      ),
                      const Divider(height: RitmoSpacing.md),
                      _buildStatusRow(
                        context,
                        label: 'طول متن در انباشتگر:',
                        value: '${toPersianDigits(manager.accumulator.length.toString())} کاراکتر',
                        icon: Icons.text_snippet_outlined,
                      ),
                      const Divider(height: RitmoSpacing.md),
                      ValueListenableBuilder<bool>(
                        valueListenable: manager.isAuthenticatedNotifier,
                        builder: (context, isAuth, _) {
                          return _buildStatusRow(
                            context,
                            label: 'وضعیت احراز هویت:',
                            value: isAuth ? 'احراز شده (وارد شده)' : 'نیاز به ورود',
                            icon: isAuth ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                            valueColor: isAuth ? colors.success : colors.error,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                // 2. سلامت سلکتورهای صفحه
                Text(
                  'سلامت سلکتورهای رابط کاربری (Selector Health)',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                RitmoCard(
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بررسی انطباق عناصر DOM صفحهٔ ChatGPT با قوانین پل ریتمو:',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.sm),
                      _buildSelectorHealthGrid(context, manager.lastSelectorHealthReport),
                    ],
                  ),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                // 3. اقدامات بازیابی دستی
                Text(
                  'اقدامات بازیابی دستی',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: RitmoSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: RitmoPrimaryButton(
                        label: 'بازیابی پاسخ از مرورگر',
                        icon: Icons.download_rounded,
                        isLoading: _isHarvesting,
                        onPressed: () => _handleHarvest(context),
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Expanded(
                      child: RitmoSecondaryButton(
                        label: 'راه‌اندازی مجدد اجباری',
                        icon: Icons.restart_alt_rounded,
                        isLoading: _isRebooting,
                        onPressed: () => _handleForceReboot(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.lg),

                // 4. ردیاب رویدادها (Event Trace Log)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ردیاب رویدادها (${toPersianDigits(BridgeTraceLog.instance.entries.length.toString())} رویداد)',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('کپی گزارش'),
                      onPressed: () => _copyTraceLog(context),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.xs),
                _buildTraceLogList(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: RitmoSpacing.xs),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorHealthGrid(BuildContext context, Map<String, dynamic>? report) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    if (report == null || report.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm),
        child: Text(
          'هنوز داده‌ای از خودآزمون دریافت نشده است. لطفاً پل را مجدداً راه‌اندازی کنید.',
          style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      );
    }

    final keys = ['composer', 'sendButton', 'assistantMessage', 'conversationTurns', 'markdownBodies', 'userMessage'];
    final labels = {
      'composer': 'کادر ورودی (Composer)',
      'sendButton': 'دکمهٔ ارسال (Send)',
      'assistantMessage': 'پیام‌های دستیار (Assistant)',
      'conversationTurns': 'نوبت‌های گفتگو (Turns)',
      'markdownBodies': 'بدنهٔ مارک‌داون (Markdown)',
      'userMessage': 'پیام‌های کاربر (User)',
    };

    return Column(
      children: keys.map((key) {
        final count = (report[key] as int?) ?? 0;
        final isZero = count == 0;
        final label = labels[key] ?? key;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                isZero ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                size: 16,
                color: isZero ? colors.error : colors.success,
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isZero ? colors.error.withValues(alpha: 0.1) : colors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${toPersianDigits(count.toString())} مورد',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isZero ? colors.error : colors.success,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTraceLogList(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final entries = BridgeTraceLog.instance.entries.reversed.toList();

    if (entries.isEmpty) {
      return RitmoCard(
        padding: const EdgeInsets.all(RitmoSpacing.md),
        child: Center(
          child: Text(
            'هیچ رویدادی هنوز در ردیاب ثبت نشده است.',
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.take(30).length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final timeStr = '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}.${entry.timestamp.millisecond.toString().padLeft(3, '0')}';

        return Container(
          padding: const EdgeInsets.all(RitmoSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLevelColor(entry.level, colors).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.type,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getLevelColor(entry.level, colors),
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.xs),
                  Text(
                    '[${entry.source}]',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    toPersianDigits(timeStr),
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
              if (entry.note != null || entry.textLength != null || entry.requestId != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${entry.requestId != null ? 'req: ${entry.requestId} · ' : ''}${entry.textLength != null ? 'طول: ${toPersianDigits(entry.textLength.toString())} کاراکتر · ' : ''}${entry.note ?? ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleHarvest(BuildContext context) async {
    setState(() => _isHarvesting = true);
    try {
      final harvested = await ChatGptWebBridgeManager.instance.harvestVisibleAnswer();
      if (!mounted) return;
      if (harvested != null && harvested.isNotEmpty) {
        RitmoToast.show(context, 'پاسخ با موفقیت بازیابی شد (${toPersianDigits(harvested.length.toString())} کاراکتر).');
      } else {
        RitmoToast.show(context, 'متن پاسخی در صفحهٔ مرورگر یافت نشد.');
      }
    } catch (e) {
      if (mounted) RitmoToast.show(context, 'خطا در بازیابی: $e');
    } finally {
      if (mounted) setState(() => _isHarvesting = false);
    }
  }

  Future<void> _handleForceReboot(BuildContext context) async {
    setState(() => _isRebooting = true);
    try {
      await ChatGptWebBridgeManager.instance.forceReboot();
      if (!mounted) return;
      RitmoToast.show(context, 'پل مجدداً راه‌اندازی شد.');
    } catch (e) {
      if (mounted) RitmoToast.show(context, 'خطا در راه‌اندازی مجدد: $e');
    } finally {
      if (mounted) setState(() => _isRebooting = false);
    }
  }

  Future<void> _copyTraceLog(BuildContext context) async {
    final text = BridgeTraceLog.instance.exportAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      RitmoToast.show(context, 'گزارش ردیاب در حافظه کپی شد.');
    }
  }

  IconData _getStatusIcon(ChatGptBridgeStatus status) {
    return switch (status) {
      ChatGptBridgeStatus.idle => Icons.nightlight_round,
      ChatGptBridgeStatus.booting => Icons.sync_rounded,
      ChatGptBridgeStatus.ready => Icons.check_circle_rounded,
      ChatGptBridgeStatus.generating => Icons.stream_rounded,
      ChatGptBridgeStatus.cloudflareChallenge => Icons.security_rounded,
      ChatGptBridgeStatus.error => Icons.error_rounded,
    };
  }

  Color _getStatusColor(ChatGptBridgeStatus status, RitmoColorScheme colors) {
    return switch (status) {
      ChatGptBridgeStatus.idle => colors.textTertiary,
      ChatGptBridgeStatus.booting => colors.info,
      ChatGptBridgeStatus.ready => colors.success,
      ChatGptBridgeStatus.generating => colors.primary,
      ChatGptBridgeStatus.cloudflareChallenge => colors.warning,
      ChatGptBridgeStatus.error => colors.error,
    };
  }

  Color _getLevelColor(BridgeTraceLevel level, RitmoColorScheme colors) {
    return switch (level) {
      BridgeTraceLevel.info => colors.info,
      BridgeTraceLevel.warning => colors.warning,
      BridgeTraceLevel.error => colors.error,
    };
  }
}
