import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';

/// Full-canvas interactive profile avatar cropper sheet.
/// Displays the full uncropped image on a dark canvas with a circular mask overlay,
/// allowing free pan & zoom, and slicing to 512x512 only on user confirmation.
class ProfileAvatarCropperSheet extends StatefulWidget {
  const ProfileAvatarCropperSheet({super.key, required this.imageFile});

  final File imageFile;

  static Future<String?> show(BuildContext context, File imageFile) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileAvatarCropperSheet(imageFile: imageFile),
    );
  }

  @override
  State<ProfileAvatarCropperSheet> createState() => _ProfileAvatarCropperSheetState();
}

class _ProfileAvatarCropperSheetState extends State<ProfileAvatarCropperSheet> {
  final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _isSaving = false;
  static const double _cropDiameter = 240.0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    RitmoHapticsPolicy.selection();
    final matrix = _transformController.value.clone();
    matrix.scaleByDouble(factor, factor, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _resetZoom() {
    RitmoHapticsPolicy.selection();
    _transformController.value = Matrix4.identity();
  }

  Future<void> _cropAndSave() async {
    if (_isSaving) return;
    RitmoHapticsPolicy.tap();
    setState(() => _isSaving = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Render boundary not found');
      }

      // 1. Capture the full canvas viewport image
      final fullCanvasImage = await boundary.toImage(pixelRatio: 2.0);
      final canvasWidth = fullCanvasImage.width.toDouble();
      final canvasHeight = fullCanvasImage.height.toDouble();

      // 2. Compute exact center crop rect matching the overlay circle in image coordinates
      final renderBox = _cropBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
      final logicalSize = renderBox?.size ?? Size(canvasWidth / 2.0, canvasHeight / 2.0);
      final pixelRatio = canvasWidth / logicalSize.width;

      final cropRadiusInPx = (_cropDiameter / 2.0) * pixelRatio;
      final centerInPx = Offset(canvasWidth / 2.0, canvasHeight / 2.0);
      final srcRect = Rect.fromCircle(center: centerInPx, radius: cropRadiusInPx);

      // 3. Draw onto a clean 512x512 canvas with circular clipping
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const outSize = 512.0;
      const dstRect = Rect.fromLTWH(0, 0, outSize, outSize);

      canvas.clipPath(Path()..addOval(dstRect));
      canvas.drawImageRect(
        fullCanvasImage,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(512, 512);
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image bytes');
      }

      final bytes = byteData.buffer.asUint8List();
      final appDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${appDir.path}/profile_avatars');
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      // Clean up previous avatars
      try {
        final existingFiles = avatarsDir.listSync();
        for (final f in existingFiles) {
          if (f is File) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      } catch (_) {}

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = File('${avatarsDir.path}/avatar_$timestamp.png');
      await savedFile.writeAsBytes(bytes);

      if (mounted) {
        Navigator.of(context).pop(savedFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        RitmoToast.show(context, 'خطا در برش و ذخیره عکس');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final canvasHeight = (screenWidth * 0.88).clamp(300.0, 360.0);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(CupertinoIcons.crop, color: colors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تنظیم کادر عکس نمایه',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textSecondary.withValues(alpha: 0.5), size: 22),
                onPressed: _isSaving ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تصویر را جابه‌جا کنید و زوم نمایید تا در کادر قرار گیرد.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 14),

          // Full-Canvas Interactive Viewport with Mask Overlay
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: canvasHeight,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // Full Interactive Image Viewport
                  RepaintBoundary(
                    key: _cropBoundaryKey,
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.5,
                        maxScale: 4.0,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        child: Center(
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Overlay Mask with Circular Cutout & Grid
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CropMaskOverlayPainter(
                        cropDiameter: _cropDiameter,
                        borderColor: colors.primary,
                        maskColor: Colors.black.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Zoom Controls Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'کوچک‌نمایی',
                icon: const Icon(CupertinoIcons.minus_circle),
                iconSize: 24,
                color: colors.textSecondary,
                onPressed: () => _zoomBy(0.85),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: colors.border.withValues(alpha: 0.6)),
                ),
                icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                label: const Text('بازنشانی', style: TextStyle(fontSize: 12)),
                onPressed: _resetZoom,
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'بزرگ‌نمایی',
                icon: const Icon(CupertinoIcons.plus_circle),
                iconSize: 24,
                color: colors.textSecondary,
                onPressed: () => _zoomBy(1.15),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: colors.border.withValues(alpha: 0.8)),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: Text('انصراف', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator(color: colors.onPrimary))
                      : const Icon(CupertinoIcons.checkmark_alt, size: 18),
                  label: Text(
                    _isSaving ? 'در حال برش و فشرده‌سازی...' : 'تأیید و اعمال',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isSaving ? null : _cropAndSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.92),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }
}

/// Semi-transparent dark mask with circular cutout, glowing border ring, and subtle rule-of-thirds grid.
class _CropMaskOverlayPainter extends CustomPainter {
  const _CropMaskOverlayPainter({
    required this.cropDiameter,
    required this.borderColor,
    required this.maskColor,
  });

  final double cropDiameter;
  final Color borderColor;
  final Color maskColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius = cropDiameter / 2.0;

    // 1. Semi-transparent dark mask outside the circle
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fullPath = Path()..addRect(fullRect);
    final circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final maskPath = Path.combine(PathOperation.difference, fullPath, circlePath);

    final maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. Circular glowing border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 3. Rule of thirds subtle grid lines inside circle
    final guidePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final third = (radius * 2.0) / 3.0;
    final leftX = center.dx - radius;
    final topY = center.dy - radius;

    canvas.save();
    canvas.clipPath(circlePath);
    canvas.drawLine(Offset(leftX, topY + third), Offset(leftX + radius * 2.0, topY + third), guidePaint);
    canvas.drawLine(Offset(leftX, topY + third * 2.0), Offset(leftX + radius * 2.0, topY + third * 2.0), guidePaint);
    canvas.drawLine(Offset(leftX + third, topY), Offset(leftX + third, topY + radius * 2.0), guidePaint);
    canvas.drawLine(Offset(leftX + third * 2.0, topY), Offset(leftX + third * 2.0, topY + radius * 2.0), guidePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropMaskOverlayPainter oldDelegate) =>
      oldDelegate.cropDiameter != cropDiameter ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.maskColor != maskColor;
}

/// Service providing unified, robust avatar picking, cropping, and persistence.
class ProfileAvatarService {
  const ProfileAvatarService._();

  static Future<String?> pickAndCropAvatar(
    BuildContext context, {
    required ImageSource source,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (picked == null) return null;

      if (!context.mounted) return null;

      final croppedPath = await ProfileAvatarCropperSheet.show(
        context,
        File(picked.path),
      );

      if (croppedPath != null && croppedPath.isNotEmpty) {
        await SettingsService.instance.set('user_avatar_path', croppedPath);
        return croppedPath;
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        RitmoToast.show(context, 'خطا در بارگذاری تصویر');
      }
      return null;
    }
  }

  static Future<void> removeAvatar(BuildContext context) async {
    await SettingsService.instance.set('user_avatar_path', '');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${appDir.path}/profile_avatars');
      if (await avatarsDir.exists()) {
        await avatarsDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
