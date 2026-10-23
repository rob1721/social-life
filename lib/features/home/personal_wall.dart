import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/calendar_event.dart';
import '../../models/invite.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Muro personal: mi información, invitaciones, novedades no vistas y
/// eventos próximos / recientes dentro de la ventana del calendario.
class PersonalWall extends ConsumerWidget {
  const PersonalWall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final invites = ref.watch(pendingInvitesProvider).value ?? const [];
    final unseen = ref.watch(unseenEventsProvider);
    final window = ref.watch(calendarWindowProvider);
    final events =
        ref.watch(visibleEventsInRangeProvider(window.range)).value ?? const [];
    final now = DateTime.now();

    final unseenFuture = unseen.where((e) => !e.isPast(now)).toList();
    final unseenPast = unseen.where((e) => e.isPast(now)).toList();
    final upcoming = events.where((e) => !e.isPast(now)).take(5).toList();
    final recent = events
        .where((e) => e.isPast(now))
        .toList()
        .reversed
        .take(5)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (me != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UserAvatar(uid: me.uid, radius: 24),
            title: Text('Hola, ${me.displayName}'),
            subtitle: Text(me.email),
            trailing: TextButton(
              onPressed: () => context.push(Routes.profile),
              child: const Text('Editar perfil'),
            ),
          ),
        for (final invite in invites) _InviteCard(invite: invite),
        _Section(
          title: 'Novedades en eventos futuros',
          icon: Icons.notifications_active,
          events: unseenFuture,
          empty: 'Sin novedades',
        ),
        _Section(
          title: 'Novedades en eventos pasados',
          icon: Icons.notifications,
          events: unseenPast,
          empty: 'Sin novedades',
        ),
        _Section(
          title: 'Próximos eventos',
          icon: Icons.upcoming,
          events: upcoming,
          empty: 'Nada planificado aún',
        ),
        _Section(
          title: 'Recuerdos recientes',
          icon: Icons.history,
          events: recent,
          empty: 'Sin eventos recientes',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.events,
    required this.empty,
  });

  final String title;
  final IconData icon;
  final List<CalendarEvent> events;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("EEE d MMM, HH:mm", 'es');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            if (events.isNotEmpty) ...[
              const SizedBox(width: 6),
              Badge(label: Text('${events.length}')),
            ],
          ],
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 24),
            child: Text(empty, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final e in events)
          ListTile(
            dense: true,
            leading: UserAvatar(uid: e.ownerId, radius: 14),
            title: Text(e.title),
            subtitle: Text(fmt.format(e.startAt)),
            onTap: () => context.push(Routes.day(e.startAt)),
          ),
      ],
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(circleRepositoryProvider);
    final uid = ref.watch(currentUidProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mail),
        title: Text('Invitación a "${invite.circleName}"'),
        subtitle: Text('De ${invite.invitedByName}'),
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Rechazar',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  runWithFeedback(context, () => repo.declineInvite(invite)),
            ),
            IconButton(
              tooltip: 'Aceptar',
              icon: const Icon(Icons.check),
              onPressed: uid == null
                  ? null
                  : () => runWithFeedback(
                      context,
                      () => repo.acceptInvite(invite, uid),
                      success: 'Te uniste a ${invite.circleName}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
