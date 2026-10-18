import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/supabase_gateway.dart';
import '../../platform/file_exporter.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
import 'backup_codec.dart';
import 'backup_models.dart';
import 'backup_repository.dart';

class BackupPanel extends StatefulWidget {
  const BackupPanel({
    super.key,
    required this.repository,
    required this.exporter,
    required this.onScopeRefresh,
  });
  final BackupRepository repository;
  final FileExporter exporter;
  final Future<void> Function() onScopeRefresh;
  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  ImportPreview? _preview;
  Uint8List? _bytes;
  ImportProgress? _progress;
  bool _busy = false, _confirm = false;
  String? _message;
  int _request = 0;
  late String _context;
  @override
  void initState() {
    super.initState();
    _context = widget.repository.gateway.context;
  }

  void _erase() {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
    _preview = null;
    _progress = null;
    _confirm = false;
    _message = null;
  }

  @override
  void didUpdateWidget(covariant BackupPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        _context != widget.repository.gateway.context) {
      _request++;
      _erase();
      _busy = false;
      _context = widget.repository.gateway.context;
    }
  }

  @override
  void dispose() {
    _request++;
    _erase();
    super.dispose();
  }

  void _current(int request, String token) {
    if (!mounted || request != _request) throw const DataFailure('stale');
    widget.repository.gateway.ensureCurrent(token);
  }

  String _failure(Object error) {
    if (error is DataFailure && error.code == 'permission') {
      return 'Seu acesso mudou. Atualize o acesso para continuar.';
    }
    if (error is BackupFormatException) {
      return switch (error.code) {
        'binary_xls' || 'unsupported_xls' => 'O formato .xls não é compatível. Salve como .xlsx e selecione novamente.',
        'row_limit' => 'O arquivo aceita até 10.000 registros. Divida o backup e tente novamente.',
        'compressed_limit' || 'expanded_limit' =>
          'O arquivo é muito grande. Divida o backup e tente novamente.',
        _ => 'Não foi possível ler este backup. Confira o modelo .xlsx e selecione novamente.',
      };
    }
    return 'Não foi possível concluir. Tente novamente; para retomar uma importação, selecione o mesmo arquivo na mesma conta.';
  }

  Future<void> _run(Future<void> Function(int, String) work) async {
    if (_busy) return;
    final request = ++_request, token = widget.repository.gateway.context;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work(request, token);
      _current(request, token);
    } catch (error) {
      try {
        _current(request, token);
      } catch (_) {
        return;
      }
      if (error is DataFailure && error.code == 'stale') return;
      if (error is DataFailure && error.code == 'permission') {
        _erase();
        setState(() {
          _message = _failure(error);
        });
        await widget.onScopeRefresh();
        try {
          _current(request, token);
        } catch (_) {
          return;
        }
      } else {
        setState(() {
          _message = _failure(error);
        });
      }
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _select() => _run((request, token) async {
    _erase();
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    _current(request, token);
    if (file == null) return;
    if (file.extension?.toLowerCase() != 'xlsx') {
      throw const BackupFormatException('unsupported_xls');
    }
    final length = await file.length();
    _current(request, token);
    if (length == null || length > BackupCodec.maxCompressed) {
      throw const BackupFormatException('compressed_limit');
    }
    // Bounded streaming prevents a changed/incorrect reported length from allocating unbounded bytes.
    final builder = BytesBuilder(copy: false);
    var count = 0;
    try {
      await for (final chunk in file.readAsByteStream()) {
        _current(request, token);
        count += chunk.length;
        if (count > BackupCodec.maxCompressed) {
          throw const BackupFormatException('compressed_limit');
        }
        builder.add(chunk);
      }
      _current(request, token);
      final bytes = builder.takeBytes();
      try {
        final preview = BackupCodec().decode(bytes);
        _current(request, token);
        setState(() {
          _preview = preview;
        });
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } finally {
      final retained = builder.takeBytes();
      retained.fillRange(0, retained.length, 0);
    }
  });
  Future<void> _prepare() => _run((request, token) async {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
    final bytes = await widget.repository.exportBytes();
    try {
      _current(request, token);
      setState(() {
        _bytes = bytes;
        _message = 'Backup preparado. Escolha Baixar backup para salvar.';
      });
    } catch (_) {
      bytes.fillRange(0, bytes.length, 0);
      rethrow;
    }
  });
  // This call enters the exporter before any await so the browser retains user activation.
  Future<void> _save() => _run((request, token) async {
    final bytes = _bytes;
    if (bytes == null) return;
    final outcome = await widget.exporter.save(
      'backup_convertidos.xlsx',
      bytes,
      ensureCurrent: () => _current(request, token),
    );
    _current(request, token);
    setState(() {
      _message = switch (outcome) {
        SaveOutcome.saved => 'Backup salvo.',
        SaveOutcome.cancelled => 'Salvamento cancelado.',
        SaveOutcome.failed => 'Não foi possível salvar. Tente novamente em um navegador compatível ou no aplicativo Android.',
      };
    });
  });
  Future<void> _import() => _run((request, token) async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _confirm = false;
      _progress = null;
    });
    await for (final progress in widget.repository.importRows(preview)) {
      _current(request, token);
      if (progress.errorCode == 'permission') {
        throw const DataFailure('permission');
      }
      setState(() {
        _progress = progress;
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final preview = _preview, progress = _progress;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Base44PageHeading(
                title: 'Backup',
                icon: Icons.backup_outlined,
              ),
              const SizedBox(height: 16),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.download_outlined,
                          color: UnifiedColors.brandNavy,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Exportar backup',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: UnifiedColors.brandNavy),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Exporte os convertidos em .xlsx. O arquivo não inclui fotos e não substitui o backup completo do banco de dados.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _prepare,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Preparar backup'),
                        ),
                        if (_bytes != null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Baixar backup'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.upload_file_outlined,
                          color: UnifiedColors.brandNavy,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Importar backup',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: UnifiedColors.brandNavy),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'IDs já existentes ou excluídos são ignorados. Cada linha é salva separadamente. Para retomar após uma interrupção, entre na mesma conta e selecione o mesmo arquivo, sem alterações.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _select,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Selecionar arquivo .xlsx'),
                      ),
                    ),
                    if (preview != null) ...[
                      const Divider(height: 28),
                      Text(
                        '${preview.rows.length} linha(s) válida(s) para conferência. ${preview.diagnostics.length} aviso(s) de validação.',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: UnifiedColors.brandNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final row in preview.rows.take(20))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Linha ${row.rowNumber}: ${row.record.name} • ${row.record.conversionDate} • ${row.congregationName.isEmpty ? 'Sem congregação' : row.congregationName}',
                          ),
                        ),
                      if (preview.rows.length > 20)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Prévia das primeiras 20 linhas. A importação processará todas as linhas válidas.',
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Congregações serão conferidas ao importar: nomes desconhecidos ficam sem congregação; nomes ambíguos impedem a linha.',
                        ),
                      ),
                      for (final diagnostic in preview.diagnostics.take(30))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Linha ${diagnostic.rowNumber}, ${diagnostic.column}: ${diagnostic.code == 'duplicate_id' ? 'ID repetido; linha ignorada.' : 'Valor inválido; corrija no arquivo.'}',
                          ),
                        ),
                      if (preview.diagnostics.length > 30)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Há mais avisos. Corrija o arquivo e selecione novamente.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_confirm) ...[
                        const Text(
                          'Confirmar a importação das linhas válidas? Os registros existentes serão preservados.',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              onPressed: _busy ? null : _import,
                              child: const Text('Confirmar importação'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _confirm = false;
                                    }),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      ] else if (progress?.done != true)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _busy || preview.rows.isEmpty
                                ? null
                                : () => setState(() {
                                    _confirm = true;
                                  }),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              progress?.errorCode == null
                                  ? 'Revisar e importar'
                                  : 'Retomar importação',
                            ),
                          ),
                        ),
                    ],
                    if (_busy)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: const Text('Processando…'),
                        ),
                      ),
                    if (progress != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${progress.done ? 'Concluído. ' : ''}${progress.processed} linha(s) processada(s): ${progress.created} criada(s), ${progress.skipped} ignorada(s), ${progress.errors} com erro.',
                          ),
                        ),
                      ),
                    if (progress != null)
                      for (final diagnostic in progress.diagnostics)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Linha ${diagnostic.rowNumber}: registro recusado (${diagnostic.code}). Corrija no arquivo e selecione novamente.',
                            style: const TextStyle(color: UnifiedColors.red),
                          ),
                        ),
                    if (progress != null &&
                        progress.done &&
                        progress.errors > 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Corrija as linhas com erro no arquivo e selecione novamente. As linhas já importadas serão ignoradas.',
                          style: TextStyle(color: UnifiedColors.red),
                        ),
                      ),
                    if (progress?.warning != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Uma ou mais congregações não foram encontradas. Os registros correspondentes ficaram sem congregação.',
                        ),
                      ),
                    if (progress?.errorCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          progress?.errorCode == 'invalid'
                              ? 'Uma linha não foi aceita. Confira os dados e tente novamente.'
                              : _failure(const DataFailure('unavailable')),
                          style: const TextStyle(color: UnifiedColors.red),
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color:
                                  _message!.startsWith('Não foi possível') ||
                                      _message!.startsWith('Seu acesso')
                                  ? UnifiedColors.red
                                  : UnifiedColors.brandNavy,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
