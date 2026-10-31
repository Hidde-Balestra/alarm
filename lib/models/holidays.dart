/// Dutch public holidays a repeating alarm can be set to skip — see
/// `Alarm.skipHolidays`.
///
/// Liberation Day (5 May) is only included in lustrum years (2025, 2030,
/// ...), the years it's widely a day off; in other years most people work.
/// Good Friday is left out entirely for the same reason.
enum DutchHoliday {
  newYearsDay,
  easterSunday,
  easterMonday,
  kingsDay,
  liberationDay,
  ascensionDay,
  whitSunday,
  whitMonday,
  christmasDay,
  boxingDay,
}

/// Easter Sunday for [year] (Gregorian calendar), via the anonymous
/// Gregorian algorithm (Meeus/Jones/Butcher).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Which Dutch public holiday [date] falls on, if any (time of day ignored).
DutchHoliday? dutchHolidayOn(DateTime date) {
  final year = date.year;
  final day = DateTime(year, date.month, date.day);

  if (date.month == 1 && date.day == 1) return DutchHoliday.newYearsDay;
  if (date.month == 12 && date.day == 25) return DutchHoliday.christmasDay;
  if (date.month == 12 && date.day == 26) return DutchHoliday.boxingDay;
  if (date.month == 5 && date.day == 5 && year % 5 == 0) return DutchHoliday.liberationDay;

  // King's Day moves to the 26th when the 27th falls on a Sunday.
  final kingsDay = DateTime(year, 4, 27).weekday == DateTime.sunday
      ? DateTime(year, 4, 26)
      : DateTime(year, 4, 27);
  if (day == kingsDay) return DutchHoliday.kingsDay;

  // Calendar-day offsets (not Duration arithmetic) so DST changes between
  // Easter and these dates can't shift the result by an hour into the
  // wrong day.
  final easter = easterSunday(year);
  DateTime fromEaster(int days) => DateTime(year, easter.month, easter.day + days);
  if (day == easter) return DutchHoliday.easterSunday;
  if (day == fromEaster(1)) return DutchHoliday.easterMonday;
  if (day == fromEaster(39)) return DutchHoliday.ascensionDay;
  if (day == fromEaster(49)) return DutchHoliday.whitSunday;
  if (day == fromEaster(50)) return DutchHoliday.whitMonday;

  return null;
}
