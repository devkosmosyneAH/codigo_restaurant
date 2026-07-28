import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/widgets/cotizacion_editor_dialog.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

// ── Provider para cargar una cotización por ID ──────────────────────────────

final cotizacionByIdProvider = FutureProvider.autoDispose
    .family<Cotizacion?, String>((ref, id) async {
      final restaurantId = sl<TenantContext>().restaurantId;
      final result = await sl<GetCotizaciones>()(restaurantId);
      return result.fold((_) => null, (items) {
        try {
          return items.firstWhere((c) => c.id == id);
        } catch (_) {
          return null;
        }
      });
    });

// ── Página pública (sin auth) ─────────────────────────────────────────────────

/// Vista de solo lectura de una cotización — accesible sin autenticación.
/// Usada como vista del cliente o como previsualización para imprimir.
class CotizacionPublicaPage extends ConsumerWidget {
  final String cotizacionId;

  const CotizacionPublicaPage({super.key, required this.cotizacionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(cotizacionByIdProvider(cotizacionId));
    final cfgState = ref.watch(publicConfigProvider);
    final nombreNegocio =
        (cfgState.hasConfig && cfgState.config!.nombreNegocio.isNotEmpty)
        ? cfgState.config!.nombreNegocio
        : AppConstants.appFullName;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          nombreNegocio,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: asyncData.whenOrNull(
          data: (c) => c != null
              ? [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Generar PDF',
                    onPressed: () => CotizacionEditorDialog.show(
                      context,
                      ref,
                      c,
                      persistirFirma: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                ]
              : null,
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cotizacion) {
          if (cotizacion == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Cotización no encontrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return _CotizacionPublicaBody(
            cotizacion: cotizacion,
            nombreNegocio: nombreNegocio,
            onGenerarPdf: () => CotizacionEditorDialog.show(
              context,
              ref,
              cotizacion,
              persistirFirma: false,
            ),
          );
        },
      ),
    );
  }
}

// ── Cuerpo principal ────────────────────────────────────────────────────────

class _CotizacionPublicaBody extends StatelessWidget {
  final Cotizacion cotizacion;
  final String nombreNegocio;
  final VoidCallback onGenerarPdf;

  const _CotizacionPublicaBody({
    required this.cotizacion,
    required this.nombreNegocio,
    required this.onGenerarPdf,
  });

