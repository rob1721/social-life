import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_event.dart';
import '../providers.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.uid, this.radius = 18});

  final String uid;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(uid)).value;
    final color = ref.watch(userColorProvider(uid));
    final photo = user?.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: photo != null ? NetworkImage(photo) : null,
      child: Text(
        (user?.displayName.isNotEmpty ?? false)
            ? user!.displayName[0].toUpperCase()
            : '?',
      ),
    );
  }
}

class UserName extends ConsumerWidget {
  const UserName({super.key, required this.uid, this.style});

  final String uid;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(uid)).value;
    return Text(user?.displayName ?? '…', style: style);
  }
}

/// Post-it de un evento en el calendario, con el color de su creador.
class PostIt extends ConsumerWidget {
  const PostIt({super.key, required this.event, this.dense = true});

  final CalendarEvent event;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(userColorProvider(event.ownerId));
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: EdgeInsets.symmetric(horizontal: 3, vertical: dense ? 1 : 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(blurRadius: 1, offset: Offset(0, 1), color: Colors.black26),
        ],
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: dense ? 9 : 14, color: Colors.black87),
      ),
    );
  }
}

class ColorPalettePicker extends StatelessWidget {
  const ColorPalettePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color? selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in postItPalette)
          GestureDetector(
            onTap: () => onSelected(c),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: c,
              child: selected?.toARGB32() == c.toARGB32()
                  ? const Icon(Icons.check, size: 18, color: Colors.black87)
                  : null,
            ),
          ),
      ],
    );
  }
}

Future<void> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
