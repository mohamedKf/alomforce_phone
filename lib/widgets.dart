// widgets.dart — small shared building blocks.
import 'package:flutter/material.dart';

import 'theme.dart';

// ---- responsive helpers (phone → tablet / iPad) ----

/// A wide screen (tablet / iPad / desktop) vs a phone.
bool isWide(BuildContext c) => MediaQuery.of(c).size.width >= 720;

/// How many columns a card grid should use for the current width.
int gridColumns(BuildContext c, {double itemWidth = 360, int max = 3}) {
  final w = MediaQuery.of(c).size.width;
  return (w / itemWidth).floor().clamp(1, max);
}

/// Centre content with a comfortable max width on big screens; on a phone it
/// just fills the width. Use to keep forms/lists readable on an iPad.
class Bounded extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Bounded(this.child, {this.maxWidth = 720, super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// A list that becomes a multi-column grid on wide screens. `itemHeight` is the
/// fixed row height used when it's a grid.
class ResponsiveCards extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsets padding;
  final double itemHeight;
  final Future<void> Function()? onRefresh;
  const ResponsiveCards({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.itemHeight = 150,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cols = isWide(context) ? gridColumns(context) : 1;
    final Widget content = cols == 1
        ? ListView.separated(
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: itemBuilder,
          )
        : GridView.builder(
            padding: padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: itemHeight,
            ),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
    if (onRefresh == null) return content;
    return RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}

/// A rounded status pill (order status, stock level, …).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Full-screen centred message with an optional retry action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(this.icon, this.message,
      {this.actionLabel, this.onAction, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: kMuted),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted, fontSize: 15)),
            if (onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel ?? 'Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString()), backgroundColor: kDanger),
  );
}

void showOk(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: kSuccess),
  );
}
