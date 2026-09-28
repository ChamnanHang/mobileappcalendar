import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'surface.dart';

/// Shows a bottom sheet on a flat surface with a hairline border.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.palette.scrim,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: 8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SurfaceCard(
        radius: AppTheme.radiusLg,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SafeArea(top: false, child: builder(context)),
      ),
    ),
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: p.borderStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- note options

enum EditorAction { tags, folder, archive, delete }

class NoteOptionsSheet extends StatelessWidget {
  const NoteOptionsSheet({super.key, required this.note, required this.accent});

  final Note note;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SheetHandle(),
        SheetTile(
          icon: Icons.sell_outlined,
          label: 'Tags',
          trailing: note.tags.isEmpty
              ? 'none'
              : note.tags.map((String t) => '#$t').join(' '),
          onTap: () => Navigator.of(context).pop(EditorAction.tags),
        ),
        SheetTile(
          icon: Icons.folder_outlined,
          label: 'Folder',
          trailing: note.folder ?? 'none',
          onTap: () => Navigator.of(context).pop(EditorAction.folder),
        ),
        SheetTile(
          icon: note.archived
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
          label: note.archived ? 'Unarchive' : 'Archive',
          onTap: () => Navigator.of(context).pop(EditorAction.archive),
        ),
        SheetTile(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          danger: true,
          onTap: () => Navigator.of(context).pop(EditorAction.delete),
        ),
      ],
    );
  }
}

class SheetTile extends StatelessWidget {
  const SheetTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final Color color = danger ? p.holiday : p.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: danger ? p.holiday : p.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: text.bodyLarge?.copyWith(color: color)),
            ),
            if (trailing != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  trailing!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: p.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- tag editor

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.selected,
    required this.suggestions,
  });

  final List<String> selected;
  final List<String> suggestions;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final List<String> _tags = <String>[...widget.selected];
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final String tag = raw.trim().replaceAll(RegExp(r'^#+'), '').trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _input.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> unused = widget.suggestions
        .where((String t) => !_tags.contains(t))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SheetHandle(),
        Text('Tags', style: text.headlineSmall),
        const SizedBox(height: 14),
        SurfaceCard(
          radius: AppTheme.radiusSm,
          color: p.surfaceMuted,
          borderColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.tag_rounded, size: 17, color: p.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: true,
                  onSubmitted: _add,
                  textInputAction: TextInputAction.done,
                  style: text.bodyMedium,
                  decoration: const InputDecoration(hintText: 'Add a tag…'),
                ),
              ),
              GestureDetector(
                onTap: () => _add(_input.text),
                child: Icon(Icons.add_rounded, size: 20, color: p.accent),
              ),
            ],
          ),
        ),
        if (_tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in _tags)
                _Chip(
                  label: '#$tag',
                  selected: true,
                  trailingIcon: Icons.close_rounded,
                  onTap: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
        ],
        if (unused.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            'Existing',
            style: text.labelSmall?.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in unused)
                _Chip(
                  label: '#$tag',
                  selected: false,
                  onTap: () => setState(() => _tags.add(tag)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Done',
          onTap: () => Navigator.of(context).pop(_tags),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- folder picker

class FolderChoice {
  const FolderChoice(this.name);

  /// `null` clears the folder.
  final String? name;
}

class FolderPickerSheet extends StatefulWidget {
  const FolderPickerSheet({
    super.key,
    required this.current,
    required this.folders,
  });

  final String? current;
  final List<String> folders;

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SheetHandle(),
        Text('Folder', style: text.headlineSmall),
        const SizedBox(height: 14),
        SheetTile(
          icon: Icons.block_rounded,
          label: 'No folder',
          trailing: widget.current == null ? 'current' : null,
          onTap: () => Navigator.of(context).pop(const FolderChoice(null)),
        ),
        for (final String folder in widget.folders)
          SheetTile(
            icon: Icons.folder_rounded,
            label: folder,
            trailing: widget.current == folder ? 'current' : null,
            onTap: () => Navigator.of(context).pop(FolderChoice(folder)),
          ),
        const SizedBox(height: 8),
        SurfaceCard(
          radius: AppTheme.radiusSm,
          color: p.surfaceMuted,
          borderColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.create_new_folder_outlined,
                size: 17,
                color: p.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (String value) {
                    if (value.trim().isEmpty) return;
                    Navigator.of(context).pop(FolderChoice(value.trim()));
                  },
                  textInputAction: TextInputAction.done,
                  style: text.bodyMedium,
                  decoration: const InputDecoration(hintText: 'New folder…'),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_input.text.trim().isEmpty) return;
                  Navigator.of(context).pop(FolderChoice(_input.text.trim()));
                },
                child: Icon(Icons.add_rounded, size: 20, color: p.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- confirm

class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SheetHandle(),
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(message, style: text.bodySmall?.copyWith(color: p.textTertiary)),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: _GhostButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: confirmLabel,
                danger: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- pieces

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 7, trailingIcon == null ? 12 : 8, 7),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? p.accent : p.textSecondary,
                fontSize: 12,
              ),
            ),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 5),
              Icon(trailingIcon, size: 13, color: p.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color fill = danger ? p.holiday : p.accent;

    return Semantics(
      button: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  // White on the red, the accent's own foreground otherwise.
                  color: danger ? Colors.white : p.onAccent,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: p.borderStrong),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: p.textPrimary, fontSize: 15),
        ),
      ),
    );
  }
}
