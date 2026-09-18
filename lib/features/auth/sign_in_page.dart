/// Sign-in page (S04, S10). Consumes app_theme tokens and lib/ui primitives.
library;

import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';
import '../../ui/form_fields.dart';
import 'auth_controller.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.controller,
    this.returnTo,
    this.onAuthenticated,
    this.onForgotPassword,
  });

  final AuthController controller;
  final String? returnTo;
  final ValueChanged<String>? onAuthenticated;
  final VoidCallback? onForgotPassword;

  static const Key emailFieldKey = Key('sign-in-email');
  static const Key passwordFieldKey = Key('sign-in-password');
  static const Key submitKey = Key('sign-in-submit');
  static const Key errorKey = Key('sign-in-error');

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GlobalKey<AppFormState> _formKey = GlobalKey<AppFormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (_navigated || !widget.controller.state.isAuthorized) {
      return;
    }
    _navigated = true;
    final String destination =
        sanitizeReturnTo(widget.returnTo) ?? '/visao-geral';
    widget.onAuthenticated?.call(destination);
  }

  Future<void> _submit() async {
    final bool valid =
        _formKey.currentState?.validateAndFocusFirstError() ?? false;
    if (!valid) {
      return;
    }
    // The password is passed straight to the controller; it is never logged,
    // echoed or stored.
    await widget.controller.signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppForm(
                key: _formKey,
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (BuildContext context, Widget? _) {
                    final AuthState state = widget.controller.state;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Entrar',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.x6),
                        AppTextField(
                          key: SignInPage.emailFieldKey,
                          label: 'E-mail',
                          controller: _email,
                          enabled: !state.submitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          required: true,
                          validator: AuthValidation.email,
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        AppTextField(
                          key: SignInPage.passwordFieldKey,
                          label: 'Senha',
                          controller: _password,
                          enabled: !state.submitting,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          required: true,
                          validator: AuthValidation.password,
                        ),
                        if (state.failure != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.x3),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              state.failure!.message,
                              key: SignInPage.errorKey,
                              style: TextStyle(color: tokens.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.x6),
                        AppButton(
                          key: SignInPage.submitKey,
                          label: 'Entrar',
                          isSubmitting: state.submitting,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        AppButton(
                          variant: AppButtonVariant.text,
                          label: 'Esqueci minha senha',
                          onPressed: state.submitting
                              ? null
                              : widget.onForgotPassword,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
