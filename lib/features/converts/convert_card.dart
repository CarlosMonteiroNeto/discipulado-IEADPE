import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/convert_policy.dart';
import '../../ui/unified_theme.dart';
import '../photos/photo_repository.dart';
import 'convert_actions.dart';

class ConvertCard extends StatefulWidget {
  const ConvertCard({
    super.key,
    required this.record,
    required this.today,
    this.congregation,
    this.gateway,
    this.photos,
    this.onEdit,
    this.onAction,
    this.busy = false,
    this.error,
  });
  final ConvertRecord record;
  final DateOnly today;
  final Congregation? congregation;
  final Gateway? gateway;
  final PhotoRepository? photos;
  final VoidCallback? onEdit;
  final Future<void> Function(ConvertAction)? onAction;
  final bool busy;
  final String? error;
  @override
  State<ConvertCard> createState() => _ConvertCardState();
}

class _ConvertCardState extends State<ConvertCard> {
  Uint8List? _photo;
  String? _photoError, _linkError;
  bool _loading = false, _zoom = false;
  ConvertAction? _confirmation;
  int _photoRequest = 0;
  final _confirmationButton = GlobalKey();
  final _confirmationFocus = FocusNode();
  void _showConfirmation(ConvertAction action) {
    final token = widget.gateway?.context;
    if (!_current(token)) return;
    setState(() => _confirmation = action);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _confirmationButton.currentContext;
      if (_current(token) && target != null) {
        Scrollable.ensureVisible(target, duration: Duration.zero);
        _confirmationFocus.requestFocus();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(ConvertCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.photoAssetId != widget.record.photoAssetId) {
      _photo = null;
      _zoom = false;
      _loadPhoto();
    }
  }

  bool _current(String? token) {
    if (!mounted) return false;
    try {
      if (token != null) widget.gateway!.ensureCurrent(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadPhoto() async {
    final request = ++_photoRequest;
    _loading = false;
    _photoError = null;
    final id = widget.record.photoAssetId;
    if (id == null || widget.photos == null || widget.gateway == null) return;
    final token = widget.gateway!.context;
    _loading = true;
    _photoError = null;
    try {
      final asset = await widget.photos!.get(id);
      if (!_current(token) || request != _photoRequest) return;
      final bytes = await widget.photos!.download(asset);
      if (_current(token) && request == _photoRequest) {
        setState(() => _photo = bytes);
      }
    } catch (_) {
      if (_current(token) && request == _photoRequest) {
        setState(() => _photoError = 'Não foi possível carregar a foto.');
      }
    } finally {
      if (_current(token) && request == _photoRequest) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _photoRequest++;
    _photo = null;
    _confirmation = null;
    _confirmationFocus.dispose();
    super.dispose();
  }

  String _date(DateOnly value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  Future<void> _openWhatsApp(Uri uri) async {
    final token = widget.gateway?.context;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (_current(token)) {
        setState(
          () => _linkError =
              'Não foi possível abrir o WhatsApp. Tente novamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final status = visitState(record, widget.today);
    final (
      color,
      stripColor,
      stripTextColor,
      borderColor,
      tint,
    ) = switch (status) {
      VisitState.urgent => (
        const Color(0xffb91c1c),
        const Color(0xffb91c1c),
        Colors.white,
        const Color(0xfff87171),
        const Color(0xfffef2f2),
      ),
      VisitState.current => (
        const Color(0xff166534),
        const Color(0xff166534),
        Colors.white,
        const Color(0xff4ade80),
        const Color(0xfff0fdf4),
      ),
      VisitState.attention => (
        const Color(0xffa16207),
        const Color(0xffa16207),
        Colors.white,
        const Color(0xfffacc15),
        const Color(0xfffefce8),
      ),
    };
    final label = switch (status) {
      VisitState.urgent => 'Visita Urgente',
      VisitState.current => 'Em dia',
      VisitState.attention => 'Atenção',
    };
    final uri = brazilWhatsApp(record.phone);
    final actions = ConvertAction.values.where(
      (action) =>
          action != ConvertAction.delete &&
          actionAllowed(action, record, widget.today),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      color: tint,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: stripColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Semantics(
                  label: 'Situação: $label',
                  child: Text(
                    label,
                    style: TextStyle(
                      color: stripTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${widget.today.differenceInDays(record.followUpDate ?? record.conversionDate)} dias desde último contato',
                  style: TextStyle(color: stripTextColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final avatar = Semantics(
                      label: _photo == null
                          ? 'Sem foto de ${record.name}'
                          : 'Foto de ${record.name}',
                      child: ClipOval(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: _photo == null
                              ? const ColoredBox(
                                  color: Color(0xffe2e8f0),
                                  child: Icon(
                                    Icons.person,
                                    size: 42,
                                    color: UnifiedColors.muted,
                                  ),
                                )
                              : Image.memory(
                                  _photo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const ColoredBox(
                                        color: Color(0xffe2e8f0),
                                        child: Icon(
                                          Icons.person,
                                          size: 42,
                                          color: UnifiedColors.muted,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                    );
                    final title = Text(
                      record.name,
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xff1e293b),
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    if (constraints.maxWidth < 440) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(alignment: Alignment.center, child: avatar),
                          if (_photo != null)
                            Align(
                              alignment: Alignment.center,
                              child: TextButton.icon(
                                onPressed: () => setState(() => _zoom = !_zoom),
                                icon: Icon(_zoom ? Icons.close : Icons.zoom_in),
                                label: Text(
                                  _zoom ? 'Fechar foto' : 'Ampliar foto',
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          title,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            avatar,
                            if (_photo != null)
                              TextButton(
                                onPressed: () => setState(() => _zoom = !_zoom),
                                child: Text(
                                  _zoom ? 'Fechar foto' : 'Ampliar foto',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: title),
                      ],
                    );
                  },
                ),
                if (_photo != null && _zoom) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photo!,
                      height: 280,
                      fit: BoxFit.contain,
                      semanticLabel: 'Foto de ${record.name}',
                      errorBuilder: (_, error, stack) => const Text(
                        'Não foi possível exibir a foto.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Carregando foto…'),
                  ),
                if (_photoError != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _photoError!,
                      style: const TextStyle(color: UnifiedColors.red),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _loading = true);
                        _loadPhoto();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar carregar foto novamente'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _detail(
                  Icons.church_outlined,
                  widget.congregation?.name ?? 'Congregação não informada',
                ),
                if (record.address?.isNotEmpty ?? false)
                  _detail(Icons.location_on_outlined, record.address!),
                _detail(Icons.place_outlined, record.landmark),
                if (record.phone?.isNotEmpty ?? false)
                  _detail(Icons.phone_outlined, record.phone!),
                if (record.congregationId == null ||
                    (record.phone?.trim().isEmpty ?? true))
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff7ed),
                      border: Border.all(color: const Color(0xfffdba74)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xffc2410c),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${record.congregationId == null ? 'Congregação não informada. ' : ''}${record.phone?.trim().isEmpty ?? true ? 'Telefone não informado.' : ''}',
                            style: const TextStyle(color: Color(0xff9a3412)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scaledText = MediaQuery.textScalerOf(context)
                        .scale(14);
                    final narrow =
                        constraints.maxWidth < 480 || scaledText > 20;
                    final conversion = _dateDetail(
                      'Conversão',
                      record.conversionDate,
                    );
                    final lastVisit = _dateDetail(
                      'Última visita',
                      record.lastVisitDate ?? record.conversionDate,
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          conversion,
                          const SizedBox(height: 6),
                          lastVisit,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: conversion),
                        const SizedBox(width: 16),
                        Expanded(child: lastVisit),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                _detail(Icons.menu_book_outlined, record.worshipType),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (record.isEffectivelyInDiscipleship)
                      const Chip(label: Text('Em Discipulado')),
                    if (record.wasVisitedOnce)
                      const Chip(label: Text('Já visitado')),
                    Chip(label: Text('${record.visitCount} visitas')),
                    Chip(
                      label: Text(
                        record.gender == Gender.male ? 'Masculino' : 'Feminino',
                      ),
                    ),
                    if (record.age != null)
                      Chip(label: Text('${record.age} anos')),
                  ],
                ),
                if (!isTerminal(record) && actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final action in actions)
                          TextButton.icon(
                            onPressed: widget.busy || widget.onAction == null
                                ? null
                                : () => _showConfirmation(action),
                            icon: Icon(_actionIcon(action)),
                            label: Text(actionLabel(action)),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: UnifiedColors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: uri == null ? null : () => _openWhatsApp(uri),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('WhatsApp'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.busy ? null : widget.onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          widget.busy ||
                              widget.onAction == null ||
                              record.deletedAt != null
                          ? null
                          : () => _showConfirmation(ConvertAction.delete),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UnifiedColors.red,
                        side: const BorderSide(color: UnifiedColors.red),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Excluir'),
                    ),
                  ],
                ),
                if (widget.busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text('Salvando…'),
                    ),
                  ),
                if (widget.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.error!,
                        style: const TextStyle(color: UnifiedColors.red),
                      ),
                    ),
                  ),
                if (_linkError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _linkError!,
                      style: const TextStyle(color: UnifiedColors.red),
                    ),
                  ),
                if (_confirmation != null)
                  AlertDialog(
                    title: Text(actionLabel(_confirmation!)),
                    content: Text(
                      _confirmation == ConvertAction.delete
                          ? 'Excluir o cadastro de ${record.name}? Esta ação não pode ser desfeita.'
                          : 'Confirma esta alteração para ${record.name}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: widget.busy
                            ? null
                            : () => setState(() => _confirmation = null),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        key: _confirmationButton,
                        focusNode: _confirmationFocus,
                        onPressed: widget.busy
                            ? null
                            : () async {
                                final action = _confirmation!;
                                setState(() => _confirmation = null);
                                await widget.onAction!(action);
                              },
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: Icon(icon, size: 18, color: UnifiedColors.muted),
        ),
        Expanded(child: Text(text, softWrap: true)),
      ],
    ),
  );

  Widget _dateDetail(String label, DateOnly value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(
        Icons.calendar_today_outlined,
        size: 14,
        color: UnifiedColors.muted,
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          '$label: ${_date(value)}',
          softWrap: true,
          style: const TextStyle(color: UnifiedColors.muted),
        ),
      ),
    ],
  );

  IconData _actionIcon(ConvertAction action) => switch (action) {
    ConvertAction.visit => Icons.check_circle_outline,
    ConvertAction.start => Icons.menu_book_outlined,
    ConvertAction.stop => Icons.pause_circle_outline,
    ConvertAction.complete => Icons.task_alt,
    ConvertAction.deviate => Icons.warning_amber_outlined,
    ConvertAction.delete => Icons.delete_outline,
  };
}
