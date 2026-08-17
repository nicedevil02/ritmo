import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:ritmo/features/health/data/pregnancy_week_data.dart';

/// UX-14 Shareable Weekly Progress Card with 4:5 fixed aspect ratio, fruit size,
/// overall progress bar, and no sensitive medical data.
class WeeklyShareCardScreen extends StatefulWidget {
  const WeeklyShareCardScreen({super.key, required this.gestationalAge});

  final GestationalAge gestationalAge;

  static Future<void> show(
    BuildContext context, {
    required GestationalAge gestationalAge,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WeeklyShareCardScreen(gestationalAge: gestationalAge),
      ),
    );
  }

  @override
  State<WeeklyShareCardScreen> createState() => _WeeklyShareCardScreenState();
}

class _WeeklyShareCardScreenState extends State<WeeklyShareCardScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _exportAndShare() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'weekly_card_week${widget.gestationalAge.weeks}.png',
      );

      await Share.shareXFiles(
        [xFile],
        text:
            'کارت رشد هفته ${widget.gestationalAge.weeks} بارداری من با اپلیکیشن ریتمو',
      );
    } catch (e) {
      debugPrint('[WeeklyShareCard] Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeks = widget.gestationalAge.weeks.clamp(1, 40);
    final days = widget.gestationalAge.days;
    final trimesterNum = widget.gestationalAge.trimester;
    final trimesterName = trimesterNum == 1
        ? 'سه ماهه اول'
        : (trimesterNum == 2 ? 'سه ماهه دوم' : 'سه ماهه سوم');

    final weekInfo = pregnancyWeekData[weeks];
    final babySize = weekInfo?.babySizeFa ?? weekInfo?.size ?? 'میوه کوچک';
    final babyWeight = weekInfo?.babyWeightFa ?? '';
    final progressFraction = (weeks / 40.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'کارت رشد هفتگی قابل اشتراک‌گذاری',
          style: TextStyle(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _exportAndShare),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // RepaintBoundary wrapping 4:5 Fixed Aspect Ratio Card
              RepaintBoundary(
                key: _boundaryKey,
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink.shade300, Colors.purple.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              trimesterName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ریتمو 🌸',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Week Number Badge
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'هفته $weeks',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (days > 0)
                                Text(
                                  '+ $days روز',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.87),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Baby Size Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.child_care,
                                size: 36,
                                color: Colors.amberAccent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اندازه جنین: $babySize',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (babyWeight.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'وزن تقریبی: $babyWeight',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.87),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Overall Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                        ) ==
                                        null
                                    ? const SizedBox()
                                    : Text(
                                        'پیشرفت بارداری',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                Text(
                                  '${(progressFraction * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressFraction,
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.24,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.share),
                label: const Text(
                  'اشتراک‌گذاری کارت رشد در شبکه‌های اجتماعی',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _exportAndShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
