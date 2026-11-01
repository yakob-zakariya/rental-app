import 'package:clock/clock.dart';

/// Africa/Addis_Ababa is UTC+3 all year (Ethiopia has no daylight saving),
/// so a fixed offset is exact and no time-zone package is needed.
const addisAbabaOffset = Duration(hours: 3);

/// [instant] as Addis Ababa wall-clock time. The result is a UTC `DateTime`
/// whose fields (hour, day, ...) read as Addis Ababa time.
DateTime toAddisAbaba(DateTime instant) =>
    instant.toUtc().add(addisAbabaOffset);

/// "14:30" (24-hour) for [instant] in Addis Ababa.
String formatAddisTime(DateTime instant) {
  final t = toAddisAbaba(instant);
  return '${_two(t.hour)}:${_two(t.minute)}';
}

/// Whether [instant] falls on today's date in Addis Ababa ("now" from
/// `clock`, so tests can set it).
bool isTodayInAddis(DateTime instant) {
  final t = toAddisAbaba(instant);
  final now = toAddisAbaba(clock.now());
  return t.year == now.year && t.month == now.month && t.day == now.day;
}

String _two(int n) => n.toString().padLeft(2, '0');
