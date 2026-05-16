import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

/// Vista pública del restaurante. Accesible sin autenticación.
class RestaurantePublicPage extends ConsumerStatefulWidget {
  const RestaurantePublicPage({super.key});

  @override
  ConsumerState<RestaurantePublicPage> createState() =>
      _RestaurantePublicPageState();
}

class _RestaurantePublicPageState extends ConsumerState<RestaurantePublicPage> {
  static const Color _teal = AppColors.primary;
  static const Color _cream = Color(0xFFF5F0EB);

  @override
  void initState() {
    super.initState();
    // Carga el menú solo una vez al abrir la página pública,
    // evitando el loop isLoading:true que ocultaba los productos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuProvider.notifier).loadMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicConfigProvider);

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: _cream,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    final config =
        state.config ?? PublicConfig.defaults(sl<TenantContext>().restaurantId);

    return Scaffold(
      backgroundColor: _cream,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cream, Color(0xFFFFFBF7)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _HeroSliver(config: config),
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final maxContentWidth = width >= 1800
                      ? 1380.0
                      : width >= 1440
                      ? 1280.0
                      : width >= 1100
                      ? 1080.0
                      : width >= 900
                      ? 920.0
                      : width;
                  final horizontalInset = width >= 1800
                      ? 56.0
                      : width >= 1440
                      ? 40.0
                      : width >= 1200
                      ? 32.0
                      : width >= 900
                      ? 20.0
                      : 0.0;

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalInset,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: Column(
                              children: [
                                if (config.mostrarBotonMenu ||
                                    config.mostrarBotonReservas)
                                  _SoftReveal(
                                    child: _CtaSection(config: config),
                                  ),
                                const SizedBox(height: 4),
                                _SoftReveal(
                                  delay: Duration(milliseconds: 70),
                                  child: _ExperienciasSection(config: config),
                                ),
                                const _SoftReveal(
                                  delay: Duration(milliseconds: 110),
                                  child: _EstadisticasSection(),
                                ),
                                if (config.mostrarBotonMenu)
                                  _SoftReveal(
                                    delay: Duration(milliseconds: 140),
                                    child: _MenuPreviewSection(config: config),
                                  ),
                                const _SoftReveal(
                                  delay: Duration(milliseconds: 160),
                                  child: _TestimoniosSection(),
                                ),
                                if (config.mostrarBotonReservas)
                                  _SoftReveal(
                                    delay: Duration(milliseconds: 170),
                                    child: _ReservasBannerSection(
                                      config: config,
                                    ),
                                  ),
                                if (config.descripcion.isNotEmpty)
                                  _SoftReveal(
                                    delay: Duration(milliseconds: 190),
                                    child: _AboutSection(config: config),
                                  ),
                                const _SoftReveal(
                                  delay: Duration(milliseconds: 210),
                                  child: _EventosSection(),
                                ),
                                _SoftReveal(
                                  delay: const Duration(milliseconds: 230),
                                  child: LayoutBuilder(
                                    builder: (ctx, cons) {
                                      if (cons.maxWidth >= 800 &&
                                          config.horarios.isNotEmpty) {
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _HorariosSection(
                                                config: config,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _ContactoSection(
                                                config: config,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return Column(
                                        children: [
                                          if (config.horarios.isNotEmpty)
                                            _HorariosSection(config: config),
                                          _ContactoSection(config: config),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (config.facebook.isNotEmpty ||
                                    config.instagram.isNotEmpty)
                                  _SoftReveal(
                                    delay: Duration(milliseconds: 250),
                                    child: _RedesSection(config: config),
                                  ),
                                _SoftReveal(
                                  delay: const Duration(milliseconds: 270),
                                  child: _UbicacionMapSection(config: config),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _Footer(config: config),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSliver extends StatelessWidget {
  const _HeroSliver({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final expandedHeight = width < 340
        ? 390.0
        : width < 600
        ? 430.0
        : width >= 1600
        ? 590.0
        : width >= 1440
        ? 560.0
        : 500.0;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeroDelegate(config: config, expandedHeight: expandedHeight),
    );
  }
}

class _HeroDelegate extends SliverPersistentHeaderDelegate {
  const _HeroDelegate({required this.config, required this.expandedHeight});

  final PublicConfig config;
  final double expandedHeight;

  static const _gradStart = Color(0xFF0A3840);

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => kToolbarHeight;

  @override
  bool shouldRebuild(_HeroDelegate old) =>
      old.config != config || old.expandedHeight != expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final heroFadeProgress = (t * 2.2).clamp(0.0, 1.0);
    final heroOpacity = 1 - Curves.easeOutCubic.transform(heroFadeProgress);
    final titleProgress = ((t - 0.55) * 3.5).clamp(0.0, 1.0);
    final titleOpacity = Curves.easeOutCubic.transform(titleProgress);
    final parallaxOffset = (shrinkOffset * 0.12).clamp(0.0, 34.0);
    final safeTop = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: _gradStart,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Transform.translate(
                offset: Offset(0, parallaxOffset),
                child: Transform.scale(
                  scale: 1.06,
                  child: Image.asset(
                    'assets/images/banner_la_pena.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0A3840),
                            Color(0xFF125968),
                            Color(0xFF1B7B8C),
                            Color(0xFF2AACB8),
                          ],
                          stops: [0.0, 0.35, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Vigneta radial
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Color(0x44000000),
                    Color(0xBB000000),
                    Color(0xEE000000),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
            ),
            // Degradado inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
            ),
            // Hero grande — se desvanece al hacer scroll
            // OverflowBox da siempre la altura máxima; ClipRect recorta el exceso
            if (heroOpacity > 0)
              OverflowBox(
                maxHeight: maxExtent,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: maxExtent,
                  child: Opacity(
                    opacity: heroOpacity,
                    child: _HeroContent(config: config),
                  ),
                ),
              ),
            // Título compacto en el AppBar — aparece al colapsar
            if (titleOpacity > 0)
              Positioned(
                top: safeTop,
                left: 0,
                right: 0,
                height: kToolbarHeight,
                child: Opacity(
                  opacity: titleOpacity,
                  child: Center(child: _CompactInlineTitle(config: config)),
                ),
              ),
            // Botón atrás siempre visible
            Positioned(top: safeTop + 4, left: 4, child: _backButton(context)),
          ],
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        color: Colors.white,
        tooltip: 'Regresar',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTiny = width < 340;
        final isCompact = width < 600;
        final isWideDesktop = width >= 1440;
        final logoSize = isTiny
            ? 70.0
            : isWideDesktop
            ? 116.0
            : 96.0;
        final titleSize = isTiny
            ? 27.0
            : isCompact
            ? 34.0
            : isWideDesktop
            ? 54.0
            : 46.0;
        final displayName = config.nombreNegocio.isNotEmpty
            ? config.nombreNegocio
            : AppConstants.appName;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact
                  ? 18
                  : isWideDesktop
                  ? 56
                  : 32,
              isWideDesktop ? 22 : 16,
              isCompact
                  ? 18
                  : isWideDesktop
                  ? 56
                  : 32,
              isTiny
                  ? 22
                  : isWideDesktop
                  ? 44
                  : 32,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_la_pena.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isWideDesktop ? 22 : 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      '✦  Bar & Restaurant  ✦',
                      style: TextStyle(
                        color: Color(0xFFE8C87C),
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: isWideDesktop ? 16 : 12),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isWideDesktop ? 1.8 : 1.5,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: isWideDesktop ? 20 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 1,
                        color: const Color(0xFFD4A843).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD4A843),
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 30,
                        height: 1,
                        color: const Color(0xFFD4A843).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  SizedBox(height: isWideDesktop ? 20 : 16),
                  Text(
                    config.slogan,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: isTiny
                          ? 13
                          : isWideDesktop
                          ? 16
                          : 15,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: isWideDesktop ? 20 : 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: isWideDesktop ? 10 : 8,
                    runSpacing: isWideDesktop ? 10 : 8,
                    children: [
                      if (config.mostrarBotonMenu)
                        const _HeroChip(
                          icon: Icons.restaurant_menu_rounded,
                          label: 'Menú fresco',
                        ),
                      if (config.mostrarBotonReservas)
                        const _HeroChip(
                          icon: Icons.event_available_rounded,
                          label: 'Reservas online',
                        ),
                      const _HeroChip(
                        icon: Icons.location_on_rounded,
                        label: 'Visítanos hoy',
                      ),
                    ],
                  ),
                  SizedBox(
                    height: isTiny
                        ? 16
                        : isWideDesktop
                        ? 30
                        : 24,
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Descubre más',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: isWideDesktop ? 12 : 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: isWideDesktop ? 22 : 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Versión estática del título compacto usada dentro del delegado
/// (no necesita [PublicConfig] porque solo usa constantes de la app).
class _CompactInlineTitle extends StatelessWidget {
  const _CompactInlineTitle({required this.config});

  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo_la_pena.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.nombreNegocio.isNotEmpty
                    ? config.nombreNegocio
                    : AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  height: 1.1,
                ),
              ),
              Text(
                'Bar & Restaurant',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaSection extends StatelessWidget {
  const _CtaSection({required this.config});

  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideDesktop = constraints.maxWidth >= 1200;
          final stack = constraints.maxWidth < 520;
          final actions = <Widget>[
            if (config.mostrarBotonMenu)
              Expanded(
                child: _CtaButton(
                  label: 'Ver menú',
                  icon: Icons.restaurant_menu_rounded,
                  backgroundColor: AppColors.primary,
                  large: isWideDesktop,
                  onTap: () => context.go(AppRouter.menuPublico),
                ),
              ),
            if (config.mostrarBotonReservas)
              Expanded(
                child: _CtaButton(
                  label: 'Reservar ahora',
                  icon: Icons.calendar_month_rounded,
                  backgroundColor: AppColors.secondary,
                  large: isWideDesktop,
                  onTap: () => context.go(AppRouter.reservasPublico),
                ),
              ),
          ];

          if (actions.isEmpty) return const SizedBox.shrink();

          Widget content;
          if (stack) {
            content = Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  Row(children: [actions[i]]),
                  if (i != actions.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          } else {
            content = Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  actions[i],
                  if (i != actions.length - 1)
                    SizedBox(width: isWideDesktop ? 16 : 12),
                ],
              ],
            );
          }

          if (constraints.maxWidth >= 700) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: content,
              ),
            );
          }
          return content;
        },
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.large = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final bool large;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _InteractiveScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: large ? 58 : 52,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.23),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: large ? 20 : 18),
                SizedBox(width: large ? 10 : 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: large ? 15 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADÍSTICAS
// ─────────────────────────────────────────────────────────────────────────────

class _EstadisticasSection extends StatelessWidget {
  const _EstadisticasSection();

  @override
  Widget build(BuildContext context) {
    const stats = [
      (
        value: '+3',
        label: 'Años de\nexperiencia',
        icon: Icons.history_edu_rounded,
      ),
      (
        value: '4.5★',
        label: 'Calificación\nen Google',
        icon: Icons.star_rounded,
      ),
      (
        value: '+60',
        label: 'Platos en\nnuestro menú',
        icon: Icons.restaurant_menu_rounded,
      ),
      (
        value: '+7K',
        label: 'Clientes\nsatisfechos',
        icon: Icons.people_rounded,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A3840), Color(0xFF125968), Color(0xFF1B7B8C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3840).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
        child: LayoutBuilder(
          builder: (_, cons) {
            final cols = cons.maxWidth >= 600 ? 4 : 2;
            return Wrap(
              alignment: WrapAlignment.spaceEvenly,
              children: stats.map((s) {
                return SizedBox(
                  width: cons.maxWidth / cols,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            s.icon,
                            color: const Color(0xFFD4A843),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTIMONIOS
// ─────────────────────────────────────────────────────────────────────────────

class _TestimoniosSection extends StatelessWidget {
  const _TestimoniosSection();

  static const _testimonios = [
    (
      nombre: 'María G.',
      texto:
          'La mejor experiencia gastronómica que he tenido. El ambiente, la comida y el servicio son simplemente perfectos.',
      estrellas: 5,
    ),
    (
      nombre: 'Carlos R.',
      texto:
          'Increíble lugar. Los platos son una obra de arte y el sabor es inigualable. Ya tengo mis reservas para la próxima semana.',
      estrellas: 5,
    ),
    (
      nombre: 'Ana M.',
      texto:
          'El sitio ideal para celebraciones especiales. Atención impecable y una carta que no te dejará indiferente.',
      estrellas: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Lo que dicen nuestros clientes'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, cons) {
              final isWide = cons.maxWidth >= 680;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _testimonios.length; i++) ...[
                      Expanded(child: _TestimonioCard(t: _testimonios[i])),
                      if (i < _testimonios.length - 1)
                        const SizedBox(width: 12),
                    ],
                  ],
                );
              }
              return Column(
                children: _testimonios
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TestimonioCard(t: t),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TestimonioCard extends StatelessWidget {
  const _TestimonioCard({required this.t});
  final ({String nombre, String texto, int estrellas}) t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              t.estrellas,
              (_) => const Icon(
                Icons.star_rounded,
                color: Color(0xFFD4A843),
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '"${t.texto}"',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTOS ESPECIALES
// ─────────────────────────────────────────────────────────────────────────────

class _EventosSection extends StatelessWidget {
  const _EventosSection();

  static const _eventos = [
    (
      icono: Icons.outdoor_grill_rounded,
      color: Color(0xFF8B3A10),
      titulo: 'Domingos de Chancho a la Brasa',
      desc:
          'Todos los domingos, disfruta de nuestro plato estrella: chancho a la brasa preparado con receta de la casa, acompañado de mote, papas y ensalada fresca.',
    ),
    (
      icono: Icons.celebration_rounded,
      color: Color(0xFF1B7B8C),
      titulo: 'Eventos Privados',
      desc:
          'Celebra tu ocasión especial con nosotros. Menús personalizados, decoración exclusiva y atención dedicada.',
    ),
    (
      icono: Icons.local_bar_rounded,
      color: Color(0xFF4A1060),
      titulo: 'Cócteles y Licores de la Casa',
      desc:
          'Descubre nuestra exclusiva carta de cócteles artesanales y licores seleccionados. Cada trago es una experiencia creada por nuestros bartenders.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Experiencias & Eventos'),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 14, bottom: 16),
            child: Text(
              'Más que un restaurante, un destino de experiencias',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          LayoutBuilder(
            builder: (_, cons) {
              final isWide = cons.maxWidth >= 680;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _eventos.length; i++) ...[
                      Expanded(child: _EventoCard(e: _eventos[i])),
                      if (i < _eventos.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              }
              return Column(
                children: _eventos
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EventoCard(e: e),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventoCard extends StatelessWidget {
  const _EventoCard({required this.e});
  final ({IconData icono, Color color, String titulo, String desc}) e;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: e.color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: e.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(e.icono, color: e.color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            e.titulo,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            e.desc,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPERIENCIAS
// ─────────────────────────────────────────────────────────────────────────────

class _ExperienciasSection extends StatelessWidget {
  const _ExperienciasSection({required this.config});
  final PublicConfig config;

  static const _icons = [
    Icons.restaurant_menu_rounded,
    Icons.groups_rounded,
    Icons.star_rounded,
  ];
  static const _iconColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFFD4A843),
  ];
  static const _iconBg = [
    Color(0xFFE8F5F7),
    Color(0xFFF5EDE4),
    Color(0xFFFDF7E8),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      (config.exp1Titulo, config.exp1Desc, 0),
      (config.exp2Titulo, config.exp2Desc, 1),
      (config.exp3Titulo, config.exp3Desc, 2),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideCards = constraints.maxWidth >= 680;

        Widget buildCard((String, String, int) item) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _iconBg[item.$3],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _icons[item.$3],
                      color: _iconColors[item.$3],
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 14),
                child: _SectionTitle(title: 'Por qué elegirnos'),
              ),
              if (wideCards)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      Expanded(child: buildCard(items[i])),
                      if (i != items.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: buildCard(item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, cons) => Text(
              title,
              style: TextStyle(
                fontSize: cons.maxWidth >= 600 ? 20 : 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MENU PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _MenuPreviewSection extends ConsumerWidget {
  const _MenuPreviewSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuState = ref.watch(menuProvider);
    final productos = menuState.productosDisponibles.take(8).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: config.tituloMenu),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    config.subtituloMenu,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (menuState.isLoading)
            const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (productos.isEmpty)
            _MenuEmptyPlaceholder()
          else
            LayoutBuilder(
              builder: (ctx, cons) {
                final isDesktop = cons.maxWidth >= 600;
                if (isDesktop) {
                  final cols = cons.maxWidth >= 900
                      ? 5
                      : cons.maxWidth >= 720
                      ? 4
                      : 3;
                  final cardW = (cons.maxWidth - 40 - (cols - 1) * 12) / cols;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: productos
                          .map(
                            (p) => _ProductoCard(
                              producto: p,
                              cardWidth: cardW,
                              inGrid: true,
                            ),
                          )
                          .toList(),
                    ),
                  );
                }
                return SizedBox(
                  height: 168,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20, right: 8),
                    itemCount: productos.length,
                    itemBuilder: (_, i) =>
                        _ProductoCard(producto: productos[i]),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: GestureDetector(
                  onTap: () => context.go(AppRouter.menuPublico),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ver menú completo',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({
    required this.producto,
    this.cardWidth = 130.0,
    this.inGrid = false,
  });
  final dynamic producto;
  final double cardWidth;
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    final hasImage = (producto.imagenUrl ?? '').toString().isNotEmpty;
    final imgH = (cardWidth * 0.69).roundToDouble();

    return Container(
      width: cardWidth,
      margin: inGrid
          ? const EdgeInsets.only(bottom: 4)
          : const EdgeInsets.only(right: 12, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: hasImage
                ? Image.network(
                    producto.imagenUrl as String,
                    height: imgH,
                    width: cardWidth,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${(producto.precioMinimo as double).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: (cardWidth * 0.69).roundToDouble(),
    width: cardWidth,
    color: const Color(0xFFEEF8F9),
    child: const Center(
      child: Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 30),
    ),
  );
}

class _MenuEmptyPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 32),
            SizedBox(height: 8),
            Text(
              'Próximamente disponible',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESERVACIONES BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ReservasBannerSection extends StatelessWidget {
  const _ReservasBannerSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: GestureDetector(
        onTap: () => context.go(AppRouter.reservasPublico),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6B4A28), Color(0xFF8B6339), Color(0xFFA8835A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                left: -10,
                bottom: -10,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stackContent = constraints.maxWidth < 320;
                    if (stackContent) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ReservasIconBox(),
                          const SizedBox(height: 14),
                          _ReservasTextContent(config: config),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const _ReservasIconBox(),
                        const SizedBox(width: 16),
                        Expanded(child: _ReservasTextContent(config: config)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservasIconBox extends StatelessWidget {
  const _ReservasIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.calendar_month_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _ReservasTextContent extends StatelessWidget {
  const _ReservasTextContent({required this.config});

  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          config.tituloReservas,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          config.subtituloReservas,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reservar ahora',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.secondary,
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOBRE NOSOTROS
// ─────────────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.info_outline_rounded,
      title: 'Sobre nosotros',
      child: Text(
        config.descripcion,
        style: const TextStyle(
          fontSize: 14,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HORARIOS
// ─────────────────────────────────────────────────────────────────────────────

class _HorariosSection extends StatelessWidget {
  const _HorariosSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.schedule_rounded,
      title: 'Horarios de atención',
      child: Column(
        children: config.horarios.asMap().entries.map((entry) {
          final isLast = entry.key == config.horarios.length - 1;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.value.dia,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.value.hora,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Divider(height: 18, color: Colors.grey.shade100, thickness: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACTO
// ─────────────────────────────────────────────────────────────────────────────

class _ContactoSection extends StatelessWidget {
  const _ContactoSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[];

    if (config.telefono.isNotEmpty) {
      items.add((
        icon: Icons.phone_rounded,
        label: config.telefono,
        onTap: () => _launchExternalUrl(
          'tel:${config.telefono.replaceAll(RegExp(r'\s'), '')}',
          allowedSchemes: const {'tel'},
        ),
      ));
    }
    if (config.whatsapp.isNotEmpty) {
      items.add((
        icon: Icons.chat_rounded,
        label: 'WhatsApp: ${config.whatsapp}',
        onTap: () => _launchExternalUrl(
          'https://wa.me/${config.whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
        ),
      ));
    }
    // La dirección se muestra en la sección de mapa "Dónde encontrarnos"

    final email = config.emailContacto.isNotEmpty
        ? config.emailContacto
        : AppConstants.contactEmail;
    items.add((
      icon: Icons.email_rounded,
      label: email,
      onTap: () =>
          _launchExternalUrl('mailto:$email', allowedSchemes: const {'mailto'}),
    ));

    if (config.emailSecundario.isNotEmpty) {
      items.add((
        icon: Icons.alternate_email_rounded,
        label: config.emailSecundario,
        onTap: () => _launchExternalUrl(
          'mailto:${config.emailSecundario}',
          allowedSchemes: const {'mailto'},
        ),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.contact_phone_rounded,
      title: 'Contacto',
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          final item = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REDES SOCIALES
// ─────────────────────────────────────────────────────────────────────────────

class _RedesSection extends StatelessWidget {
  const _RedesSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.share_rounded,
      title: 'Síguenos',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackButtons = constraints.maxWidth < 320;
          final buttons = [
            if (config.facebook.isNotEmpty)
              _SocialButton(
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                icon: Icons.facebook_rounded,
                onTap: () => _launchExternalUrl(config.facebook),
              ),
            if (config.instagram.isNotEmpty)
              _SocialButton(
                label: 'Instagram',
                color: const Color(0xFFE1306C),
                imageAsset: 'assets/images/instagram_logo.png',
                onTap: () => _launchExternalUrl(config.instagram),
              ),
          ];

          if (stackButtons) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  buttons[i],
                  if (i != buttons.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                Expanded(child: buttons[i]),
                if (i != buttons.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.imageAsset,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? imageAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = imageAsset != null
        ? Image.asset(imageAsset!, width: 18, height: 18)
        : Icon(icon, size: 18);
    return _InteractiveScale(
      hoverScale: 1.015,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: iconWidget,
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UBICACIÓN EN MAPA
// ─────────────────────────────────────────────────────────────────────────────

class _UbicacionMapSection extends StatelessWidget {
  const _UbicacionMapSection({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          const _SectionTitle(title: 'Dónde encontrarnos'),
          const SizedBox(height: 14),

          // Tarjeta de mapa
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  // Mapa interactivo
                  LayoutBuilder(
                    builder: (ctx, cons) => SizedBox(
                      height: cons.maxWidth >= 700 ? 320 : 220,
                      child: RepaintBoundary(
                        child: _MapView(lat: config.mapLat, lng: config.mapLng),
                      ),
                    ),
                  ),

                  // Barra de info y botón
                  _MapInfoBar(config: config, onOpenMaps: _openMaps),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMaps(String url) async {
    await _launchExternalUrl(url);
  }
}

class _MapInfoBar extends StatelessWidget {
  const _MapInfoBar({required this.config, required this.onOpenMaps});

  final PublicConfig config;
  final void Function(String url) onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 390;
        final info = Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.nombreNegocio.isNotEmpty
                        ? config.nombreNegocio
                        : AppConstants.appFullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (config.direccion.isNotEmpty)
                    Text(
                      config.direccion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: isCompact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(color: Colors.white),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 12),
                    _MapButton(onTap: () => onOpenMaps(config.mapUrl)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 8),
                    _MapButton(onTap: () => onOpenMaps(config.mapUrl)),
                  ],
                ),
        );
      },
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _InteractiveScale(
      hoverScale: 1.015,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_rounded, color: Colors.white, size: 14),
                SizedBox(width: 5),
                Text(
                  'Ir ahora',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftReveal extends StatelessWidget {
  const _SoftReveal({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    const duration = Duration(milliseconds: 360);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final totalMs = (duration + delay).inMilliseconds;
        final delayFraction = totalMs <= 0
            ? 0.0
            : delay.inMilliseconds / totalMs;
        final progress = delayFraction >= 1
            ? 1.0
            : ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}

class _InteractiveScale extends StatefulWidget {
  const _InteractiveScale({required this.child, this.hoverScale = 1.01});

  final Widget child;
  final double hoverScale;

  @override
  State<_InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<_InteractiveScale> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.disableAnimationsOf(context)
        ? 1.0
        : _pressed
        ? 0.985
        : _hovered
        ? widget.hoverScale
        : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Widget interno que muestra el mapa con flutter_map + OpenStreetMap.
class _MapView extends StatelessWidget {
  const _MapView({required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: 16.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.lapena.restaurant_app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(lat, lng),
              width: 48,
              height: 56,
              child: _MapPin(),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        Container(
          width: 4,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.config});
  final PublicConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.08),
            AppColors.primaryDark.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo_la_pena.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              config.nombreNegocio.isNotEmpty
                  ? config.nombreNegocio
                  : AppConstants.appFullName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              config.slogan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.shade300, height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.grey.shade300,
                    size: 12,
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.shade300, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '© ${DateTime.now().year}  ${config.nombreNegocio.isNotEmpty ? config.nombreNegocio : AppConstants.appFullName}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Todos los derechos reservados',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(
                  'https://devkosmosyneah.github.io/devkosmosyne-website/',
                );
                await _launchExternalUri(uri);
              },
              child: const Text(
                'Desarrollado por DevCosmosyne',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  letterSpacing: 0.3,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideDesktop = width >= 1440;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isWideDesktop ? 8 : 16,
        12,
        isWideDesktop ? 8 : 16,
        4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWideDesktop ? 20 : 18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isWideDesktop ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isWideDesktop ? 8 : 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: isWideDesktop ? 18 : 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isWideDesktop ? 16 : 15,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isWideDesktop ? 18 : 16),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> _launchExternalUrl(
  String url, {
  Set<String> allowedSchemes = const {'https'},
}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  await _launchExternalUri(uri, allowedSchemes: allowedSchemes);
}

Future<void> _launchExternalUri(
  Uri uri, {
  Set<String> allowedSchemes = const {'https'},
}) async {
  if (!allowedSchemes.contains(uri.scheme.toLowerCase())) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
