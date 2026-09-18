import 'dart:math';

import '../utils/markdown_text.dart';

/// A note is either free-form (markdown) text or a checklist.
enum NoteKind { text, checklist }

/// One generator for the process — constructing a `Random` per call is both
/// slower and a weaker source of entropy than reusing one.
final Random _rnd = Random();

String newId() {
  final int stamp = DateTime.now().microsecondsSinceEpoch;
  final int salt = _rnd.nextInt(0x7fffffff);
  return '${stamp.toRadixString(36)}${salt.toRadixString(36)}';
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.done = false,
  });

  final String id;
  final String text;
  final bool done;

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(id: id, text: text ?? this.text, done: done ?? this.done);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'done': done,
  };

  static ChecklistItem fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] as String? ?? newId(),
    text: json['text'] as String? ?? '',
    done: json['done'] as bool? ?? false,
  );
}

class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.items = const <ChecklistItem>[],
    this.tags = const <String>[],
    this.folder,
    this.accent = 0,
    this.pinned = false,
    this.favorite = false,
    this.archived = false,
  });

  factory Note.empty({
    NoteKind kind = NoteKind.text,
    String? folder,
    int accent = 0,
  }) {
    final DateTime now = DateTime.now();
    return Note(
      id: newId(),
      title: '',
      body: '',
      kind: kind,
      createdAt: now,
      updatedAt: now,
      folder: folder,
      accent: accent,
      items: kind == NoteKind.checklist
          ? <ChecklistItem>[ChecklistItem(id: newId(), text: '')]
          : const <ChecklistItem>[],
    );
  }

  final String id;
  final String title;
  final String body;
  final NoteKind kind;
  final List<ChecklistItem> items;
  final List<String> tags;
  final String? folder;
  final int accent;
  final bool pinned;
  final bool favorite;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      items.every((ChecklistItem i) => i.text.trim().isEmpty);

  int get doneCount => items.where((ChecklistItem i) => i.done).length;

  double get progress => items.isEmpty ? 0 : doneCount / items.length;

  // A note is immutable, so anything derived from it can be computed once and
  // kept. `copyWith` returns a fresh instance, which drops these caches with
  // it — there is nothing to invalidate by hand.
  String? _preview;
  String? _plainPreview;
  String? _haystack;

  /// Raw preview source: the body, or the checklist items joined up.
  String get preview => _preview ??= _buildPreview();

  String _buildPreview() {
    if (kind == NoteKind.checklist) {
      return items
          .where((ChecklistItem i) => i.text.trim().isNotEmpty)
          .map((ChecklistItem i) => i.text.trim())
          .join('  •  ');
    }
    return body.trim();
  }

  /// [preview] with markdown syntax removed, ready to render on a card.
  ///
  /// Cached because stripping runs eight regex passes, and the grid used to
  /// redo that for every visible card on every rebuild.
  String get plainPreview => _plainPreview ??= stripMarkdown(preview);

  /// Everything this note can be searched by, folded to lower case once.
  String get _searchHaystack => _haystack ??= <String>[
    title,
    body,
    ...tags,
    ...items.map((ChecklistItem i) => i.text),
  ].join('\n').toLowerCase();

  /// Whether this note matches an already-lower-cased [query].
  bool matches(String query) =>
      query.isEmpty || _searchHaystack.contains(query);

  Note copyWith({
    String? title,
    String? body,
    NoteKind? kind,
    List<ChecklistItem>? items,
    List<String>? tags,
    Object? folder = _sentinel,
    int? accent,
    bool? pinned,
    bool? favorite,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      items: items ?? this.items,
      tags: tags ?? this.tags,
      folder: folder == _sentinel ? this.folder : folder as String?,
      accent: accent ?? this.accent,
      pinned: pinned ?? this.pinned,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'kind': kind.name,
    'items': items.map((ChecklistItem i) => i.toJson()).toList(),
    'tags': tags,
    'folder': folder,
    'accent': accent,
    'pinned': pinned,
    'favorite': favorite,
    'archived': archived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Note fromJson(Map<String, dynamic> json) {
    final DateTime now = DateTime.now();
    return Note(
      id: json['id'] as String? ?? newId(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: NoteKind.values.firstWhere(
        (NoteKind k) => k.name == json['kind'],
        orElse: () => NoteKind.text,
      ),
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ChecklistItem.fromJson)
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      folder: json['folder'] as String?,
      accent: json['accent'] as int? ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      favorite: json['favorite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
