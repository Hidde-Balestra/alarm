import 'dart:math';

/// A generated arithmetic problem used to gate dismissing an alarm — hard
/// enough to require actually waking up, easy enough to solve without paper.
class MathChallenge {
  final int a;
  final int b;
  final String operator;
  final int answer;

  const MathChallenge._({
    required this.a,
    required this.b,
    required this.operator,
    required this.answer,
  });

  factory MathChallenge.generate([Random? random]) {
    final rng = random ?? Random();
    switch (rng.nextInt(3)) {
      case 0:
        final a = rng.nextInt(50) + 10;
        final b = rng.nextInt(50) + 10;
        return MathChallenge._(a: a, b: b, operator: '+', answer: a + b);
      case 1:
        final a = rng.nextInt(50) + 20;
        final b = rng.nextInt(a);
        return MathChallenge._(a: a, b: b, operator: '-', answer: a - b);
      default:
        final a = rng.nextInt(10) + 2;
        final b = rng.nextInt(10) + 2;
        return MathChallenge._(a: a, b: b, operator: '×', answer: a * b);
    }
  }

  String get question => '$a $operator $b';

  bool check(String input) => int.tryParse(input.trim()) == answer;
}
