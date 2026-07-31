import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/notes_controller.dart';
import '../data/notes_scope.dart';
import '../models/note.dart';
import '../theme/app_colors.dart';
import '../utils/markdown_controller.dart';
import '../utils/relative_time.dart';
import '../widgets/aurora_background.dart';
import '../widgets/format_toolbar.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';

/// Full-screen note editor. Owns a local copy of the note and commits it back
/// to [NotesController] on a short debounce, so typing never rebuilds the list.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.initial,
    this.autofocusBody = false,
  });

  final Note initial;
  final bool autofocusBody;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Note _note = widget.initial;
  late final TextEditingController _titleController = TextEditingController(
    text: _note.title,
  );
  late final MarkdownEditingController _bodyController =
      MarkdownEditingController(text: _note.body);
  final FocusNode _bodyFocus = FocusNode();

  final Map<String, TextEditingController> _itemControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _itemFocus = <String, FocusNode>{};

  NotesController? _notes;
  Timer? _debounce;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notes ??= NotesScope.read(context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) _notes?.upsert(_note);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    for (final TextEditingController c in _itemControllers.values) {
      c.dispose();
    }
    for (final FocusNode f in _itemFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ state

  /// Updates the local note and schedules a commit.
  void _update(Note next, {bool immediate = false}) {
    setState(() {
      _note = next.copyWith(updatedAt: DateTime.now());
      _dirty = true;
    });
    _debounce?.cancel();
    if (immediate) {
      _notes?.upsert(_note);
      _dirty = false;
    } else {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _notes?.upsert(_note);
        _dirty = false;
      });
    }
  }

  TextEditingController _controllerFor(ChecklistItem item) {
    return _itemControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.text),
    );
  }

  FocusNode _focusFor(ChecklistItem item) {
    return _itemFocus.putIfAbsent(item.id, FocusNode.new);
  }

  void _setItems(List<ChecklistItem> items) =>
      _update(_note.copyWith(items: items));

  void _addItem({int? after}) {
    final ChecklistItem item = ChecklistItem(id: newId(), text: '');
    final List<ChecklistItem> items = <ChecklistItem>[..._note.items];
    final int index = after == null ? items.length : after + 1;
    items.insert(index, item);
    _setItems(items);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFor(item).requestFocus();
    });
  }

  void _removeItem(ChecklistItem item) {
    _setItems(_note.items.where((ChecklistItem i) => i.id != item.id).toList());
    _itemControllers.remove(item.id)?.dispose();
    _itemFocus.remove(item.id)?.dispose();
  }

  void _toggleItem(ChecklistItem item) {
    HapticFeedback.selectionClick();
    _setItems(
      _note.items
          .map(
            (ChecklistItem i) =>
                i.id == item.id ? i.copyWith(done: !i.done) : i,
          )
          .toList(),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _openMore() async {
    final Color accent = AppColors.accentAt(_note.accent);
    final EditorAction? action = await showGlassSheet<EditorAction>(
      context: context,
      builder: (BuildContext context) =>
          NoteOptionsSheet(note: _note, accent: accent),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case EditorAction.tags:
        await _editTags();
      case EditorAction.folder:
        await _pickFolder();
      case EditorAction.archive:
        _update(
          _note.copyWith(archived: !_note.archived, pinned: false),
          immediate: true,
        );
        if (mounted) Navigator.of(context).pop();
      case EditorAction.delete:
        await _confirmDelete();
    }
  }

  Future<void> _editTags() async {
    final List<String>? tags = await showGlassSheet<List<String>>(
      context: context,
      builder: (BuildContext context) => TagEditorSheet(
        selected: _note.tags,
        suggestions: _notes?.allTags ?? const <String>[],
      ),
    );
    if (tags != null) _update(_note.copyWith(tags: tags), immediate: true);
  }

  Future<void> _pickFolder() async {
    final FolderChoice? choice = await showGlassSheet<FolderChoice>(
      context: context,
      builder: (BuildContext context) => FolderPickerSheet(
        current: _note.folder,
        folders: _notes?.allFolders ?? const <String>[],
      ),
    );
    if (choice != null) {
      _update(_note.copyWith(folder: choice.name), immediate: true);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showGlassSheet<bool>(
      context: context,
      builder: (BuildContext context) => const ConfirmSheet(
        title: 'Delete this note?',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true || !mounted) return;

    _debounce?.cancel();
    _dirty = false;
    _notes?.delete(_note.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _close() {
    _debounce?.cancel();
    if (_dirty) {
      _notes?.upsert(_note);
      _dirty = false;
    }
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accentAt(_note.accent);
    final bool isChecklist = _note.kind == NoteKind.checklist;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _EditorHeader(
                note: _note,
                accent: accent,
                onBack: _close,
                onTogglePin: () => _update(
                  _note.copyWith(pinned: !_note.pinned),
                  immediate: true,
                ),
                onToggleFavorite: () => _update(
                  _note.copyWith(favorite: !_note.favorite),
                  immediate: true,
                ),
                onMore: _openMore,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: <Widget>[
                    _TitleField(
                      controller: _titleController,
                      autofocus: !widget.autofocusBody && _note.title.isEmpty,
                      onChanged: (String value) =>
                          _update(_note.copyWith(title: value)),
                      onSubmitted: () {
                        if (isChecklist) {
                          if (_note.items.isNotEmpty) {
                            _focusFor(_note.items.first).requestFocus();
                          }
                        } else {
                          _bodyFocus.requestFocus();
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    _MetaRow(note: _note, accent: accent),
                    const SizedBox(height: 18),
                    if (isChecklist)
                      _ChecklistEditor(
                        note: _note,
                        accent: accent,
                        controllerFor: _controllerFor,
                        focusFor: _focusFor,
                        onToggle: _toggleItem,
                        onTextChanged: (ChecklistItem item, String value) {
                          _setItems(
                            _note.items
                                .map(
                                  (ChecklistItem i) => i.id == item.id
                                      ? i.copyWith(text: value)
                                      : i,
                                )
                                .toList(),
                          );
                        },
                        onSubmit: (ChecklistItem item) => _addItem(
                          after: _note.items.indexWhere(
                            (ChecklistItem i) => i.id == item.id,
                          ),
                        ),
                        onRemove: _removeItem,
                        onAdd: _addItem,
                      )
                    else
                      _BodyField(
                        controller: _bodyController,
                        focusNode: _bodyFocus,
                        autofocus: widget.autofocusBody,
                        onChanged: (String value) =>
                            _update(_note.copyWith(body: value)),
                      ),
                    const SizedBox(height: 22),
                    _TagsRow(
                      tags: _note.tags,
                      accent: accent,
                      onEdit: _editTags,
                      onRemove: (String tag) => _update(
                        _note.copyWith(
                          tags: _note.tags
                              .where((String t) => t != tag)
                              .toList(),
                        ),
                        immediate: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AccentPicker(
                      selected: _note.accent,
                      onSelect: (int index) => _update(
                        _note.copyWith(accent: index),
                        immediate: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isChecklist)
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    keyboard > 0 ? 10 : 16,
                  ),
                  child: FormatToolbar(controller: _bodyController),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sub-widgets

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.note,
    required this.accent,
    required this.onBack,
    required this.onTogglePin,
    required this.onToggleFavorite,
    required this.onMore,
  });

  final Note note;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: <Widget>[
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: onBack,
          ),
          const Spacer(),
          if (note.kind == NoteKind.checklist && note.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '${note.doneCount}/${note.items.length}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: accent, fontSize: 12),
              ),
            ),
          GlassIconButton(
            icon: note.pinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
            tooltip: note.pinned ? 'Unpin' : 'Pin',
            active: note.pinned,
            activeColor: accent,
            onTap: onTogglePin,
          ),
          const SizedBox(width: 8),
          GlassIconButton(
            icon: note.favorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            tooltip: note.favorite ? 'Unfavourite' : 'Favourite',
            active: note.favorite,
            activeColor: AppColors.amber,
            onTap: onToggleFavorite,
          ),
          const SizedBox(width: 8),
          GlassIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More',
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      maxLines: null,
      style: Theme.of(context).textTheme.displaySmall,
      decoration: const InputDecoration(hintText: 'Title'),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.note, required this.accent});

  final Note note;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? folder = note.folder;

    return Row(
      children: <Widget>[
        Text(
          'Edited ${relativeTime(note.updatedAt)}',
          style: text.labelSmall?.copyWith(color: AppColors.textLow),
        ),
        if (folder != null && folder.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          Icon(
            Icons.folder_rounded,
            size: 12,
            color: accent.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            folder,
            style: text.labelSmall?.copyWith(color: AppColors.textMid),
          ),
        ],
      ],
    );
  }
}

class _BodyField extends StatelessWidget {
  const _BodyField({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.onChanged,
  });

  final MarkdownEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      maxLines: null,
      minLines: 12,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      decoration: const InputDecoration(
        hintText: 'Start writing…  **bold**, *italic*, # heading, - [ ] task',
      ),
    );
  }
}

class _ChecklistEditor extends StatelessWidget {
  const _ChecklistEditor({
    required this.note,
    required this.accent,
    required this.controllerFor,
    required this.focusFor,
    required this.onToggle,
    required this.onTextChanged,
    required this.onSubmit,
    required this.onRemove,
    required this.onAdd,
  });

  final Note note;
  final Color accent;
  final TextEditingController Function(ChecklistItem) controllerFor;
  final FocusNode Function(ChecklistItem) focusFor;
  final void Function(ChecklistItem) onToggle;
  final void Function(ChecklistItem, String) onTextChanged;
  final void Function(ChecklistItem) onSubmit;
  final void Function(ChecklistItem) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (note.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: note.progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? _) =>
                    LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
              ),
            ),
          ),
        for (final ChecklistItem item in note.items)
          Padding(
            key: ValueKey<String>(item.id),
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onToggle(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    child: _BigTick(done: item.done, accent: accent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controllerFor(item),
                    focusNode: focusFor(item),
                    onChanged: (String value) => onTextChanged(item, value),
                    onSubmitted: (_) => onSubmit(item),
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    style: text.bodyLarge?.copyWith(
                      color: item.done ? AppColors.textLow : AppColors.textHigh,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textLow,
                    ),
                    decoration: const InputDecoration(hintText: 'List item'),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onRemove(item),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textLow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
          child: Row(
            children: <Widget>[
              Icon(Icons.add_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Text('Add item', style: text.bodyMedium?.copyWith(color: accent)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigTick extends StatelessWidget {
  const _BigTick({required this.done, required this.accent});

  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: done ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: done ? accent : AppColors.glassBorderStrong,
          width: 1.6,
        ),
        boxShadow: done
            ? <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 9),
              ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
          : null,
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({
    required this.tags,
    required this.accent,
    required this.onEdit,
    required this.onRemove,
  });

  final List<String> tags;
  final Color accent;
  final VoidCallback onEdit;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final String tag in tags)
          GestureDetector(
            onTap: () => onRemove(tag),
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 6, 8, 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.32)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '#$tag',
                    style: text.labelSmall?.copyWith(
                      color: AppColors.textHigh,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.close_rounded, size: 13, color: AppColors.textMid),
                ],
              ),
            ),
          ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.add_rounded, size: 14, color: AppColors.textMid),
                const SizedBox(width: 4),
                Text(
                  'Tag',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textMid,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          'Colour',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textLow),
        ),
        const SizedBox(width: 14),
        for (int i = 0; i < AppColors.accents.length; i++)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 10),
              width: selected == i ? 26 : 20,
              height: selected == i ? 26 : 20,
              decoration: BoxDecoration(
                color: AppColors.accents[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == i
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accents[i].withValues(
                      alpha: selected == i ? 0.65 : 0.3,
                    ),
                    blurRadius: selected == i ? 12 : 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
