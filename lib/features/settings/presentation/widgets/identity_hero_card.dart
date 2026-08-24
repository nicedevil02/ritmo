import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// کارت هیرو نمایش هویت کاربر در صفحه تنظیمات هویت
class IdentityHeroCard extends StatelessWidget {
  const IdentityHeroCard({
    super.key,
    required this.userName,
    required this.avatarPath,
    required this.genderLabel,
    required this.age,
    required this.appMode,
    required this.onPickAvatar,
    required this.onEditName,
  });

  final String userName;
  final String avatarPath;
  final String genderLabel;
  final int age;
  final String appMode;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditName;

  bool _isAvatarFileValid(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        path.startsWith('data:')) {
      return true;
    }
    if (!kIsWeb) {
      try {
        return File(path).existsSync();
      } catch (e, st) {
        RitmoLog.error('Settings', 'Failed to check avatar file exists in hero card', e, st);
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final displayName = userName.trim().isNotEmpty ? userName.trim() : 'کاربر گرامی';
    final hasValidAvatar = _isAvatarFileValid(avatarPath);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colors.surfaceElevated,
                  colors.surface,
                ]
              : [
                  Colors.white,
                  colors.surface,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : colors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Avatar with Glowing Ring and Camera Floating Badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer subtle gradient glow ring
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary,
                            const Color(0xFF38BDF8),
                            const Color(0xFFA855F7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: hasValidAvatar
                              ? (avatarPath.startsWith('http') || avatarPath.startsWith('blob:')
                                  ? Image.network(
                                      avatarPath,
                                      width: 90,
                                      height: 90,
                                      cacheWidth: 200,
                                      cacheHeight: 200,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(avatarPath),
                                      width: 90,
                                      height: 90,
                                      cacheWidth: 200,
                                      cacheHeight: 200,
                                      fit: BoxFit.cover,
                                    ))
                              : Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        colors.primary.withValues(alpha: 0.25),
                                        colors.primary.withValues(alpha: 0.08),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.person_fill,
                                    size: 46,
                                    color: colors.primary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // Floating Glass Camera Button
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: GestureDetector(
                        onTap: onPickAvatar,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Name with Quick Edit Button
                GestureDetector(
                  onTap: onEditName,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 14,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Quick Identity Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildHeroBadge(
                      icon: CupertinoIcons.sparkles,
                      label: appMode == 'full' ? 'نسخهٔ کامل' : 'نسخهٔ ساده',
                      color: appMode == 'full' ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                    _buildHeroBadge(
                      icon: CupertinoIcons.person_fill,
                      label: genderLabel,
                      color: colors.primary,
                      isDark: isDark,
                    ),
                    _buildHeroBadge(
                      icon: CupertinoIcons.calendar,
                      label: '${toPersianDigits(age)} سال',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
