/// Contact editor for local and supervisor-authorized scopes (S05, S06).
///
/// On a stale-revision or unavailable failure the form keeps the operator's
/// inputs in memory and offers an explicit reload; success is only shown after
/// the backend acknowledges the mutation.
library;

import 'package:flutter/material.dart';

import '../../domain/contact.dart';
import '../../domain/ports.dart';
import '../../domain/validation.dart';
import '../../ui/app_theme.dart';
import '../../ui/form_fields.dart';
import 'role_replacement_dialog.dart';
import 'team_repository.dart';

class ContactFormConfig {
  const ContactFormConfig({
    required this.scope,
    this.congregationId,
    this.contactId,
    this.expectedRevision,
    this.initialName = '',
    this.initialRoleCode,
    this.initialPhone,
  });

  final ContactScope scope;
  final String? congregationId;
  final String? contactId;
  final int? expectedRevision;
  final String initialName;
  final RoleCode? initialRoleCode;
  final String? initialPhone;

  bool get isEditing => contactId != null;
}

class ContactForm extends StatefulWidget {
  const ContactForm({
    super.key,
    required this.repository,
    required this.config,
    this.onSaved,
    this.onCancel,
  });

  final TeamRepository repository;
  final ContactFormConfig config;
  final ValueChanged<TeamMutationResult>? onSaved;
  final VoidCallback? onCancel;

