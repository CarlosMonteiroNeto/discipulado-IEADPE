import 'package:flutter/material.dart';

import 'unified_theme.dart';

class Base44PageHeading extends StatelessWidget {
  const Base44PageHeading({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;

  Widget _heading(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2, right: UnifiedSpace.x3),
        child: ExcludeSemantics(
          child: Icon(
            icon,
            size: UnifiedSize.actionIcon,
            color: UnifiedColors.brandNavy,
          ),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (trailing == null) return _heading(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 520 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(context),
              const SizedBox(height: UnifiedSpace.x2),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _heading(context)),
            trailing!,
          ],
        );
      },
    );
  }
}

/// Centers page content and applies the shared phone/wide insets and width.
class Base44PageContent extends StatelessWidget {
  const Base44PageContent({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalInset =
          constraints.maxWidth < UnifiedLayout.navigationBreakpoint
          ? UnifiedSpace.phoneInset
          : UnifiedSpace.wideInset;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: UnifiedLayout.maxContentWidth,
          ),
          child: Padding(
            padding:
                padding ?? EdgeInsets.symmetric(horizontal: horizontalInset),
            child: child,
          ),
        ),
      );
    },
  );
}

class Base44SectionHeading extends StatelessWidget {
  const Base44SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null)
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    if (trailing == null) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 520 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: UnifiedSpace.x2),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            trailing!,
          ],
        );
      },
    );
  }
}

class Base44Panel extends StatelessWidget {
  const Base44Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UnifiedSpace.x4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: UnifiedColors.surface,
      border: Border.all(color: UnifiedColors.border),
      borderRadius: BorderRadius.circular(UnifiedRadius.standard),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100f172a),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

enum Base44StatusTone { primary, success, warning, error, neutral }

class Base44StatusBadge extends StatelessWidget {
  const Base44StatusBadge({
    super.key,
    required this.label,
    this.tone = Base44StatusTone.neutral,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final Base44StatusTone tone;
  final IconData? icon;
  final String? semanticsLabel;

  Color get _foreground => switch (tone) {
    Base44StatusTone.primary => UnifiedColors.brandNavy,
    Base44StatusTone.success => UnifiedColors.success,
    Base44StatusTone.warning => UnifiedColors.warning,
    Base44StatusTone.error => UnifiedColors.error,
    Base44StatusTone.neutral => UnifiedColors.disabledText,
  };

  Color get _background => switch (tone) {
    Base44StatusTone.primary => UnifiedColors.selected,
    Base44StatusTone.success => UnifiedColors.successSurface,
    Base44StatusTone.warning => UnifiedColors.warningSurface,
    Base44StatusTone.error => UnifiedColors.errorSurface,
    Base44StatusTone.neutral => UnifiedColors.disabledSurface,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticsLabel ?? label,
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(UnifiedRadius.badge),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnifiedSpace.x3,
            vertical: UnifiedSpace.x1,
          ),
          child: icon == null
              ? Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _foreground,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: UnifiedSize.inlineIcon,
                      color: _foreground,
                    ),
                    const SizedBox(width: UnifiedSpace.x1),
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

enum Base44FeedbackKind { loading, empty, error }

/// Standard panel for loading, empty, and retryable error states.
class Base44FeedbackState extends StatelessWidget {
  const Base44FeedbackState({
    super.key,
    required this.kind,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
  });

  final Base44FeedbackKind kind;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final content = switch (kind) {
      Base44FeedbackKind.loading => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: UnifiedSize.inlineIcon,
            height: UnifiedSize.inlineIcon,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: UnifiedSpace.x3),
          Expanded(child: Text(message)),
        ],
      ),
      Base44FeedbackKind.empty => _messageContent(
        context,
        icon: Icons.inbox_outlined,
        color: UnifiedColors.muted,
      ),
      Base44FeedbackKind.error => _messageContent(
        context,
        icon: Icons.error_outline,
        color: UnifiedColors.error,
      ),
    };
    final panel = Base44Panel(
      padding: const EdgeInsets.all(UnifiedSpace.x6),
      child: content,
    );
    if (kind != Base44FeedbackKind.loading) return panel;

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel ?? 'Carregando: $message',
      child: ExcludeSemantics(child: panel),
    );
  }

  Widget _messageContent(
    BuildContext context, {
    required IconData icon,
    required Color color,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, color: color, size: UnifiedSize.actionIcon),
          ),
          const SizedBox(width: UnifiedSpace.x3),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kind == Base44FeedbackKind.error
                    ? UnifiedColors.error
                    : UnifiedColors.text,
              ),
            ),
          ),
        ],
      ),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: UnifiedSpace.x3),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ),
      ],
    ],
  );
}

class Base44Hero extends StatelessWidget {
  const Base44Hero({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(UnifiedSpace.x6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [UnifiedColors.brandNavy, UnifiedColors.brandBlue],
      ),
      borderRadius: BorderRadius.circular(UnifiedRadius.large),
      boxShadow: const [
        BoxShadow(
          color: Color(0x241e3a5f),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

/// Animated content switch that follows the platform reduced-motion setting.
class Base44AnimatedSwitcher extends StatelessWidget {
  const Base44AnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: UnifiedMotion.durationFor(context, requested: duration),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    child: child,
  );
}
