# Changelog

## 1.0.1+2 - 2026-04-25

### Estabilidad y producción
- Se validaron builds de producción para Web y Android.
- Se corrigió el empaquetado Android para Firebase Firestore elevando minSdk efectivo a 23.
- Se confirmó generación de artefactos release:
  - APK: build/app/outputs/flutter-apk/app-release.apk
  - AAB: build/app/outputs/bundle/release/app-release.aab
  - Web: build/web

### Sincronización y nube
- Se activó sincronización real hacia Firestore con verificación de disponibilidad.
- Se mejoró serialización de registros de sync a JSON robusto.
- Se reforzó UI de estado de nube y feedback de sincronización.

### Responsive y UX
- Mejoras en navegación principal (selección por rutas anidadas, menú móvil robusto).
- Ajustes de accesibilidad visual en NavigationBar y NavigationRail.
- Pulido responsive y de legibilidad en módulos:
  - Página pública
  - Reportes
  - Sincronización
  - Caja
  - Backup
  - Usuarios
  - Reservaciones (admin y pública)
  - Pedidos
  - Mesas
  - Cocina
  - Home/dashboard

### Calidad
- Análisis estático en verde.
- Suite de pruebas en verde.
