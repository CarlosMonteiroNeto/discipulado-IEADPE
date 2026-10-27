import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../converts/congregation_order.dart';
import '../converts/convert_form.dart';
import '../../platform/portuguese_sort.dart';
import '../../ui/unified_theme.dart';
import '../../widgets/app_shell.dart';
import 'intake_models.dart';
import 'public_intake_repository.dart';
import 'turnstile_challenge.dart';

final class _FrozenSubmission {
  const _FrozenSubmission({required this.id, required this.draft});

  final String id;
  final PublicIntakeDraft draft;
}

class PublicRegistrationPage extends StatefulWidget {
  const PublicRegistrationPage({
    super.key,
    required this.repository,
    required this.challenge,
    this.sortNames,
    this.onNavigateToProtected,
  });

  final PublicIntakeRepository? repository;
  final TurnstileChallenge challenge;
  final Future<List<String>> Function(List<String>)? sortNames;
  final ValueChanged<String>? onNavigateToProtected;

  @override
  State<PublicRegistrationPage> createState() => _PublicRegistrationPageState();
}

class _PublicRegistrationPageState extends State<PublicRegistrationPage> {
  List<Congregation> _catalog = const [];
  String? _catalogError;
  bool _catalogLoading = true;
  bool _busy = false;
  bool _accepted = false;
  String? _error;
  _FrozenSubmission? _frozen;
  int _formGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.repository == null) {
      _catalogLoading = false;
      _catalogError = 'O serviço de cadastro está indisponível.';
    } else {
      unawaited(_loadCatalog());
    }
  }

  @override
  void dispose() {
    widget.challenge.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final repository = widget.repository;
    if (repository == null || _catalogLoading && _catalog.isNotEmpty) return;
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      final publicItems = await repository.listAllCongregations();
      final ordered = await orderCongregations([
        for (final item in publicItems)
          Congregation(id: item.id, name: item.name),
      ], sortNames: widget.sortNames ?? sortPortugueseNames);
      if (!mounted) return;
      setState(() => _catalog = List.unmodifiable(ordered));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalog = const [];
        _catalogError =
            'Não foi possível carregar as congregações. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  Future<void> _submit(ConvertDraft draft) async {
    if (_busy || _accepted) return;
    final repository = widget.repository;
    if (repository == null || !widget.challenge.isSupported) {
      setState(() => _error = 'A verificação de segurança está indisponível.');
      return;
    }
    final retrying = _frozen != null;
    final submission =
        _frozen ??
        _FrozenSubmission(
          id: const Uuid().v4(),
          draft: PublicIntakeDraft.fromConvertDraft(draft),
        );
    setState(() {
      _busy = true;
      _error = null;
      _frozen = submission;
    });
    try {
      if (retrying) widget.challenge.reset();
      final token = await widget.challenge.acquireToken();
      await repository.submit(
        submissionId: submission.id,
        turnstileToken: token,
        draft: submission.draft,
      );
      if (!mounted) return;
      widget.challenge.reset();
      setState(() {
        _accepted = true;
        _frozen = null;
        _error = null;
      });
    } on PublicIntakeFailure catch (failure) {
      widget.challenge.reset();
      if (!mounted) return;
      setState(() {
        _frozen = failure.outcomeUnknown ? submission : null;
        _error = _messageFor(failure);
      });
    } on ArgumentError {
      if (!mounted) return;
      setState(() {
        _frozen = null;
        _error = 'Confira os campos obrigatórios e tente novamente.';
      });
    } catch (_) {
      widget.challenge.reset();
      if (!mounted) return;
      setState(() {
        _frozen = retrying ? submission : null;
        _error = retrying
            ? 'Não foi possível confirmar o envio. Tente novamente.'
            : 'Não foi possível concluir a verificação de segurança.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(PublicIntakeFailure failure) => switch (failure.code) {
    PublicIntakeFailureCode.validation =>
      'Confira os dados do cadastro e tente novamente.',
    PublicIntakeFailureCode.conflict => 'Não foi possível confirmar esta tentativa. Revise os dados e tente novamente.',
    PublicIntakeFailureCode.rateLimited =>
      'Muitas tentativas. Aguarde ${failure.retryAfterSeconds ?? 60} segundos e tente novamente.',
    PublicIntakeFailureCode.unavailable => 'Não foi possível confirmar o envio. Seus dados estão mantidos para uma nova tentativa.',
    PublicIntakeFailureCode.botCheckFailed =>
      'A verificação de segurança expirou. Faça a verificação novamente.',
    PublicIntakeFailureCode.invalidResponse =>
      'Não foi possível confirmar o envio. Tente novamente.',
  };

  Future<void> _retry() async {
    final repository = widget.repository;
    final submission = _frozen;
    if (_busy || repository == null || submission == null) return;
    setState(() => _busy = true);
    try {
      widget.challenge.reset();
      final token = await widget.challenge.acquireToken();
      await repository.submit(
        submissionId: submission.id,
        turnstileToken: token,
        draft: submission.draft,
      );
      if (!mounted) return;
      widget.challenge.reset();
      setState(() {
        _accepted = true;
        _frozen = null;
        _error = null;
      });
    } on PublicIntakeFailure catch (failure) {
      widget.challenge.reset();
      if (!mounted) return;
      setState(() {
        _frozen = failure.outcomeUnknown ? submission : null;
        _error = _messageFor(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _frozen = submission;
        _error = 'Não foi possível confirmar o envio. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearDraft() {
    if (_busy || _frozen != null) return;
    setState(() {
      _error = null;
      _formGeneration++;
    });
  }

  void _newRegistration() {
    setState(() {
      _accepted = false;
      _error = null;
      _formGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) => AppShell(
    scope: AccessScope(),
    currentRoute: '/register',
    publicMode: true,
    onNavigate: (route) => widget.onNavigateToProtected?.call(route),
    onSignOut: () {},
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: UnifiedColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cadastro público',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Preencha os dados do novo convertido. O cadastro será enviado para análise da congregação.',
                  ),
                  if (_catalogLoading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Carregando congregações…'),
                  ],
                  if (_catalogError != null) ...[
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, child: Text(_catalogError!)),
                    TextButton.icon(
                      onPressed: _catalogLoading ? null : _loadCatalog,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar carregar novamente'),
                    ),
                  ],
                  if (_accepted) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Cadastro enviado para análise da congregação.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _newRegistration,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Fazer novo cadastro'),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: widget.challenge.view,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(liveRegion: true, child: Text(_error!)),
                    ],
                    if (_frozen != null && !_busy) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar envio novamente'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ConvertForm(
                      key: ValueKey('public-registration-$_formGeneration'),
                      congregations: _catalog,
                      allowPhotos: false,
                      requireCongregation: true,
                      submissionLocked: _frozen != null,
                      submitEnabled:
                          !_busy &&
                          !_catalogLoading &&
                          _catalogError == null &&
                          _catalog.isNotEmpty &&
                          widget.repository != null &&
                          widget.challenge.isSupported &&
                          _frozen == null,
                      onSubmit: _submit,
                      onCancel: _clearDraft,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
