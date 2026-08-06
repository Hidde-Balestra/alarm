import 'dart:math';

import 'package:alarm_app/models/math_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check() accepts the correct answer', () {
    final challenge = MathChallenge.generate(Random(1));
    expect(challenge.check(challenge.answer.toString()), isTrue);
  });

  test('check() rejects a wrong answer', () {
    final challenge = MathChallenge.generate(Random(1));
    expect(challenge.check((challenge.answer + 1).toString()), isFalse);
  });

  test('check() rejects non-numeric input instead of throwing', () {
    final challenge = MathChallenge.generate(Random(1));
    expect(challenge.check('not a number'), isFalse);
  });

  test('generated subtraction problems never produce a negative answer', () {
    for (var seed = 0; seed < 50; seed++) {
      final challenge = MathChallenge.generate(Random(seed));
      expect(challenge.answer, greaterThanOrEqualTo(0));
    }
  });
}
