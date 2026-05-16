import 'package:flutter/material.dart';

/// Paleta de colores de La Peña Bar & Restaurant.
///
/// Inspirada en el logo: teal profundo (#1B7B8C) como color
/// principal, tonos cálidos amaderados (#8B6339) como secundario
/// y fondos blancos/crema para apariencia elegante y natural.
class AppColors {
  AppColors._();

  // ── Colores Primarios (Teal – color del logo) ──────────────────────
  static const Color primary = Color(0xFF1B7B8C); // Teal La Peña
  static const Color primaryLight = Color(0xFF2A9CAF);
  static const Color primaryDark = Color(0xFF125968);
  static const Color onPrimary = Colors.white;

  // ── Colores Secundarios (Madera cálida) ────────────────────────────
  static const Color secondary = Color(0xFF8B6339); // Madera cálida
  static const Color secondaryLight = Color(0xFFA8835A);
  static const Color secondaryDark = Color(0xFF6B4A28);
  static const Color onSecondary = Colors.white;

  // ── Colores de Superficie (Blanco cálido) ──────────────────────────
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F0EB);
  static const Color background = Color(0xFFF8F4EF);

  // ── Colores de Estado ──────────────────────────────────────────────
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF9A825);
  static const Color info = Color(0xFF1976D2);

  // ── Colores de Estado de Mesa ──────────────────────────────────────
  static const Color mesaLibre = Color(0xFF4CAF50);
  static const Color mesaOcupada = Color(0xFFEF5350);
  static const Color mesaReservada = Color(0xFFFFA726);

  // ── Colores de Estado de Pedido ────────────────────────────────────
  static const Color pedidoCreado = Color(0xFF90CAF9);
  static const Color pedidoAceptado = Color(0xFF42A5F5);
  static const Color pedidoEnPreparacion = Color(0xFFFFA726);
  static const Color pedidoFinalizado = Color(0xFF66BB6A);
  static const Color pedidoEntregado = Color(0xFF9E9E9E);

  // ── Modo Oscuro (Pantalla Cocina) ──────────────────────────────────
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color onDark = Color(0xFFE0E0E0);

  // ── Texto ──────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
}
