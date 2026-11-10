import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';

class EquationsScreen extends StatelessWidget {
  const EquationsScreen({required this.store, super.key});
  final PracticeStore store;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final controller = TextEditingController(
      text: index == null ? '' : store.equations[index].expression.notation,
    );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void save() {
            try {
              store.putEquation(controller.text, index: index);
              Navigator.pop(context);
            } on FormatException catch (e) {
              setState(() => error = e.message);
            }
          }

          return AlertDialog(
            title: Text(index == null ? 'Add an equation' : 'Edit equation'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      hintText: '2d6 + 3',
                      errorText: error,
                      errorMaxLines: 3,
                      labelText: 'Dice equation',
                    ),
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Try 1d20 + 7, 2d4, or 2d6 + 1d4 − 2.\nUse adv(d20) or dis(d20) to roll two and keep the higher or lower number.',
                    style: TextStyle(color: muted, fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(onPressed: save, child: const Text('Save equation')),
            ],
          );
        },
      ),
    );
    // Wait for the dialog's exit transition before disposing its text controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(26, 32, 26, 32),
    children: [
      const SectionLabel('Your collection'),
      const SizedBox(height: 10),
      Text('Equations', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 10),
      const Text(
        'New rolls are drawn equally from enabled equations. Missed rolls can return for review.',
        style: TextStyle(color: muted, height: 1.6),
      ),
      const SizedBox(height: 26),
      ...store.equations.indexed.map((entry) {
        final (index, equation) = entry;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(
              children: [
                Semantics(
                  label: 'Enable ${equation.expression.notation}',
                  child: Switch(
                    value: equation.enabled,
                    onChanged: (_) => store.toggle(index),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _edit(context, index),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        equation.expression.notation,
                        style: TextStyle(
                          fontSize: 18,
                          color: equation.enabled ? null : muted,
                        ),
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Equation options',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _edit(context, index);
                    } else {
                      store.remove(index);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
      if (store.equations.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Text(
            'Your collection is empty. Add your first equation below.',
            style: TextStyle(color: muted),
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add equation'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: gold.withValues(alpha: .4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      const SizedBox(height: 30),
      const SectionLabel('Advantage & disadvantage'),
      const SizedBox(height: 14),
      const Text(
        'adv(d20) + 7     ·     dis(d20) + 2',
        style: TextStyle(color: gold),
      ),
      const SizedBox(height: 10),
      const Text(
        'During practice, ↑(4, 18) means keep 18.\n↓(4, 18) means keep 4. Then do the math.\n\nYou can also write 2d20kh1 or 2d20kl1.',
        style: TextStyle(color: muted, fontSize: 13, height: 1.7),
      ),
    ],
  );
}
