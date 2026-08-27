import 'package:alarm_app/app.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveEffectiveLocale', () {
    test('an explicit Dutch setting wins regardless of the device locale', () {
      const settings = AppSettings(language: AppLanguage.dutch);
      expect(resolveEffectiveLocale(settings), const Locale('nl'));
    });

    test('an explicit English setting wins regardless of the device locale', () {
      const settings = AppSettings(language: AppLanguage.english);
      expect(resolveEffectiveLocale(settings), const Locale('en'));
    });
  });
}
