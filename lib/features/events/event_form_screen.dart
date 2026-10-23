import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_window.dart';
import '../../models/calendar_event.dart';
import '../../models/circle.dart';
import '../../providers.dart';

/// Crear (sin [eventId]) o editar un evento propio.
class EventFormScreen extends ConsumerWidget {
  const EventFormScreen({
    super.key,
    this.initialDay,
    this.circleId,
    this.eventId,
  });

  final DateTime? initialDay;
  final String? circleId;
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (circleId == null || eventId == null) {
      return _EventForm(initialDay: initialDay ?? DateTime.now());
    }
    final event = ref.watch(eventProvider((circleId!, eventId!)));
    return event.when(
      data: (e) => e == null
          ? const Scaffold(body: Center(child: Text('Evento no encontrado')))
          : _EventForm(initialDay: e.startAt, existing: e),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({required this.initialDay, this.existing});

  final DateTime initialDay;
  final CalendarEvent? existing;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final _location = TextEditingController(text: widget.existing?.location);
  late DateTime _start;
  late DateTime _end;
  late bool _allDay = widget.existing?.allDay ?? false;
  String? _circleId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _start = e.startAt;
      _end = e.endAt;
      _circleId = e.circleId;
    } else {
      final d = dateOnly(widget.initialDay);
      _start = DateTime(d.year, d.month, d.day, 20);
      _end = _start.add(const Duration(hours: 2));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    if (_allDay) return DateTime(date.year, date.month, date.day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate() || _circleId == null) return;
    var start = _start;
    var end = _end;
    if (_allDay) {
      start = dateOnly(start);
      end = DateTime(end.year, end.month, end.day, 23, 59);
    }
    if (end.isBefore(start)) {
      _showError('La fecha de término debe ser posterior al inicio');
      return;
    }
    if (end.difference(start) > CalendarEvent.maxDuration) {
      _showError('Un evento puede durar como máximo 31 días');
      return;
    }

    final event = CalendarEvent(
      id: widget.existing?.id ?? '',
      circleId: _circleId!,
      ownerId: uid,
      title: _title.text.trim(),
      description: _description.text.trim(),
      location: _location.text.trim(),
      startAt: start,
      endAt: end,
      allDay: _allDay,
    );

    setState(() => _saving = true);
    try {
      final repo = ref.read(eventRepositoryProvider);
      if (_isEdit) {
        await repo.updateEvent(event);
      } else {
        await repo.createEvent(event);
      }
      if (mounted) context.pop();
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider)!;
    final circles = ref.watch(myCirclesProvider).value ?? const <Circle>[];
    _circleId ??=
        circles.where((c) => c.isPersonal).firstOrNull?.id ??
        circles.firstOrNull?.id;
    final fmt = DateFormat(
      _allDay ? 'EEE d MMM y' : 'EEE d MMM y, HH:mm',
      'es',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar evento' : 'Nuevo evento'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(uid),
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _circleId,
              decoration: const InputDecoration(labelText: 'Compartir con'),
              items: [
                for (final c in circles)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              // Un evento no cambia de red una vez creado.
              onChanged: _isEdit ? null : (v) => setState(() => _circleId = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todo el día'),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Inicio'),
              subtitle: Text(fmt.format(_start)),
              onTap: () async {
                final picked = await _pickDateTime(_start);
                if (picked == null) return;
                setState(() {
                  final duration = _end.difference(_start);
                  _start = picked;
                  _end = picked.add(duration);
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Término'),
              subtitle: Text(fmt.format(_end)),
              onTap: () async {
                final picked = await _pickDateTime(_end);
                if (picked != null) setState(() => _end = picked);
              },
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Lugar'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
