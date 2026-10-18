import 'package:flutter/material.dart';

import '../../platform/file_exporter.dart';
import 'reports_repository.dart';
import 'report_view.dart';

class ConversionPanel extends StatelessWidget {
  const ConversionPanel({
    super.key,
    required this.repository,
    required this.exporter,
    required this.onScopeRefresh,
  });
  final ReportsRepository repository;
  final FileExporter exporter;
  final Future<void> Function() onScopeRefresh;
  @override
  Widget build(BuildContext context) => ReportView(
    repository: repository,
    exporter: exporter,
    onScopeRefresh: onScopeRefresh,
    events: false,
  );
}
