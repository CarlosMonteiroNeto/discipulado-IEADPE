/// Password-reset page with an anti-enumeration generic response (S04, S10).
library;

import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';
import '../../ui/form_fields.dart';
import 'auth_controller.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, required this.controller});

  final AuthController controller;

  static const Key emailFieldKey = Key('reset-email');
  static const Key submitKey = Key('reset-submit');
  static const Key confirmationKey = Key('reset-confirmation');

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final GlobalKey<AppFormState> _formKey = GlobalKey<AppFormState>();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool valid =
        _formKey.currentState?.validateAndFocusFirstError() ?? false;
    if (!valid) {
      return;
    }
    await widget.controller.requestPasswordReset(_email.text);
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
                          'Recuperar senha',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        Text(
                          'Informe o e-mail da sua conta.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.x6),
                        AppTextField(
                          key: PasswordResetPage.emailFieldKey,
                          label: 'E-mail',
                          controller: _email,
                          enabled: !state.submitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          required: true,
                          validator: AuthValidation.email,
                        ),
                        if (state.failure != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.x3),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              state.failure!.message,
                              style: TextStyle(color: tokens.error),
                            ),
                          ),
                        ],
                        if (state.resetRequested) ...<Widget>[
                          const SizedBox(height: AppSpacing.x3),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Se houver uma conta com este e-mail, enviaremos as instruções.',
                              key: PasswordResetPage.confirmationKey,
                              style: TextStyle(color: tokens.onSurfaceVariant),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.x6),
                        AppButton(
                          key: PasswordResetPage.submitKey,
                          label: 'Enviar instruções',
                          isSubmitting: state.submitting,
                          onPressed: _submit,
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
