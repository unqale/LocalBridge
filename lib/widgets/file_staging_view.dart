import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_staging.dart';
import '../theme/editorial_theme.dart';
import 'editorial_graphics.dart';

class StagedTargetOption {
  final String key;
  final String alias;
  final String subtitle;
  final bool isTrusted;

  const StagedTargetOption({
    required this.key,
    required this.alias,
    this.subtitle = '',
    this.isTrusted = false,
  });
}

class FileStagingModal extends StatelessWidget {
  final FileStagingController controller;
  final List<StagedTargetOption> targetOptions;
  final String Function(String key) tr;
  final String Function(int bytes) formatBytes;
  final Future<void> Function() onAddMoreFiles;
  final Future<void> Function() onStartSend;
  final VoidCallback? onCancelTransfer;
  final double? transferProgress;
  final bool isDesktopLayout;

  const FileStagingModal({
    super.key,
    required this.controller,
    required this.targetOptions,
    required this.tr,
    required this.formatBytes,
    required this.onAddMoreFiles,
    required this.onStartSend,
    this.onCancelTransfer,
    this.transferProgress,
    this.isDesktopLayout = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final accent = p.accent;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;
        final totalBytes = controller.totalBytes;
        final count = controller.totalCount;
        final countLabel =
            '$count ${count == 1 ? tr('stageFileSingular') : tr('stageFilePlural')}';
        final canSend = controller.isNotEmpty &&
            !controller.isTransferring &&
            (controller.targetKey != null || controller.isBroadcast);

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktopLayout ? 680 : 620,
            maxHeight: isDesktopLayout
                ? 680
                : MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: isDesktopLayout
                  ? BorderRadius.circular(26)
                  : const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
                width: 1.1,
              ),
              boxShadow: p.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: isDesktopLayout
                  ? BorderRadius.circular(25)
                  : const BorderRadius.vertical(top: Radius.circular(25)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: EditorialMotifPainter(
                            variant: EditorialMotifVariant.steppedCards,
                            primary: accent,
                            secondary: p.secondaryAccent,
                            warm: p.warmHighlight,
                            opacity: 0.11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isDesktopLayout)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 2),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: p.borderStrong,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      _buildHeader(context, countLabel, totalBytes, p, accent),
                      Divider(height: 1, color: p.border),
                      _buildCompositionBar(items, totalBytes, p, accent),
                      _buildTargetBar(context, p, accent, cs),
                      if (controller.isTransferring)
                        _buildTransferringBanner(p, accent),
                      if (controller.lastError != null &&
                          !controller.isTransferring)
                        _buildErrorBanner(p),
                      Flexible(
                        child: items.isEmpty
                            ? _buildEmptyState(p, accent)
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  16,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    _StagedFileCard(
                                  item: items[index],
                                  index: index,
                                  palette: p,
                                  accent: accent,
                                  formatBytes: formatBytes,
                                  removeTooltip: tr('stageRemoveFile'),
                                  enabled: !controller.isTransferring,
                                  onRemove: () => controller.removeAt(index),
                                ),
                              ),
                      ),
                      Divider(height: 1, color: p.border),
                      _buildFooter(context, canSend, countLabel, p, accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String countLabel,
    int totalBytes,
    EditorialPalette p,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.24),
                  p.secondaryAccent.withValues(alpha: 0.14),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: accent.withValues(alpha: 0.36),
              ),
            ),
            child: Icon(
              Icons.layers_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tr('stageTitle'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: p.ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        '$countLabel • ${formatBytes(totalBytes)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tr('stageSubtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.isTransferring
                ? null
                : () => Navigator.of(context).maybePop(false),
            tooltip: tr('cancel'),
            icon: Icon(
              Icons.close_rounded,
              color: p.inkSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionBar(
    List<StagedFileItem> items,
    int totalBytes,
    EditorialPalette p,
    Color accent,
  ) {
    if (items.isEmpty || totalBytes <= 0) return const SizedBox.shrink();
    final buckets = <StagedFileCategory, int>{};
    for (final f in items) {
      final sz = f.size > 0 ? f.size : 1;
      buckets[f.category] = (buckets[f.category] ?? 0) + sz;
    }

    Color colorFor(StagedFileCategory cat) => switch (cat) {
          StagedFileCategory.image => const Color(0xFFE06D53),
          StagedFileCategory.video => const Color(0xFF8B6CEF),
          StagedFileCategory.audio => const Color(0xFFD9822B),
          StagedFileCategory.document => accent,
          StagedFileCategory.archive => const Color(0xFF289D8F),
          StagedFileCategory.code => const Color(0xFF3A86FF),
          StagedFileCategory.executable => const Color(0xFFE55381),
          StagedFileCategory.other => p.warmHighlight,
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 5,
          child: Row(
            children: buckets.entries.map((e) {
              final flex = (e.value * 1000 ~/ totalBytes).clamp(1, 1000);
              return Expanded(
                flex: flex,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  color: colorFor(e.key),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetBar(
    BuildContext context,
    EditorialPalette p,
    Color accent,
    ColorScheme cs,
  ) {
    final currentKey = controller.targetKey;
    final hasCurrentInList =
        currentKey != null && targetOptions.any((o) => o.key == currentKey);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceRecessed,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.devices_rounded, size: 18, color: accent),
          const SizedBox(width: 10),
          Text(
            tr('stageTargetDevice'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.inkSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: targetOptions.isEmpty
                ? Text(
                    controller.targetAlias ?? tr('stageNoReceiverSelected'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: controller.targetAlias != null ? p.ink : p.warning,
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: hasCurrentInList
                          ? currentKey
                          : targetOptions.first.key,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: p.cardElevated,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                      items: targetOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt.key,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  opt.alias,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                              ),
                              if (opt.subtitle.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${opt.subtitle})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: p.inkMuted,
                                  ),
                                ),
                              ],
                              if (opt.isTrusted) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: Color(0xFFF5A623),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: controller.isTransferring
                          ? null
                          : (newKey) {
                              if (newKey == null) return;
                              final found = targetOptions.firstWhere(
                                (o) => o.key == newKey,
                                orElse: () => targetOptions.first,
                              );
                              controller.setTarget(
                                key: found.key,
                                alias: found.alias,
                                ip: found.subtitle,
                              );
                            },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferringBanner(EditorialPalette p, Color accent) {
    final pct = ((transferProgress ?? 0.0) * 100).clamp(0, 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${tr('sending')} (${controller.sentFilesCount}/${controller.totalCount}) • $pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              if (onCancelTransfer != null)
                TextButton(
                  onPressed: onCancelTransfer,
                  style: TextButton.styleFrom(
                    foregroundColor: p.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(tr('cancel')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: transferProgress,
              minHeight: 5,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(EditorialPalette p) {
    final err = controller.lastError ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: p.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: p.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              err,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(EditorialPalette p, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditorialLaunchpadIllustration(
            accent: accent,
            secondary: p.secondaryAccent,
            warm: p.warmHighlight,
            size: 68,
          ),
          const SizedBox(height: 12),
          Text(
            tr('stageEmptyTitle'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('stageEmptyHint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: p.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    bool canSend,
    String countLabel,
    EditorialPalette p,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('stage_add_more_btn'),
                onPressed: controller.isTransferring ? null : onAddMoreFiles,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(tr('stageAddMore')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.ink,
                  side: BorderSide(color: p.borderStrong),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (controller.isNotEmpty)
                TextButton.icon(
                  key: const Key('stage_clear_all_btn'),
                  onPressed:
                      controller.isTransferring ? null : controller.clear,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 17),
                  label: Text(tr('stageClearAll')),
                  style: TextButton.styleFrom(
                    foregroundColor: p.danger,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: controller.isTransferring
                    ? null
                    : () => Navigator.of(context).maybePop(false),
                style: TextButton.styleFrom(
                  foregroundColor: p.inkSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
                child: Text(tr('cancel')),
              ),
              FilledButton.icon(
                key: const Key('stage_send_now_btn'),
                onPressed: canSend ? onStartSend : null,
                icon: const Icon(Icons.send_rounded, size: 17),
                label: Text(
                  controller.lastError != null
                      ? tr('stageRetryRemaining')
                      : '${tr('stageSendNow')} ($countLabel)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: p.border,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StagedFileCard extends StatelessWidget {
  final StagedFileItem item;
  final int index;
  final EditorialPalette palette;
  final Color accent;
  final String Function(int bytes) formatBytes;
  final String removeTooltip;
  final bool enabled;
  final VoidCallback onRemove;

  const _StagedFileCard({
    required this.item,
    required this.index,
    required this.palette,
    required this.accent,
    required this.formatBytes,
    required this.removeTooltip,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ext = item.extension.isEmpty ? 'FILE' : item.extension.toUpperCase();
    final hasThumb =
        item.canPreviewThumbnail && item.path != null && File(item.path!).existsSync();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceRecessed,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          if (hasThumb)
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image(
                image: ResizeImage(
                  FileImage(File(item.path!)),
                  width: 88,
                  height: 88,
                ),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => EditorialFileIllustration(
                  fileName: item.name,
                  size: 40,
                ),
              ),
            )
          else
            EditorialFileIllustration(
              fileName: item.name,
              size: 40,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ext,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatBytes(item.size),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.inkSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('stage_remove_item_$index'),
            onPressed: enabled ? onRemove : null,
            tooltip: removeTooltip,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: palette.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
