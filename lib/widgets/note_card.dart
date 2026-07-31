import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/markdown_controller.dart';
import '../utils/relative_time.dart';
import 'glass.dart';

/// A single glass note tile in the home grid.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onToggleFavorite,
    required this.onLongPress,
    this.onToggleItem,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleFavorite;
  final VoidCallback onLongPress;
  final void Function(String itemId)? onToggleItem;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = AppColors.accentAt(note.accent);
    final bool isChecklist = note.kind == NoteKind.checklist;

    return GlassTapPanel(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: AppTheme.radiusLg,
      glow: accent,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(top: 3, right: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  note.title.trim().isEmpty ? 'Untitled' : note.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    color: note.title.trim().isEmpty
                        ? AppColors.textLow
                        : AppColors.textHigh,
                  ),
                ),
              ),
              if (note.pinned)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.push_pin_rounded, size: 15, color: accent),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isChecklist)
            _ChecklistPreview(note: note, accent: accent, onToggleItem: onToggleItem)
          else if (note.preview.isNotEmpty)
            Text(
              stripMarkdown(note.preview),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: AppColors.textMid,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 12),
          _CardFooter(
            note: note,
            accent: accent,
            onToggleFavorite: onToggleFavorite,
          ),
        ],
      ),
    );
  }
}

class _ChecklistPreview extends StatelessWidget {
  const _ChecklistPreview({
    required this.note,
    required this.accent,
    this.onToggleItem,
  });

  final Note note;
  final Color accent;
  final void Function(String itemId)? onToggleItem;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<ChecklistItem> shown = note.items
        .where((ChecklistItem i) => i.text.trim().isNotEmpty)
        .take(4)
        .toList();
    final int remaining = note.items
            .where((ChecklistItem i) => i.text.trim().isNotEmpty)
            .length -
        shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ChecklistItem item in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleItem == null ? null : () => onToggleItem!(item.id),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Tick(done: item.done, accent: accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: item.done ? AppColors.textLow : AppColors.textMid,
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textLow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '+$remaining more',
              style: text.labelSmall?.copyWith(color: AppColors.textLow),
            ),
          ),
        if (note.items.isNotEmpty) ...<Widget>[
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: note.progress),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? _) =>
                  LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.done, required this.accent});

  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 15,
      height: 15,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: done ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: done ? accent : AppColors.glassBorderStrong,
          width: 1.4,
        ),
        boxShadow: done
            ? <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 7),
              ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 11, color: Colors.black)
          : null,
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.note,
    required this.accent,
    required this.onToggleFavorite,
  });

  final Note note;
  final Color accent;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                relativeTime(note.updatedAt),
                style: text.labelSmall?.copyWith(color: AppColors.textLow),
              ),
              for (final String tag in note.tags.take(2)) _TagPill(tag: tag),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggleFavorite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(
              note.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: note.favorite ? AppColors.amber : AppColors.textLow,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMid,
              fontSize: 10,
            ),
      ),
    );
  }
}
