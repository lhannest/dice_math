import 'package:flutter/material.dart';
import '../models/history.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/die_mark.dart';
import 'equations.dart';
import 'practice.dart';
import 'progress.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store, super.key});
  final PracticeStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => !widget.store.isLoaded
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_off_outlined,
                        color: gold,
                        size: 40,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Couldn’t open your saved practice.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your saved data has been left in place.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.store.load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      if (widget.store.storageError != null)
                        MaterialBanner(
                          content: Text(widget.store.storageError!),
                          actions: [
                            TextButton(
                              onPressed: widget.store.retrySave,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: switch (_tab) {
                          0 => _PracticeHome(
                            store: widget.store,
                            onEquations: () => setState(() => _tab = 1),
                          ),
                          1 => EquationsScreen(store: widget.store),
                          _ => ProgressScreen(store: widget.store),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.casino_outlined),
                  selectedIcon: Icon(Icons.casino),
                  label: 'Practice',
                ),
                NavigationDestination(
                  icon: Icon(Icons.functions),
                  label: 'Equations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Progress',
                ),
              ],
            ),
          ),
  );
}

class _PracticeHome extends StatelessWidget {
  const _PracticeHome({required this.store, required this.onEquations});
  final PracticeStore store;
  final VoidCallback onEquations;
  @override
  Widget build(BuildContext context) {
    final stats = PracticeStats(store.attempts);
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 32),
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: gold, size: 18),
            const SizedBox(width: 10),
            Text(
              'DICE MATH',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: gold),
            ),
          ],
        ),
        const SizedBox(height: 38),
        const Center(child: DieMark()),
        const SizedBox(height: 25),
        Text(
          'Less counting.\nMore adventuring.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 14),
        const Text(
          'A little practice. A quicker turn at the table.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.5),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: store.enabled.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PracticeScreen(store: store),
                  ),
                ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Start practicing'),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          store.enabled.isEmpty
              ? 'Enable an equation to start practicing.'
              : 'No rounds. No countdown. Just you and the numbers.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 34),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('In your rotation'),
            TextButton(onPressed: onEquations, child: const Text('Edit')),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: store.enabled
              .map(
                (e) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e.notation, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
        ),
        if (stats.count > 0) ...[
          const SizedBox(height: 30),
          SurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: _SmallStat('${stats.bestStreak}', 'Best streak'),
                ),
                Expanded(
                  child: _SmallStat(
                    '${(stats.accuracy * 100).round()}%',
                    'Accuracy',
                  ),
                ),
                Expanded(
                  child: _SmallStat(
                    stats.medianSeconds == null
                        ? '—'
                        : '${stats.medianSeconds!.toStringAsFixed(1)}s',
                    'Typical time',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          color: gold,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: muted),
      ),
    ],
  );
}
