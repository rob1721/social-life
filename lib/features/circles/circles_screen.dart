import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../models/circle.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Mis redes privadas: crear, invitar por email, ver miembros y salir.
class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis redes')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.group_add),
        label: const Text('Nueva red'),
        onPressed: () => _createCircle(context, ref),
      ),
      body: circles.when(
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [for (final c in list) _CircleCard(circle: c)],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _createCircle(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var kind = CircleKind.friends;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Nueva red'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              DropdownButton<CircleKind>(
                value: kind,
                isExpanded: true,
                items: [
                  for (final k in CircleKind.values)
                    if (k != CircleKind.personal)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (k) => setState(() => kind = k ?? kind),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    final uid = ref.read(currentUidProvider);
    if (ok == true &&
        name.text.trim().isNotEmpty &&
        uid != null &&
        context.mounted) {
      await runWithFeedback(
        context,
        () => ref
            .read(circleRepositoryProvider)
            .createCircle(ownerId: uid, name: name.text.trim(), kind: kind),
      );
    }
    name.dispose();
  }
}

class _CircleCard extends ConsumerWidget {
  const _CircleCard({required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final repo = ref.read(circleRepositoryProvider);
    final isOwner = circle.ownerId == uid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${circle.name} · ${circle.kind.label}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!isOwner)
                  TextButton(
                    onPressed: () => runWithFeedback(
                      context,
                      () => repo.leaveCircle(circle.id, uid!),
                    ),
                    child: const Text('Salir'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final m in circle.memberIds)
                  InkWell(
                    onTap: () => context.push(Routes.user(m)),
                    child: UserAvatar(uid: m),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Invitar por email'),
                onPressed: () => _invite(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Invitar a ${circle.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Gmail de la persona'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Invitar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final me = ref.read(currentUserProvider).value;
    if (email == null ||
        !email.contains('@') ||
        me == null ||
        !context.mounted) {
      return;
    }
    await runWithFeedback(
      context,
      () => ref
          .read(circleRepositoryProvider)
          .invite(circle: circle, inviter: me, email: email),
      success: 'Invitación enviada a $email',
    );
  }
}
