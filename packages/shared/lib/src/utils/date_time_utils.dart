/// Date and time utility functions
class DateTimeUtils {
  /// Format DateTime to readable string
  static String formatDateTime(DateTime dateTime, {bool includeTime = true}) {
    if (includeTime) {
      return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
    }
    return _formatDate(dateTime);
  }

  /// Format date only
  static String formatDate(DateTime dateTime) {
    return _formatDate(dateTime);
  }

  /// Format time only
  static String formatTime(DateTime dateTime) {
    return _formatTime(dateTime);
  }

  /// Get relative time string (e.g., "2 hours ago")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if date is today
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  /// Get days until a future date
  static int daysUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    return difference.inDays;
  }

  /// Check if date is in the past
  static bool isPast(DateTime dateTime) {
    return dateTime.isBefore(DateTime.now());
  }

  /// Check if date is in the future
  static bool isFuture(DateTime dateTime) {
    return dateTime.isAfter(DateTime.now());
  }

  // Private helper methods
  static String _formatDate(DateTime dateTime) {
    return '${_padZero(dateTime.month)}/${_padZero(dateTime.day)}/${dateTime.year}';
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${_padZero(hour)}:${_padZero(dateTime.minute)} $period';
  }

  static String _padZero(int value) {
    return value.toString().padLeft(2, '0');
  }
}
