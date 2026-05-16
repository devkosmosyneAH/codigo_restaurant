import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';

/// Pantalla de login mediante PIN de 4 dígitos.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final List<String> _digits = [];
  final TextEditingController _activationCodeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  static const List<({String label, String pin, IconData icon})> _demoPins = [
    (label: 'Admin', pin: '1111', icon: Icons.admin_panel_settings_rounded),
    (label: 'Caja', pin: '2222', icon: Icons.point_of_sale_rounded),
    (label: 'Mesero', pin: '3333', icon: Icons.room_service_rounded),
    (label: 'Cocina', pin: '4444', icon: Icons.soup_kitchen_rounded),
  ];

  static final Uri _supportUri = Uri.parse(
    'https://devkosmosyneah.github.io/devkosmosyne-website/',
  );

  ActivationChangeNotifier get _activation => sl<ActivationChangeNotifier>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_activation.isInitialized && !_activation.isLoading) {
        _activation.loadStatus();
      }
    });
  }

  @override
  void dispose() {
    _activationCodeCtrl.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_digits.length >= 4 || _isLoading || !_activation.canAccessApp) return;
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    if (_digits.length == 4) {
      _submit();
    }
  }

  void _removeDigit() {
    if (_digits.isEmpty || _isLoading) return;
    setState(() {
      _digits.removeLast();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_activation.canAccessApp) {
      setState(() => _error = _activation.status.message);
      return;
    }

    setState(() => _isLoading = true);
    final pin = _digits.join();
    final error = await sl<AuthChangeNotifier>().loginWithPin(pin);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
        _digits.clear();
        _error = error;
      });
      return;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _submitActivationCode() async {
    final code = _activationCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Ingresa el código de activación.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final error = await _activation.activate(code);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _error = error;
      if (error == null) {
        _activationCodeCtrl.clear();
        _digits.clear();
      }
    });
  }

  Future<void> _loginWithDemoPin(String pin) async {
    if (_isLoading) return;

    setState(() {
      _digits
        ..clear()
        ..addAll(pin.split(''));
      _error = null;
    });

    await _submit();
  }

  Future<void> _openSupportLink() async {
    final opened = await launchUrl(
      _supportUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace de soporte.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;
    final horizontalPadding = screenWidth < 360 ? 20.0 : 32.0;

    return AnimatedBuilder(
      animation: _activation,
      builder: (context, _) {
        final activationStatus = _activation.status;
        final requiresActivation = !_activation.canAccessApp;

        return Scaffold(
          backgroundColor: AppColors.background,
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: _SupportBanner(onTap: _openSupportLink),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 420 : 360,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/logo_la_pena.jpg',
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                                cacheWidth: isWide ? 200 : 120,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.restaurant_rounded,
                                  color: AppColors.primary,
                                  size: 64,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'La Peña',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Bar & Restaurant',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.secondary),
                            ),
                            const SizedBox(height: 32),
                            if (requiresActivation) ...[
                              Text(
                                'Ingresa tu código de activación',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                activationStatus.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _ActivationCard(
                                controller: _activationCodeCtrl,
                                error: _error,
                                isLoading: _isLoading || _activation.isLoading,
                                onSubmit: _submitActivationCode,
                                debugHint: null,
                              ),
                            ] else ...[
                              Text(
                                'Ingresa tu PIN',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.black87),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (i) {
                                  final filled = i < _digits.length;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: filled
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _error != null
                                            ? AppColors.error
                                            : AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 20),
                              if (kDebugMode) ...[
                                _DemoAccessCard(
                                  onSelectPin: _loginWithDemoPin,
                                  demoPins: _demoPins,
                                ),
                                const SizedBox(height: 12),
                              ],
                              const _SecurityNoticeCard(),
                              const SizedBox(height: 20),
                              if (_isLoading)
                                const CircularProgressIndicator()
                              else
                                _PinKeyboard(
                                  onDigit: _addDigit,
                                  onDelete: _removeDigit,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({
    required this.controller,
    required this.onSubmit,
    required this.isLoading,
    this.error,
    this.debugHint,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? error;
  final String? debugHint;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Código de activación',
                prefixIcon: Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (debugHint != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  debugHint!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: const Text('Activar y continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinKeyboard extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _PinKeyboard({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 320;
        final buttonWidth = isCompact ? 68.0 : 80.0;
        final buttonHeight = isCompact ? 60.0 : 72.0;

        return Column(
          children: [
            for (final row in digits)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row
                    .map(
                      (d) => _KeyButton(
                        label: d,
                        onTap: () => onDigit(d),
                        width: buttonWidth,
                        height: buttonHeight,
                      ),
                    )
                    .toList(),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: buttonWidth, height: buttonHeight),
                _KeyButton(
                  label: '0',
                  onTap: () => onDigit('0'),
                  width: buttonWidth,
                  height: buttonHeight,
                ),
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: IconButton(
                    icon: const Icon(Icons.backspace_outlined),
                    color: AppColors.secondary,
                    iconSize: 26,
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DemoAccessCard extends StatelessWidget {
  final void Function(String) onSelectPin;
  final List<({String label, String pin, IconData icon})> demoPins;

  const _DemoAccessCard({required this.onSelectPin, required this.demoPins});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acceso rápido solo en desarrollo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Esta ayuda no se muestra en la versión final instalada.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in demoPins)
                  ActionChip(
                    avatar: Icon(item.icon, size: 16, color: AppColors.primary),
                    label: Text('${item.label} · ${item.pin}'),
                    onPressed: () => onSelectPin(item.pin),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityNoticeCard extends StatelessWidget {
  const _SecurityNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceVariant,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Seguridad activa: después de 3 intentos fallidos el acceso se bloquea temporalmente. Cambia los PIN iniciales desde Usuarios.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.code_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Desarrollado por',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'DevKosmosyne',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Soporte',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.width = 80,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
