import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Edición del perfil propio: apodo, avatar y color de post-it.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: me.when(
        data: (user) =>
            user == null ? const SizedBox.shrink() : _ProfileForm(user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _nickname = TextEditingController(text: widget.user.nickname);
  late bool _showNickname = widget.user.showNickname;
  bool _uploading = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await runWithFeedback(
      context,
      () =>
          ref.read(userRepositoryProvider).uploadAvatar(widget.user.uid, bytes),
    );
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final repo = ref.read(userRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Stack(
            children: [
              UserAvatar(uid: user.uid, radius: 48),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit, size: 16),
                  onPressed: _uploading ? null : _pickAvatar,
                ),
              ),
            ],
          ),
        ),
        if (user.avatarUrl != null)
          TextButton(
            onPressed: () =>
                runWithFeedback(context, () => repo.removeAvatar(user.uid)),
            child: const Text('Usar foto de Google'),
          ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cuenta de Google'),
          subtitle: Text('${user.googleName}\n${user.email}'),
          isThreeLine: true,
        ),
        TextField(
          controller: _nickname,
          decoration: const InputDecoration(
            labelText: 'Apodo (nick)',
            helperText: 'Quien abra tu perfil verá siempre tu nombre y correo de Google',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar mi apodo en lugar de mi nombre'),
          value: _showNickname,
          onChanged: (v) => setState(() => _showNickname = v),
        ),
        FilledButton(
          onPressed: () => runWithFeedback(
            context,
            () => repo.updateProfile(
              user.uid,
              nickname: _nickname.text.trim(),
              showNickname: _showNickname,
            ),
            success: 'Perfil actualizado',
          ),
          child: const Text('Guardar'),
        ),
        const SizedBox(height: 24),
        Text(
          'Color de mis post-its',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ColorPalettePicker(
          selected: Color(user.colorValue),
          onSelected: (c) => runWithFeedback(
            context,
            () => repo.updateProfile(user.uid, colorValue: c.toARGB32()),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          onPressed: () => ref.read(authServiceProvider).signOut(),
        ),
      ],
    );
  }
}
