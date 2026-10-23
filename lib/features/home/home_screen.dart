import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/calendar_window.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'calendar_grid.dart';
import 'personal_wall.dart';

/// Pantalla principal: muro personal arriba, calendario siempre visible abajo.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuestro Calendario'),
        actions: [
          IconButton(
            tooltip: 'Mis redes',
            icon: const Icon(Icons.group),
            onPressed: () => context.push(Routes.circles),
          ),
          if (uid != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push(Routes.profile),
                child: UserAvatar(uid: uid),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo evento',
        onPressed: () => context.push(Routes.newEvent(DateTime.now())),
        child: const Icon(Icons.add),
      ),
      body: const Column(
        children: [
          Expanded(child: PersonalWall()),
          Divider(height: 1),
          Expanded(child: CalendarSection()),
        ],
      ),
    );
  }
}

class CalendarSection extends ConsumerWidget {
  const CalendarSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(calendarWindowProvider);
    final notifier = ref.read(calendarWindowProvider.notifier);
    final events = ref.watch(visibleEventsInRangeProvider(window.range));

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '3 semanas atrás',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => notifier.shift(-3),
            ),
            Expanded(
              child: TextButton(
                onPressed: notifier.goToToday,
                child: Text(
                  isSameDay(window.anchor, DateTime.now())
                      ? 'Hoy'
                      : 'Volver a hoy',
                ),
              ),
            ),
            IconButton(
              tooltip: '3 semanas adelante',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => notifier.shift(3),
            ),
          ],
        ),
        Expanded(
          child: events.when(
            data: (list) => CalendarGrid(
              window: window,
              events: list,
              onDayTap: (day) => context.push(Routes.day(day)),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}
