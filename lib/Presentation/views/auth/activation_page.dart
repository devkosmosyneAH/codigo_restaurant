import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/Presentation/core/di/injection_container.dart';
import 'package:restaurant_app/Presentation/providers/auth/activation_provider.dart';
import 'package:restaurant_app/Presentation/config/routes/app_router.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  ActivationPageState createState() => ActivationPageState();
}

class ActivationPageState extends State<ActivationPage> {
  final _controller = TextEditingController();
  late final ActivationChangeNotifier _activation;

  @override
  void initState() {
    super.initState();
    _activation = sl<ActivationChangeNotifier>();
    _activation.addListener(_onActivationChanged);
  }

  @override
  void dispose() {
    _activation.removeListener(_onActivationChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onActivationChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activation = _activation;
    final isLoading = activation.isLoading;
    final errorMessage = activation.status.message;
    final isActivated = activation.canAccessApp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activar app'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Ingrese su código de activación para continuar.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Código de activación',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = _controller.text.trim();
                      await activation.activate(code);
                    },
              child: Text(isLoading ? 'Validando...' : 'Activar'),
            ),
            const SizedBox(height: 12),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            if (isActivated)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'La aplicación está activada. Ahora puede iniciar sesión.',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () {
                GoRouter.of(context).go(AppRouter.login);
              },
              child: const Text('Ir a iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
