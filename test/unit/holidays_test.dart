import 'package:alarm_app/models/holidays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('easterSunday matches known dates', () {
    expect(easterSunday(2024), DateTime(2024, 3, 31));
    expect(easterSunday(2025), DateTime(2025, 4, 20));
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
  });

  test('fixed-date holidays are recognized regardless of time of day', () {
    expect(dutchHolidayOn(DateTime(2026, 1, 1, 7, 30)), DutchHoliday.newYearsDay);
    expect(dutchHolidayOn(DateTime(2026, 12, 25, 23, 59)), DutchHoliday.christmasDay);
    expect(dutchHolidayOn(DateTime(2026, 12, 26)), DutchHoliday.boxingDay);
  });

  test('Easter-based holidays follow Easter', () {
    expect(dutchHolidayOn(DateTime(2026, 4, 5)), DutchHoliday.easterSunday);
    expect(dutchHolidayOn(DateTime(2026, 4, 6)), DutchHoliday.easterMonday);
    expect(dutchHolidayOn(DateTime(2026, 5, 14)), DutchHoliday.ascensionDay);
    expect(dutchHolidayOn(DateTime(2026, 5, 24)), DutchHoliday.whitSunday);
    expect(dutchHolidayOn(DateTime(2026, 5, 25)), DutchHoliday.whitMonday);
  });

  test("King's Day moves to the 26th when the 27th is a Sunday", () {
    // 27 April 2025 was a Sunday.
    expect(dutchHolidayOn(DateTime(2025, 4, 26)), DutchHoliday.kingsDay);
    expect(dutchHolidayOn(DateTime(2025, 4, 27)), isNull);
    expect(dutchHolidayOn(DateTime(2026, 4, 27)), DutchHoliday.kingsDay);
  });

  test('Liberation Day only counts in lustrum years', () {
    expect(dutchHolidayOn(DateTime(2025, 5, 5)), DutchHoliday.liberationDay);
    expect(dutchHolidayOn(DateTime(2026, 5, 5)), isNull);
    expect(dutchHolidayOn(DateTime(2030, 5, 5)), DutchHoliday.liberationDay);
  });

  test('an ordinary day is not a holiday', () {
    expect(dutchHolidayOn(DateTime(2026, 10, 31)), isNull);
    // Good Friday is deliberately not included.
    expect(dutchHolidayOn(DateTime(2026, 4, 3)), isNull);
  });
}
