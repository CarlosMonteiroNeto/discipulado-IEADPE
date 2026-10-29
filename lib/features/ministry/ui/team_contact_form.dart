import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/access_repository.dart';
import '../../../data/supabase_gateway.dart';
import '../../../domain/models.dart' show AccessRole;
import '../../../ui/base44_widgets.dart';
import '../../../ui/br_input.dart';
import '../../../ui/form_fields.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import 'team_role_labels.dart';

class TeamContactForm extends StatefulWidget {
  const TeamContactForm({
    super.key,
    required this.repository,
    required this.accessRepository,
    required this.scope,
    required this.congregationId,
    this.congregationName,
    required this.current,
    required this.directory,
    required this.canManageAccess,
    required this.createId,
    required this.isScopeCurrent,
    required this.onScopeRefresh,
    required this.onSaved,
  });

  final MinistryRepository repository;
  final AccessRepository accessRepository;
  final ContactScope scope;
  final String? congregationId;
  final String? congregationName;
  final MinistryContactDetail? current;
  final List<MinistryDirectoryEntry> directory;
  final bool canManageAccess;
  final String Function() createId;
  final bool Function() isScopeCurrent;
  final Future<void> Function()? onScopeRefresh;
  final VoidCallback onSaved;

  @override
  State<TeamContactForm> createState() => _TeamContactFormState();
}

