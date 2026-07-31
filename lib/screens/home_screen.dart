import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/notes_controller.dart';
import '../data/notes_scope.dart';
import '../models/note.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/note_card.dart';
import '../widgets/sheets.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openNote(Note note, {bool autofocusBody = false}) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) =>
            EditorScreen(initial: note, autofocusBody: autofocusBody),
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondary,
              Widget child,
            ) {
              final Animation<double> curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
      ),
    );
  }

  Future<void> _create(NoteKind kind) async {
    HapticFeedback.mediumImpact();
    final NotesController notes = NotesScope.read(context);
    await _openNote(notes.draft(kind: kind), autofocusBody: false);
  }

  Future<void> _quickActions(Note note) async {
    HapticFeedback.mediumImpact();
    final NotesController notes = NotesScope.read(context);
    final EditorAction? action = await showGlassSheet<EditorAction>(
      context: context,
      builder: (BuildContext context) =>
          NoteOptionsSheet(note: note, accent: AppColors.accentAt(note.accent)),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case EditorAction.tags:
        final List<String>? tags = await showGlassSheet<List<String>>(
          context: context,
          builder: (BuildContext context) =>
              TagEditorSheet(selected: note.tags, suggestions: notes.allTags),
        );
        if (tags != null) notes.upsert(note.copyWith(tags: tags));
      case EditorAction.folder:
        final FolderChoice? choice = await showGlassSheet<FolderChoice>(
          context: context,
          builder: (BuildContext context) => FolderPickerSheet(
            current: note.folder,
            folders: notes.allFolders,
          ),
        );
        if (choice != null) notes.setFolderOf(note.id, choice.name);
      case EditorAction.archive:
        notes.setArchived(note.id, !note.archived);
      case EditorAction.delete:
        final bool? ok = await showGlassSheet<bool>(
          context: context,
          builder: (BuildContext context) => const ConfirmSheet(
            title: 'Delete this note?',
            message: 'This cannot be undone.',
            confirmLabel: 'Delete',
          ),
        );
        if (ok == true) _deleteWithUndo(note);
    }
  }

  void _archiveWithUndo(Note note) {
    final NotesController notes = NotesScope.read(context);
    notes.setArchived(note.id, true);
    _snack('Archived', onUndo: () => notes.setArchived(note.id, false));
  }

  void _deleteWithUndo(Note note) {
    final NotesController notes = NotesScope.read(context);
    notes.delete(note.id);
    _snack('Note deleted', onUndo: () => notes.restore(note));
  }

  void _snack(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: onUndo == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  textColor: AppColors.cyan,
                  onPressed: onUndo,
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = NotesScope.of(context);
    final List<Note> visible = notes.visibleNotes;
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width < 620 ? 2 : (width < 1000 ? 3 : 4);

    final bool grouping = notes.query.trim().isEmpty;
    final List<Note> pinned = grouping
        ? visible.where((Note n) => n.pinned).toList()
        : <Note>[];
    final List<Note> rest = grouping
        ? visible.where((Note n) => !n.pinned).toList()
        : visible;

    // The aurora background lives in AppShell so it survives tab switches.
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _ExpandingFab(
        onNewNote: () => _create(NoteKind.text),
        onNewChecklist: () => _create(NoteKind.checklist),
      ),
      body: SafeArea(
        child: notes.loading
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            : CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _Header(count: visible.length, filter: notes.filter),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                      child: _SearchField(
                        controller: _search,
                        onChanged: notes.search,
                        onClear: () {
                          _search.clear();
                          notes.search('');
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _FilterBar(notes: notes)),
                  if (notes.allFolders.isNotEmpty)
                    SliverToBoxAdapter(child: _FolderBar(notes: notes)),
                  if (notes.allTags.isNotEmpty)
                    SliverToBoxAdapter(child: _TagBar(notes: notes)),
                  if (visible.isEmpty)
                    SliverToBoxAdapter(child: _emptyFor(notes))
                  else ...<Widget>[
                    if (pinned.isNotEmpty) ...<Widget>[
                      const SliverToBoxAdapter(
                        child: _SectionLabel(
                          label: 'Pinned',
                          icon: Icons.push_pin_rounded,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _MasonryGrid(
                          notes: pinned,
                          columns: columns,
                          buildCard: _card,
                        ),
                      ),
                    ],
                    if (rest.isNotEmpty) ...<Widget>[
                      if (pinned.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: _SectionLabel(label: 'Notes'),
                        ),
                      SliverToBoxAdapter(
                        child: _MasonryGrid(
                          notes: rest,
                          columns: columns,
                          buildCard: _card,
                        ),
                      ),
                    ],
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
      ),
    );
  }

  Widget _emptyFor(NotesController notes) {
    if (notes.query.trim().isNotEmpty ||
        notes.activeTag != null ||
        notes.activeFolder != null) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        message: 'Try a different word, or clear the filters above.',
        accent: AppColors.cyan,
      );
    }
    return switch (notes.filter) {
      NoteFilter.archive => const EmptyState(
        icon: Icons.archive_outlined,
        title: 'Archive is empty',
        message: 'Swipe a note sideways to tuck it away here.',
        accent: AppColors.blue,
      ),
      NoteFilter.favorites => const EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'No favourites yet',
        message: 'Tap the star on a note to keep it close.',
        accent: AppColors.amber,
      ),
      NoteFilter.all => const EmptyState(
        icon: Icons.edit_note_rounded,
        title: 'Nothing noted yet',
        message: 'Tap the + button to write your first note.',
      ),
    };
  }

  Widget _card(Note note) {
    final NotesController notes = NotesScope.read(context);
    return Dismissible(
      key: ValueKey<String>(note.id),
      direction: note.archived
          ? DismissDirection.startToEnd
          : DismissDirection.endToStart,
      background: _SwipeBackground(archived: note.archived),
      secondaryBackground: _SwipeBackground(archived: note.archived),
      onDismissed: (_) {
        if (note.archived) {
          notes.setArchived(note.id, false);
          _snack('Restored');
        } else {
          _archiveWithUndo(note);
        }
      },
      child: NoteCard(
        note: note,
        onTap: () => _openNote(note),
        onLongPress: () => _quickActions(note),
        onTogglePin: () => notes.togglePin(note.id),
        onToggleFavorite: () {
          HapticFeedback.selectionClick();
          notes.toggleFavorite(note.id);
        },
        onToggleItem: (String itemId) =>
            notes.toggleChecklistItem(note.id, itemId),
      ),
    );
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.filter});

  final int count;
  final NoteFilter filter;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String label = switch (filter) {
      NoteFilter.all => count == 1 ? '1 note' : '$count notes',
      NoteFilter.favorites => '$count favourite${count == 1 ? '' : 's'}',
      NoteFilter.archive => '$count archived',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ShaderMask(
                  shaderCallback: (Rect bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Noted',
                    style: text.headlineMedium?.copyWith(color: Colors.white),
                  ),
                ),
                Text(
                  label,
                  style: text.labelSmall?.copyWith(color: AppColors.textLow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 16,
      blur: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, size: 19, color: AppColors.textLow),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'Search notes, tags, tasks…',
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue value, Widget? _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: AppColors.textMid,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.notes});

  final NotesController notes;

  @override
  Widget build(BuildContext context) {
    // Scrolls horizontally so the pills never overflow on narrow phones.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Row(
        children: <Widget>[
          _FilterPill(
            label: 'All',
            icon: Icons.grid_view_rounded,
            selected: notes.filter == NoteFilter.all,
            accent: AppColors.violet,
            onTap: () => notes.setFilter(NoteFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Favourites',
            icon: Icons.star_rounded,
            count: notes.favoriteCount,
            selected: notes.filter == NoteFilter.favorites,
            accent: AppColors.amber,
            onTap: () => notes.setFilter(NoteFilter.favorites),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Archive',
            icon: Icons.archive_rounded,
            count: notes.archivedCount,
            selected: notes.filter == NoteFilter.archive,
            accent: AppColors.blue,
            onTap: () => notes.setFilter(NoteFilter.archive),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.45)
                : AppColors.glassBorder,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: selected ? accent : AppColors.textLow),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.textHigh : AppColors.textMid,
                fontSize: 12,
              ),
            ),
            if (count != null && count! > 0) ...<Widget>[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? accent : AppColors.textLow,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({required this.notes});

  final NotesController notes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        children: <Widget>[
          for (final String folder in notes.allFolders)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SmallChip(
                label: folder,
                icon: Icons.folder_rounded,
                trailing: '${notes.notesInFolder(folder)}',
                selected: notes.activeFolder == folder,
                onTap: () => notes.selectFolder(folder),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({required this.notes});

  final NotesController notes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        children: <Widget>[
          for (final String tag in notes.allTags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SmallChip(
                label: '#$tag',
                selected: notes.activeTag == tag,
                onTap: () => notes.toggleTagFilter(tag),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.cyan.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.cyan.withValues(alpha: 0.45)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 13,
                color: selected ? AppColors.cyan : AppColors.textLow,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.textHigh : AppColors.textMid,
                fontSize: 12,
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                trailing!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textLow,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 2),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: AppColors.textLow),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textLow,
              letterSpacing: 1.2,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple masonry: notes are dealt round-robin into fixed columns, so cards of
/// different heights stagger naturally without a third-party grid.
class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({
    required this.notes,
    required this.columns,
    required this.buildCard,
  });

  final List<Note> notes;
  final int columns;
  final Widget Function(Note) buildCard;

  @override
  Widget build(BuildContext context) {
    final List<List<Note>> buckets = List<List<Note>>.generate(
      columns,
      (_) => <Note>[],
    );
    for (int i = 0; i < notes.length; i++) {
      buckets[i % columns].add(notes[i]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int c = 0; c < columns; c++)
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final Note note in buckets[c])
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: buildCard(note),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.archived});

  final bool archived;

  @override
  Widget build(BuildContext context) {
    final Color color = archived ? AppColors.lime : AppColors.blue;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(
        archived ? Icons.unarchive_rounded : Icons.archive_rounded,
        color: color,
        size: 22,
      ),
    );
  }
}

// --------------------------------------------------------------------- fab

class _ExpandingFab extends StatefulWidget {
  const _ExpandingFab({required this.onNewNote, required this.onNewChecklist});

  final VoidCallback onNewNote;
  final VoidCallback onNewChecklist;

  @override
  State<_ExpandingFab> createState() => _ExpandingFabState();
}

class _ExpandingFabState extends State<_ExpandingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _pick(VoidCallback action) {
    _controller.reverse();
    setState(() => _open = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _MiniAction(
          animation: _curve,
          index: 1,
          icon: Icons.checklist_rounded,
          label: 'Checklist',
          accent: AppColors.lime,
          onTap: () => _pick(widget.onNewChecklist),
        ),
        _MiniAction(
          animation: _curve,
          index: 0,
          icon: Icons.notes_rounded,
          label: 'Note',
          accent: AppColors.cyan,
          onTap: () => _pick(widget.onNewNote),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _open ? 0.375 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: const Icon(
                Icons.add_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.animation,
    required this.index,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final Animation<double> animation;
  final int index;
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: Transform.scale(
              scale: 0.85 + 0.15 * t,
              alignment: Alignment.centerRight,
              child: IgnorePointer(ignoring: t < 0.6, child: child),
            ),
          ),
        );
      },
      child: Padding(
        // Kept compact: the Scaffold's FAB slot is height-constrained, and a
        // taller stack overflows it once both actions are expanded.
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: onTap,
          child: GlassPanel(
            radius: 16,
            blur: 20,
            fill: AppColors.glassFillStrong,
            glow: accent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 17, color: accent),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
