import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/convert_policy.dart';
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
    final color = switch (status) {
      VisitState.urgent => Colors.red.shade800,
      VisitState.current => Colors.green.shade800,
      VisitState.attention => Colors.amber.shade900,
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
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Situação: $label',
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${widget.today.differenceInDays(record.lastVisitDate ?? record.conversionDate)} dias desde última visita',
            ),
            const SizedBox(height: 12),
            Text(record.name, style: Theme.of(context).textTheme.titleLarge),
            if (_photo != null) ...[
              TextButton(
                onPressed: () => setState(() => _zoom = !_zoom),
                child: Text(_zoom ? 'Fechar foto' : 'Ampliar foto'),
              ),
              Image.memory(
                _photo!,
                height: _zoom ? 280 : 96,
                fit: BoxFit.contain,
                semanticLabel: 'Foto de ${record.name}',
                errorBuilder: (_, error, stack) =>
                    const Text('Não foi possível exibir a foto.'),
              ),
            ],
            if (_loading) const Text('Carregando foto…'),
            if (_photoError != null) ...[
              Text(_photoError!),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _loadPhoto();
                },
                child: const Text('Tentar carregar foto novamente'),
              ),
            ],
            Text(widget.congregation?.name ?? 'Congregação não informada'),
            if (record.address?.isNotEmpty ?? false) Text(record.address!),
            Text(record.landmark),
            if (record.phone?.isNotEmpty ?? false) Text(record.phone!),
            if (record.congregationId == null ||
                (record.phone?.trim().isEmpty ?? true))
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade100,
                child: Text(
                  '${record.congregationId == null ? 'Congregação não informada. ' : ''}${record.phone?.trim().isEmpty ?? true ? 'Telefone não informado.' : ''}',
                  style: TextStyle(color: Colors.brown.shade900),
                ),
              ),
            Text('Conversão: ${_date(record.conversionDate)}'),
            Text(
              'Última visita: ${_date(record.lastVisitDate ?? record.conversionDate)}',
            ),
            Text(record.worshipType),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (record.isInDiscipleship)
                  const Chip(label: Text('Em Discipulado')),
                if (record.wasVisitedOnce)
                  const Chip(label: Text('Já visitado')),
                Chip(label: Text('${record.visitCount} visitas')),
                Chip(
                  label: Text(
                    record.gender == Gender.male ? 'Masculino' : 'Feminino',
                  ),
                ),
                if (record.age != null) Chip(label: Text('${record.age} anos')),
              ],
            ),
            if (!isTerminal(record))
              for (final action in actions)
                TextButton(
                  onPressed: widget.busy || widget.onAction == null
                      ? null
                      : () => _showConfirmation(action),
                  child: Text(actionLabel(action)),
                ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: uri == null ? null : () => _openWhatsApp(uri),
                  child: const Text('WhatsApp'),
                ),
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onEdit,
                  child: const Text('Editar'),
                ),
                OutlinedButton(
                  onPressed:
                      widget.busy ||
                          widget.onAction == null ||
                          record.deletedAt != null
                      ? null
                      : () => _showConfirmation(ConvertAction.delete),
                  child: const Text('Excluir'),
                ),
              ],
            ),
            if (widget.busy)
              Semantics(liveRegion: true, child: const Text('Salvando…')),
            if (widget.error != null)
              Semantics(liveRegion: true, child: Text(widget.error!)),
            if (_linkError != null) Text(_linkError!),
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
    );
  }
}
