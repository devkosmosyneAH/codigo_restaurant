import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion_item.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/widgets/cotizacion_editor_dialog.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';

/// Ítem en edición dentro del formulario de cotización manual.
class _DraftItem {
  final String id;
  final String productoId; // vacío = ítem personalizado
  String nombre;
  String descripcion;
  int cantidad;
  double precioUnitario;
  double descuento; // 0-100 %

  _DraftItem({
    String? id,
    this.productoId = '',
    required this.nombre,
    this.descripcion = '',
    required this.cantidad,
    required this.precioUnitario,
    this.descuento = 0,
  }) : id = id ?? const Uuid().v4();

  double get subtotal => cantidad * precioUnitario * (1 - descuento / 100);

  CotizacionItem toEntity(String cotizacionId) => CotizacionItem(
    id: id,
    cotizacionId: cotizacionId,
    productoId: productoId.isEmpty ? null : productoId,
    productoNombre: nombre,
    descripcion: descripcion.isEmpty ? null : descripcion,
    cantidad: cantidad,
    precioUnitario: precioUnitario,
    descuento: descuento,
    subtotal: subtotal,
  );
}

/// Página de formulario para crear/editar una cotización manualmente.
class CotizacionManualFormPage extends ConsumerStatefulWidget {
  /// null → nueva cotización; no null → editar cotización existente.
  final Cotizacion? cotizacion;

  const CotizacionManualFormPage({super.key, this.cotizacion});

  @override
  ConsumerState<CotizacionManualFormPage> createState() =>
      _CotizacionManualFormPageState();
}

