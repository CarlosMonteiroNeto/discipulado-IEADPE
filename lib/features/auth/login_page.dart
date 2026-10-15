import 'package:flutter/material.dart';

import 'auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth, this.intendedRoute});
  final AuthGateway auth;
  final String? intendedRoute;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _busy = false;
  String? _message;
  Future<void> _login() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.auth.signInWithGoogle(intendedRoute: widget.intendedRoute);
      if (mounted) {
        setState(
          () => _message =
              'Conclua o acesso no navegador. Se cancelou, tente novamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Não foi possível entrar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('IEADPE')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.church, size: 48, color: Color(0xff1e3a5f)),
                const SizedBox(height: 24),
                Text(
                  'Novos Convertidos',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text('Entre com sua conta Google para continuar.'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: Text(_busy ? 'Abrindo acesso…' : 'Entrar com Google'),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(liveRegion: true, child: Text(_message!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
