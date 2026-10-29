import 'package:flutter/material.dart';

import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
import 'auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.auth,
    this.intendedRoute,
    this.onBackToRegistration,
  });
  final AuthGateway auth;
  final String? intendedRoute;
  final VoidCallback? onBackToRegistration;
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
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [UnifiedColors.page, UnifiedColors.pageTint],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: UnifiedColors.brandNavy,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.church_outlined,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'IEADPE',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: UnifiedColors.brandNavy,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Novos Convertidos',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: UnifiedColors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Entre com sua conta Google para continuar.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: UnifiedColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Base44Panel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : _login,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_outlined),
                              label: Text(
                                _busy ? 'Abrindo acesso…' : 'Entrar com Google',
                              ),
                            ),
                            if (_message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _message!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: UnifiedColors.red,
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.onBackToRegistration != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : widget.onBackToRegistration,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Voltar ao cadastro'),
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
        ),
      ),
    ),
  );
}
