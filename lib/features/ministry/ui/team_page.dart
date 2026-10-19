import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.repository,
    this.congregationId,
    this.supervision = false,
  });
  final MinistryRepository repository;
  final String? congregationId;
  final bool supervision;
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final _uuid = const Uuid();
  final _search = TextEditingController();
  MinistryPage<MinistryDirectoryEntry>? _page;
  String? _cursor;
  String? _error;
  bool _loading = false;
  bool _teacherDetailLoading = false;
  BuildContext? _teacherDialogContext;
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TeamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.supervision != widget.supervision) {
      _search.clear();
      _page = null;
      _teacherDetailLoading = false;
      _loadGeneration++;
      final dialogContext = _teacherDialogContext;
      if (dialogContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        });
      }
      _load();
    }
  }

  Future<void> _load({String? cursor}) async {
    final generation = ++_loadGeneration;
    final congregationId = widget.congregationId;
    final supervision = widget.supervision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listDirectory(
        scope: supervision ? 'supervision' : 'congregation',
        congregationId: congregationId,
        namePrefix: _search.text.trim().isEmpty ? null : _search.text.trim(),
        limit: 50,
        cursor: cursor,
      );
      if (mounted &&
          generation == _loadGeneration &&
          congregationId == widget.congregationId &&
          supervision == widget.supervision) {
        setState(() {
          _page = page;
          _cursor = cursor;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar a equipe. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Base44PageHeading(
                title: 'Equipe de discipulado',
                icon: Icons.groups_outlined,
                subtitle: widget.supervision
                    ? 'Diretório de supervisão'
                    : 'Diretório da congregação',
                trailing: !widget.supervision && widget.congregationId != null
                    ? FilledButton.icon(
                        onPressed: _loading || _teacherDetailLoading
                            ? null
                            : () => _openTeacherEditor(),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Adicionar professor'),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loading ? null : () => _load(),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : () => _load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Base44Panel(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando equipe',
                    ),
                  ),
                ),
              if (_error != null)
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _load(cursor: _cursor),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Base44Panel(child: Text('Nenhuma pessoa encontrada.')),
              for (final item
                  in _page?.items ?? const <MinistryDirectoryEntry>[])
                Card(
                  child: ListTile(
                    title: Text(item.name, softWrap: true),
                    subtitle: Text(
                      item.roleCode ?? 'Sem função atribuída',
                      softWrap: true,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: UnifiedColors.pageTint,
                      foregroundColor: UnifiedColors.brandNavy,
                      child: Icon(Icons.person_outline),
                    ),
                    trailing:
                        !widget.supervision &&
                            item.roleCode == 'teacher' &&
                            widget.congregationId != null
                        ? IconButton(
                            tooltip: 'Editar professor',
                            onPressed: _teacherDetailLoading
                                ? null
                                : () => _openTeacherEditor(item),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                    minVerticalPadding: 12,
                    onTap:
                        !widget.supervision &&
                            item.roleCode == 'teacher' &&
                            widget.congregationId != null
                        ? () => _openTeacherEditor(item)
                        : null,
                  ),
                ),
              if (_page?.nextCursor != null)
                Base44Panel(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _load(cursor: _page!.nextCursor),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próxima página'),
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

  Future<void> _openTeacherEditor([MinistryDirectoryEntry? item]) async {
    final scopeId = widget.congregationId;
    if (widget.supervision || scopeId == null || _teacherDetailLoading) return;
    MinistryTeacherContactDetail? detail;
    if (item != null) {
      setState(() {
        _teacherDetailLoading = true;
        _error = null;
      });
      try {
        detail = await widget.repository.getTeacherContact(
          congregationId: scopeId,
          contactId: item.id,
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            _teacherDetailLoading = false;
            _error = 'Não foi possível carregar os dados do professor.';
          });
        }
        return;
      }
      if (!mounted || widget.congregationId != scopeId || widget.supervision) {
        return;
      }
      setState(() => _teacherDetailLoading = false);
    }
    if (!mounted || widget.congregationId != scopeId || widget.supervision) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        _teacherDialogContext = dialogContext;
        return _TeacherContactDialog(
          repository: widget.repository,
          congregationId: scopeId,
          current: detail,
          createId: _uuid.v4,
          isScopeCurrent: () =>
              mounted &&
              widget.congregationId == scopeId &&
              !widget.supervision,
          onSaved: () {
            Navigator.of(dialogContext).pop();
            _teacherDialogContext = null;
            if (mounted) _load();
          },
        );
      },
    );
    _teacherDialogContext = null;
  }
}

