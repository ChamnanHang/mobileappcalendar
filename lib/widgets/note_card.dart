import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import 'surface.dart';

/// A single note tile in the home grid.
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
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = NoteColors.at(note.accent);
    final bool isChecklist = note.kind == NoteKind.checklist;

    return TapSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The note's colour, reduced to a dot: enough to tell notes apart
              // at a glance without the card turning into a swatch.
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 7, right: 9),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  note.title.trim().isEmpty ? 'Untitled' : note.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    color: note.title.trim().isEmpty
                        ? p.textTertiary
                        : p.textPrimary,
                  ),
                ),
              ),
              if (note.pinned)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 15,
                    color: p.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isChecklist)
            _ChecklistPreview(
              note: note,
              accent: accent,
              onToggleItem: onToggleItem,
            )
          else if (note.plainPreview.isNotEmpty)
            Text(
              note.plainPreview,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: p.textSecondary,
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
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final List<ChecklistItem> filled = note.items
        .where((ChecklistItem i) => i.text.trim().isNotEmpty)
        .toList(growable: false);
    final List<ChecklistItem> shown = filled.take(4).toList(growable: false);
    final int remaining = filled.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ChecklistItem item in shown)
          Semantics(
            checked: item.done,
            label: item.text.trim(),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleItem == null ? null : () => onToggleItem!(item.id),
              // Vertical padding rather than a margin, so the whole strip is
              // tappable instead of just the 15dp tick.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                          color: item.done ? p.textTertiary : p.textSecondary,
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: p.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '+$remaining more',
              style: text.labelSmall?.copyWith(color: p.textTertiary),
            ),
          ),
        if (note.items.isNotEmpty) ...<Widget>[
          const SizedBox(height: 9),
          Semantics(
            label: '${note.doneCount} of ${note.items.length} items done',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: note.progress),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? _) =>
                    LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: context.palette.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
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
    final AppPalette p = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 15,
      height: 15,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: done ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: done ? accent : p.borderStrong, width: 1.4),
      ),
      // White reads on every note colour; the old black check vanished on
      // the darker ones.
      child: done
          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
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
    final AppPalette p = context.palette;
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
                style: text.labelSmall?.copyWith(color: p.textTertiary),
              ),
              for (final String tag in note.tags.take(2)) _TagPill(tag: tag),
            ],
          ),
        ),
        Semantics(
          button: true,
          toggled: note.favorite,
          label: note.favorite ? 'Unfavourite' : 'Favourite',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleFavorite,
            child: TapTarget(
              size: 40,
              child: Icon(
                note.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: note.favorite ? p.holy : p.textTertiary,
              ),
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
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: p.textSecondary, fontSize: 10),
      ),
    );
  }
}
