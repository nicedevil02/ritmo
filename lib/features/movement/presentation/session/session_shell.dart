import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/secondary_actions_row.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_app_bar.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_primary_cta.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_status_strip.dart';

/// اسکلت ثابت و غیرقابل تغییر ساختار جلسهٔ زنده (SessionShell)
class SessionShell extends StatelessWidget {
  const SessionShell({
    super.key,
    required this.appBar,
    required this.status,
    required this.content,
    required this.secondary,
    required this.primary,
  });

  final SessionAppBar appBar;
  final SessionStatusStrip status;
  final Widget content;
  final SecondaryActionsRow secondary;
  final SessionPrimaryCta primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: appBar,
      body: SafeArea(
        child: Column(
          children: [
            status,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
                child: content,
              ),
            ),
            secondary,
            primary,
          ],
        ),
      ),
    );
  }
}