class _TeacherContactDialog extends StatefulWidget {
  const _TeacherContactDialog({
    required this.repository,
    required this.congregationId,
    required this.current,
    required this.createId,
    required this.isScopeCurrent,
    required this.onSaved,
  });

  final MinistryRepository repository;
  final String congregationId;
  final MinistryTeacherContactDetail? current;
  final String Function() createId;
  final bool Function() isScopeCurrent;
  final VoidCallback onSaved;

  @override
  State<_TeacherContactDialog> createState() => _TeacherContactDialogState();
}

class _TeacherContactDialogState extends State<_TeacherContactDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _birthDate;
  late final String _contactId;
  bool _busy = false;
  String? _error;
  String? _signature;
  String? _operationId;

  @override
  void initState() {
    super.initState();
    _contactId = widget.current?.id ?? widget.createId();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _phone = TextEditingController(text: widget.current?.phoneE164 ?? '');
    _birthDate = TextEditingController(
      text: widget.current?.birthDate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.clear();
    _phone.clear();
    _birthDate.clear();
    _name.dispose();
    _phone.dispose();
    _birthDate.dispose();
    super.dispose();
  }

  CalendarDate? _parsedBirthDate() {
    final value = _birthDate.text.trim();
    if (value.isEmpty) return null;
    try {
      return CalendarDate.parse(value);
    } on MinistryDataException {
      return null;
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!widget.isScopeCurrent()) {
      setState(
        () => _error = 'A congregação selecionada mudou. Reabra o formulário.',
      );
      _name.clear();
      _phone.clear();
      _birthDate.clear();
      return;
    }
    final current = widget.current;
    final name = _name.text.trim();
    final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
    final birthDate = _parsedBirthDate();
    final id = _contactId;
    final signature = jsonEncode([
      widget.congregationId,
      id,
      current?.revision,
      name,
      phone,
      birthDate?.toString(),
    ]);
    if (_signature != signature) {
      _signature = signature;
      _operationId = widget.createId();
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveTeacherContact(
        operationId: _operationId!,
        id: id,
        congregationId: widget.congregationId,
        name: name,
        phoneE164: phone,
        birthDate: birthDate,
        expectedRevision: current?.revision,
      );
      widget.repository.gateway.ensureCurrent(token);
      if (!widget.isScopeCurrent()) return;
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is DataFailure && error.code == 'stale_revision'
            ? 'Outro usuário atualizou este contato. Feche e abra novamente para revisar os dados.'
            : 'Não foi possível salvar o professor. Os dados foram mantidos para uma nova tentativa.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.current == null ? 'Adicionar professor' : 'Editar professor',
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Função: Professor'),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('teacher-contact-name'),
                controller: _name,
                enabled: !_busy,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Nome é obrigatório';
                  if (name.length > 200)
                    return 'O nome deve ter até 200 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('teacher-contact-phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (phone.isNotEmpty &&
                      !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phone)) {
                    return 'Use o formato internacional, por exemplo +5511999990000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('teacher-contact-birth-date'),
                controller: _birthDate,
                enabled: !_busy,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Data de nascimento (aaaa-mm-dd)',
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        _parsedBirthDate() != null
                    ? null
                    : 'Informe uma data válida (aaaa-mm-dd)',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(_error!)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _save,
        icon: Icon(_busy ? Icons.hourglass_top : Icons.save_outlined),
        label: Text(_busy ? 'Salvando…' : 'Salvar'),
      ),
    ],
  );
}
