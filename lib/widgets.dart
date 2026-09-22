// widgets.dart — small shared building blocks.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'i18n.dart';
import 'offline.dart';
import 'theme.dart';
import 'update.dart';

/// A thin status bar shown at the top of the app shells when the phone is
/// offline or has changes waiting to sync. Invisible when online and empty.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([offline.online, offline.pending]),
      builder: (context, _) {
        final online = offline.online.value;
        final n = offline.pending.value;
        if (online && n == 0) return const SizedBox.shrink();
        final color = online ? kBlue : kWarn;
        final icon = online ? Icons.sync : Icons.cloud_off;
        final text = online
            ? t('Syncing {n} change(s)…').replaceFirst('{n}', '$n')
            : n > 0
                ? t('Offline — {n} change(s) will sync').replaceFirst('{n}', '$n')
                : t('Offline — showing saved data');
        return Material(
          color: color.withValues(alpha: 0.14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      style: TextStyle(
                          color: color,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A thin notice at the top of the app shells when the server has published a
/// newer APK than the one running. Invisible otherwise — including when
/// nothing has been published at all, which is silence, not "up to date".
///
/// Download opens the .apk in the browser and Android installs it; there is
/// no in-app installer. Dismiss remembers this build (see [AppUpdate]).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  Future<void> _download(BuildContext context, AppRelease release) async {
    final uri = Uri.tryParse(release.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppRelease?>(
      valueListenable: appUpdate.available,
      builder: (context, release, _) {
        if (release == null) return const SizedBox.shrink();
        final headline = release.version.isEmpty
            ? t('A new version is available')
            : t('Version {v} is available').replaceFirst('{v}', release.version);
        return Material(
          color: kBlue.withValues(alpha: 0.14),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
            child: Row(
              children: [
                const Icon(Icons.system_update, size: 18, color: kBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(headline,
                          style: const TextStyle(
                              color: kBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                      if (release.notes.isNotEmpty)
                        Text(release.notes,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: kMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _download(context, release),
                  style: TextButton.styleFrom(
                      foregroundColor: kBlue,
                      visualDensity: VisualDensity.compact),
                  child: Text(t('Download'),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: t('Not now'),
                  icon: const Icon(Icons.close, size: 18),
                  color: kMuted,
                  visualDensity: VisualDensity.compact,
                  onPressed: appUpdate.dismiss,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

/// One chip per maker, with "All" first, above a catalogue or stock list.
///
/// Renders nothing when there is fewer than two makers to choose between:
/// a single-maker yard (or a server that predates the manufacturer axis,
/// where [makers] is null) sees the screens exactly as before. [selected]
/// is the maker's slug, null meaning every maker.
class ManufacturerChips extends StatelessWidget {
  final List<Map>? makers;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const ManufacturerChips({
    required this.makers,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final list = makers ?? const <Map>[];
    if (list.length < 2) return const SizedBox.shrink();
    Widget chip(String label, String? value) {
      final active = selected == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : kInk, fontSize: 13)),
          selected: active,
          showCheckmark: false,
          selectedColor: kNavy,
          backgroundColor: Colors.white,
          side: BorderSide(color: active ? kNavy : kLine),
          onSelected: (_) => onChanged(value),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          chip(t('All manufacturers'), null),
          for (final m in list) chip(makerName(m), m['slug'].toString()),
        ],
      ),
    );
  }
}
