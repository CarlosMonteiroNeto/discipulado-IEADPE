import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
import 'feedback_repository.dart';

/// Inline protected content. Mount inside the protected root, never a root route.
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({
    super.key,
    required this.repository,
    required this.onClose,
    required this.onScopeRefresh,
  });
  final FeedbackRepository repository;
  final VoidCallback onClose;
  final Future<void> Function() onScopeRefresh;
  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _text = TextEditingController();
  String? _operation, _snapshot, _notice;
  bool _busy = false;
  late String _token;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _token = widget.repository.gateway.context;
  }

  @override
  void didUpdateWidget(covariant FeedbackDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_token != widget.repository.gateway.context) {
      _request++;
      _text.clear();
      _operation = null;
      _snapshot = null;
      _notice = null;
      _busy = false;
      _token = widget.repository.gateway.context;
    }
  }

  @override
  void dispose() {
    _request++;
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final message = _snapshot ?? _text.text.trim();
    if (message.isEmpty || message.runes.length > 5000) {
      setState(() => _notice = 'Escreva uma mensagem de até 5.000 caracteres.');
      return;
    }
    _snapshot = message;
    _operation ??= const Uuid().v4();
    final request = ++_request, token = _token;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      widget.repository.gateway.ensureCurrent(token);
      final result = await widget.repository.submit(message, _operation!);
      if (!mounted || request != _request) return;
      widget.repository.gateway.ensureCurrent(token);
      setState(() {
        _busy = false;
        if (result.status == MutationStatus.applied) {
          _text.clear();
          _snapshot = null;
          _operation = null;
          _notice = 'Mensagem enviada! Obrigado pelo feedback.';
        } else {
          _notice = feedbackFailure(result.errorCode);
          if (!uncertainFeedback(result.errorCode)) {
            _operation = null;
            _snapshot = null;
          }
        }
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      if (widget.repository.gateway.context != token) {
        setState(() {
          _text.clear();
          _operation = null;
          _snapshot = null;
          _notice = null;
          _busy = false;
        });
        return;
      }
      setState(() {
        _busy = false;
        _notice = feedbackFailure(error is DataFailure ? error.code : null);
      });
    }
  }

  Future<void> _refreshScope() async {
    if (_busy) return;
    final request = ++_request, token = _token;
    setState(() => _busy = true);
    try {
      widget.repository.gateway.ensureCurrent(token);
      await widget.onScopeRefresh();
      if (!mounted || request != _request) return;
      widget.repository.gateway.ensureCurrent(token);
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _busy = false;
        _notice = feedbackFailure(error is DataFailure ? error.code : null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Base44PageHeading(
                title: 'Dúvidas e sugestões',
                icon: Icons.chat_bubble_outline,
              ),
              const SizedBox(height: 16),
              Base44Panel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Compartilhe suas dúvidas, sugestões ou relate um erro encontrado.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: UnifiedColors.muted),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      readOnly: _busy || _snapshot != null,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Sua mensagem',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _notice!,
                            semanticsLabel: _notice,
                            style: TextStyle(
                              color: _notice!.startsWith('Mensagem enviada')
                                  ? const Color(0xff166534)
                                  : UnifiedColors.red,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _busy ? null : _refreshScope,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar acesso'),
                        ),
                        TextButton(
                          onPressed: widget.onClose,
                          child: const Text('Fechar'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _send,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _busy
                                ? 'Enviando…'
                                : _snapshot != null
                                ? 'Tentar novamente'
                                : 'Enviar',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

bool uncertainFeedback(String? code) =>
    !{'invalid', 'permission', 'stale'}.contains(code);
String feedbackFailure(String? code) => switch (code) {
  'permission' ||
  'stale' => 'Seu acesso mudou. Atualize o acesso para continuar.',
  'invalid' =>
    'Confira a mensagem e tente novamente. O limite é de 5.000 caracteres.',
  _ => 'Não foi possível confirmar. Tente novamente para concluir a mesma operação.',
};
