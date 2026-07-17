import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizacion_cart_provider.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizacion_provider.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';
import 'package:restaurant_app/features/reservaciones/presentation/providers/reservas_provider.dart';

/// Hoja inferior para confirmar pedidos y solicitudes de evento desde el menu.
class CotizacionSheet extends ConsumerStatefulWidget {
  final String? mesaId;

  const CotizacionSheet({super.key, this.mesaId});

  static Future<void> show(BuildContext context, {String? mesaId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CotizacionSheet(mesaId: mesaId),
    );
  }

  @override
  ConsumerState<CotizacionSheet> createState() => _CotizacionSheetState();
}

enum _CotizacionFlow { pedido, evento }

class _CotizacionSheetState extends ConsumerState<CotizacionSheet> {
  final _cedulaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _fechaEventoCtrl = TextEditingController();
  final _personasCtrl = TextEditingController();
  final _comidaCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _CotizacionFlow _flow = _CotizacionFlow.pedido;
  DateTime? _fechaEvento;
  bool _buscandoCliente = false;
  bool _clienteEncontrado = false;

  bool get _esEvento => _flow == _CotizacionFlow.evento;

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _fechaEventoCtrl.dispose();
    _personasCtrl.dispose();
    _comidaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cotizacionCartProvider);
    final cotState = ref.watch(cotizacionProvider);
    final cotizacionesAsync = ref.watch(cotizacionesProvider);
    final reservasState = ref.watch(reservasProvider);
    final reservasEnFecha = _fechaEvento == null
        ? const <String>[]
        : reservasState.reservasMes
              .where((r) => r.fecha == _formatDate(_fechaEvento!))
              .map((r) => r.id)
              .toList();
    final cotizacionesPendientes = _fechaEvento == null
        ? const <String>[]
        : cotizacionesAsync.maybeWhen(
            data: (items) => items
                .where(
                  (c) =>
                      c.reservaLocal &&
                      c.estado == 'pendiente' &&
                      c.fechaEvento == _formatDate(_fechaEvento!),
                )
                .map((c) => c.id)
                .toList(),
            orElse: () => const <String>[],
          );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Regresar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Icon(Icons.shopping_cart_checkout_rounded),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Resumen del pedido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
            const Divider(),
            if (cart.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Agrega productos para cotizar.'),
              ),
            if (cart.items.isNotEmpty) _buildCartSummary(cart),
            if (cart.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildTotals(cart),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildFlowSelector(context),
                        const SizedBox(height: 12),
                        _buildCustomerFields(),
                        if (_esEvento) ...[
                          const SizedBox(height: 12),
                          _buildEventFields(
                            reservasState: reservasState,
                            cotizacionesAsync: cotizacionesAsync,
                            fechaOcupada: reservasEnFecha.isNotEmpty,
                            reservasEnFecha: reservasEnFecha,
                            fechaConSolicitudPendiente:
                                cotizacionesPendientes.isNotEmpty,
                            cotizacionesPendientes: cotizacionesPendientes,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: cotState.isSaving ? null : _crearCotizacion,
                  child: cotState.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_esEvento ? 'Solicitar reserva' : 'Enviar pedido'),
                ),
              ),
              if (cotState.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  cotState.errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
            const SizedBox(height: 12),
            _buildContactCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(CotizacionCartState cart) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E1D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del pedido',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (_, i) {
                final item = cart.items[i];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nombreLinea,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${item.precioUnitario.toStringAsFixed(2)} c/u',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CartQtyControl(
                      cantidad: item.cantidad,
                      onDecrement: () => ref
                          .read(cotizacionCartProvider.notifier)
                          .decrement(
                            item.producto.id,
                            varianteId: item.varianteId,
                          ),
                      onIncrement: () => ref
                          .read(cotizacionCartProvider.notifier)
                          .increment(
                            item.producto.id,
                            varianteId: item.varianteId,
                          ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        '${AppConstants.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(CotizacionCartState cart) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal', style: TextStyle(fontSize: 14)),
            Text(
              '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total estimado', style: TextStyle(fontSize: 14)),
            Text(
              '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlowSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Que deseas hacer?',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_CotizacionFlow>(
            segments: const [
              ButtonSegment(
                value: _CotizacionFlow.pedido,
                icon: Icon(Icons.shopping_bag_outlined),
                label: Text('Pedir comida'),
              ),
              ButtonSegment(
                value: _CotizacionFlow.evento,
                icon: Icon(Icons.event_available_outlined),
                label: Text('Reservar evento'),
              ),
            ],
            selected: {_flow},
            onSelectionChanged: (selection) {
              setState(() {
                _flow = selection.first;
                if (!_esEvento) {
                  _fechaEvento = null;
                  _fechaEventoCtrl.clear();
                  _personasCtrl.clear();
                  _comidaCtrl.clear();
                  _notasCtrl.clear();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerFields() {
    return Column(
      children: [
        TextFormField(
          controller: _cedulaCtrl,
          decoration: InputDecoration(
            labelText: 'Cedula',
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
                ? const Icon(Icons.verified_user_rounded, color: Colors.green)
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
            if (!Cliente.esCedulaValida(value)) return 'Cedula/RUC invalido';
            return null;
          },
          onChanged: _lookupCliente,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _telefonoCtrl,
          decoration: const InputDecoration(
            labelText: 'Telefono',
            prefixIcon: Icon(Icons.call_outlined),
          ),
          keyboardType: TextInputType.phone,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              _validEmail(v) ? null : 'Correo electronico invalido',
        ),
      ],
    );
  }

  Widget _buildEventFields({
    required ReservasState reservasState,
    required AsyncValue<List<Cotizacion>> cotizacionesAsync,
    required bool fechaOcupada,
    required List<String> reservasEnFecha,
    required bool fechaConSolicitudPendiente,
    required List<String> cotizacionesPendientes,
  }) {
    return Column(
      children: [
        TextFormField(
          controller: _fechaEventoCtrl,
          decoration: const InputDecoration(
            labelText: 'Fecha del evento',
            prefixIcon: Icon(Icons.event_outlined),
          ),
          readOnly: true,
          onTap: () => _pickFechaEvento(context),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Indica la fecha del evento'
              : null,
        ),
        if (_fechaEvento != null) ...[
          const SizedBox(height: 6),
          _buildDisponibilidad(
            isLoading: reservasState.isLoading || cotizacionesAsync.isLoading,
            ocupada: fechaOcupada,
            total: reservasEnFecha.length,
            pendiente: fechaConSolicitudPendiente,
            totalPendientes: cotizacionesPendientes.length,
          ),
        ],
        const SizedBox(height: 10),
        TextFormField(
          controller: _personasCtrl,
          decoration: const InputDecoration(
            labelText: 'Cantidad de personas',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          keyboardType: TextInputType.number,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Indica la cantidad' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _comidaCtrl,
          decoration: const InputDecoration(
            labelText: 'Menu preferido',
            prefixIcon: Icon(Icons.restaurant_menu_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notasCtrl,
          decoration: const InputDecoration(
            labelText: 'Notas adicionales',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  bool _validEmail(String? email) {
    final value = email?.trim() ?? '';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return value.isNotEmpty && regex.hasMatch(value);
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
        if (cliente.telefono != null) _telefonoCtrl.text = cliente.telefono!;
        if (cliente.email != null) _emailCtrl.text = cliente.email!;
      }
    });
  }

  Future<Cliente?> _resolverCliente() async {
    final cedula = _cedulaCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();
    if (cedula.isEmpty || nombre.isEmpty) return null;
    return sl<ClienteService>().buscarOCrear({
      'cedula': cedula,
      'nombres': nombre,
      'telefono': _telefonoCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'direccion': '',
    });
  }

  Future<void> _pickFechaEvento(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaEvento ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      _fechaEvento = picked;
      _fechaEventoCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    });
    await ref.read(reservasProvider.notifier).loadMes(picked);
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Widget _buildDisponibilidad({
    required bool isLoading,
    required bool ocupada,
    required int total,
    required bool pendiente,
    required int totalPendientes,
  }) {
    if (isLoading) return const Text('Verificando disponibilidad...');
    if (ocupada) {
      return Text(
        'Hay $total reserva(s) en esa fecha',
        style: const TextStyle(color: AppColors.error),
      );
    }
    if (pendiente) {
      return Text(
        'Hay $totalPendientes cotizacion(es) pendiente(s) en esa fecha',
        style: const TextStyle(color: Colors.orange),
      );
    }
    return const Text(
      'Fecha disponible para reservar',
      style: TextStyle(color: Colors.green),
    );
  }

  List<String> _cotizacionesPendientesEnFecha(String fechaEvento) {
    final asyncValue = ref.read(cotizacionesProvider);
    return asyncValue.maybeWhen(
      data: (items) => items
          .where(
            (c) =>
                c.reservaLocal &&
                c.estado == 'pendiente' &&
                c.fechaEvento == fechaEvento,
          )
          .map((c) => c.id)
          .toList(),
      orElse: () => const <String>[],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E1D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consultas y ajustes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final cfg = ref.watch(publicConfigProvider);
              final telefono =
                  (cfg.hasConfig && cfg.config!.telefono.isNotEmpty)
                  ? cfg.config!.telefono
                  : AppConstants.contactPhone;
              final whatsapp =
                  (cfg.hasConfig && cfg.config!.whatsapp.isNotEmpty)
                  ? cfg.config!.whatsapp
                  : AppConstants.contactWhatsapp;
              final email =
                  (cfg.hasConfig && cfg.config!.emailContacto.isNotEmpty)
                  ? cfg.config!.emailContacto
                  : AppConstants.contactEmail;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Telefono: $telefono'),
                  Text('WhatsApp: $whatsapp'),
                  Text('Correo: $email'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _crearCotizacion() async {
    if (_formKey.currentState?.validate() != true) return;

    final cart = ref.read(cotizacionCartProvider);
    if (cart.items.isEmpty) return;

    Cliente? cliente;
    try {
      cliente = await _resolverCliente();
      if (cliente == null) {
        _showMessage('Debes completar cedula y nombre del cliente.');
        return;
      }
    } on BusinessException catch (e) {
      _showMessage(e.message);
      return;
    } catch (e) {
      _showMessage('No se pudo registrar cliente: $e');
      return;
    }

    if (_esEvento && _fechaEvento != null) {
      await ref.read(reservasProvider.notifier).loadMes(_fechaEvento!);
      final fechaEvento = _formatDate(_fechaEvento!);
      final reservasEnFecha = ref
          .read(reservasProvider)
          .reservasMes
          .where((r) => r.fecha == fechaEvento)
          .toList();
      final cotizacionesPendientes = _cotizacionesPendientesEnFecha(
        fechaEvento,
      );

      if (reservasEnFecha.isNotEmpty) {
        _showMessage(
          'La fecha seleccionada ya tiene reservaciones registradas. Elige otra fecha.',
        );
        return;
      }

      if (cotizacionesPendientes.isNotEmpty) {
        _showMessage(
          'Ya existe una cotizacion pendiente para esa fecha. Confirma disponibilidad antes de continuar.',
        );
        return;
      }
    }

    final id = await ref
        .read(cotizacionProvider.notifier)
        .crearCotizacion(
          restaurantId: sl<TenantContext>().restaurantId,
          mesaId: widget.mesaId,
          idCliente: cliente.idCliente,
          clienteNombre: _nombreCtrl.text.trim(),
          clienteTelefono: _telefonoCtrl.text.trim(),
          clienteEmail: _emailCtrl.text.trim(),
          reservaLocal: _esEvento,
          fechaEvento: _esEvento && _fechaEvento != null
              ? _formatDate(_fechaEvento!)
              : null,
          personas: _esEvento ? int.tryParse(_personasCtrl.text.trim()) : null,
          comidaPreferida: _esEvento && _comidaCtrl.text.trim().isNotEmpty
              ? _comidaCtrl.text.trim()
              : null,
          notas: _esEvento && _notasCtrl.text.trim().isNotEmpty
              ? _notasCtrl.text.trim()
              : null,
          items: cart.items,
        );

    if (!mounted) return;
    if (id != null) {
      ref.read(cotizacionCartProvider.notifier).clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud enviada: ${id.substring(0, 8)}')),
      );
    }
  }
}

class _CartQtyControl extends StatelessWidget {
  final int cantidad;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CartQtyControl({
    required this.cantidad,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9D0C1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Text(
            '$cantidad',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
