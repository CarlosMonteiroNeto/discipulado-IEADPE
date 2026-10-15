import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/convert_repository.dart';
import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../photos/photo_repository.dart';
import 'convert_form.dart';
import 'convert_save_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.converts,
    required this.photos,
    this.congregations = const [],
    this.onCancel,
    this.onSaved,
    this.initial,
    this.pickPhoto = pickConvertPhoto,
  });
  final ConvertRepository converts;
  final PhotoRepository photos;
  final List<Congregation> congregations;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onSaved;
  final ConvertRecord? initial;
  final Future<Uint8List?> Function() pickPhoto;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final ConvertSaveController _save;
  Uint8List? _oldPhoto;
  bool _success = false, _loadingPhoto = false;
  String? _photoError;
  @override
  void initState() {
    super.initState();
    _save = ConvertSaveController(
      gateway: widget.converts.gateway,
      photos: widget.photos,
      convertId: widget.initial?.id,
    );
    if (widget.initial?.photoAssetId != null) _loadPhoto();
  }

  @override
  void dispose() {
    _save.clear();
    _oldPhoto = null;
    super.dispose();
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
    final token = widget.converts.gateway.context;
    final id = await _save.save(draft);
    if (!_current(token)) throw const DataFailure('stale');
    setState(() {
      _success = true;
      _oldPhoto = null;
    });
    widget.onSaved?.call(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('IEADPE • Novos Convertidos')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff1e3a5f), Color(0xff2563eb)],
                      ),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        const Icon(Icons.church, color: Colors.white),
                        Text(
                          widget.initial == null
                              ? 'Cadastrar Novo Convertido'
                              : 'Editar Convertido',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _success
                        ? Column(
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  widget.initial == null
                                      ? 'Novo convertido cadastrado com sucesso!'
                                      : 'Convertido atualizado com sucesso!',
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (widget.initial == null)
                                FilledButton(
                                  onPressed: () =>
                                      setState(() => _success = false),
                                  child: const Text(
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
                              if (_loadingPhoto) const Text('Carregando foto…'),
                              if (_photoError != null)
                                Column(
                                  children: [
                                    Text(_photoError!),
                                    TextButton(
                                      onPressed: _loadPhoto,
                                      child: const Text(
                                        'Tentar carregar foto novamente',
                                      ),
                                    ),
                                  ],
                                ),
                              ConvertForm(
                                initial: widget.initial,
                                congregations: widget.congregations,
                                onSubmit: _submit,
                                onCancel: widget.onCancel,
                                gateway: widget.converts.gateway,
                                existingPhoto: _oldPhoto,
                                pickPhoto: widget.pickPhoto,
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
