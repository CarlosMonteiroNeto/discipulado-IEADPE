import 'package:flutter/material.dart';

import '../domain/ports.dart';
import 'app_theme.dart';
import 'form_fields.dart';

/// Distinct asynchronous situations required by S03 and S10-S13.
enum AsyncPhase {
  loading,
  data,
  emptyData,
  emptySearch,
  error,
  forbidden,
  notFound,
}

/// Immutable view state for an asynchronous resource.
class AsyncViewState<T> {
  const AsyncViewState.loading()
    : phase = AsyncPhase.loading,
      data = null,
      query = null,
      failure = null;

  const AsyncViewState.data(T value)
    : phase = AsyncPhase.data,
      data = value,
      query = null,
      failure = null;

  const AsyncViewState.emptyData()
    : phase = AsyncPhase.emptyData,
      data = null,
      query = null,
      failure = null;

  const AsyncViewState.emptySearch({required this.query})
    : phase = AsyncPhase.emptySearch,
      data = null,
      failure = null;

  const AsyncViewState.forbidden()
    : phase = AsyncPhase.forbidden,
      data = null,
      query = null,
      failure = null;

  const AsyncViewState.notFound()
    : phase = AsyncPhase.notFound,
      data = null,
      query = null,
      failure = null;

  const AsyncViewState.error(AppFailure this.failure)
    : phase = AsyncPhase.error,
      data = null,
      query = null;

  final AsyncPhase phase;
  final T? data;
  final String? query;
  final AppFailure? failure;

  /// Maps an [AppFailure] code to its own presentation phase so that a denied
  /// request or a missing record is never rendered as an empty database.
  factory AsyncViewState.fromFailure(AppFailure failure) {
    return switch (failure.code) {
      AppFailureCode.forbidden => AsyncViewState<T>.forbidden(),
      AppFailureCode.notFound => AsyncViewState<T>.notFound(),
      _ => AsyncViewState<T>.error(failure),
    };
  }
}

/// Renders loading, data, empty, error, forbidden and not-found states with
/// distinct, accessible presentations.
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.state,
    this.dataBuilder,
    this.onRetry,
    this.retryLabel = 'Tentar novamente',
  });

  final AsyncViewState<T> state;
  final Widget Function(BuildContext context, T value)? dataBuilder;
  final Future<void> Function()? onRetry;
  final String retryLabel;

  static const Key loadingKey = Key('async-loading');
  static const Key emptyDataKey = Key('async-empty-data');
  static const Key emptySearchKey = Key('async-empty-search');
  static const Key errorKey = Key('async-error');
  static const Key retryKey = Key('async-retry');
  static const Key forbiddenKey = Key('async-forbidden');
  static const Key notFoundKey = Key('async-not-found');

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case AsyncPhase.loading:
        return Center(
          key: loadingKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.x3),
              Text(
                'Carregando…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      case AsyncPhase.data:
        final T? value = state.data;
        if (value == null || dataBuilder == null) {
          return const SizedBox.shrink();
        }
        return dataBuilder!(context, value);
      case AsyncPhase.emptyData:
        return _message(
          context,
          emptyDataKey,
          Icons.inbox_outlined,
          'Nenhum registro encontrado',
        );
      case AsyncPhase.emptySearch:
        return _message(
          context,
          emptySearchKey,
          Icons.search_off,
          'Nenhum resultado encontrado para a busca',
        );
      case AsyncPhase.error:
        return _error(context);
      case AsyncPhase.forbidden:
        return _message(
          context,
          forbiddenKey,
          Icons.lock_outline,
          'Acesso não autorizado',
        );
      case AsyncPhase.notFound:
        return _message(
          context,
          notFoundKey,
          Icons.help_outline,
          'Registro não encontrado',
        );
    }
  }

  Widget _message(
    BuildContext context,
    Key key,
    IconData icon,
    String message,
  ) {
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: AppSizes.controlHeight,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) {
    final String message =
        state.failure?.message ?? 'Não foi possível carregar os dados.';
    return Center(
      key: errorKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: AppSizes.controlHeight,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.x4),
          if (onRetry != null)
            AppButton(
              key: retryKey,
              label: retryLabel,
              onPressed: () => onRetry!(),
            ),
        ],
      ),
    );
  }
}