class _CotizacionManualFormPageState
    extends ConsumerState<CotizacionManualFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Controladores cliente ─────────────────────────────────────────
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _empresaCtrl;
  late final TextEditingController _direccionCtrl;

  // ── Controladores evento ──────────────────────────────────────────
  late final TextEditingController _personasCtrl;
  late final TextEditingController _lugarCtrl;
  late final TextEditingController _notasCtrl;

  // ── Controladores financieros ─────────────────────────────────────
  late final TextEditingController _descuentoCtrl;
  late final TextEditingController _tasaImpCtrl;

  // ── Estado del formulario ─────────────────────────────────────────
  bool _reservaLocal = false;
  DateTime? _fechaEvento;
  String _horaEvento = '';
  String _estado = 'pendiente';
  List<_DraftItem> _items = [];
  bool _isSaving = false;
  bool _buscandoCliente = false;
  bool _clienteEncontrado = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _currencyFmt = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  bool get _esEdicion => widget.cotizacion != null;

  // ── Totales calculados ────────────────────────────────────────────
  double get _subtotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get _descuentoMonto =>
      _subtotal * (double.tryParse(_descuentoCtrl.text) ?? 0) / 100;
  double get _impuestoMonto =>
      (_subtotal - _descuentoMonto) *
      (double.tryParse(_tasaImpCtrl.text) ?? 0) /
      100;
  double get _total => _subtotal - _descuentoMonto + _impuestoMonto;

  @override
  void initState() {
    super.initState();
    final c = widget.cotizacion;
    _cedulaCtrl = TextEditingController();
    _nombreCtrl = TextEditingController(text: c?.clienteNombre ?? '');
    _telCtrl = TextEditingController(text: c?.clienteTelefono ?? '');
    _emailCtrl = TextEditingController(text: c?.clienteEmail ?? '');
    _empresaCtrl = TextEditingController(text: c?.clienteEmpresa ?? '');
    _direccionCtrl = TextEditingController(text: c?.clienteDireccion ?? '');
    _personasCtrl = TextEditingController(
      text: c?.personas != null ? '${c!.personas}' : '',
    );
    _lugarCtrl = TextEditingController(text: c?.lugarEvento ?? '');
    _notasCtrl = TextEditingController(text: c?.notas ?? '');
    _descuentoCtrl = TextEditingController(
      text: (c?.descuento ?? 0) > 0 ? '${c!.descuento}' : '',
    );
    _tasaImpCtrl = TextEditingController(
      text: (c?.tasaImpuesto ?? 0) > 0 ? '${c!.tasaImpuesto}' : '',
    );
    if (c != null) {
      _reservaLocal = c.reservaLocal;
      _estado = c.estado;
      _horaEvento = c.horaEvento ?? '';
      if (c.fechaEvento != null && c.fechaEvento!.isNotEmpty) {
        try {
          _fechaEvento = DateTime.parse(c.fechaEvento!);
        } catch (_) {}
      }
      _items = c.items.map((item) {
        return _DraftItem(
          id: item.id,
          productoId: item.productoId ?? '',
          nombre: item.productoNombre,
          descripcion: item.descripcion ?? '',
          cantidad: item.cantidad,
          precioUnitario: item.precioUnitario,
          descuento: item.descuento,
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _empresaCtrl.dispose();
    _direccionCtrl.dispose();
    _personasCtrl.dispose();
    _lugarCtrl.dispose();
    _notasCtrl.dispose();
    _descuentoCtrl.dispose();
    _tasaImpCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCliente(String cedula) async {
    final clean = cedula.trim();
    if (clean.length != 10 && clean.length != 13) {
      setState(() {
        _clienteEncontrado = false;
      });
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
          _telCtrl.text = cliente.telefono!;
        }
        if (cliente.email != null) {
          _emailCtrl.text = cliente.email!;
        }
        if (cliente.direccion != null) {
          _direccionCtrl.text = cliente.direccion!;
        }
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
      'telefono': _telCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
    });
  }

  // ─────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar cotización' : 'Nueva cotización'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildSeccionCliente(),
            const SizedBox(height: 12),
            _buildSeccionEvento(),
            const SizedBox(height: 12),
            _buildSeccionItems(),
            const SizedBox(height: 12),
            _buildSeccionTotales(),
            const SizedBox(height: 12),
            _buildSeccionEstado(),
            const SizedBox(height: 24),
            _buildBotonesAccion(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  SECCIONES
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSeccionCliente() {
    return _SectionCard(
      icon: Icons.person_outline,
      title: 'Datos del cliente',
      child: Column(
        children: [
          _field(
            controller: _cedulaCtrl,
            label: 'Cédula *',
            icon: Icons.badge_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
            suffix: _buscandoCliente
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(1),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_clienteEncontrado
                      ? const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.green,
                        )
                      : null),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Campo requerido';
              if (!Cliente.esCedulaValida(value)) return 'Cédula/RUC inválido';
              return null;
            },
            onChanged: _lookupCliente,
          ),
          _field(
            controller: _nombreCtrl,
            label: 'Nombre completo *',
            icon: Icons.badge_outlined,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
          ),
          _field(
            controller: _telCtrl,
            label: 'Teléfono *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
          ),
          _field(
            controller: _emailCtrl,
            label: 'Correo electrónico *',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (!v.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
          _field(
            controller: _empresaCtrl,
            label: 'Empresa (opcional)',
            icon: Icons.business_outlined,
          ),
          _field(
            controller: _direccionCtrl,
            label: 'Dirección (opcional)',
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEvento() {
    return _SectionCard(
      icon: Icons.event_outlined,
      title: 'Datos del evento',
      child: Column(
        children: [
          // Tipo
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Reserva de local',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Activa si el cliente reserva el local completo',
              style: TextStyle(fontSize: 12),
            ),
            value: _reservaLocal,
            onChanged: (v) => setState(() => _reservaLocal = v),
            activeColor: AppColors.secondary,
          ),
          const Divider(height: 8),
          const SizedBox(height: 4),
          // Fecha del evento
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            title: Text(
              _fechaEvento != null
                  ? _dateFmt.format(_fechaEvento!)
                  : 'Fecha del evento (opcional)',
              style: TextStyle(
                fontSize: 14,
                color: _fechaEvento != null ? null : AppColors.textSecondary,
              ),
            ),
            trailing: _fechaEvento != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _fechaEvento = null),
                  )
                : null,
            onTap: _pickFecha,
          ),
          // Hora del evento
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.access_time_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            title: Text(
              _horaEvento.isNotEmpty
                  ? _horaEvento
                  : 'Hora del evento (opcional)',
              style: TextStyle(
                fontSize: 14,
                color: _horaEvento.isNotEmpty ? null : AppColors.textSecondary,
              ),
            ),
            trailing: _horaEvento.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _horaEvento = ''),
                  )
                : null,
            onTap: _pickHora,
          ),
          const SizedBox(height: 4),
          // Personas y lugar
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _field(
                  controller: _personasCtrl,
                  label: 'N.º personas',
                  icon: Icons.group_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          _field(
            controller: _lugarCtrl,
            label: 'Lugar del evento',
            icon: Icons.place_outlined,
          ),
          _field(
            controller: _notasCtrl,
            label: 'Observaciones',
            icon: Icons.notes_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionItems() {
    return _SectionCard(
      icon: Icons.shopping_bag_outlined,
      title: 'Productos y servicios',
      child: Column(
        children: [
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Agrega al menos un ítem para generar la cotización.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) => _ItemTile(
                item: _items[i],
                currencyFmt: _currencyFmt,
                onEdit: () => _editarItem(i),
                onDelete: () => setState(() => _items.removeAt(i)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _agregarItemCatalogo,
                  icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                  label: const Text('Del catálogo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _agregarItemPersonalizado,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Personalizado'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionTotales() {
    return _SectionCard(
      icon: Icons.calculate_outlined,
      title: 'Resumen financiero',
      child: StatefulBuilder(
        builder: (ctx, setS) {
          // recalcula al cambiar texto de descuento/impuesto
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _descuentoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Descuento %',
                        prefixIcon: Icon(Icons.discount_outlined, size: 18),
                        suffixText: '%',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tasaImpCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Impuesto %',
                        prefixIcon: Icon(Icons.percent_outlined, size: 18),
                        suffixText: '%',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    _totalRow('Subtotal', _subtotal),
                    if (_descuentoMonto > 0)
                      _totalRow(
                        'Descuento (${_descuentoCtrl.text}%)',
                        -_descuentoMonto,
                        color: Colors.orange,
                      ),
                    if (_impuestoMonto > 0)
                      _totalRow(
                        'Impuesto (${_tasaImpCtrl.text}%)',
                        _impuestoMonto,
                        color: AppColors.info,
                      ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _currencyFmt.format(_total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeccionEstado() {
    return _SectionCard(
      icon: Icons.flag_outlined,
      title: 'Estado de la cotización',
      child: DropdownButtonFormField<String>(
        value: _estado,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.assignment_outlined, size: 18),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'borrador', child: Text('Borrador')),
          DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
          DropdownMenuItem(value: 'aceptada', child: Text('Aceptada')),
          DropdownMenuItem(value: 'rechazada', child: Text('Rechazada')),
          DropdownMenuItem(value: 'finalizada', child: Text('Finalizada')),
        ],
        onChanged: (v) => setState(() => _estado = v ?? _estado),
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _guardar,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_esEdicion ? 'Guardar cambios' : 'Crear cotización'),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  HELPERS DE UI
  // ─────────────────────────────────────────────────────────────────

  Widget _totalRow(String label, double amount, {Color? color}) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: effectiveColor)),
          Text(
            _currencyFmt.format(amount),
            style: TextStyle(fontSize: 13, color: effectiveColor),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          suffixIcon: suffix,
          isDense: true,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  ACCIONES
  // ─────────────────────────────────────────────────────────────────

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaEvento ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _fechaEvento = picked);
  }

  Future<void> _pickHora() async {
    final inicial = _horaEvento.isNotEmpty
        ? TimeOfDay(
            hour: int.parse(_horaEvento.split(':')[0]),
            minute: int.parse(_horaEvento.split(':')[1]),
          )
        : const TimeOfDay(hour: 19, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: inicial);
    if (picked != null) {
      setState(() {
        _horaEvento =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _agregarItemCatalogo() {
    final menuState = ref.read(menuProvider);
    final productos = menuState.productosDisponibles;
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos en el catálogo')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogoPicker(
        productos: productos,
        onPicked: (p) {
          setState(() {
            _items.add(
              _DraftItem(
                productoId: p.id,
                nombre: p.nombre,
                descripcion: p.descripcion ?? '',
                cantidad: 1,
                precioUnitario: p.precio,
              ),
            );
          });
        },
      ),
    );
  }

  void _agregarItemPersonalizado() {
    _mostrarEditorItem(null);
  }

  void _editarItem(int index) {
    _mostrarEditorItem(index);
  }

  void _mostrarEditorItem(int? index) {
    final existente = index != null ? _items[index] : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemEditorSheet(
        item: existente,
        currencyFmt: _currencyFmt,
        onSave: (draft) {
          setState(() {
            if (index != null) {
              _items[index] = draft;
            } else {
              _items.add(draft);
            }
          });
        },
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ítem a la cotización'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final cotizacionId = widget.cotizacion?.id ?? const Uuid().v4();
    final items = _items.map((i) => i.toEntity(cotizacionId)).toList();
    final subtotal = items.fold(0.0, (s, i) => s + i.subtotal);
    final descPct = double.tryParse(_descuentoCtrl.text) ?? 0;
    final impPct = double.tryParse(_tasaImpCtrl.text) ?? 0;
    final descMonto = subtotal * descPct / 100;
    final total = subtotal - descMonto + (subtotal - descMonto) * impPct / 100;

    Cliente? cliente;
    try {
      cliente = await _resolverCliente();
      if (!mounted) return;
      if (cliente == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cédula del cliente es obligatoria')),
        );
        setState(() => _isSaving = false);
        return;
      }
    } on BusinessException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _isSaving = false);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al registrar cliente: $e')));
      setState(() => _isSaving = false);
      return;
    }

    final cotizacion = Cotizacion(
      id: cotizacionId,
      restaurantId: sl<TenantContext>().restaurantId,
      mesaId: widget.cotizacion?.mesaId,
      idCliente: cliente.idCliente,
      clienteNombre: _nombreCtrl.text.trim(),
      clienteTelefono: _telCtrl.text.trim(),
      clienteEmail: _emailCtrl.text.trim(),
      clienteEmpresa: _empresaCtrl.text.trim().isEmpty
          ? null
          : _empresaCtrl.text.trim(),
      clienteDireccion: _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      reservaLocal: _reservaLocal,
      personas: int.tryParse(_personasCtrl.text.trim()),
      fechaEvento: _fechaEvento?.toIso8601String().split('T').first,
      horaEvento: _horaEvento.isEmpty ? null : _horaEvento,
      lugarEvento: _lugarCtrl.text.trim().isEmpty
          ? null
          : _lugarCtrl.text.trim(),
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      estado: _estado,
      descuento: descPct,
      tasaImpuesto: impPct,
      origen: 'admin',
      subtotal: subtotal,
      total: total,
      createdAt: widget.cotizacion?.createdAt ?? DateTime.now(),
      items: items,
    );

    final result = _esEdicion
        ? await sl<UpdateCotizacion>()(cotizacion)
        : await sl<CreateCotizacion>()(cotizacion);

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      (f) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      },
      (_) {
        ref.invalidate(cotizacionesProvider);
        _mostrarExito(context, cotizacion);
      },
    );
  }

  void _mostrarExito(BuildContext context, Cotizacion cotizacion) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _esEdicion ? 'Cotización actualizada' : 'Cotización creada',
        ),
        content: const Text('¿Deseas generar el PDF ahora?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Volver al listado'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              // pequeño delay para que el Navigator se asiente
              Future.delayed(const Duration(milliseconds: 200), () {
                if (context.mounted) {
                  CotizacionEditorDialog.show(context, ref, cotizacion);
                }
              });
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Generar PDF'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────

/// Tarjeta con encabezado de sección.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tile para mostrar un ítem en la lista.
class _ItemTile extends StatelessWidget {
  final _DraftItem item;
  final NumberFormat currencyFmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.item,
    required this.currencyFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${item.cantidad}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (item.descripcion.isNotEmpty)
                  Text(
                    item.descripcion,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  '${currencyFmt.format(item.precioUnitario)} c/u'
                  '${item.descuento > 0 ? ' · ${item.descuento.toStringAsFixed(0)}% desc.' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onEdit,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                    color: AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  ITEM EDITOR SHEET
// ─────────────────────────────────────────────────────────────────────

class _ItemEditorSheet extends StatefulWidget {
  final _DraftItem? item;
  final NumberFormat currencyFmt;
  final void Function(_DraftItem) onSave;

  const _ItemEditorSheet({
    this.item,
    required this.currencyFmt,
    required this.onSave,
  });

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _descuentoCtrl;
  final _formKey = GlobalKey<FormState>();

  double get _subtotal {
    final cant = int.tryParse(_cantidadCtrl.text) ?? 1;
    final precio = double.tryParse(_precioCtrl.text) ?? 0;
    final desc = double.tryParse(_descuentoCtrl.text) ?? 0;
    return cant * precio * (1 - desc / 100);
  }

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nombreCtrl = TextEditingController(text: i?.nombre ?? '');
    _descCtrl = TextEditingController(text: i?.descripcion ?? '');
    _cantidadCtrl = TextEditingController(
      text: i != null ? '${i.cantidad}' : '1',
    );
    _precioCtrl = TextEditingController(
      text: i != null ? i.precioUnitario.toStringAsFixed(2) : '',
    );
    _descuentoCtrl = TextEditingController(
      text: i != null && i.descuento > 0 ? i.descuento.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.item == null ? 'Agregar ítem' : 'Editar ítem',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto/servicio *',
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción adicional (opcional)',
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cantidadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Cantidad *',
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if ((int.tryParse(v) ?? 0) < 1) return 'Mín. 1';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Precio unitario *',
                      prefixText: '${AppConstants.currencySymbol} ',
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if ((double.tryParse(v) ?? -1) < 0) return 'Inválido';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _descuentoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Descuento %',
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          widget.currencyFmt.format(_subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirmar,
                    child: Text(widget.item == null ? 'Agregar' : 'Actualizar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    final draft = _DraftItem(
      id: widget.item?.id,
      productoId: widget.item?.productoId ?? '',
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      cantidad: int.tryParse(_cantidadCtrl.text) ?? 1,
      precioUnitario: double.tryParse(_precioCtrl.text) ?? 0,
      descuento: double.tryParse(_descuentoCtrl.text) ?? 0,
    );
    Navigator.of(context).pop();
    widget.onSave(draft);
  }
}

// ─────────────────────────────────────────────────────────────────────
//  CATÁLOGO PICKER
// ─────────────────────────────────────────────────────────────────────

class _CatalogoPicker extends StatefulWidget {
  final List<Producto> productos;
  final void Function(Producto) onPicked;

  const _CatalogoPicker({required this.productos, required this.onPicked});

  @override
  State<_CatalogoPicker> createState() => _CatalogoPickerState();
}

class _CatalogoPickerState extends State<_CatalogoPicker> {
  String _query = '';

  List<Producto> get _filtered => widget.productos
      .where((p) => p.nombre.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccionar del catálogo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar producto…',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.nombre),
                    subtitle: p.descripcion != null
                        ? Text(
                            p.descripcion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Text(
                      fmt.format(p.precio),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onPicked(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
