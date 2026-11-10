import 'dart:math';
import 'package:flutter/material.dart';
import '../models/history.dart';
import '../store.dart';
import '../theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({required this.store, super.key});
  final PracticeStore store;
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _days = 7;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _days == 0
        ? null
        : DateTime(today.year, today.month, today.day - _days + 1);
    final attempts = widget.store.attempts
        .where((a) => start == null || !a.at.isBefore(start))
        .toList();
    final stats = PracticeStats(attempts);
    final groups = <DateTime, List<Attempt>>{};
    for (final attempt in attempts) {
      final local = attempt.at.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => []).add(attempt);
    }
    final daily =
        groups.entries
            .map((e) => _DayStats(e.key, PracticeStats(e.value)))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final byEquation = <String, List<Attempt>>{};
    for (final attempt in attempts) {
      byEquation.putIfAbsent(attempt.equation, () => []).add(attempt);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 32, 26, 32),
      children: [
        const SectionLabel('Every roll counts'),
        const SizedBox(height: 10),
        Text(
          'Your progress',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'Small gains add up. Find your rhythm.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 0, label: Text('All time')),
          ],
          selected: {_days},
          onSelectionChanged: (value) => setState(() => _days = value.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.comfortable),
        ),
        const SizedBox(height: 24),
        if (attempts.isEmpty) ...[
          const SizedBox(height: 42),
          const Icon(Icons.insights_rounded, color: gold, size: 48),
          const SizedBox(height: 22),
          Text(
            'Your next roll is a beginning.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Answer a few questions to see your accuracy,\nspeed, and progress over time here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.7),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _Metric(
                  '${(stats.accuracy * 100).toStringAsFixed(0)}%',
                  'Accuracy',
                  '${stats.correct} of ${stats.count} correct',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  stats.medianSeconds == null
                      ? '—'
                      : '${stats.medianSeconds!.toStringAsFixed(1)}s',
                  'Typical time',
                  'Median · correct answers',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${stats.count} answered  ·  ${stats.bestStreak} best streak',
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          if (attempts.length >= 40) ...[
            const SizedBox(height: 20),
            _Comparison(attempts: attempts),
          ],
          const SizedBox(height: 26),
          _TrendCard(
            title: 'Accuracy over time',
            daily: daily,
            start: start,
            end: today,
            speed: false,
          ),
          const SizedBox(height: 14),
          _TrendCard(
            title: 'Speed over time',
            daily: daily,
            start: start,
            end: today,
            speed: true,
          ),
          const SizedBox(height: 28),
          const SectionLabel('By equation'),
          const SizedBox(height: 14),
          ...byEquation.entries.map((entry) {
            final item = PracticeStats(entry.value);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(item.accuracy * 100).round()}% correct  ·  ${item.medianSeconds == null ? '—' : '${item.medianSeconds!.toStringAsFixed(1)}s'} typical  ·  ${item.count} answered',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    if (entry.value.length >= 40) ...[
                      const SizedBox(height: 10),
                      _Comparison(attempts: entry.value, compact: true),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const SectionLabel('Recent answers'),
          const SizedBox(height: 12),
          ...attempts.reversed
              .take(10)
              .map(
                (attempt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        attempt.correct
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: attempt.correct ? success : failure,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${attempt.calculation} = ${attempt.expected}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              '${_date(attempt.at.toLocal())} · ${attempt.at.toLocal().hour.toString().padLeft(2, '0')}:${attempt.at.toLocal().minute.toString().padLeft(2, '0')}${attempt.correct ? '' : ' · entered ${attempt.answer}'}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${attempt.seconds.toStringAsFixed(1)}s',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 10),
          const Text(
            'Only submitted answers count. Leaving practice adds nothing to your history.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
        ],
      ],
    );
  }
}

String _date(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.detail);
  final String value;
  final String label;
  final String detail;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            color: gold,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(detail, style: const TextStyle(color: muted, fontSize: 10)),
      ],
    ),
  );
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.attempts, this.compact = false});
  final List<Attempt> attempts;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final recent = PracticeStats(attempts.skip(attempts.length - 20));
    final earlier = PracticeStats(attempts.skip(attempts.length - 40).take(20));
    final accuracyDelta = ((recent.accuracy - earlier.accuracy) * 100).round();
    final before = earlier.medianSeconds;
    final after = recent.medianSeconds;
    final parts = <String>[];
    if (before != null && after != null) {
      final delta = after - before;
      parts.add(
        '${delta.abs().toStringAsFixed(1)}s ${delta <= 0 ? 'faster' : 'slower'}',
      );
    }
    parts.add('${accuracyDelta >= 0 ? '+' : ''}$accuracyDelta pts accuracy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.join(' · '),
          style: TextStyle(color: gold, fontSize: compact ? 12 : 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Last 20 answers vs previous 20',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _DayStats {
  const _DayStats(this.date, this.stats);
  final DateTime date;
  final PracticeStats stats;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.daily,
    required this.start,
    required this.end,
    required this.speed,
  });
  final String title;
  final List<_DayStats> daily;
  final DateTime? start;
  final DateTime end;
  final bool speed;
  @override
  Widget build(BuildContext context) {
    final points = daily
        .where((day) => !speed || day.stats.medianSeconds != null)
        .toList();
    final values = points
        .map(
          (day) => speed ? day.stats.medianSeconds! : day.stats.accuracy * 100,
        )
        .toList();
    final upper = speed
        ? max(1.0, values.fold(0.0, max) * 1.2).ceilToDouble()
        : 100.0;
    final from =
        start ??
        (daily.first.date.isBefore(end)
            ? daily.first.date
            : DateTime(end.year, end.month, end.day - 1));
    final to = end;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            speed
                ? 'Daily median · correct answers · lower is quicker'
                : 'Daily accuracy · higher is better',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 22),
          if (points.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Correct answers will appear here.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            )
          else
            Semantics(
              label: points
                  .map(
                    (p) =>
                        '${_date(p.date)}: ${speed ? '${p.stats.medianSeconds!.toStringAsFixed(1)} seconds' : '${(p.stats.accuracy * 100).round()} percent correct'}',
                  )
                  .join('. '),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    height: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          speed ? '${upper.toStringAsFixed(0)}s' : '100%',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                        Text(
                          speed ? '0s' : '0%',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: CustomPaint(
                        painter: _TrendPainter(
                          points: points.indexed
                              .map(
                                (e) => Offset(
                                  (e.$2.date.difference(from).inMilliseconds /
                                          to.difference(from).inMilliseconds)
                                      .clamp(0.0, 1.0),
                                  values[e.$1] / upper,
                                ),
                              )
                              .toList(),
                          color: speed ? gold : success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _date(from),
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
                Text(
                  _date(to),
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points, required this.color});
  final List<Offset> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = muted.withValues(alpha: .15)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      canvas.drawLine(
        Offset(0, 5 + (size.height - 10) * i / 2),
        Offset(size.width, 5 + (size.height - 10) * i / 2),
        grid,
      );
    }
    final offsets = points
        .map(
          (p) => Offset(
            5 + p.dx * (size.width - 10),
            5 + (1 - p.dy) * (size.height - 10),
          ),
        )
        .toList();
    if (offsets.length > 1) {
      final path = Path()..addPolygon(offsets, false);
      final fill = Path.from(path)
        ..lineTo(offsets.last.dx, size.height)
        ..lineTo(offsets.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .16), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final point in offsets) {
      canvas.drawCircle(point, 4, Paint()..color = color);
      canvas.drawCircle(point, 1.5, Paint()..color = panel);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
