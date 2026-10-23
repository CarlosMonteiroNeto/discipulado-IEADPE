import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/business_calendar.dart';
import '../../domain/models.dart';
import '../../platform/file_exporter.dart';
import '../../platform/portuguese_sort.dart';
import '../../platform/table_workbook.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/br_input.dart';
import '../../ui/form_fields.dart';
import '../../ui/unified_theme.dart';
import '../admin/congregation_repository.dart';
import 'reports_repository.dart';

/// The root must synchronously unmount this owner on protected invalidation.
class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    required this.repository,
    required this.exporter,
    required this.onScopeRefresh,
    required this.events,
  });
  final ReportsRepository repository;
  final FileExporter exporter;
  final Future<void> Function() onScopeRefresh;
  final bool events;
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final _filterForm = GlobalKey<FormState>();
  final _start = TextEditingController(), _end = TextEditingController();
  late String _token;
  int _request = 0, _catalogRequest = 0, _sortColumn = 3;
  bool _ascending = false, _busy = false, _saving = false, _applied = false;
  String? _congregation, _message;
  List<Congregation> _catalog = [];
  List<List<String>> _rows = [];
  List<WorshipCount> _counts = [];
  Uint8List? _bytes;
  DateRange _range = const DateRange();
  Gateway get _gateway => widget.repository.gateway;
  bool get _current {
    if (!mounted) return false;
    try {
      _gateway.ensureCurrent(_token);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<String> get _headers => widget.events
      ? [
          'Convertido',
          'Congregação',
          'Evento',
          'Data do Evento',
          'Registrado por',
        ]
      : ['Tipo de Culto', 'Conversões'];
  @override
  void initState() {
    super.initState();
    _token = _gateway.context;
    if (widget.events) {
      _loadCatalog();
    } else {
      _apply();
    }
  }

  @override
  void didUpdateWidget(covariant ReportView old) {
    super.didUpdateWidget(old);
    if (old.repository.gateway != _gateway ||
        _token != _gateway.context ||
        old.events != widget.events) {
      _request++;
      _catalogRequest++;
      _token = _gateway.context;
      _clear();
      _catalog = [];
      _congregation = null;
      _busy = false;
      _saving = false;
      if (widget.events) {
        _loadCatalog();
      } else {
        _apply();
      }
    }
  }

  void _clear() {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _rows = [];
    _counts = [];
    _bytes = null;
    _applied = false;
    _message = null;
  }

  @override
  void dispose() {
    _request++;
    _catalogRequest++;
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
    _rows = [];
    _counts = [];
    _catalog = [];
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final token = _token, request = ++_catalogRequest, gateway = _gateway;
    try {
      final catalog = await CongregationRepository(gateway).list();
      gateway.ensureCurrent(token);
      if (_current && request == _catalogRequest) {
        setState(() => _catalog = catalog);
      }
    } catch (error) {
      if (!_current || request != _catalogRequest) return;
      setState(
        () => _message = 'Não foi possível carregar as congregações. Tente aplicar novamente.',
      );
      if (error is DataFailure && error.code == 'permission') {
        setState(() {
          _clear();
          _catalog = [];
        });
        gateway.boundary.invalidate();
        try {
          await widget.onScopeRefresh();
        } catch (_) {}
      }
    }
  }

  void _edited() {
    setState(() {
      _request++;
      _busy = false;
      _clear();
    });
  }

  String _name(String? id) => id == null
      ? '-'
      : _catalog.where((c) => c.id == id).firstOrNull?.name ?? 'Desconhecida';
  String _date(DateOnly date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().padLeft(4, '0')}';
  String _label(ConvertEventType type) => switch (type) {
    ConvertEventType.visit => 'Visita realizada',
    ConvertEventType.discipleshipStarted => 'Iniciou discipulado',
    ConvertEventType.discipleshipCompleted => 'Concluiu discipulado',
    ConvertEventType.deviated => 'Desviou-se',
  };
  void _encode() {
    _bytes = _rows.isEmpty
        ? null
        : tableWorkbook(widget.events ? 'Eventos' : 'Conversões por Culto', [
            _headers,
            ..._rows,
          ]);
  }

  Future<void> _apply() async {
    if (!_current || _saving) return;
    if (!(_filterForm.currentState?.validate() ?? true)) return;
    DateRange range;
    try {
      final start = parseDateInput(_start.text);
      final end = parseDateInput(_end.text);
      if ((_start.text.trim().isNotEmpty && start == null) ||
          (_end.text.trim().isNotEmpty && end == null)) {
        throw const FormatException();
      }
      range = DateRange(
        start: start == null
            ? null
            : DateOnly(start.year, start.month, start.day),
        end: end == null ? null : DateOnly(end.year, end.month, end.day),
      );
      if (!range.valid) throw const FormatException();
    } catch (_) {
      setState(
        () => _message =
            'Confira as datas no formato DD/MM/AAAA e a ordem do período.',
      );
      return;
    }
    final request = ++_request, token = _token;
    // Applying owns a newer catalog snapshot than the initial background read.
    _catalogRequest++;
    final repository = widget.repository;
    setState(() {
      _clear();
      _busy = true;
    });
    try {
      List<List<String>> rows;
      if (widget.events) {
        final catalog = await CongregationRepository(repository.gateway).list();
        repository.gateway.ensureCurrent(token);
        if (!_current || request != _request) return;
        _catalog = catalog;
        final data = await repository.events(
          EventQuery(range: range, congregationId: _congregation),
        );
        repository.gateway.ensureCurrent(token);
        if (!_current || request != _request) return;
        rows = data
            .map(
              (e) => [
                e.convertName ?? '-',
                _name(e.congregationId),
                _label(e.eventType),
                _date(e.eventDate),
                e.doneByEmail ?? '-',
              ],
            )
            .toList();
        // Initial source order is descending business date, not formatted text.
        final indices = List.generate(data.length, (i) => i)
          ..sort((a, b) => data[b].eventDate.compareTo(data[a].eventDate));
        rows = indices.map((i) => rows[i]).toList();
        _sortColumn = 3;
        _ascending = false;
      } else {
        final counts = await repository.conversions(range);
        repository.gateway.ensureCurrent(token);
        if (!_current || request != _request) return;
        _counts = counts;
        rows = counts.map((e) => [e.name, e.count.toString()]).toList();
        _sortColumn = 1;
        _ascending = false;
      }
      if (!_current || request != _request) return;
      setState(() {
        _range = range;
        _rows = rows;
        _applied = true;
        _encode();
        _busy = false;
      });
    } catch (error) {
      if (!_current || request != _request) return;
      setState(() {
        _clear();
        _busy = false;
        _message = error is DataFailure && error.code == 'permission'
            ? 'Seu acesso mudou. Atualize seu acesso para continuar.'
            : 'Não foi possível carregar o relatório. Tente aplicar novamente.';
      });
      if (error is DataFailure && error.code == 'permission') {
        _gateway.boundary.invalidate();
        try {
          await widget.onScopeRefresh();
        } catch (_) {}
      }
    }
  }

  Future<void> _sort(int column, bool ascending) async {
    if (!_current || _busy || _saving || !_applied) return;
    final request = ++_request, token = _token;
    final rows = _rows.map((r) => List<String>.of(r)).toList();
    setState(() => _busy = true);
    try {
      if ((widget.events && column == 3) || (!widget.events && column == 1)) {
        String key(String v) => widget.events
            ? '${v.substring(6)}-${v.substring(3, 5)}-${v.substring(0, 2)}'
            : v;
        rows.sort((a, b) {
          final cmp = widget.events
              ? key(a[column]).compareTo(key(b[column]))
              : int.parse(a[column]).compareTo(int.parse(b[column]));
          return ascending ? cmp : -cmp;
        });
      } else {
        final values = rows.map((r) => r[column]).toSet().toList();
        final sorted = values.length < 2
            ? values
            : await sortPortugueseNames(values);
        _gateway.ensureCurrent(token);
        if (sorted.length != values.length ||
            sorted.toSet().length != values.length ||
            !sorted.toSet().containsAll(values)) {
          throw StateError('Invalid locale response');
        }
        final rank = {for (final e in sorted.indexed) e.$2: e.$1};
        rows.sort((a, b) {
          final cmp = rank[a[column]]!.compareTo(rank[b[column]]!);
          return ascending ? cmp : -cmp;
        });
      }
      if (!_current || request != _request) return;
      setState(() {
        _rows = rows;
        _sortColumn = column;
        _ascending = ascending;
        _encode();
        _busy = false;
      });
    } catch (_) {
      if (_current && request == _request) {
        setState(() {
          _busy = false;
          _message = 'Não foi possível ordenar. Tente novamente.';
        });
      }
    }
  }

  Future<void> _export() async {
    if (!_current || _busy || _saving || _bytes == null) return;
    // Bytes are prepared with the displayed rows before the click, preserving web activation.
    final token = _token, request = _request;
    final gateway = _gateway;
    final exporter = widget.exporter;
    final filename =
        '${widget.events ? 'eventos' : 'relatorio_conversoes'}_${_range.start ?? 'inicio'}_${_range.end ?? 'fim'}.xlsx';
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await exporter.save(
        filename,
        _bytes!,
        ensureCurrent: () {
          if (!mounted ||
              request != _request ||
              token != _token ||
              gateway != _gateway) {
            throw const DataFailure('stale');
          }
          gateway.ensureCurrent(token);
        },
      );
      _gateway.ensureCurrent(token);
      if (!_current || request != _request) return;
      setState(
        () => _message = switch (result) {
          SaveOutcome.saved => 'Arquivo salvo no local escolhido.',
          SaveOutcome.cancelled => 'Salvamento cancelado.',
          SaveOutcome.failed => 'Não foi possível salvar. Tente novamente em um navegador compatível ou no aplicativo Android.',
        },
      );
    } catch (_) {
      if (_current && request == _request) {
        setState(() => _message = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (_current && request == _request) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return Base44Panel(
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onScopeRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar acesso'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Base44PageHeading(
          title: widget.events
              ? 'Registro de Eventos'
              : 'Relatório por Tipo de Culto',
          icon: widget.events ? Icons.event_note_outlined : Icons.bar_chart,
        ),
        const SizedBox(height: 12),
        Base44Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _filterForm,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 210,
                      child: BrDateField(
                        fieldKey: const Key('report-start-date'),
                        controller: _start,
                        label: 'Data inicial',
                        helperText: 'Opcional',
                        enabled: !_saving,
                        allowClear: true,
                        onChanged: (_) => _edited(),
                        validator: brDateValidationError,
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: BrDateField(
                        fieldKey: const Key('report-end-date'),
                        controller: _end,
                        label: 'Data final',
                        helperText: 'Opcional',
                        enabled: !_saving,
                        allowClear: true,
                        onChanged: (_) => _edited(),
                        validator: brDateValidationError,
                      ),
                    ),
                    if (widget.events)
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            '$_token-$_congregation-${_catalog.length}',
                          ),
                          initialValue: _congregation,
                          decoration: const InputDecoration(
                            labelText: 'Congregação',
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todas'),
                            ),
                            for (final c in _catalog)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) {
                                  _congregation = v;
                                  _edited();
                                },
                        ),
                      ),
                    FilledButton(
                      onPressed: _busy || _saving ? null : _apply,
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
              if (_busy)
                Semantics(
                  liveRegion: true,
                  child: const Text('Carregando relatório…'),
                ),
              if (_saving)
                Semantics(
                  liveRegion: true,
                  child: const Text('Escolha onde salvar o arquivo…'),
                ),
              if (_message != null)
                Semantics(
                  liveRegion: true,
                  child: Builder(
                    builder: (context) {
                      final isError =
                          _message!.startsWith('Não foi possível') ||
                          _message!.startsWith('Confira') ||
                          _message!.startsWith('Seu acesso');
                      final isSuccess = _message!.startsWith('Arquivo salvo');
                      final foreground = isError
                          ? UnifiedColors.red
                          : isSuccess
                          ? const Color(0xff166534)
                          : UnifiedColors.muted;
                      final background = isError
                          ? const Color(0xfffff7f7)
                          : isSuccess
                          ? const Color(0xfff0fdf4)
                          : UnifiedColors.page;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: background,
                          border: Border.all(
                            color: isError
                                ? const Color(0xfffecaca)
                                : isSuccess
                                ? const Color(0xffbbf7d0)
                                : UnifiedColors.border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(color: foreground),
                        ),
                      );
                    },
                  ),
                ),
              if (!_applied && !_busy)
                const Text('Selecione os filtros e clique em Aplicar.'),
              if (_applied) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      widget.events
                          ? '${_rows.length} evento(s) encontrado(s)'
                          : '${_counts.fold<int>(0, (s, c) => s + c.count)} conversões no período',
                    ),
                    if (_bytes != null)
                      OutlinedButton(
                        onPressed: _busy || _saving ? null : _export,
                        child: const Text('Exportar XLSX'),
                      ),
                  ],
                ),
                if (_rows.isEmpty)
                  const Text('Nenhum registro no período selecionado.'),
                if (!widget.events && _counts.isNotEmpty) ...[
                  const Text('Distribuição por Tipo de Culto'),
                  Semantics(
                    label: _counts
                        .map((c) => '${c.name}: ${c.count}')
                        .join(', '),
                    child: SizedBox(
                      height: 220,
                      child: CustomPaint(painter: _Pie(_counts)),
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final entry in _counts.indexed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: Container(
                                width: 12,
                                height: 12,
                                color:
                                    _Pie.colors[entry.$1 % _Pie.colors.length],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${entry.$2.name} (${entry.$2.count})',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                if (_rows.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTableTheme(
                      data: DataTableThemeData(
                        headingRowColor: const WidgetStatePropertyAll(
                          UnifiedColors.pageTint,
                        ),
                        headingTextStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              color: UnifiedColors.brandNavy,
                              fontWeight: FontWeight.w700,
                            ),
                        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                        dividerThickness: 1,
                      ),
                      child: DataTable(
                        sortColumnIndex: _sortColumn,
                        sortAscending: _ascending,
                        columns: [
                          for (final h in _headers)
                            DataColumn(label: Text(h), onSort: _sort),
                        ],
                        rows: [
                          for (final entry in _rows.indexed)
                            DataRow(
                              color: WidgetStatePropertyAll(
                                entry.$1.isOdd
                                    ? UnifiedColors.page
                                    : Colors.white,
                              ),
                              cells: [
                                for (final value in entry.$2)
                                  DataCell(Text(value)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Pie extends CustomPainter {
  _Pie(this.counts);
  final List<WorshipCount> counts;
  static const colors = [
    Color(0xff1e3a5f),
    Color(0xff2563eb),
    Color(0xff10b981),
    Color(0xfff59e0b),
    Color(0xffef4444),
    Color(0xff8b5cf6),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.fold<int>(0, (s, c) => s + c.count);
    var angle = -math.pi / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 8,
    );
    for (final entry in counts.indexed) {
      final sweep = entry.$2.count / total * math.pi * 2;
      canvas.drawArc(
        rect,
        angle,
        sweep,
        true,
        Paint()..color = colors[entry.$1 % colors.length],
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Pie old) => old.counts != counts;
}