  @override
  Widget build(BuildContext context) {
    final c = cotizacion;
    final currency = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    final dateFmt = DateFormat('dd/MM/yyyy');
    final fechaCreacion = dateFmt.format(c.createdAt);
    final fechaEvento = c.fechaEvento != null && c.fechaEvento!.isNotEmpty
        ? dateFmt.format(DateTime.parse(c.fechaEvento!))
        : null;

    final colorEstado = _colorEstado(c.estado);

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ── Cabecera ──────────────────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.request_quote_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreNegocio,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Text(
                                  'COTIZACIÓN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorEstado.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _labelEstado(c.estado).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _metaChip(
                            Icons.calendar_today_outlined,
                            'Emitida',
                            fechaCreacion,
                          ),
                          if (fechaEvento != null) ...[
                            const SizedBox(width: 12),
                            _metaChip(
                              Icons.event_outlined,
                              'Evento',
                              fechaEvento,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Datos del cliente ─────────────────────────────────────
              _section(
                icon: Icons.person_outline,
                title: 'DATOS DEL CLIENTE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.badge_outlined, 'Nombre', c.clienteNombre),
                    _infoRow(
                      Icons.phone_outlined,
                      'Teléfono',
                      c.clienteTelefono,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppColors.textSecondary,
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: c.clienteTelefono),
                        ),
                      ),
                    ),
                    _infoRow(Icons.email_outlined, 'Correo', c.clienteEmail),
                    if (c.clienteEmpresa != null &&
                        c.clienteEmpresa!.isNotEmpty)
                      _infoRow(
                        Icons.business_outlined,
                        'Empresa',
                        c.clienteEmpresa!,
                      ),
                    if (c.clienteDireccion != null &&
                        c.clienteDireccion!.isNotEmpty)
                      _infoRow(
                        Icons.location_on_outlined,
                        'Dirección',
                        c.clienteDireccion!,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Datos del evento (si aplica) ──────────────────────────
              if (c.reservaLocal ||
                  fechaEvento != null ||
                  (c.personas != null && c.personas! > 0) ||
                  (c.lugarEvento?.isNotEmpty ?? false) ||
                  (c.horaEvento?.isNotEmpty ?? false)) ...[
                _section(
                  icon: Icons.celebration_outlined,
                  title: 'DATOS DEL EVENTO',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.reservaLocal)
                        _tagRow(
                          'Tipo',
                          'Reserva completa del local',
                          color: AppColors.secondary,
                        ),
                      if (fechaEvento != null)
                        _infoRow(
                          Icons.calendar_month_outlined,
                          'Fecha',
                          fechaEvento,
                        ),
                      if (c.horaEvento != null && c.horaEvento!.isNotEmpty)
                        _infoRow(
                          Icons.access_time_outlined,
                          'Hora',
                          c.horaEvento!,
                        ),
                      if (c.personas != null && c.personas! > 0)
                        _infoRow(
                          Icons.group_outlined,
                          'Personas',
                          '${c.personas}',
                        ),
                      if (c.lugarEvento != null && c.lugarEvento!.isNotEmpty)
                        _infoRow(Icons.place_outlined, 'Lugar', c.lugarEvento!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Tabla de ítems ────────────────────────────────────────
              if (c.items.isNotEmpty) ...[
                _section(
                  icon: Icons.shopping_bag_outlined,
                  title: 'PRODUCTOS Y SERVICIOS',
                  child: Column(
                    children: [
                      // Encabezado tabla
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Descripción',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                'Cant.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                'Precio',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < c.items.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: Colors.grey.shade200),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.items[i].productoNombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (c.items[i].descripcion != null &&
                                              c
                                                  .items[i]
                                                  .descripcion!
                                                  .isNotEmpty)
                                            Text(
                                              c.items[i].descripcion!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          if (c.items[i].descuento > 0)
                                            Text(
                                              'Descuento: ${c.items[i].descuento.toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        '${c.items[i].cantidad}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        currency.format(
                                          c.items[i].precioUnitario,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        currency.format(c.items[i].subtotal),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Totales ───────────────────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (c.descuento > 0 || c.tasaImpuesto > 0) ...[
                        _totalLine('Subtotal', currency.format(c.subtotal)),
                        if (c.descuento > 0)
                          _totalLine(
                            'Descuento (${c.descuento.toStringAsFixed(0)}%)',
                            '- ${currency.format(c.subtotal * c.descuento / 100)}',
                            valueColor: Colors.orange,
                          ),
                        if (c.tasaImpuesto > 0)
                          _totalLine(
                            'Impuesto (${c.tasaImpuesto.toStringAsFixed(0)}%)',
                            '+ ${currency.format((c.subtotal - c.subtotal * c.descuento / 100) * c.tasaImpuesto / 100)}',
                            valueColor: Colors.blue.shade700,
                          ),
                        const Divider(height: 20),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currency.format(c.total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Notas ─────────────────────────────────────────────────
              if (c.notas != null && c.notas!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _section(
                  icon: Icons.notes_outlined,
                  title: 'OBSERVACIONES',
                  child: Text(c.notas!, style: const TextStyle(fontSize: 14)),
                ),
              ],

              const SizedBox(height: 24),

              // ── Botón PDF ─────────────────────────────────────────────
              FilledButton.icon(
                onPressed: onGenerarPdf,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text(
                  'Generar PDF de la cotización',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),

              const SizedBox(height: 32),

              // ── Footer ────────────────────────────────────────────────
              Center(
                child: Text(
                  '© $nombreNegocio · Cotización generada con ${AppConstants.appFullName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
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

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _tagRow(String label, String value, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    return switch (estado) {
      'aceptada' => Colors.green.shade700,
      'rechazada' => Colors.red.shade700,
      'finalizada' => AppColors.primary,
      'borrador' => Colors.blueGrey.shade600,
      _ => Colors.orange.shade700,
    };
  }

  String _labelEstado(String estado) {
    return switch (estado) {
      'borrador' => 'Borrador',
      'aceptada' => 'Aceptada',
      'rechazada' => 'Rechazada',
      'finalizada' => 'Finalizada',
      _ => 'Pendiente',
    };
  }
}
