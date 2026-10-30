import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/br_input.dart';
import '../../../ui/form_fields.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import 'team_role_labels.dart';

/// Directory record for a team member. Team membership carries application
/// access: the e-mail is the only access input, and it is optional.
class TeamContactForm extends StatefulWidget {
  const TeamContactForm({
    super.key,
    required this.repository,
    required this.scope,
    required this.congregationId,
    this.congregationName,
    required this.current,
    required this.directory,
    required this.createId,
    required this.isScopeCurrent,
    required this.onScopeRefresh,
    required this.onSaved,
  });

  final MinistryRepository repository;
  final ContactScope scope;
  final String? congregationId;
  final String? congregationName;
  final MinistryContactDetail? current;
  final List<MinistryDirectoryEntry> directory;
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
  bool _replaceHolder = false;
  bool _loadingPrevious = false;
  bool _busy = false;
  bool _mutationAttempted = false;
  String? _previousContactId;
  MinistryContactDetail? _previousContact;
  String? _error;
  String? _saveSignature;
  String? _saveOperationId;
  String? _completedStageSignature;
  int? _completedStageRevision;
  String? _replaceSignature;
  String? _replaceOperationId;
  String? _lifecycleSignature;
  String? _lifecycleOperationId;

  MinistryContact? get _contact => widget.current?.contact;

  bool get _canEditFields =>
      !_busy && !_mutationAttempted && !(_contact?.archived ?? false);

  bool get _canChangeArchiveState => !_busy && !_mutationAttempted;

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
    }
    final token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _mutationAttempted = true;
      _error = null;
    });

    try {
      var targetRevision = _completedStageRevision;
      if (_completedStageSignature != signature) {
        targetRevision = current?.revision;
        {
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

      if (current?.email != email) {
        // Access follows the e-mail, so the session scope may have changed.
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
        title: Text(
          archived ? 'Marcar membro como inativo?' : 'Reativar membro?',
        ),
        content: Text(
          archived
              ? 'A pessoa sai da equipe ativa e perde o acesso ao aplicativo. O histórico é mantido e a reativação devolve o acesso.'
              : 'A pessoa volta a aparecer na equipe ativa e recupera o acesso ao aplicativo quando houver e-mail cadastrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(archived ? 'Marcar como inativo' : 'Reativar membro'),
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
      if (contact.email != null) {
        widget.repository.gateway.boundary.invalidate();
        await widget.onScopeRefresh?.call();
      }
      if (!mounted || !widget.isScopeCurrent()) return;
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível alterar o estado do membro. Tente novamente.',
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
    final theme = Theme.of(context);
    final dialogWidth = math.min(560.0, MediaQuery.sizeOf(context).width - 48);

    return Dialog(
      // The keyboard inset must apply before EditableText scrolls the focused
      // field into view. With the default 100 ms inset animation the caret is
      // revealed against the old, taller viewport and the field ends up under
      // the keyboard.
      insetAnimationDuration: Duration.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                current == null ? 'Novo membro da equipe' : 'Editar membro',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Base44SectionHeading(
                        title: 'Dados do membro',
                        subtitle: 'Adicionar à equipe concede acesso ao app quando houver e-mail.',
                      ),
                      if (widget.congregationName != null) ...[
                        const SizedBox(height: UnifiedSpace.x2),
                        Text('Congregação: ${widget.congregationName}'),
                      ],
                      if (archived) ...[
                        const SizedBox(height: UnifiedSpace.x2),
                        Text(
                          'Membro inativo · sem acesso ao aplicativo',
                          style: TextStyle(
                            color: UnifiedColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                          if (name.length > 200) {
                            return 'Use até 200 caracteres.';
                          }
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
                      if (_roleCode != null &&
                          _replacementCandidates.isNotEmpty) ...[
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
                              labelText:
                                  'Contato que ocupa a função atualmente',
                            ),
                            items: [
                              for (final entry in _replacementCandidates)
                                DropdownMenuItem(
                                  key: ValueKey(
                                    'team-replace-option-${entry.id}',
                                  ),
                                  value: entry.id,
                                  child: Text(entry.name, softWrap: true),
                                ),
                            ],
                            onChanged: _canEditFields
                                ? _loadPreviousContact
                                : null,
                            validator: (value) => value == null
                                ? 'Selecione o contato atual.'
                                : null,
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
                      const SizedBox(height: UnifiedSpace.x2),
                      TextFormField(
                        key: const ValueKey('team-contact-email'),
                        controller: _email,
                        enabled: _canEditFields,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail (opcional)',
                          helperText: 'Sem e-mail a pessoa fica na equipe, mas não entra no app.',
                          helperMaxLines: 2,
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isNotEmpty &&
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(email)) {
                            return 'Informe um e-mail válido.';
                          }
                          return null;
                        },
                      ),
                      if (current != null) ...[
                        const SizedBox(height: UnifiedSpace.x2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _canChangeArchiveState
                                ? _changeArchiveState
                                : null,
                            icon: Icon(
                              archived
                                  ? Icons.person_add_alt_1_outlined
                                  : Icons.person_off_outlined,
                            ),
                            label: Text(
                              archived
                                  ? 'Reativar membro'
                                  : 'Marcar como inativo',
                            ),
                          ),
                        ),
                      ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('team-contact-save'),
                    onPressed: _busy || archived ? null : _save,
                    icon: Icon(
                      _busy ? Icons.hourglass_top : Icons.save_outlined,
                    ),
                    label: Text(
                      _busy
                          ? 'Salvando…'
                          : _mutationAttempted
                          ? 'Tentar novamente'
                          : 'Salvar contato',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
