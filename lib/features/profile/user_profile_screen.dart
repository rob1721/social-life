import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../widgets/common.dart';

/// Perfil de otra persona. Siempre muestra el nombre y correo de Google
/// además del apodo, y permite asignarle un color local.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(uid)).value;
    final localColor = ref.watch(localColorsProvider)[uid];
    final colors = ref.read(localColorsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(user?.displayName ?? '')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(child: UserAvatar(uid: uid, radius: 48)),
                const SizedBox(height: 16),
                if (user.nickname?.isNotEmpty ?? false)
                  Center(
                    child: Text(
                      user.nickname!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                Center(child: Text(user.googleName)),
                Center(child: Text(user.email)),
                const SizedBox(height: 32),
                Text(
                  'Color de sus post-its (solo en tu dispositivo)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ColorPalettePicker(
                  selected: ref.watch(userColorProvider(uid)),
                  onSelected: (c) => colors.setColor(uid, c),
                ),
                if (localColor != null)
                  TextButton(
                    onPressed: () => colors.setColor(uid, null),
                    child: const Text('Usar el color que eligió'),
                  ),
              ],
            ),
    );
  }
}
