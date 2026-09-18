/// Explicit, user-initiated WhatsApp and phone-copy actions (S06, S10, S12).
///
/// The link carries only normalized digits and never prefills or sends any
/// personal or religious information.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/app_theme.dart';
import '../../ui/feedback.dart';
import '../../ui/form_fields.dart';

/// Digits-only form used by the `https://wa.me/{digits}` link (S06).
String phoneDigits(String? phoneE164) =>
    (phoneE164 ?? '').replaceAll(RegExp(r'[^0-9]'), '');

/// The user-initiated WhatsApp target, or `null` when no phone is available.
String? whatsAppUrl(String? phoneE164) {
  final String digits = phoneDigits(phoneE164);
  return digits.isEmpty ? null : 'https://wa.me/$digits';
}

class PhoneActions extends StatelessWidget {
  const PhoneActions({
    super.key,
    required this.phoneE164,
    this.onLaunch,
    this.onCopy,
  });

  final String? phoneE164;

  /// Injected launcher seam so tests never touch the platform channel.
  final Future<bool> Function(Uri uri)? onLaunch;

  /// Injected clipboard seam.
  final Future<void> Function(String digits)? onCopy;

  static const Key whatsAppKey = Key('phone-whatsapp');
  static const Key copyKey = Key('phone-copy');
  static const Key missingKey = Key('phone-missing');

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final String digits = phoneDigits(phoneE164);
    final String? url = whatsAppUrl(phoneE164);
    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        AppButton(
          key: whatsAppKey,
          label: 'WhatsApp',
          icon: Icons.chat_outlined,
          semanticLabel: 'Abrir conversa no WhatsApp',
          onPressed: url == null
              ? null
              : () => _launch(context, Uri.parse(url)),
        ),
        if (url == null)
          Text(
            'Telefone não informado',
            key: missingKey,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.onSurfaceVariant),
          )
        else
          AppButton(
            key: copyKey,
            label: 'Copiar telefone',
            variant: AppButtonVariant.secondary,
            onPressed: () => _copy(context, digits),
          ),
      ],
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final Future<bool> Function(Uri uri)? launcher = onLaunch;
    final bool opened = launcher != null
        ? await launcher(uri)
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppFeedback(
        context,
        message: 'Não foi possível abrir o WhatsApp.',
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _copy(BuildContext context, String digits) async {
    final Future<void> Function(String digits)? copier = onCopy;
    if (copier != null) {
      await copier(digits);
    } else {
      await Clipboard.setData(ClipboardData(text: digits));
    }
    if (context.mounted) {
      showAppFeedback(
        context,
        message: 'Telefone copiado.',
        type: AppFeedbackType.success,
      );
    }
  }
}
