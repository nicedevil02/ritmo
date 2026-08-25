// lib/features/supplementary_sports/movement/presentation/session/open_session.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_screen.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// تنها دروازهٔ ورود به صفحهٔ جلسه.
///
/// هر جای اپ که می‌خواهد جلسه‌ای را باز کند — تب حرکت، داشبورد، یادآور، برنامهٔ روز —
/// باید همین تابع را صدا بزند؛ نه مستقیم Navigator.push با صفحهٔ داخلی.
/// این‌طور انتخاب قالب و رفتار جلسه فقط یک جا تعریف می‌شود.
Future<void> openMovementSession(
  BuildContext context, {
  required MovementSession session,
  required MovementKind kind,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MovementSessionScreen(session: session, kind: kind),
    ),
  );
}

/// جریان شروع یک جلسه ورزشی جدید (با مدیریت و بررسی جلسات زندهٔ فعال قبلی)
Future<void> startMovementSessionFlow(
  BuildContext context,
  MovementKind kind,
) async {
  RitmoHaptics.tap();
  final active = await MovementSessionRepository.instance.getActiveSession();

  if (active != null) {
    // نمایش دیالوگ مدیریت جلسه فعال
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'جلسهٔ زندهٔ ناتمام',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'یک جلسهٔ ورزشی ناتمام پیدا شد. می‌خواهی چه کار کنی؟',
            style: TextStyle(),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await MovementSessionRepository.instance.abandonSession(
                  active.id,
                );
                // پس از حذف، جلسه جدید را استارت می‌زنیم
                if (context.mounted) {
                  await _startAndOpenNewSession(context, kind);
                }
              },
              child: const Text(
                'حذف قبلی',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await MovementSessionRepository.instance.finishSession(
                  active.id,
                );
                // پس از ذخیره، جلسه جدید را استارت می‌زنیم
                if (context.mounted) {
                  await _startAndOpenNewSession(context, kind);
                }
              },
              child: const Text(
                'پایان و ذخیره قبلی',
                style: TextStyle(color: Colors.amber),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                // ادامه جلسه قبلی
                final kinds = await MovementRepository.instance.getKinds();
                final activeKind = kinds.firstWhere(
                  (k) => k.code == active.kindCode,
                  orElse: () => kind,
                );
                if (context.mounted) {
                  await openMovementSession(
                    context,
                    session: active,
                    kind: activeKind,
                  );
                }
              },
              child: const Text(
                'ادامهٔ قبلی',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  } else {
    if (context.mounted) {
      await _startAndOpenNewSession(context, kind);
    }
  }
}

Future<void> _startAndOpenNewSession(
  BuildContext context,
  MovementKind kind,
) async {
  final mode = effectiveMode(kind);
  final session = await MovementSessionRepository.instance.startSession(
    kind: kind,
    sessionMode: mode.code,
    target: null,
  );
  if (context.mounted) {
    await openMovementSession(context, session: session, kind: kind);
  }
}
