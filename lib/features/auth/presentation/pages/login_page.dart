import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/widgets/auth_email_password_form.dart';

/// Pantalla de login con Firebase Authentication.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _activationCodeCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_activation.canAccessApp) {
      setState(() => _error = _activation.status.message);
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final error = await sl<AuthChangeNotifier>().loginWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
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
      }
    });
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
                                'Inicia sesión con Firebase',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              AuthEmailPasswordForm(
                                emailController: _emailCtrl,
                                passwordController: _passwordCtrl,
                                isLoading: _isLoading,
                                errorText: _error,
                                onSubmit: _submit,
                              ),
                              const SizedBox(height: 12),
                              const _SecurityNoticeCard(),
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
