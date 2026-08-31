import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';

/// Unified Empty State Widget powered by RitmoNeuEmptyCard.
class MvEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: RitmoNeuEmptyCard(
        title: title,
        subtitle: description,
        icon: icon,
        actionLabel: actionLabel,
        onActionTap: onAction,
      ),
    );
  }
}
