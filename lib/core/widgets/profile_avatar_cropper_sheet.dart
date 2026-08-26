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

/// Interactive circular avatar cropper sheet and manager.
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
      // Allow frame to settle
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Render boundary not found');
      }

      // 260px * 2.0 pixelRatio = 520x520 crisp high-res avatar
      final uiImage = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
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
    final cropSize = (screenWidth * 0.68).clamp(220.0, 270.0);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(height: 6),
          Text(
            'تصویر را با دو انگشت جابه‌جا کنید و اندازه کادر را تنظیم نمایید.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),

          // Interactive Circular Cropping Viewport
          Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: cropSize,
                  height: cropSize,
                  child: RepaintBoundary(
                    key: _cropBoundaryKey,
                    child: ColoredBox(
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.6,
                        maxScale: 4.0,
                        boundaryMargin: EdgeInsets.all(cropSize * 1.5),
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Glowing Circular Ring Indicator
              IgnorePointer(
                child: Container(
                  width: cropSize,
                  height: cropSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

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
              const SizedBox(width: 4),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: colors.border.withValues(alpha: 0.6)),
                ),
                icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                label: const Text('بازنشانی', style: TextStyle(fontSize: 12)),
                onPressed: _resetZoom,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'بزرگ‌نمایی',
                icon: const Icon(CupertinoIcons.plus_circle),
                iconSize: 24,
                color: colors.textSecondary,
                onPressed: () => _zoomBy(1.15),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                    _isSaving ? 'در حال ذخیره‌سازی...' : 'تأیید و اعمال',
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
      child: RitmoTheme.glassCardLight(
        borderRadius: 28,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.92),
          ),
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }
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
        imageQuality: 92,
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