  static const Key nameFieldKey = Key('contact-form-name');
  static const Key roleFieldKey = Key('contact-form-role');
  static const Key phoneFieldKey = Key('contact-form-phone');
  static const Key saveKey = Key('contact-form-save');
  static const Key conflictKey = Key('contact-form-conflict');
  static const Key reloadKey = Key('contact-form-reload');

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final GlobalKey<AppFormState> _formKey = GlobalKey<AppFormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.config.initialName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.config.initialPhone ?? '',
  );
  late RoleCode? _role = widget.config.initialRoleCode;
  late int? _expectedRevision = widget.config.expectedRevision;
  RoleReplacementRequest? _nextRequest;
  String? _nextHolderName;
  bool _reloadRequested = false;
  AppFailure? _failure;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool valid =
        _formKey.currentState?.validateAndFocusFirstError() ?? false;
    if (!valid) {
      return;
    }
    String? phone;
    if (_phone.text.trim().isNotEmpty) {
      phone = normalizeBrazilianPhone(_phone.text);
    }
    final RoleCode? role = _role;
    // Teacher keeps multiple holders; every other role is a single-holder
    // administrative slot that must be explicitly replaced (S06).
    if (role != null && role != RoleCode.teacher) {
      setState(() {
        _submitting = true;
        _failure = null;
      });
      final DirectoryEntry? holder;
      try {
        holder = await widget.repository.findAdministrativeHolder(
          scope: widget.config.scope,
          congregationId: widget.config.congregationId,
          roleCode: role,
        );
      } on AppFailure catch (failure) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _failure = failure;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      if (holder != null && holder.id != widget.config.contactId) {
        if (!widget.config.isEditing) {
          setState(
            () => _failure = const AppFailure(
              code: AppFailureCode.validation,
              message:
                  'Este papel administrativo já possui responsável. Escolha '
                  'outro papel ou libere-o antes de cadastrar.',
            ),
          );
          return;
        }
        await _offerReplacement(holder, role);
        return;
      }
    }
    await _save(phone);
  }

  Future<void> _save(String? phone) async {
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final TeamMutationResult result = await widget.repository.saveContact(
        draft: ContactDraft(
          name: _name.text,
          scope: widget.config.scope,
          congregationId: widget.config.congregationId,
          roleCode: _role,
          phone: phone,
        ),
        id: widget.config.contactId,
        expectedRevision: _expectedRevision,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onSaved?.call(result);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      // Inputs keep their in-memory values; nothing is silently discarded.
      setState(() {
        _submitting = false;
        _failure = failure;
      });
    }
  }

  /// Shows the existing holder and requires explicit confirmation before the
  /// single holder swap. Cancelling sends no mutation. Reloading after a
  /// conflict re-reads both revisions and re-opens the confirmation with the
  /// refreshed identity so a resubmit can succeed.
  Future<void> _offerReplacement(DirectoryEntry holder, RoleCode role) async {
    final String? targetId = widget.config.contactId;
    if (targetId == null) {
      return;
    }
    final RoleReplacementRequest? initial = await _replacementRequest(
      holder,
      role,
      targetId,
    );
    if (!mounted) return;
    if (initial == null) {
      setState(
        () => _failure = const AppFailure(
          code: AppFailureCode.notFound,
          message: 'Não foi possível carregar o responsável atual.',
        ),
      );
      return;
    }
    RoleReplacementRequest current = initial;
    String holderName = holder.name;
    while (mounted) {
      _reloadRequested = false;
      _nextRequest = null;
      _nextHolderName = null;
      final bool replaced =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) => RoleReplacementDialog(
              repository: widget.repository,
              request: current,
              roleLabel: role.label,
              holderName: holderName,
              onReload: _reloadReplacement,
            ),
          ) ??
          false;
      if (!mounted) return;
      if (replaced) {
        widget.onSaved?.call(
          TeamMutationResult(
            id: targetId,
            revision: _expectedRevision ?? current.targetExpectedRevision,
          ),
        );
        return;
      }
      final RoleReplacementRequest? refreshed = _nextRequest;
      if (!_reloadRequested || refreshed == null) {
        return;
      }
      current = refreshed;
      holderName = _nextHolderName ?? holderName;
    }
  }

  Future<RoleReplacementRequest?> _replacementRequest(
    DirectoryEntry holder,
    RoleCode role,
    String targetId,
  ) async {
    final int? targetRevision = _expectedRevision;
    if (targetRevision == null) {
      return null;
    }
    final Contact? holderRecord = await widget.repository.getContact(
      id: holder.id,
      scope: widget.config.scope,
      congregationId: widget.config.congregationId,
    );
    if (holderRecord == null) {
      return null;
    }
    return RoleReplacementRequest(
      scope: widget.config.scope,
      congregationId: widget.config.congregationId,
      roleCode: role,
      previousContactId: holder.id,
      previousExpectedRevision: holderRecord.revision,
      targetContactId: targetId,
      targetExpectedRevision: targetRevision,
    );
  }

  /// Re-runs the holder lookup and re-reads both contact records, then closes
  /// the stale confirmation so it can be re-opened with authoritative
  /// revisions (S06, S11).
  Future<void> _reloadReplacement() async {
    _reloadRequested = false;
    _nextRequest = null;
    _nextHolderName = null;
    final RoleCode? role = _role;
    final String? targetId = widget.config.contactId;
    if (role != null && targetId != null) {
      try {
        final DirectoryEntry? holder = await widget.repository
            .findAdministrativeHolder(
              scope: widget.config.scope,
              congregationId: widget.config.congregationId,
              roleCode: role,
            );
        if (holder != null) {
          final Contact? holderRecord = await widget.repository.getContact(
            id: holder.id,
            scope: widget.config.scope,
            congregationId: widget.config.congregationId,
          );
          final Contact? targetRecord = await widget.repository.getContact(
            id: targetId,
            scope: widget.config.scope,
            congregationId: widget.config.congregationId,
          );
          if (holderRecord != null && targetRecord != null) {
            _expectedRevision = targetRecord.revision;
            _nextRequest = RoleReplacementRequest(
              scope: widget.config.scope,
              congregationId: widget.config.congregationId,
              roleCode: role,
              previousContactId: holder.id,
              previousExpectedRevision: holderRecord.revision,
              targetContactId: targetId,
              targetExpectedRevision: targetRecord.revision,
            );
            _nextHolderName = holder.name;
            _reloadRequested = true;
          }
        }
      } on AppFailure {
        _reloadRequested = false;
      }
    }
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  /// A save conflict re-fetches the contact record to refresh the revision
  /// instead of only clearing the message.
  Future<void> _reload() async {
    final String? id = widget.config.contactId;
    if (id == null) {
      setState(() => _failure = null);
      return;
    }
    try {
      final Contact? record = await widget.repository.getContact(
        id: id,
        scope: widget.config.scope,
        congregationId: widget.config.congregationId,
      );
      if (!mounted) return;
      setState(() {
        if (record != null) {
          _expectedRevision = record.revision;
        }
        _failure = null;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final List<RoleCode> roles = RoleCode.values
        .where((RoleCode role) => role.scope == widget.config.scope)
        .toList(growable: false);
    return AppForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            key: ContactForm.nameFieldKey,
            label: 'Nome',
            controller: _name,
            required: true,
            validator: validateDisplayName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.x3),
          DropdownButtonFormField<RoleCode?>(
            key: ContactForm.roleFieldKey,
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Papel'),
            items: <DropdownMenuItem<RoleCode?>>[
              const DropdownMenuItem<RoleCode?>(child: Text('Sem papel')),
              for (final RoleCode role in roles)
                DropdownMenuItem<RoleCode?>(
                  value: role,
                  child: Text(role.label),
                ),
            ],
            onChanged: _submitting
                ? null
                : (RoleCode? role) => setState(() => _role = role),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: ContactForm.phoneFieldKey,
            label: 'Telefone',
            controller: _phone,
            keyboardType: TextInputType.phone,
            helperText:
                'Compartilhado com a equipe autenticada quando informado.',
            validator: validatePhone,
          ),
          if (_failure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            Text(
              _failure!.message,
              key: ContactForm.conflictKey,
              style: TextStyle(color: tokens.error),
            ),
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                key: ContactForm.reloadKey,
                label: 'Recarregar',
                variant: AppButtonVariant.secondary,
                onPressed: _reload,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (widget.onCancel != null)
                AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.text,
                  onPressed: widget.onCancel,
                ),
              const SizedBox(width: AppSpacing.x2),
              AppButton(
                key: ContactForm.saveKey,
                label: 'Salvar',
                isSubmitting: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
