import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/convert_repository.dart';
import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../ui/unified_theme.dart';
import '../photos/photo_repository.dart';
import 'convert_form.dart';
import 'convert_save_controller.dart';
import '../intake/intake_models.dart';
import '../intake/public_intake_repository.dart';
import '../intake/turnstile_challenge.dart';

final class _PendingConvertSubmission {
  const _PendingConvertSubmission({required this.id, required this.draft});

  final String id;
  final PublicIntakeDraft draft;
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.converts,
    required this.photos,
    this.congregations = const [],
    this.onCancel,
    this.onSaved,
    this.initial,
    this.pickPhoto,
    required this.scope,
    this.publicIntakeRepository,
    this.turnstileChallengeFactory,
    this.revalidateScope,
    this.revalidatePhotoAuthority,
  });
  final ConvertRepository converts;
  final PhotoRepository photos;
  final List<Congregation> congregations;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onSaved;
  final ConvertRecord? initial;
  final Future<Uint8List?> Function()? pickPhoto;
  final AccessScope scope;
  final PublicIntakeRepository? publicIntakeRepository;
  final TurnstileChallengeFactory? turnstileChallengeFactory;
  final Future<bool> Function(String? congregationId)? revalidateScope;
  final Future<bool> Function(String? congregationId)? revalidatePhotoAuthority;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final ConvertSaveController _save;
  TurnstileChallenge? _challenge;
  Uint8List? _oldPhoto;
  bool _success = false, _loadingPhoto = false, _pendingBusy = false;
  bool _pendingMode = false, _pendingSuccess = false;
  int _formGeneration = 0;
  String? _selectedCongregation, _pendingError;
  _PendingConvertSubmission? _frozen;
  String? _photoError;

  TurnstileChallenge get _turnstile => _challenge ??=
      (widget.turnstileChallengeFactory ?? createTurnstileChallenge)();

  bool _pendingFor(String? congregationId) => congregationId == null
      ? !widget.scope.isGlobalManager && widget.scope.congregationIds.isEmpty
      : !widget.scope.canAccess(congregationId);

  @override
  void initState() {
    super.initState();
    _save = ConvertSaveController(
      gateway: widget.converts.gateway,
      photos: widget.photos,
      initial: widget.initial,
    );
    _selectedCongregation = widget.initial?.congregationId;
    _pendingMode = _pendingFor(_selectedCongregation);
    if (widget.initial?.photoAssetId != null &&
        widget.scope.canAccess(widget.initial?.congregationId)) {
      _loadPhoto();
    }
  }

  @override
  void didUpdateWidget(covariant RegisterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      final lostPhotoAuthority =
          oldWidget.scope.canAccess(_selectedCongregation) &&
          !widget.scope.canAccess(_selectedCongregation);
      if (lostPhotoAuthority) _clearProtectedPhoto();
      _pendingMode = _pendingFor(_selectedCongregation);
    }
  }

  @override
  void dispose() {
    _save.clear();
    _oldPhoto = null;
    _challenge?.dispose();
    _challenge = null;
    super.dispose();
  }

  void _clearProtectedPhoto() {
    _oldPhoto = null;
    _photoError = null;
    _loadingPhoto = false;
  }

  void _revokeProtectedPhoto() {
    if (!mounted) return;
    setState(_clearProtectedPhoto);
  }

  void _congregationChanged(String? congregationId) {
    if (!mounted) return;
    setState(() {
      _selectedCongregation = congregationId;
      _pendingMode = _pendingFor(congregationId);
      _pendingError = null;
    });
  }

  bool _current(String token) {
    if (!mounted) return false;
    try {
      widget.converts.gateway.ensureCurrent(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadPhoto() async {
    final token = widget.converts.gateway.context;
    setState(() {
      _loadingPhoto = true;
      _photoError = null;
    });
    try {
      final asset = await widget.photos.get(widget.initial!.photoAssetId!);
      final bytes = await widget.photos.download(asset);
      if (_current(token)) setState(() => _oldPhoto = bytes);
    } catch (_) {
      if (_current(token)) {
        setState(
          () => _photoError =
              'Não foi possível carregar a foto. Tente novamente.',
        );
      }
    } finally {
      if (_current(token)) setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _submit(ConvertDraft draft) async {
    final authorized =
        await (widget.revalidateScope?.call(draft.congregationId) ??
            Future<bool>.value(widget.scope.canAccess(draft.congregationId)));
    if (!mounted) return;
    if (!authorized) {
      if (widget.initial != null) throw const DataFailure('permission');
      await _submitPending(draft);
      return;
    }
    final token = widget.converts.gateway.context;
    final id = await _save.save(draft);
    if (!_current(token)) throw const DataFailure('stale');
    setState(() {
      _success = true;
      _pendingSuccess = false;
      _oldPhoto = null;
    });
    widget.onSaved?.call(id);
  }

  Future<void> _submitPending(ConvertDraft draft) async {
    final repository = widget.publicIntakeRepository;
    final challenge = _turnstile;
    if (repository == null || !challenge.isSupported) {
      setState(
        () => _pendingError =
            'O envio público está indisponível neste dispositivo.',
      );
      return;
    }
    if (draft.photoBytes != null || draft.removePhoto) {
      _revokeProtectedPhoto();
      setState(() {
        _pendingMode = true;
        _pendingError = 'Seu acesso mudou. A foto foi removida; confira os dados e tente novamente.';
      });
      return;
    }
    final submission =
        _frozen ??
        _PendingConvertSubmission(
          id: const Uuid().v4(),
          draft: PublicIntakeDraft.fromConvertDraft(draft),
        );
    setState(() {
      _pendingMode = true;
      _pendingBusy = true;
      _frozen = submission;
      _pendingError = null;
    });
    try {
      // If scope revalidation redirected this choice to the pending path,
      // give the page-owned challenge a frame to mount before acquiring a token.
      await WidgetsBinding.instance.endOfFrame;
      final token = await challenge.acquireToken();
      try {
        await repository.submit(
          submissionId: submission.id,
          turnstileToken: token,
          draft: submission.draft,
        );
      } on PublicIntakeFailure catch (failure) {
        if (!mounted) return;
        challenge.reset();
        setState(() {
          _frozen = failure.outcomeUnknown ? submission : null;
          _pendingError = _messageFor(failure);
        });
        return;
      } catch (_) {
        if (!mounted) return;
        challenge.reset();
        setState(() {
          _frozen = submission;
          _pendingError =
              'Não foi possível confirmar o envio. Tente novamente.';
        });
        return;
      }
      if (!mounted) return;
      challenge.reset();
      setState(() {
        _success = true;
        _pendingSuccess = true;
        _frozen = null;
        _pendingError = null;
        _oldPhoto = null;
      });
    } catch (_) {
      if (!mounted) return;
      challenge.reset();
      setState(() {
        _frozen = null;
        _pendingError = 'Não foi possível concluir a verificação de segurança.';
      });
    } finally {
      if (mounted) setState(() => _pendingBusy = false);
    }
  }

  Future<void> _retryPending() async {
    final repository = widget.publicIntakeRepository;
    final submission = _frozen;
    if (_pendingBusy || repository == null || submission == null) return;
    final challenge = _turnstile;
    setState(() {
      _pendingBusy = true;
      _pendingError = null;
    });
    try {
      challenge.reset();
      final token = await challenge.acquireToken();
      try {
        await repository.submit(
          submissionId: submission.id,
          turnstileToken: token,
          draft: submission.draft,
        );
      } on PublicIntakeFailure catch (failure) {
        if (!mounted) return;
        challenge.reset();
        setState(() {
          _frozen = failure.outcomeUnknown ? submission : null;
          _pendingError = _messageFor(failure);
        });
        return;
      } catch (_) {
        if (!mounted) return;
        challenge.reset();
        setState(() {
          _frozen = submission;
          _pendingError =
              'Não foi possível confirmar o envio. Tente novamente.';
        });
        return;
      }
      if (!mounted) return;
      challenge.reset();
      setState(() {
        _success = true;
        _pendingSuccess = true;
        _frozen = null;
        _pendingError = null;
        _oldPhoto = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _frozen = submission;
        _pendingError = 'Não foi possível confirmar o envio. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _pendingBusy = false);
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

  void _newRegistration() {
    _turnstile.reset();
    setState(() {
      _success = false;
      _pendingSuccess = false;
      _pendingError = null;
      _frozen = null;
      _formGeneration++;
      _selectedCongregation = null;
      _pendingMode = _pendingFor(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    bool photoAuthority(String? id) => scope.canAccess(id);
    final pendingReady =
        widget.publicIntakeRepository != null && _turnstile.isSupported;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: UnifiedColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ColoredBox(
                      color: UnifiedColors.brandNavy,
                      child: SizedBox(height: 4),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            UnifiedColors.brandNavy,
                            UnifiedColors.brandBlue,
                          ],
                        ),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Icon(
                            widget.initial == null
                                ? Icons.person_add_alt_1
                                : Icons.edit_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Text(
                              widget.initial == null
                                  ? 'Cadastrar Novo Convertido'
                                  : 'Editar Convertido',
                              softWrap: true,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _success
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    widget.initial == null
                                        ? _pendingSuccess
                                              ? 'Cadastro enviado para análise da congregação.'
                                              : 'Novo convertido cadastrado com sucesso!'
                                        : 'Convertido atualizado com sucesso!',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (widget.initial == null)
                                  FilledButton.icon(
                                    onPressed: _newRegistration,
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text(
                                      'Cadastrar outro convertido',
                                    ),
                                  ),
                                TextButton(
                                  onPressed: widget.onCancel,
                                  child: const Text('Voltar'),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                if (_loadingPhoto)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text('Carregando foto…'),
                                  ),
                                if (_photoError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      children: [
                                        Text(_photoError!),
                                        TextButton.icon(
                                          onPressed: _loadPhoto,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text(
                                            'Tentar carregar foto novamente',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_pendingMode) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _turnstile.view,
                                  ),
                                  if (widget.publicIntakeRepository == null)
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'O envio público está indisponível.',
                                      ),
                                    ),
                                  if (_pendingError != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Semantics(
                                        liveRegion: true,
                                        child: Text(_pendingError!),
                                      ),
                                    ),
                                  if (_frozen != null && !_pendingBusy)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.icon(
                                        onPressed: _retryPending,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text(
                                          'Tentar envio novamente',
                                        ),
                                      ),
                                    ),
                                ],
                                ConvertForm(
                                  key: ValueKey(
                                    'register-form-$_formGeneration',
                                  ),
                                  initial: widget.initial,
                                  congregations: widget.congregations,
                                  onSubmit: _submit,
                                  onCancel: widget.onCancel,
                                  gateway: widget.converts.gateway,
                                  existingPhoto:
                                      photoAuthority(_selectedCongregation)
                                      ? _oldPhoto
                                      : null,
                                  pickPhoto: widget.pickPhoto,
                                  allowPhotos: true,
                                  photoAuthority: photoAuthority,
                                  revalidatePhotoAuthority:
                                      widget.revalidatePhotoAuthority,
                                  onPhotoAuthorityRevoked:
                                      _revokeProtectedPhoto,
                                  onCongregationChanged: _congregationChanged,
                                  submissionLocked: _frozen != null,
                                  submitEnabled:
                                      !_pendingMode ||
                                      (pendingReady && _frozen == null),
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
    );
  }
}
