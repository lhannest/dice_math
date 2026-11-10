import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dice_math/models/dice.dart';

class SequenceRandom implements Random {
  SequenceRandom(this.values);
  final List<int> values;
  int _index = 0;
  @override
  int nextInt(int max) => values[_index++ % values.length] % max;
  @override
  bool nextBool() => nextInt(2) == 1;
  @override
  double nextDouble() => nextInt(1000) / 1000;
}

void main() {
  test('expands dice into actual numbers, preserving subtraction signs', () {
    final question = DiceExpression.parse(
      '2d6 - 2d4 + 3',
    ).roll(SequenceRandom([1, 5, 2, 0]));
    expect(question.calculation, '2 + 6 − 3 − 1 + 3');
    expect(question.total, 7);
  });

  test('advantage and disadvantage keep the appropriate die independently', () {
    final question = DiceExpression.parse(
      'adv(d20) + dis(d20) - 2',
    ).roll(SequenceRandom([3, 17, 3, 17]));
    expect(question.calculation, '↑(4, 18) + ↓(4, 18) − 2');
    expect(question.total, 20);
    expect(
      DiceExpression.parse('2d20kh1 + 2d20kl1').notation,
      'adv(1d20) + dis(1d20)',
    );
  });

  test('normalizes shorthand, whitespace, case, and unicode minus', () {
    expect(DiceExpression.parse(' D20 + 2D6 − 3 ').notation, '1d20 + 2d6 − 3');
    final negative = DiceExpression.parse('-d4 + 1').roll(SequenceRandom([3]));
    expect(negative.total, -3);
    expect(negative.calculation, '−4 + 1');
  });

  test('rejects incomplete, ambiguous, or excessive expressions', () {
    for (final source in [
      '',
      '2',
      '0d20',
      '1d1',
      '21d6',
      '1d1001',
      'd20 +',
      'd20 ++ 2',
      'adv(2d20)',
      'd20 * 2',
      'd20junk',
      'd20 + 10001',
      List.filled(21, 'd6').join('+'),
    ]) {
      expect(
        () => DiceExpression.parse(source),
        throwsFormatException,
        reason: source,
      );
    }
  });

  test('all standard dice roll within inclusive bounds', () {
    final random = Random(42);
    for (final sides in [4, 6, 8, 10, 12, 20, 100]) {
      final expression = DiceExpression.parse('1d$sides');
      final values = List.generate(1000, (_) => expression.roll(random).total);
      expect(values.every((v) => v >= 1 && v <= sides), isTrue);
      expect(values.contains(1), isTrue);
      expect(values.contains(sides), isTrue);
    }
  });
}
