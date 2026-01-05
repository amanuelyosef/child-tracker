/// Formats a DateTime to time string (HH:MM:SS)
String formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

/// Formats a DateTime to short date string (MMM DD, YYYY)
String formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
}

/// Formats a DateTime to full date-time string
String formatDateTime(DateTime dt) {
  return '${formatDate(dt)} at ${formatTime(dt)}';
}
