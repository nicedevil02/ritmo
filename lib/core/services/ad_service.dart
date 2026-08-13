import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/features/premium/presentation/premium_upgrade_sheet.dart';
import 'package:tapsell_plus/tapsell_plus.dart';


class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();

  static const String _tapsellAppId = String.fromEnvironment('TAPSELL_APP_ID');
  static const String _bannerZoneId = String.fromEnvironment('TAPSELL_BANNER_ZONE_ID');
  static const String _rewardedZoneId = String.fromEnvironment('TAPSELL_REWARDED_ZONE_ID');

  /// صفحاتی که هرگز تبلیغ نمی‌بینند — محتوای حساس یا دینی/پزشکی/زیستی
  static const Set<String> _adFreeScreens = {
    'worship',
    'prayer',
    'quran',
    'fasting',
    'cycle',
    'pregnancy',
    'medicine',
    'medication',
    'sleep',
    'reflection',
    'energy',
  };

  bool _initialized = false;
  bool _initAttempted = false;

  bool get _isTapsellSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (PremiumService.instance.isPremium) return;
    if (!_isTapsellSupported) return;
    if (_initialized || _initAttempted) return;
    _initAttempted = true;

    if (_tapsellAppId.trim().isEmpty) {
      debugPrint('AdService: TAPSELL_APP_ID is empty; skipping Tapsell initialization.');
      return;
    }

    try {
      await TapsellPlus.instance.initialize(_tapsellAppId);
      _initialized = true;
    } catch (e) {
      debugPrint('AdService: Tapsell initialization failed: $e');
    }
  }

  /// Returns a banner ad widget if the user is free and screen is allowed.
  /// [screenId]: ID of the current screen — sensitive screens never show ads.
  Widget getBannerAd({String screenId = ''}) {
    if (PremiumService.instance.isPremium) {
      return const SizedBox.shrink();
    }
    // Never show ads on sensitive / religious / medical / biological screens
    if (_adFreeScreens.contains(screenId)) {
      return const SizedBox.shrink();
    }

    return StatefulBuilder(
      builder: (context, setState) {
        if (!_isTapsellSupported) {
          return _buildSimulatedBannerAd(context);
        }

        if (!_initialized && !_initAttempted) {
          init().then((_) {
            if (context.mounted && _initialized) {
              setState(() {});
            }
          });
          return _buildSimulatedBannerAd(context);
        }

        if (!_initialized || _bannerZoneId.trim().isEmpty) {
          return _buildSimulatedBannerAd(context);
        }

        try {
          return Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 50,
            child: const TapsellPlusBannerAd(
              zoneId: _bannerZoneId,
              bannerType: TapsellPlusBannerType.BANNER_320x50,
              margin: EdgeInsets.all(0),
            ),
          );
        } catch (e) {
          debugPrint('AdService banner rendering error: $e; falling back to simulated ad');
          return _buildSimulatedBannerAd(context);
        }
      },
    );
  }

  Widget _buildSimulatedBannerAd(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1A1A2E), Color(0xff22223B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffFFA500).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xffFFA500),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'تبلیغ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ریتم؛ دستیار هوشمند و ریتمیک شما 💎',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazirmatn',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'خرید اشتراک پریمیوم برای حذف تبلیغات و دسترسی کامل',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontFamily: 'Vazirmatn',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              PremiumUpgradeSheet.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFFA500),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'ارتقا',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Vazirmatn'),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  /// اینترستیشال حذف شد — طبق قانون فاز ۴ نقشه راه
  /// دلیل: تجربه کاربری مختل شده و احتمال ظاهر‌شدن در صفحات حساس
  Future<void> showInterstitialAd([BuildContext? context]) async {
    // Disabled in Phase 4
    debugPrint('AdService: Interstitial ads are disabled.');
  }

  Future<bool> showRewardedAdForAi(BuildContext context) async {
    if (PremiumService.instance.isPremium) return false;
    if (!_isTapsellSupported || !_initialized || _rewardedZoneId.isEmpty) {
      return false;
    }
    try {
      final completer = Completer<bool>();
      final responseId = await TapsellPlus.instance.requestRewardedVideoAd(_rewardedZoneId);
      
      await TapsellPlus.instance.showRewardedVideoAd(
        responseId,
        onOpened: (map) {
          debugPrint('AdService: Rewarded ad opened: $map');
        },
        onClosed: (map) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onRewarded: (map) {
          completer.complete(true);
        },
        onError: (map) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      return await completer.future;
    } catch (e) {
      debugPrint('AdService: Rewarded ad error: $e');
      return false;
    }
  }
}

class TapsellPlusBannerAd extends StatefulWidget {

  const TapsellPlusBannerAd({
    super.key,
    required this.zoneId,
    required this.bannerType,
    required this.margin,
  });
  final String zoneId;
  final TapsellPlusBannerType bannerType;
  final EdgeInsets margin;

  @override
  State<TapsellPlusBannerAd> createState() => _TapsellPlusBannerAdState();
}

class _TapsellPlusBannerAdState extends State<TapsellPlusBannerAd> {
  String? _responseId;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    try {
      await TapsellPlus.instance.requestStandardBannerAd(
        widget.zoneId,
        widget.bannerType,
        onResponse: (map) {
          final respId = map['response_id'];
          if (respId != null && mounted) {
            _responseId = respId;
            TapsellPlus.instance.showStandardBannerAd(
              respId,
              TapsellPlusHorizontalGravity.BOTTOM,
              TapsellPlusVerticalGravity.CENTER,
              margin: widget.margin,
            );
          }
        },
        onError: (map) {
          debugPrint("TapsellPlusBannerAd load error: ${map['error_message']}");
        },
      );
    } catch (e) {
      debugPrint('TapsellPlusBannerAd error: $e');
    }
  }

  @override
  void dispose() {
    if (_responseId != null) {
      TapsellPlus.instance.destroyStandardBanner(_responseId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.transparent,
    );
  }
}
