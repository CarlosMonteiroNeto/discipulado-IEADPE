import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'responsive_scaffold.dart';

class AppRecordColumn<T> {
  const AppRecordColumn({
    required this.label,
    required this.cell,
    this.numeric = false,
    this.flex = 1,
  });

  final String label;
  final Widget Function(BuildContext context, T item) cell;
  final bool numeric;
  final int flex;
}

/// Comparable records render as a table on wide viewports and as cards on
/// narrow ones. Only the explicitly labelled table region may scroll
/// horizontally; the page itself never does.
class AppRecordList<T> extends StatelessWidget {
  const AppRecordList({
    super.key,
    required this.items,
    required this.columns,
    this.onOpen,
    this.toolbar,
    this.emptyMessage = 'Nenhum registro encontrado',
  });

  final List<T> items;
  final List<AppRecordColumn<T>> columns;
  final ValueChanged<T>? onOpen;
  final Widget? toolbar;
  final String emptyMessage;

  static const Key tableKey = Key('record-table');
  static const Key tableScrollKey = Key('record-table-scroll');
  static const Key cardsKey = Key('record-cards');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= AppBreakpoints.medium;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (toolbar != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: <Widget>[toolbar!],
                ),
              ),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            else
              Expanded(child: wide ? _table(context) : _cards(context)),
          ],
        );
      },
    );
  }

  Widget _table(BuildContext context) {
    return SingleChildScrollView(
      key: tableScrollKey,
      scrollDirection: Axis.horizontal,
      child: DataTable(
        key: tableKey,
        columns: <DataColumn>[
          for (final AppRecordColumn<T> column in columns)
            DataColumn(label: Text(column.label), numeric: column.numeric),
        ],
        rows: <DataRow>[
          for (final T item in items)
            DataRow(
              onSelectChanged: onOpen == null ? null : (_) => onOpen!(item),
              cells: <DataCell>[
                for (final AppRecordColumn<T> column in columns)
                  DataCell(column.cell(context, item)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cards(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return ListView.separated(
      key: cardsKey,
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.x3),
      itemBuilder: (BuildContext context, int index) {
        final T item = items[index];
        return Card(
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
          ),
          child: InkWell(
            borderRadius: AppRadii.cardRadius,
            onTap: onOpen == null ? null : () => onOpen!(item),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (
                    int columnIndex = 0;
                    columnIndex < columns.length;
                    columnIndex++
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: columnIndex == columns.length - 1
                            ? 0
                            : AppSpacing.x3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            columns[columnIndex].label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          columns[columnIndex].cell(context, item),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
