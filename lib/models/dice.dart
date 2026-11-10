import 'dart:math';

enum RollMode { normal, advantage, disadvantage }

class DiceTerm {
  const DiceTerm({
    required this.sign,
    this.count = 0,
    this.sides = 0,
    this.constant = 0,
    this.mode = RollMode.normal,
  });

  final int sign;
  final int count;
  final int sides;
  final int constant;
  final RollMode mode;

  String get notation {
    final dice = '${count}d$sides';
    return count == 0
        ? '$constant'
        : switch (mode) {
            RollMode.normal => dice,
            RollMode.advantage => 'adv($dice)',
            RollMode.disadvantage => 'dis($dice)',
          };
  }
}

class DiceExpression {
  DiceExpression._(this.terms);
  final List<DiceTerm> terms;

  factory DiceExpression.parse(String input) {
    final source = input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('−', '-');
    if (source.isEmpty || source.length > 300) {
      throw const FormatException('Enter an equation, like 2d6 + 3.');
    }
    final token = RegExp(
      r'(adv\((?:1)?d\d+\)|dis\((?:1)?d\d+\)|2d\d+k[hl]1|\d*d\d+|\d+)',
    );
    final terms = <DiceTerm>[];
    var position = 0;
    while (position < source.length) {
      var sign = 1;
      if (source[position] == '+' || source[position] == '-') {
        sign = source[position] == '-' ? -1 : 1;
        position++;
      } else if (terms.isNotEmpty) {
        throw const FormatException('Separate terms with + or −.');
      }
      final match = token.matchAsPrefix(source, position);
      if (match == null) {
        throw const FormatException(
          'Use dice (2d6), numbers, adv(d20), or dis(d20).',
        );
      }
      final value = match[0]!;
      if (!value.contains('d')) {
        final number = int.tryParse(value);
        if (number == null || number > 10000) {
          throw const FormatException(
            'Fixed numbers must be between 0 and 10,000.',
          );
        }
        terms.add(DiceTerm(sign: sign, constant: number));
      } else {
        final dice = RegExp(r'(\d*)d(\d+)').firstMatch(value)!;
        final mode = value.startsWith('adv') || value.endsWith('kh1')
            ? RollMode.advantage
            : value.startsWith('dis') || value.endsWith('kl1')
            ? RollMode.disadvantage
            : RollMode.normal;
        final count = mode == RollMode.normal
            ? (dice[1]!.isEmpty ? 1 : int.tryParse(dice[1]!) ?? 0)
            : 1;
        final sides = int.tryParse(dice[2]!) ?? 0;
        if (count < 1 || count > 20 || sides < 2 || sides > 1000) {
          throw const FormatException('Use 1–20 dice with 2–1,000 sides each.');
        }
        terms.add(DiceTerm(sign: sign, count: count, sides: sides, mode: mode));
      }
      position = match.end;
      if (terms.length > 20) {
        throw const FormatException('Use at most 20 terms per equation.');
      }
    }
    if (!terms.any((term) => term.count > 0)) {
      throw const FormatException('Include at least one die, like 1d20 + 7.');
    }
    return DiceExpression._(List.unmodifiable(terms));
  }

  String get notation => terms.indexed.map((entry) {
    final (index, term) = entry;
    return '${index == 0 ? (term.sign < 0 ? '−' : '') : (term.sign < 0 ? ' − ' : ' + ')}${term.notation}';
  }).join();

  RolledQuestion roll(Random random) {
    final numbers = <RolledNumber>[];
    for (final term in terms) {
      if (term.count == 0) {
        numbers.add(RolledNumber(sign: term.sign, values: [term.constant]));
      } else if (term.mode != RollMode.normal) {
        numbers.add(
          RolledNumber(
            sign: term.sign,
            mode: term.mode,
            values: List.generate(2, (_) => random.nextInt(term.sides) + 1),
          ),
        );
      } else {
        for (var i = 0; i < term.count; i++) {
          numbers.add(
            RolledNumber(
              sign: term.sign,
              values: [random.nextInt(term.sides) + 1],
            ),
          );
        }
      }
    }
    return RolledQuestion(notation, List.unmodifiable(numbers));
  }
}

class RolledNumber {
  const RolledNumber({
    required this.sign,
    required this.values,
    this.mode = RollMode.normal,
  });
  final int sign;
  final List<int> values;
  final RollMode mode;
  int get value =>
      sign *
      switch (mode) {
        RollMode.normal => values.first,
        RollMode.advantage => values.reduce(max),
        RollMode.disadvantage => values.reduce(min),
      };
  String get display => mode == RollMode.normal
      ? '${values.first}'
      : '${mode == RollMode.advantage ? '↑' : '↓'}(${values.join(', ')})';
}

class RolledQuestion {
  const RolledQuestion(this.equation, this.numbers);
  final String equation;
  final List<RolledNumber> numbers;
  int get total => numbers.fold(0, (sum, number) => sum + number.value);
  String get calculation => numbers.indexed.map((entry) {
    final (index, number) = entry;
    final sign = index == 0
        ? (number.sign < 0 ? '−' : '')
        : (number.sign < 0 ? ' − ' : ' + ');
    return '$sign${number.display}';
  }).join();
}
