import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Dúvidas e sugestões',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Compartilhe suas dúvidas, sugestões ou relate um erro encontrado.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                readOnly: _busy || _snapshot != null,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Sua mensagem',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_notice!, semanticsLabel: _notice),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _refreshScope,
                    child: const Text('Atualizar acesso'),
                  ),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Fechar'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _send,
                    child: Text(
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
