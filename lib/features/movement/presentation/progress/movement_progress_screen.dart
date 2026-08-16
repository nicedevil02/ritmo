import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_personal_record.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/body_map_card.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/distribution_card.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/kpi_grid.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/pr_list.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/range_filter_bar.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/status_breakdown_card.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/strength_progress_card.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/trend_chart_card.dart';

/// صفحهٔ پیشرفت و تحلیل جامع حرکت (MovementProgressScreen)
/// نمایش ۸ بلوک استاندارد با فیلتر بازهٔ زمانی و بارگذاری غیرمسدودکننده.
class MovementProgressScreen extends StatefulWidget {
  const MovementProgressScreen({
    super.key,
    this.progressService,
    this.initialRange = MovementProgressRange.week,
  });

  final MovementProgressService? progressService;
  final MovementProgressRange initialRange;

  @override
  State<MovementProgressScreen> createState() => _MovementProgressScreenState();
}

class _MovementProgressScreenState extends State<MovementProgressScreen> {
  late final MovementProgressService _service;
  late MovementProgressRange _selectedRange;

  bool _isLoading = true;
  String? _errorMessage;

  MovementKpiData? _kpiData;
  MovementTrendData? _trendData;
  List<MovementDistributionItem> _distributionItems = [];
  List<MovementMuscleWorkloadItem> _muscleWorkload = [];
  MovementStrengthProgressData? _strengthProgressData;
  MovementStatusBreakdownData? _statusBreakdown;
  List<MovementPersonalRecord> _personalRecords = [];

  @override
  void initState() {
    super.initState();
    _service = widget.progressService ?? MovementProgressService();
    _selectedRange = widget.initialRange;
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getKpiData(range: _selectedRange),
        _service.getTrendData(range: _selectedRange),
        _service.getDistributionData(),
        _service.getMuscleWorkload(),
        _service.getStrengthProgressData(),
        _service.getStatusBreakdown(),
        _service.getPersonalRecords(),
      ]);

      if (mounted) {
        setState(() {
          _kpiData = results[0] as MovementKpiData;
          _trendData = results[1] as MovementTrendData;
          _distributionItems = results[2] as List<MovementDistributionItem>;
          _muscleWorkload = results[3] as List<MovementMuscleWorkloadItem>;
          _strengthProgressData = results[4] as MovementStrengthProgressData?;
          _statusBreakdown = results[5] as MovementStatusBreakdownData;
          _personalRecords = results[6] as List<MovementPersonalRecord>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleRangeChanged(MovementProgressRange newRange) {
    if (_selectedRange == newRange) return;
    setState(() => _selectedRange = newRange);
    _loadProgressData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return MovementScreenShell(
      title: MovementStrings.progressScreenTitle,
      body: RefreshIndicator(
        onRefresh: _loadProgressData,
        color: sportsColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MovementLayout.kScreenPadding,
            vertical: RitmoSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ۱. فیلتر بازهٔ زمانی
              RangeFilterBar(
                selectedRange: _selectedRange,
                onRangeChanged: _handleRangeChanged,
              ),
              const SizedBox(height: MovementLayout.kCardSpacing),

              if (_isLoading) ...[
                const ChartSkeleton(),
                const SizedBox(height: MovementLayout.kCardSpacing),
                const CardSkeleton(height: 120),
                const SizedBox(height: MovementLayout.kCardSpacing),
                const CardSkeleton(height: 200),
              ] else if (_errorMessage != null) ...[
                _buildErrorCard(colors),
              ] else if (_kpiData == null || (_kpiData!.isEmpty && _personalRecords.isEmpty)) ...[
                _buildEmptyState(colors, sportsColor),
              ] else ...[
                // ۲. شبکهٔ KPI
                if (_kpiData != null) ...[
                  KpiGrid(kpiData: _kpiData!),
                  const SizedBox(height: MovementLayout.kCardSpacing),
                ],

                // ۳. نمودار روند فعالیت هفتگی
                if (_trendData != null) ...[
                  TrendChartCard(trendData: _trendData!),
                  const SizedBox(height: MovementLayout.kCardSpacing),
                ],

                // ۴. توزیع خانواده‌های ورزشی
                if (_distributionItems.isNotEmpty) ...[
                  DistributionCard(items: _distributionItems),
                  const SizedBox(height: MovementLayout.kCardSpacing),
                ],

                // ۵. پیشرفت تمرینات قدرتی (در صورت وجود برنامه)
                if (_strengthProgressData != null) ...[
                  StrengthProgressCard(strengthData: _strengthProgressData!),
                  const SizedBox(height: MovementLayout.kCardSpacing),
                ],

                // ۶. نقشهٔ توزیع کار گروه‌های عضلانی
                if (_muscleWorkload.isNotEmpty) ...[
                  BodyMapCard(items: _muscleWorkload),
                  const SizedBox(height: MovementLayout.kCardSpacing),
                ],

                // ۷. فهرست رکوردهای شخصی واقعی
                PrList(records: _personalRecords),
                const SizedBox(height: MovementLayout.kCardSpacing),

                // ۸. تفکیک وضعیت جلسات
                if (_statusBreakdown != null) ...[
                  StatusBreakdownCard(data: _statusBreakdown!),
                ],
              ],

              const SizedBox(height: RitmoSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(RitmoColors colors, Color sportsColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats_rounded, size: 48, color: colors.textTertiary),
          const SizedBox(height: RitmoSpacing.md),
          Text(
            MovementStrings.noProgressData,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            'با ثبت اولین تمرین یا اجرای برنامهٔ ورزشی، آمار و نمودارهای تحلیلی در این بخش فعال می‌شوند.',
            style: RitmoTextStyles.body(colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: RitmoSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('بازگشت به مرکز حرکت'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, MovementLayout.kSecondaryButtonHeight),
              backgroundColor: sportsColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RitmoRadius.field)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(RitmoColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.accent, size: 32),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            'خطا در بارگذاری داده‌های پیشرفت',
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),
          TextButton.icon(
            onPressed: _loadProgressData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }
}
