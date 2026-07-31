/// Short, human date labels without pulling in `intl`.
String relativeTime(DateTime when) {
  final DateTime now = DateTime.now();
  final Duration diff = now.difference(when);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24 && _sameDay(now, when)) return '${diff.inHours}h ago';

  final DateTime yesterday = now.subtract(const Duration(days: 1));
  if (_sameDay(yesterday, when)) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final String label = '${months[when.month - 1]} ${when.day}';
  return when.year == now.year ? label : '$label, ${when.year}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