class _TeamContactFormState extends State<TeamContactForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _birthDate;
  late final TextEditingController _email;
  late final String _contactId;
  RoleCode? _roleCode;
  late AccessRole _accessRole;
  bool _manageAccess = false;
  bool _replaceHolder = false;
  bool _loadingPrevious = false;
  bool _busy = false;
  bool _mutationAttempted = false;
  String? _previousContactId;
  MinistryContactDetail? _previousContact;
  String? _selectedAccessId;
  bool _createNewAccess = false;
  MinistryPage<TeamAccessCandidate>? _accessCandidatePage;
  bool _loadingAccessCandidates = false;
  String? _accessCandidateError;
  int _accessCandidateLoadGeneration = 0;
  String? _error;
  String? _saveSignature;
  String? _saveOperationId;
  String? _completedStageSignature;
  int? _completedStageRevision;
  bool _completedStageChangedAccess = false;
  String? _replaceSignature;
  String? _replaceOperationId;
  String? _lifecycleSignature;
  String? _lifecycleOperationId;

  MinistryContact? get _contact => widget.current?.contact;
  bool get _hasLinkedAccess => _contact?.accessLinked ?? false;

  bool get _canEditFields =>
      !_busy && !_mutationAttempted && !(_contact?.archived ?? false);

  bool get _canChangeArchiveState => !_busy && !_mutationAttempted;

  bool get _canEditEmail =>
      _canEditFields &&
      (!_hasLinkedAccess || (widget.canManageAccess && _manageAccess));

  @override
  void initState() {
    super.initState();
    _contactId = _contact?.id ?? widget.createId();
    _name = TextEditingController(text: _contact?.name ?? '');
    _phone = TextEditingController(text: brPhoneDisplay(_contact?.phoneE164));
    _birthDate = TextEditingController(
      text: brDateDisplay(_contact?.birthDate?.toString()),
    );
    _email = TextEditingController(text: _contact?.email ?? '');
    _roleCode = _contact?.roleCode;
    _accessRole = widget.scope == ContactScope.congregation
        ? AccessRole.direction
        : AccessRole.supervision;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _birthDate.dispose();
    _email.dispose();
    super.dispose();
  }

  CalendarDate? _parsedBirthDate() {
    final value = parseDateInput(_birthDate.text);
    return value == null
        ? null
        : CalendarDate(value.year, value.month, value.day);
  }

  List<MinistryDirectoryEntry> get _replacementCandidates => _roleCode == null
      ? const []
      : widget.directory
            .where(
              (entry) =>
                  entry.id != _contactId &&
                  entry.roleCode == _roleCode!.wire &&
                  entry.archivedAt == null,
            )
            .toList(growable: false);

  Future<void> _loadPreviousContact(String? id) async {
    setState(() {
      _previousContactId = id;
      _previousContact = null;
      _error = null;
      _loadingPrevious = id != null;
    });
    if (id == null) return;
    try {
      final detail = await widget.repository.getContact(
        scope: widget.scope,
        congregationId: widget.congregationId,
        contactId: id,
      );
      if (!mounted || !widget.isScopeCurrent()) return;
      setState(() {
        _previousContact = detail;
        _loadingPrevious = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previousContactId = null;
        _loadingPrevious = false;
        _error = 'Não foi possível carregar o contato que será substituído.';
      });
    }
  }

  Future<void> _loadAccessCandidates({String? cursor}) async {
    if (!widget.canManageAccess || !_manageAccess || _hasLinkedAccess) return;
    final generation = ++_accessCandidateLoadGeneration;
    if (cursor != null) {
      _selectedAccessId = null;
      _createNewAccess = false;
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _loadingAccessCandidates = true;
      _accessCandidateError = null;
    });
    try {
      final page = await widget.accessRepository.listCandidates(
        scope: widget.scope,
        congregationId: widget.congregationId,
        role: _accessRole,
        limit: 50,
        cursor: cursor,
      );
      widget.repository.gateway.ensureCurrent(token);
      if (!mounted ||
          generation != _accessCandidateLoadGeneration ||
          !widget.isScopeCurrent() ||
          !_manageAccess) {
        return;
      }
      setState(() {
        _accessCandidatePage = page;
        _loadingAccessCandidates = false;
      });
    } catch (_) {
      if (!mounted || generation != _accessCandidateLoadGeneration) return;
      setState(() {
        _loadingAccessCandidates = false;
        _accessCandidateError =
            'Não foi possível carregar os vínculos disponíveis.';
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if (!widget.isScopeCurrent()) {
      setState(() {
        _error = 'A congregação selecionada mudou. Reabra o formulário.';
        _name.clear();
        _phone.clear();
        _birthDate.clear();
        _email.clear();
      });
      return;
    }
    if (_replaceHolder &&
        (_previousContactId == null ||
            _previousContact == null ||
            _loadingPrevious)) {
      setState(() => _error = 'Selecione o ocupante atual da função.');
      return;
    }
    if (_manageAccess && _hasLinkedAccess && _selectedAccessId == null) {
      setState(
        () => _error = 'Selecione o vínculo de acesso que será atualizado.',
      );
      return;
    }
    if (_manageAccess &&
        !_hasLinkedAccess &&
        _selectedAccessId == null &&
        !_createNewAccess) {
      setState(
        () =>
            _error = 'Selecione um vínculo existente ou escolha criar um novo.',
      );
      return;
    }

    final name = _name.text.trim();
    final phone = resolveBrPhone(_phone.text);
    final birthDate = _parsedBirthDate();
    final emailText = _email.text.trim();
    final email = emailText.isEmpty ? null : emailText.toLowerCase();
    final current = _contact;
    final signature = jsonEncode([
      _contactId,
      current?.revision,
      widget.scope.wire,
      widget.congregationId,
      name,
      _roleCode?.wire,
      phone,
      birthDate?.toString(),
      email,
      _manageAccess,
      _selectedAccessId,
      _accessRole.wireValue,
      _replaceHolder,
      _previousContactId,
      _previousContact?.contact.revision,
    ]);
    if (_mutationAttempted && _saveSignature != signature) {
      setState(() {
        _error = 'O envio anterior ainda está pendente. Tente novamente ou reabra o formulário.';
      });
      return;
    }
    if (_saveSignature != signature) {
      _saveSignature = signature;
      _saveOperationId = widget.createId();
      _replaceSignature = null;
      _replaceOperationId = null;
      _completedStageSignature = null;
      _completedStageRevision = null;
      _completedStageChangedAccess = false;
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _mutationAttempted = true;
      _error = null;
    });

    try {
      var targetRevision = _completedStageRevision;
      var accessChanged = _completedStageChangedAccess;
      if (_completedStageSignature != signature) {
        final hasDirectoryChanges =
            current == null ||
            current.name != name ||
            current.roleCode != _roleCode ||
            current.phoneE164 != phone ||
            current.birthDate != birthDate ||
            (!_hasLinkedAccess && current.email != email);
        targetRevision = current?.revision;
        accessChanged = false;
        if (_manageAccess) {
          final accessResult = await widget.accessRepository
              .saveContactWithAccess(
                operationId: _saveOperationId!,
                id: _contactId,
                expectedRevision: current?.revision,
                scope: widget.scope,
                congregationId: widget.congregationId,
                name: name,
                roleCode: _roleCode,
                phoneE164: phone,
                birthDate: birthDate,
                email: email!,
                accessId: _selectedAccessId,
                accessRole: _accessRole,
                accessCongregationId: widget.scope == ContactScope.congregation
                    ? widget.congregationId
                    : null,
              );
          targetRevision = accessResult.revision;
          accessChanged = true;
        } else if (hasDirectoryChanges) {
          final result = await widget.repository.saveContact(
            operationId: _saveOperationId!,
            id: _contactId,
            scope: widget.scope,
            congregationId: widget.congregationId,
            name: name,
            roleCode: _roleCode,
            phoneE164: phone,
            birthDate: birthDate,
            email: email,
            expectedRevision: current?.revision,
          );
          targetRevision = result.revision;
        }
        _completedStageSignature = signature;
        _completedStageRevision = targetRevision;
        _completedStageChangedAccess = accessChanged;
      }

      if (_replaceHolder) {
        final previous = _previousContact!;
        final replaceSignature = jsonEncode([
          _contactId,
          targetRevision,
          _roleCode!.wire,
          previous.contact.id,
          previous.contact.revision,
          widget.scope.wire,
          widget.congregationId,
        ]);
        if (_replaceSignature != replaceSignature) {
          _replaceSignature = replaceSignature;
          _replaceOperationId = widget.createId();
        }
        await widget.repository.replaceRoleHolder(
          operationId: _replaceOperationId!,
          id: _contactId,
          scope: widget.scope,
          congregationId: widget.congregationId,
          roleCode: _roleCode!,
          previousContactId: previous.contact.id,
          expectedRevision: targetRevision!,
          previousExpectedRevision: previous.contact.revision,
        );
      }

      if (accessChanged) {
        widget.repository.gateway.boundary.invalidate();
        await widget.onScopeRefresh?.call();
      } else {
        widget.repository.gateway.ensureCurrent(token);
      }
      if (!mounted || !widget.isScopeCurrent()) return;
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is DataFailure && error.code == 'stale_revision'
            ? 'Outro usuário atualizou este contato. Feche e abra novamente para revisar os dados.'
            : 'Não foi possível confirmar. Os dados permanecem no formulário para uma nova tentativa.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeArchiveState() async {
    final contact = _contact;
    if (contact == null ||
        !_canChangeArchiveState ||
        !widget.isScopeCurrent()) {
      return;
    }
    final archived = !contact.archived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archived ? 'Arquivar contato?' : 'Restaurar contato?'),
        content: Text(
          archived
              ? 'O contato ficará no histórico. Esta ação não revoga o acesso ao aplicativo${_hasLinkedAccess ? '; ele continuará ativo até ser revogado separadamente' : ''}.'
              : 'O contato voltará a aparecer como ativo no diretório.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              archived ? 'Confirmar arquivamento' : 'Restaurar contato',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final signature = jsonEncode([
      contact.id,
      contact.revision,
      archived,
      widget.scope.wire,
      widget.congregationId,
    ]);
    if (_lifecycleSignature != signature) {
      _lifecycleSignature = signature;
      _lifecycleOperationId = widget.createId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.setContactArchived(
        operationId: _lifecycleOperationId!,
        id: contact.id,
        scope: widget.scope,
        congregationId: widget.congregationId,
        archived: archived,
        expectedRevision: contact.revision,
      );
      if (!mounted || !widget.isScopeCurrent()) return;
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível alterar o estado do contato. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeAccess() async {
    final contact = _contact;
    final access = widget.current?.access;
    if (contact == null || access == null || _busy || !widget.canManageAccess) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar acesso?'),
        content: Text(
          'Revogar o acesso de ${access.userEmail} mantém este contato no diretório e preserva o histórico de professor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar revogação'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !widget.isScopeCurrent()) return;
    final signature = jsonEncode([
      contact.id,
      contact.revision,
      access.id,
      widget.scope.wire,
      widget.congregationId,
    ]);
    if (_lifecycleSignature != signature) {
      _lifecycleSignature = signature;
      _lifecycleOperationId = widget.createId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accessRepository.revokeContactAccess(
        operationId: _lifecycleOperationId!,
        id: contact.id,
        scope: widget.scope,
        congregationId: widget.congregationId,
        expectedRevision: contact.revision,
      );
      widget.repository.gateway.boundary.invalidate();
      await widget.onScopeRefresh?.call();
      if (!mounted || !widget.isScopeCurrent()) return;
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível confirmar a revogação. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _contact;
    final archived = current?.archived ?? false;
    final roleOptions = RoleCode.values
        .where((role) => role.scope == widget.scope)
        .toList(growable: false);
    final linkedAccess = widget.current?.access;

    return AlertDialog(
      title: Text(current == null ? 'Novo contato' : 'Editar contato'),
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
                Base44SectionHeading(
                  title: 'Dados do contato',
                  subtitle:
                      'Função na equipe e acesso ao app são campos separados.',
                ),
                if (widget.congregationName != null) ...[
                  const SizedBox(height: UnifiedSpace.x2),
                  Text('Congregação: ${widget.congregationName}'),
                ],
                const SizedBox(height: UnifiedSpace.x3),
                TextFormField(
                  key: const ValueKey('team-contact-name'),
                  controller: _name,
                  enabled: _canEditFields,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Nome é obrigatório.';
                    if (name.length > 200) return 'Use até 200 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: UnifiedSpace.x2),
                DropdownButtonFormField<RoleCode?>(
                  key: const ValueKey('team-contact-role'),
                  initialValue: _roleCode,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Função na equipe',
                  ),
                  items: [
                    const DropdownMenuItem<RoleCode?>(
                      value: null,
                      child: Text('Sem função'),
                    ),
                    for (final role in roleOptions)
                      DropdownMenuItem<RoleCode?>(
                        value: role,
                        child: Text(teamRoleLabel(role.wire)),
                      ),
                  ],
                  onChanged: !_canEditFields
                      ? null
                      : (role) => setState(() {
                          _roleCode = role;
                          _replaceHolder = false;
                          _previousContactId = null;
                          _previousContact = null;
                        }),
                ),
                if (_roleCode != null && _replacementCandidates.isNotEmpty) ...[
                  const SizedBox(height: UnifiedSpace.x2),
                  CheckboxListTile(
                    key: const ValueKey('team-replace-holder-toggle'),
                    contentPadding: EdgeInsets.zero,
                    value: _replaceHolder,
                    onChanged: !_canEditFields
                        ? null
                        : (value) => setState(() {
                            _replaceHolder = value ?? false;
                            _previousContactId = null;
                            _previousContact = null;
                          }),
                    title: const Text('Substituir ocupante atual'),
                    subtitle: const Text(
                      'O contato anterior permanece no diretório e no histórico.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_replaceHolder)
                    DropdownButtonFormField<String>(
                      key: const ValueKey('team-replace-holder'),
                      initialValue: _previousContactId,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Contato que ocupa a função atualmente',
                      ),
                      items: [
                        for (final entry in _replacementCandidates)
                          DropdownMenuItem(
                            key: ValueKey('team-replace-option-${entry.id}'),
                            value: entry.id,
                            child: Text(entry.name, softWrap: true),
                          ),
                      ],
                      onChanged: _canEditFields ? _loadPreviousContact : null,
                      validator: (value) =>
                          value == null ? 'Selecione o contato atual.' : null,
                    ),
                ],
                const SizedBox(height: UnifiedSpace.x2),
                BrPhoneField(
                  fieldKey: const ValueKey('team-contact-phone'),
                  controller: _phone,
                  label: 'Telefone',
                  helperText: 'Opcional · 11 dígitos com DDD',
                  enabled: _canEditFields,
                ),
                const SizedBox(height: UnifiedSpace.x2),
                BrDateField(
                  fieldKey: const ValueKey('team-contact-birth-date'),
                  controller: _birthDate,
                  label: 'Nascimento',
                  helperText: 'Opcional · selecione no calendário',
                  enabled: _canEditFields,
                  allowClear: true,
                  validator: brDateValidationError,
                ),
                if (widget.canManageAccess) ...[
                  const SizedBox(height: UnifiedSpace.sectionGap),
                  Base44SectionHeading(
                    title: 'Acesso ao aplicativo',
                    subtitle: current?.email == null
                        ? 'Ao informar um email, o acesso será concedido automaticamente ao perfil desta equipe.'
                        : linkedAccess?.boundUserId == null && _hasLinkedAccess
                        ? 'Aguardando confirmação do email para ativar o acesso.'
                        : _hasLinkedAccess
                        ? 'Acesso ativo para ${linkedAccess!.userEmail}.'
                        : 'Um email novo concede acesso automaticamente; vínculos revogados permanecem revogados.',
                  ),
                  if (!archived)
                    CheckboxListTile(
                      key: const ValueKey('team-manage-access-toggle'),
                      contentPadding: EdgeInsets.zero,
                      value: _manageAccess,
                      onChanged: !_canEditFields
                          ? null
                          : (value) async {
                              final manageAccess = value ?? false;
                              setState(() {
                                _manageAccess = manageAccess;
                                _selectedAccessId = null;
                                _createNewAccess = false;
                                _accessCandidatePage = null;
                                _accessCandidateError = null;
                                _accessCandidateLoadGeneration++;
                              });
                              if (manageAccess && !_hasLinkedAccess) {
                                await _loadAccessCandidates();
                              }
                            },
                      title: Text(
                        _hasLinkedAccess
                            ? 'Atualizar vínculo de acesso'
                            : 'Selecionar vínculo manualmente',
                      ),
                      subtitle: const Text(
                        'O acesso só fica ativo quando o email corresponde a uma conta verificada.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  if (_manageAccess) ...[
                    const SizedBox(height: UnifiedSpace.x2),
                    DropdownButtonFormField<AccessRole>(
                      key: const ValueKey('team-access-role'),
                      initialValue: _accessRole,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Perfil de acesso',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: widget.scope == ContactScope.congregation
                              ? AccessRole.direction
                              : AccessRole.supervision,
                          child: Text(
                            widget.scope == ContactScope.congregation
                                ? 'Direção da congregação'
                                : 'Supervisão geral',
                          ),
                        ),
                      ],
                      onChanged: !_canEditFields
                          ? null
                          : (role) async {
                              if (role != null && role != _accessRole) {
                                setState(() {
                                  _accessRole = role;
                                  _selectedAccessId = null;
                                  _createNewAccess = false;
                                  _accessCandidatePage = null;
                                });
                                if (!_hasLinkedAccess) {
                                  await _loadAccessCandidates();
                                }
                              }
                            },
                    ),
                    if (_hasLinkedAccess) ...[
                      const SizedBox(height: UnifiedSpace.x2),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('team-access-assignment'),
                        initialValue: _selectedAccessId,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          labelText:
                              'Vínculo existente (selecione explicitamente)',
                        ),
                        items: [
                          if (linkedAccess != null)
                            DropdownMenuItem(
                              value: linkedAccess.id,
                              child: Text('ID ${linkedAccess.id}'),
                            ),
                        ],
                        onChanged: !_canEditFields
                            ? null
                            : (id) => setState(() {
                                _selectedAccessId = id;
                                _createNewAccess = false;
                              }),
                        validator: (value) => value == null
                            ? 'Selecione o vínculo existente.'
                            : null,
                      ),
                    ],
                    if (!_hasLinkedAccess) ...[
                      const SizedBox(height: UnifiedSpace.x2),
                      if (_loadingAccessCandidates)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Carregando vínculos de acesso',
                        )
                      else if (_accessCandidateError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_accessCandidateError!),
                            TextButton.icon(
                              onPressed: _canEditFields
                                  ? _loadAccessCandidates
                                  : null,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar carregar novamente'),
                            ),
                          ],
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          key: const ValueKey('team-access-candidate'),
                          initialValue: _selectedAccessId,
                          isExpanded: true,
                          itemHeight: null,
                          decoration: const InputDecoration(
                            labelText: 'Vínculo existente (escolha pelo ID)',
                          ),
                          items: [
                            for (final candidate
                                in _accessCandidatePage?.items ??
                                    const <TeamAccessCandidate>[])
                              DropdownMenuItem(
                                value: candidate.id,
                                child: Text(
                                  'ID ${candidate.id} · ${candidate.email} · ${teamAccessRoleLabel(candidate.role)} · ${candidate.scope.wire}',
                                  softWrap: true,
                                ),
                              ),
                          ],
                          onChanged:
                              !_canEditFields || _accessCandidatePage == null
                              ? null
                              : (id) => setState(() {
                                  _selectedAccessId = id;
                                  _createNewAccess = false;
                                }),
                          validator: (value) =>
                              value != null || _createNewAccess
                              ? null
                              : 'Escolha um vínculo ou crie um novo.',
                        ),
                        if (_accessCandidatePage?.items.isEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: UnifiedSpace.x1,
                            ),
                            child: Text(
                              'Nenhum vínculo existente neste perfil e escopo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (_accessCandidatePage?.nextCursor != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _canEditFields
                                  ? () => _loadAccessCandidates(
                                      cursor: _accessCandidatePage!.nextCursor,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Mais vínculos'),
                            ),
                          ),
                        CheckboxListTile(
                          key: const ValueKey('team-create-new-access'),
                          contentPadding: EdgeInsets.zero,
                          value: _createNewAccess,
                          onChanged: !_canEditFields
                              ? null
                              : (value) => setState(() {
                                  _createNewAccess = value ?? false;
                                  if (_createNewAccess) {
                                    _selectedAccessId = null;
                                  }
                                }),
                          title: const Text('Criar novo vínculo pendente'),
                          subtitle: const Text(
                            'Use quando nenhuma atribuição existente deve ser vinculada.',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ],
                  ],
                  if (_hasLinkedAccess && linkedAccess != null) ...[
                    const SizedBox(height: UnifiedSpace.x2),
                    Text(
                      linkedAccess.boundUserId == null
                          ? 'Aguardando email verificado'
                          : 'Acesso vinculado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!archived)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _canEditFields ? _revokeAccess : null,
                          icon: const Icon(Icons.person_remove_outlined),
                          label: const Text('Revogar acesso'),
                        ),
                      ),
                  ],
                ],
                TextFormField(
                  key: const ValueKey('team-contact-email'),
                  controller: _email,
                  enabled: _canEditEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _manageAccess
                        ? 'Email para acesso *'
                        : 'Email (opcional)',
                    helperText: _hasLinkedAccess
                        ? 'O email muda somente com o vínculo selecionado.'
                        : 'Email verificado concede acesso.',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (_manageAccess && email.isEmpty) {
                      return 'Informe um email para conceder acesso.';
                    }
                    if (email.isNotEmpty &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(email)) {
                      return 'Informe um email válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: UnifiedSpace.x2),
                if (current != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _canChangeArchiveState
                          ? _changeArchiveState
                          : null,
                      icon: Icon(
                        archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      label: Text(
                        archived ? 'Restaurar contato' : 'Arquivar contato',
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: UnifiedSpace.x2),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: UnifiedColors.error),
                    ),
                  ),
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
          key: const ValueKey('team-contact-save'),
          onPressed: _busy || archived ? null : _save,
          icon: Icon(_busy ? Icons.hourglass_top : Icons.save_outlined),
          label: Text(
            _busy
                ? 'Salvando…'
                : _mutationAttempted
                ? 'Tentar novamente'
                : 'Salvar contato',
          ),
        ),
      ],
    );
  }
}
