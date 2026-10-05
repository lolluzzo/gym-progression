/// Monday of the week [date] falls in, at local midnight.
DateTime mondayOf(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day - (date.weekday - DateTime.monday),
  );
}

/// The week's Monday as `yyyy-MM-dd`. Workouts and completions use it to
/// tell which week they belong to.
String weekKeyFor(DateTime date) {
  final monday = mondayOf(date);
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${monday.year}-${twoDigits(monday.month)}-${twoDigits(monday.day)}';
}

DateTime mondayFromWeekKey(String weekKey) {
  final parts = weekKey.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
