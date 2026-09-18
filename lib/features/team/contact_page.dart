/// Contact detail route (S06, S10).
///
/// Outside the caller's manageable scope the page resolves only the directory
/// projection and never fetches private fields; authorized local/supervisor
/// editors additionally load the full scoped record and expose the write
/// controls. Birth dates are never rendered here.
library;

import 'package:flutter/material.dart';

import '../../domain/access.dart';
import '../../domain/contact.dart';
import '../../domain/ports.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/confirmation_dialog.dart';
import '../../ui/feedback.dart';
import '../../ui/form_fields.dart';
import '../congregations/congregation_repository.dart';
import 'contact_form.dart';
import 'phone_actions.dart';
import 'team_repository.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({
    super.key,
    required this.repository,
    required this.profile,
    required this.contactId,
    this.catalog,
    this.scope,
    this.congregationId,
    this.onDone,
  });

  final TeamRepository repository;
  final AccessProfile profile;
  final String contactId;
  final CongregationRepository? catalog;

  /// Validated scope/congregation for a direct (archived) lookup, used instead
  /// of relying only on [profile] (S06, S10).
  final ContactScope? scope;
  final String? congregationId;
  final VoidCallback? onDone;

  static const Key directoryOnlyKey = Key('contact-directory-only');
  static const Key editKey = Key('contact-edit');
  static const Key archiveKey = Key('contact-archive');
  static const Key restoreKey = Key('contact-restore');
  static const Key roleLabelKey = Key('contact-role-label');
  static const Key errorKey = Key('contact-error');

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  DirectoryEntry? _entry;
  Contact? _contact;
  String? _congregationName;
  bool _loading = true;
  AppFailure? _failure;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _canManage(DirectoryEntry entry) {
    if (widget.profile.accessRole == AccessRole.supervisor) {
      return true;
    }
    return entry.scope == ContactScope.congregation &&
        entry.congregationId != null &&
        entry.congregationId == widget.profile.congregationId;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
      _congregationName = null;
    });
    try {
      DirectoryEntry? entry = await widget.repository.getDirectoryEntry(
        widget.contactId,
      );
      Contact? contact;
      if (entry == null) {
        // An archived contact has no directory projection; a validated
        // scope/congregation supplied by the route (or the caller's own scope)
        // resolves the private record for authorized direct lookup.
        final ContactScope? requestedScope = widget.scope;
        final String? requestedCongregation =
            widget.congregationId ?? widget.profile.congregationId;
        if (requestedScope != null) {
          contact = await widget.repository.getContact(
            id: widget.contactId,
            scope: requestedScope,
            congregationId: requestedCongregation,
          );
          if (contact != null) {
            entry = _entryFromContact(contact);
          }
        }
      } else if (_canManage(entry)) {
        contact = await widget.repository.getContact(
          id: entry.id,
          scope: entry.scope,
          congregationId: entry.congregationId,
        );
      }
      String? congregationName;
      final CongregationRepository? catalog = widget.catalog;
      if (entry != null &&
          entry.scope == ContactScope.congregation &&
          entry.congregationId != null &&
          catalog != null) {
        try {
          congregationName = (await catalog.getCongregation(
            entry.congregationId!,
          ))?.name;
        } catch (_) {
          congregationName = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _entry = entry;
        _contact = contact;
        _congregationName = congregationName;
        _loading = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = failure;
      });
    }
  }

  DirectoryEntry _entryFromContact(Contact contact) => DirectoryEntry(
    id: contact.id,
    name: contact.name,
    normalizedName: contact.normalizedName,
    scope: contact.scope,
    roleCode: contact.roleCode,
    congregationId: contact.congregationId,
    phoneE164: contact.phoneE164,
  );

  Future<void> _archive() async {
    final Contact? contact = _contact;
    if (contact == null) return;
    final bool confirmed = await showConfirmationDialog(
      context,
      title: 'Arquivar contato',
      message: 'Arquivar ${contact.name}?',
      confirmLabel: 'Arquivar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _setArchived(contact, true);
  }

  Future<void> _restore() async {
    final Contact? contact = _contact;
    if (contact == null) return;
    await _setArchived(contact, false);
  }

  Future<void> _setArchived(Contact contact, bool archived) async {
    try {
      await widget.repository.setContactArchived(
        id: contact.id,
        scope: contact.scope,
        congregationId: contact.congregationId,
        archived: archived,
        expectedRevision: contact.revision,
      );
      if (!mounted) return;
      widget.onDone?.call();
      await _load();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: failure.message,
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      backgroundColor: tokens.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (_editing && _entry != null) {
      return ContactForm(
        repository: widget.repository,
        config: ContactFormConfig(
          scope: _entry!.scope,
          congregationId: _entry!.congregationId,
          contactId: _contact?.id ?? _entry!.id,
          expectedRevision: _contact?.revision,
          initialName: _entry!.name,
          initialRoleCode: _entry!.roleCode,
          initialPhone: _entry!.phoneE164,
        ),
        onSaved: (_) {
          setState(() => _editing = false);
          _load();
        },
        onCancel: () => setState(() => _editing = false),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failure != null) {
      return AsyncContent<void>(
        state: AsyncViewState<void>.fromFailure(_failure!),
        onRetry: _load,
      );
    }
    final DirectoryEntry? entry = _entry;
    if (entry == null) {
      return const AsyncContent<void>(state: AsyncViewState<void>.notFound());
    }
    return _detail(context, entry);
  }

  Widget _detail(BuildContext context, DirectoryEntry entry) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final bool canManage = _canManage(entry);
    final bool archived = _contact?.archived ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                entry.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (!canManage)
              Chip(
                key: ContactPage.directoryOnlyKey,
                label: const Text('Somente dados do diretório'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          entry.roleLabel ?? 'Sem papel',
          key: ContactPage.roleLabelKey,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          entry.scope == ContactScope.supervision
              ? 'Supervisão'
              : (_congregationName ?? '—'),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: tokens.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.x4),
        PhoneActions(phoneE164: entry.phoneE164),
        if (canManage) ...<Widget>[
          const SizedBox(height: AppSpacing.x6),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: <Widget>[
              AppButton(
                key: ContactPage.editKey,
                label: 'Editar',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _editing = true),
              ),
              if (!archived)
                AppButton(
                  key: ContactPage.archiveKey,
                  label: 'Arquivar',
                  variant: AppButtonVariant.danger,
                  onPressed: _archive,
                ),
              if (archived)
                AppButton(
                  key: ContactPage.restoreKey,
                  label: 'Restaurar',
                  variant: AppButtonVariant.secondary,
                  onPressed: _restore,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
