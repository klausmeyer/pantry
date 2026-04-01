import 'package:flutter/cupertino.dart';

class BestBeforeBadge extends StatelessWidget {
  const BestBeforeBadge({super.key, required this.bestBefore});

  final String bestBefore;

  @override
  Widget build(BuildContext context) {
    final delta = bestBeforeDeltaDays(bestBefore);
    final label = bestBeforeLabel(bestBefore);
    final colors = bestBeforeColors(context, delta);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

int bestBeforeDeltaDays(String bestBefore) {
  final today = _startOfUtcDate(DateTime.now());
  final target = _startOfUtcDate(DateTime.parse('${bestBefore}T00:00:00Z'));
  const msPerDay = 24 * 60 * 60 * 1000;
  return ((target.millisecondsSinceEpoch - today.millisecondsSinceEpoch) / msPerDay)
      .round();
}

String bestBeforeLabel(String bestBefore) {
  final delta = bestBeforeDeltaDays(bestBefore);
  final dayWord = _dayWord(delta.abs());
  if (delta < 0) {
    final days = delta.abs();
    return '$days $dayWord overdue';
  }
  if (delta == 0) {
    return 'Expires today';
  }
  return '$delta ${_dayWord(delta)} left';
}

BestBeforeColors bestBeforeColors(BuildContext context, int delta) {
  if (delta <= 0) {
    return BestBeforeColors(
      background: CupertinoColors.systemRed.withValues(alpha: 0.2),
      foreground: CupertinoColors.systemRed,
    );
  }
  if (delta >= 30) {
    return BestBeforeColors(
      background: CupertinoColors.systemGreen.withValues(alpha: 0.2),
      foreground: CupertinoColors.systemGreen,
    );
  }
  if (delta >= 14) {
    return BestBeforeColors(
      background: CupertinoColors.systemYellow.withValues(alpha: 0.2),
      foreground: CupertinoColors.systemYellow,
    );
  }
  return BestBeforeColors(
    background: CupertinoColors.systemOrange.withValues(alpha: 0.2),
    foreground: CupertinoColors.systemOrange,
  );
}

String _dayWord(int count) => count == 1 ? 'day' : 'days';

DateTime _startOfUtcDate(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day);
}

class BestBeforeColors {
  const BestBeforeColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
