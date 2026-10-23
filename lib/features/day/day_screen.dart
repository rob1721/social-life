import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/calendar_window.dart';
import '../../models/calendar_event.dart';
import '../../models/event_post.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  final _markedSeen = <String>{};

  void _markSeen(List<CalendarEvent> events) {
    final uid = ref.read(currentUidProvider);
    final pending = events.where((e) => _markedSeen.add(e.key)).toList();
    if (uid == null || pending.isEmpty) return;
    ref.read(eventRepositoryProvider).markSeen(uid, pending);
  }

  @override
  Widget build(BuildContext context) {
    final range = dayRange(widget.day);
    final events = ref.watch(visibleEventsInRangeProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMMEEEEd('es').format(widget.day)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newEvent(widget.day)),
        icon: const Icon(Icons.add),
        label: const Text('Evento'),
      ),
      body: events.when(
        data: (list) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen(list));
          if (list.isEmpty) {
            return const Center(child: Text('No hay eventos este día'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [for (final e in list) _EventCard(event: e)],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final repo = ref.read(eventRepositoryProvider);
    final isOwner = event.ownerId == uid;
    final participation = event.participationOf(uid);
    final timeFmt = DateFormat.Hm('es');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PostIt(event: event, dense: false),
          ListTile(
            leading: InkWell(
              onTap: () => context.push(Routes.user(event.ownerId)),
              child: UserAvatar(uid: event.ownerId),
            ),
            title: UserName(uid: event.ownerId),
            subtitle: Text(
              [
                event.allDay
                    ? 'Todo el día'
                    : '${timeFmt.format(event.startAt)} – ${timeFmt.format(event.endAt)}',
                if (event.location.isNotEmpty) event.location,
              ].join(' · '),
            ),
            trailing: _EventMenu(event: event, isOwner: isOwner),
          ),
          if (event.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(event.description),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Van: '),
                for (final p in event.participantIds)
                  InkWell(
                    onTap: () => context.push(Routes.user(p)),
                    child: UserAvatar(uid: p, radius: 12),
                  ),
              ],
            ),
          ),
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<Participation>(
                segments: const [
                  ButtonSegment(
                    value: Participation.going,
                    label: Text('Participo'),
                  ),
                  ButtonSegment(
                    value: Participation.declined,
                    label: Text('No participo'),
                  ),
                ],
                emptySelectionAllowed: true,
                selected: {
                  if (participation != Participation.none) participation,
                },
                onSelectionChanged: (s) => runWithFeedback(
                  context,
                  () => repo.setParticipation(
                    event,
                    uid,
                    s.isEmpty ? Participation.none : s.first,
                  ),
                ),
              ),
            ),
          const Divider(),
          _PostsSection(event: event),
        ],
      ),
    );
  }
}

class _EventMenu extends ConsumerWidget {
  const _EventMenu({required this.event, required this.isOwner});

  final CalendarEvent event;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final repo = ref.read(eventRepositoryProvider);
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            context.push(Routes.editEvent(event.circleId, event.id));
          case 'delete':
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('¿Eliminar evento?'),
                content: const Text('Se eliminará para todos los miembros.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await runWithFeedback(context, () => repo.deleteEvent(event));
            }
          case 'hide':
            if (context.mounted) {
              await runWithFeedback(
                context,
                () => repo.setHidden(uid, event, true),
                success: 'Ya no verás este evento',
              );
            }
        }
      },
      itemBuilder: (_) => [
        if (isOwner) ...const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
        const PopupMenuItem(value: 'hide', child: Text('Dejar de recordar')),
      ],
    );
  }
}

class _PostsSection extends ConsumerWidget {
  const _PostsSection({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final repo = ref.read(eventRepositoryProvider);
    final posts =
        ref.watch(eventPostsProvider((event.circleId, event.id))).value ??
        const <EventPost>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in posts)
          ListTile(
            leading: UserAvatar(uid: p.authorId, radius: 14),
            title: p.type == PostType.photo && p.mediaUrls.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(p.mediaUrls.first, fit: BoxFit.cover),
                  )
                : Text(p.text),
            subtitle: p.type == PostType.photo && p.text.isNotEmpty
                ? Text(p.text)
                : null,
            trailing: p.authorId == uid
                ? PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await runWithFeedback(
                          context,
                          () => repo.deletePost(event, p.id),
                        );
                      } else if (v == 'edit') {
                        final text = await _askText(
                          context,
                          'Editar texto',
                          initial: p.text,
                        );
                        if (text != null && context.mounted) {
                          await runWithFeedback(
                            context,
                            () => repo.updatePostText(event, p.id, text),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  )
                : null,
          ),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Comentar'),
              onPressed: () async {
                final text = await _askText(context, 'Nuevo comentario');
                if (text != null && text.isNotEmpty && context.mounted) {
                  await runWithFeedback(
                    context,
                    () => repo.addNote(event, uid, text),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Foto'),
              onPressed: () async {
                final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 2048,
                  imageQuality: 85,
                );
                if (file == null || !context.mounted) return;
                final bytes = await file.readAsBytes();
                if (!context.mounted) return;
                await runWithFeedback(
                  context,
                  () => repo.addPhoto(event, uid, bytes),
                  success: 'Foto agregada',
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

Future<String?> _askText(
  BuildContext context,
  String title, {
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
