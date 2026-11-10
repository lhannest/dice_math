class Attempt {
  const Attempt({
    required this.at,
    required this.equation,
    required this.calculation,
    required this.answer,
    required this.expected,
    required this.milliseconds,
    this.streak = 0,
  });
  final DateTime at;
  final String equation;
  final String calculation;
  final int answer;
  final int expected;
  final int milliseconds;
  final int streak;
  bool get correct => answer == expected;
  double get seconds => milliseconds / 1000;

  Map<String, Object> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'equation': equation,
    'calculation': calculation,
    'answer': answer,
    'expected': expected,
    'milliseconds': milliseconds,
    'streak': streak,
  };
  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
    at: DateTime.parse(json['at'] as String),
    equation: json['equation'] as String,
    calculation: json['calculation'] as String,
    answer: json['answer'] as int,
    expected: json['expected'] as int,
    milliseconds: json['milliseconds'] as int,
    streak: json['streak'] as int? ?? 0,
  );
}

class PracticeStats {
  PracticeStats(Iterable<Attempt> attempts) : attempts = attempts.toList();
  final List<Attempt> attempts;
  int get count => attempts.length;
  int get correct => attempts.where((a) => a.correct).length;
  double get accuracy => count == 0 ? 0 : correct / count;
  double? get medianSeconds {
    final times =
        attempts.where((a) => a.correct).map((a) => a.seconds).toList()..sort();
    if (times.isEmpty) return null;
    final middle = times.length ~/ 2;
    return times.length.isOdd
        ? times[middle]
        : (times[middle - 1] + times[middle]) / 2;
  }

  int get bestStreak {
    var best = 0;
    for (final attempt in attempts) {
      if (attempt.streak > best) best = attempt.streak;
    }
    return best;
  }
}
