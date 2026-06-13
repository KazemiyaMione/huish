import 'package:flutter/material.dart';

/// Displays current score in an M3-styled card.
class ScoreHeader extends StatelessWidget {
  final Map<String, dynamic> scoreInfo;
  const ScoreHeader({super.key, required this.scoreInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = scoreInfo['score'] as String? ?? '0';
    final totalScore = scoreInfo['totalScore'] as String? ?? '0';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('可用积分',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer.withAlpha(180))),
          const SizedBox(height: 6),
          Text(score,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimaryContainer.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('累计获得: $totalScore',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}
