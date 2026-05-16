import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';

/// Dialogo para crear o editar una reservacion.
class ReservaFormDialog extends StatefulWidget {
  final DateTime fecha;
  final List<Mesa> mesas;
  final Reserva? initialReserva;

  const ReservaFormDialog({
    super.key,
    required this.fecha,
    required this.mesas,
    this.initialReserva,
  });

  static Future<ReservaFormResult?> show(
    BuildContext context, {
    required DateTime fecha,
    required List<Mesa> mesas,
    Reserva? initialReserva,
  }) {
    return showDialog<ReservaFormResult>(
      context: context,
      builder: (_) => ReservaFormDialog(
        fecha: fecha,
        mesas: mesas,
        initialReserva: initialReserva,
      ),
    );
  }

  @override
  State<ReservaFormDialog> createState() => _ReservaFormDialogState();
}

class _ReservaFormDialogState extends State<ReservaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _personasCtrl = TextEditingController(text: '2');
  final _notasCtrl = TextEditingController();
  final _requerimientosCtrl = TextEditingController();
  final _nombreLocalCtrl = TextEditingController();
  final _mantelesCtrl = TextEditingController();
  final _colorMantelCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  TipoReserva _tipo = TipoReserva.mesa;
  EstadoReserva _estado = EstadoReserva.pendiente;
  TipoEvento _tipoEvento = TipoEvento.cumpleanos;
  String? _mesaId;
  TimeOfDay _horaInicio = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 20, minute: 30);
  bool _buscandoCliente = false;
  bool _clienteEncontrado = false;

  List<Mesa> get _mesasSugeridas {
    final personas = int.tryParse(_personasCtrl.text) ?? 2;
    final mesas = [...widget.mesas]
      ..sort((a, b) => a.capacidad.compareTo(b.capacidad));
    final sugeridas = mesas.where((m) => m.capacidad >= personas).toList();
    return sugeridas.isEmpty ? mesas : sugeridas;
  }

  @override
  void initState() {
    super.initState();
    final reserva = widget.initialReserva;
    if (reserva == null) return;

    _tipo = reserva.tipo;
    _estado = reserva.estado;
    _mesaId = reserva.mesaId;
    _horaInicio = _parseTime(reserva.horaInicio);
    _horaFin = _parseTime(reserva.horaFin);
    _nombreCtrl.text = reserva.clienteNombre;
    _telefonoCtrl.text = reserva.clienteTelefono;
    _emailCtrl.text = reserva.clienteEmail;
    _personasCtrl.text = reserva.numeroPersonas.toString();
    _notasCtrl.text = reserva.notas ?? '';
    _requerimientosCtrl.text = reserva.requerimientos ?? '';
    _nombreLocalCtrl.text = reserva.nombreLocalEvento ?? '';
    _mantelesCtrl.text = reserva.manteles ?? '';
    _colorMantelCtrl.text = reserva.colorManteleria ?? '';
    _precioCtrl.text = reserva.precioEstimado != null
        ? reserva.precioEstimado!.toStringAsFixed(2)
        : '';

    final match = TipoEvento.values.where((t) => t.label == reserva.tipoEvento);
    if (match.isNotEmpty) {
      _tipoEvento = match.first;
    }
  }

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _personasCtrl.dispose();
    _notasCtrl.dispose();
    _requerimientosCtrl.dispose();
    _nombreLocalCtrl.dispose();
    _mantelesCtrl.dispose();
    _colorMantelCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCliente(String cedula) async {
    final clean = cedula.trim();
    if (clean.length != 10 && clean.length != 13) {
      setState(() => _clienteEncontrado = false);
      return;
    }

    setState(() => _buscandoCliente = true);
    final cliente = await sl<ClienteService>().buscarPorCedula(clean);
    if (!mounted) return;
    setState(() {
      _buscandoCliente = false;
      _clienteEncontrado = cliente != null;
      if (cliente != null) {
        _nombreCtrl.text = cliente.nombreCompleto;
        if (cliente.telefono != null) {
          _telefonoCtrl.text = cliente.telefono!;
        }
        if (cliente.email != null) {
          _emailCtrl.text = cliente.email!;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = DateFormat('dd/MM/yyyy').format(widget.fecha);
    final mesasSugeridas = _mesasSugeridas;
    final selectedMesaId = mesasSugeridas.any((m) => m.id == _mesaId)
        ? _mesaId
        : null;

    final isEditing = widget.initialReserva != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar reservación' : 'Reservar $fechaStr'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<TipoReserva>(
                  value: _tipo,
                  items: TipoReserva.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de reserva',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<EstadoReserva>(
                  value: _estado,
                  items: EstadoReserva.values
                      .where((e) => e != EstadoReserva.noAsistio)
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _estado = v ?? _estado),
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HoraSelectorTile(
                        label: 'Hora inicio',
                        icon: Icons.schedule,
                        value: _formatTime(_horaInicio),
                        onTap: () => _pickHora(esInicio: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HoraSelectorTile(
                        label: 'Hora fin',
                        icon: Icons.timer_outlined,
                        value: _formatTime(_horaFin),
                        onTap: () => _pickHora(esInicio: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _personasCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de personas',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                  validator: (v) {
                    final value = int.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) {
                      return 'Ingresa un número válido';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                if (_tipo == TipoReserva.mesa)
                  DropdownButtonFormField<String>(
                    value: selectedMesaId,
                    items: mesasSugeridas
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.displayName} · ${m.capacidad} pers.',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _mesaId = v),
                    decoration: const InputDecoration(
                      labelText: 'Mesa sugerida',
                      helperText: 'Filtradas según capacidad',
                      prefixIcon: Icon(Icons.table_restaurant_rounded),
                    ),
                    validator: (v) {
                      if (_tipo != TipoReserva.mesa) return null;
                      if (v == null || v.isEmpty) return 'Selecciona una mesa';
                      final personas = int.tryParse(_personasCtrl.text) ?? 2;
                      final mesa = widget.mesas
                          .where((m) => m.id == v)
                          .toList();
                      if (mesa.isNotEmpty && mesa.first.capacidad < personas) {
                        return 'La mesa no cubre esa capacidad';
                      }
                      return null;
                    },
                  ),
                if (_tipo == TipoReserva.local) ...[
                  DropdownButtonFormField<TipoEvento>(
                    value: _tipoEvento,
                    items: TipoEvento.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoEvento = v ?? _tipoEvento),
                    decoration: const InputDecoration(
                      labelText: 'Tipo de evento',
                      prefixIcon: Icon(Icons.celebration_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nombreLocalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del local / salón',
                      hintText: 'Ej: Salón El Rosal',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _mantelesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mantelería',
                      hintText: 'Ej: Tela bordada, descartable...',
                      prefixIcon: Icon(Icons.table_bar_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _colorMantelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Color de mantelería',
                      hintText: 'Ej: Blanco, rojo, azul marino...',
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio estimado (\$)',
                      hintText: 'Ej: 350.00',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v.trim()) == null) {
                        return 'Ingresa un monto válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _requerimientosCtrl,
                  decoration: InputDecoration(
                    labelText: _tipo == TipoReserva.local
                        ? 'Comida / requerimientos del evento'
                        : 'Comida o preferencia del cliente',
                    hintText: _tipo == TipoReserva.local
                        ? 'Ej: parrillada, vegetariano, torta, decoración...'
                        : 'Ej: encebollado, parrillada, sin picante...',
                    prefixIcon: const Icon(Icons.restaurant_menu_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cedulaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cédula del cliente',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: _buscandoCliente
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _clienteEncontrado
                        ? const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.green,
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Requerido';
                    if (!Cliente.esCedulaValida(value)) {
                      return 'Cédula/RUC inválido';
                    }
                    return null;
                  },
                  onChanged: _lookupCliente,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _telefonoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo (opcional)',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return null;
                    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!regex.hasMatch(value)) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Text(
                  'Horario del restaurante: ${AppConstants.restaurantOpeningHour}:00 - ${AppConstants.restaurantClosingHour}:00',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final mesa = widget.mesas.where((m) => m.id == _mesaId).toList();
            Navigator.pop(
              context,
              ReservaFormResult(
                tipo: _tipo,
                estado: _estado,
                horaInicio: _formatTime(_horaInicio),
                horaFin: _formatTime(_horaFin),
                numeroPersonas: int.tryParse(_personasCtrl.text.trim()) ?? 2,
                mesaId: _mesaId,
                mesaNombre: mesa.isNotEmpty ? mesa.first.displayName : null,
                clienteCedula: _cedulaCtrl.text.trim(),
                clienteNombre: _nombreCtrl.text.trim(),
                clienteTelefono: _telefonoCtrl.text.trim(),
                clienteEmail: _emailCtrl.text.trim(),
                notas: _notasCtrl.text.trim().isEmpty
                    ? null
                    : _notasCtrl.text.trim(),
                tipoEvento: _tipo == TipoReserva.local
                    ? _tipoEvento.label
                    : null,
                requerimientos: _requerimientosCtrl.text.trim().isNotEmpty
                    ? _requerimientosCtrl.text.trim()
                    : null,
                nombreLocalEvento: _nombreLocalCtrl.text.trim().isNotEmpty
                    ? _nombreLocalCtrl.text.trim()
                    : null,
                manteles: _mantelesCtrl.text.trim().isNotEmpty
                    ? _mantelesCtrl.text.trim()
                    : null,
                colorManteleria: _colorMantelCtrl.text.trim().isNotEmpty
                    ? _colorMantelCtrl.text.trim()
                    : null,
                precioEstimado: double.tryParse(_precioCtrl.text.trim()),
              ),
            );
          },
          child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickHora({required bool esInicio}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esInicio ? _horaInicio : _horaFin,
    );
    if (picked == null) return;

    setState(() {
      if (esInicio) {
        _horaInicio = picked;
        final inicio = _toMinutes(_horaInicio);
        final fin = _toMinutes(_horaFin);
        if (fin <= inicio) {
          _horaFin = _sumarDuracion(
            picked,
            AppConstants.reservaDuracionMinutos,
          );
        }
      } else {
        _horaFin = picked;
      }
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 19 : 19;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _toMinutes(TimeOfDay time) => (time.hour * 60) + time.minute;

  TimeOfDay _sumarDuracion(TimeOfDay time, int minutes) {
    final total = _toMinutes(time) + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }
}

class ReservaFormResult {
  final TipoReserva tipo;
  final EstadoReserva estado;
  final String horaInicio;
  final String horaFin;
  final int numeroPersonas;
  final String? mesaId;
  final String? mesaNombre;
  final String clienteCedula;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteEmail;
  final String? notas;
  final String? tipoEvento;
  final String? requerimientos;
  final String? nombreLocalEvento;
  final String? manteles;
  final String? colorManteleria;
  final double? precioEstimado;

  const ReservaFormResult({
    required this.tipo,
    required this.estado,
    required this.horaInicio,
    required this.horaFin,
    required this.numeroPersonas,
    required this.mesaId,
    required this.mesaNombre,
    required this.clienteCedula,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteEmail,
    required this.notas,
    required this.tipoEvento,
    required this.requerimientos,
    this.nombreLocalEvento,
    this.manteles,
    this.colorManteleria,
    this.precioEstimado,
  });
}

class _HoraSelectorTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _HoraSelectorTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}
