import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A [TextEditingController] that styles markdown **while you type** —
/// live preview in the same field, so bold looks bold as you write it.
///
/// Markers stay visible (dimmed) so every character keeps its offset and the
/// caret never drifts out of sync with the text.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  static final RegExp _inline = RegExp(
    r'\*\*(?<bold>[^*\n]+)\*\*'
    r'|\*(?<italic>[^*\n]+)\*'
    r'|`(?<code>[^`\n]+)`'
    r'|~~(?<strike>[^~\n]+)~~',
  );

  static final RegExp _heading = RegExp(r'^(#{1,3})\s');
  static final RegExp _checkbox = RegExp(r'^(\s*)-\s\[([ xX])\]\s');
  static final RegExp _bullet = RegExp(r'^(\s*)([-*])\s');
  static final RegExp _quote = RegExp(r'^>\s?');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle base = style ?? const TextStyle();
    final String src = text;
    final List<InlineSpan> children = <InlineSpan>[];

    int lineStart = 0;
    while (true) {
      final int newline = src.indexOf('\n', lineStart);
      final int lineEnd = newline == -1 ? src.length : newline;
      children.addAll(_lineSpans(src.substring(lineStart, lineEnd), base));
      if (newline == -1) break;
      children.add(TextSpan(text: '\n', style: base));
      lineStart = newline + 1;
    }

    return TextSpan(style: base, children: children);
  }

  Color get _dimColor =>
      (AppColors.textHigh).withValues(alpha: 0.26);

  List<InlineSpan> _lineSpans(String line, TextStyle base) {
    if (line.isEmpty) return const <InlineSpan>[];

    final TextStyle dim = base.copyWith(color: _dimColor);

    final RegExpMatch? heading = _heading.firstMatch(line);
    if (heading != null) {
      final int level = heading.group(1)!.length;
      final double scale = switch (level) { 1 => 1.55, 2 => 1.3, _ => 1.14 };
      final TextStyle headingStyle = base.copyWith(
        fontSize: (base.fontSize ?? 16) * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.3,
      );
      return <InlineSpan>[
        TextSpan(text: heading.group(0), style: dim.copyWith(fontSize: headingStyle.fontSize)),
        ..._inlineSpans(line.substring(heading.end), headingStyle),
      ];
    }

    final RegExpMatch? checkbox = _checkbox.firstMatch(line);
    if (checkbox != null) {
      final bool done = checkbox.group(2)!.toLowerCase() == 'x';
      final TextStyle bodyStyle = done
          ? base.copyWith(
              color: AppColors.textLow,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textLow,
            )
          : base;
      return <InlineSpan>[
        TextSpan(
          text: checkbox.group(0),
          style: base.copyWith(
            color: done ? AppColors.lime : AppColors.cyan,
            fontWeight: FontWeight.w600,
          ),
        ),
        ..._inlineSpans(line.substring(checkbox.end), bodyStyle),
      ];
    }

    final RegExpMatch? bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      return <InlineSpan>[
        TextSpan(
          text: bullet.group(0),
          style: base.copyWith(
            color: AppColors.violet,
            fontWeight: FontWeight.w700,
          ),
        ),
        ..._inlineSpans(line.substring(bullet.end), base),
      ];
    }

    final RegExpMatch? quote = _quote.firstMatch(line);
    if (quote != null) {
      return <InlineSpan>[
        TextSpan(
          text: quote.group(0),
          style: base.copyWith(color: AppColors.amber, fontWeight: FontWeight.w700),
        ),
        ..._inlineSpans(
          line.substring(quote.end),
          base.copyWith(
            color: AppColors.textMid,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    return _inlineSpans(line, base);
  }

  List<InlineSpan> _inlineSpans(String line, TextStyle base) {
    if (line.isEmpty) return const <InlineSpan>[];

    final TextStyle dim = base.copyWith(color: _dimColor);
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;

    for (final RegExpMatch match in _inline.allMatches(line)) {
      if (match.start > last) {
        spans.add(TextSpan(text: line.substring(last, match.start), style: base));
      }

      final String? bold = match.namedGroup('bold');
      final String? italic = match.namedGroup('italic');
      final String? code = match.namedGroup('code');

      final String content;
      final TextStyle contentStyle;
      final int markerLength;

      if (bold != null) {
        content = bold;
        contentStyle = base.copyWith(fontWeight: FontWeight.w700);
        markerLength = 2;
      } else if (italic != null) {
        content = italic;
        contentStyle = base.copyWith(fontStyle: FontStyle.italic);
        markerLength = 1;
      } else if (code != null) {
        content = code;
        contentStyle = base.copyWith(
          fontFamily: 'monospace',
          fontSize: (base.fontSize ?? 16) * 0.92,
          color: AppColors.cyan,
          backgroundColor: AppColors.cyan.withValues(alpha: 0.10),
        );
        markerLength = 1;
      } else {
        content = match.namedGroup('strike')!;
        contentStyle = base.copyWith(
          color: AppColors.textLow,
          decoration: TextDecoration.lineThrough,
          decorationColor: AppColors.textLow,
        );
        markerLength = 2;
      }

      spans
        ..add(TextSpan(
          text: line.substring(match.start, match.start + markerLength),
          style: dim,
        ))
        ..add(TextSpan(text: content, style: contentStyle))
        ..add(TextSpan(
          text: line.substring(match.end - markerLength, match.end),
          style: dim,
        ));

      last = match.end;
    }

    if (last < line.length) {
      spans.add(TextSpan(text: line.substring(last), style: base));
    }
    return spans;
  }
}

/// Removes markdown syntax so card previews read as clean prose.
String stripMarkdown(String source) {
  return source
      .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*-\s\[[ xX]\]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
      // `replaceAll` does not expand capture groups — these must be mapped.
      .replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), _group1)
      .replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), _group1)
      .replaceAllMapped(RegExp(r'~~([^~\n]+)~~'), _group1)
      .replaceAllMapped(RegExp(r'`([^`\n]+)`'), _group1)
      .trim();
}

String _group1(Match match) => match.group(1) ?? '';

/// Text-editing helpers used by the formatting toolbar.
extension MarkdownEditing on TextEditingController {
  /// Wraps the selection in [token] (or unwraps it when already wrapped).
  void wrapSelection(String token) {
    final TextSelection sel = selection;
    if (!sel.isValid) return;

    final String source = text;
    final int start = sel.start;
    final int end = sel.end;
    final String selected = source.substring(start, end);

    final int tokenLength = token.length;
    final bool alreadyWrapped = start >= tokenLength &&
        end + tokenLength <= source.length &&
        source.substring(start - tokenLength, start) == token &&
        source.substring(end, end + tokenLength) == token;

    if (alreadyWrapped) {
      value = TextEditingValue(
        text: source.substring(0, start - tokenLength) +
            selected +
            source.substring(end + tokenLength),
        selection: TextSelection(
          baseOffset: start - tokenLength,
          extentOffset: end - tokenLength,
        ),
      );
      return;
    }

    final String placeholder = selected.isEmpty ? '' : selected;
    value = TextEditingValue(
      text: source.substring(0, start) +
          token +
          placeholder +
          token +
          source.substring(end),
      selection: TextSelection(
        baseOffset: start + tokenLength,
        extentOffset: start + tokenLength + placeholder.length,
      ),
    );
  }

  /// Adds or removes [prefix] at the start of every selected line.
  void toggleLinePrefix(String prefix) {
    final TextSelection sel = selection;
    if (!sel.isValid) return;

    final String source = text;
    final int lineStart = source.lastIndexOf('\n', sel.start == 0 ? 0 : sel.start - 1) + 1;
    int lineEnd = source.indexOf('\n', sel.end);
    if (lineEnd == -1) lineEnd = source.length;

    final List<String> lines = source.substring(lineStart, lineEnd).split('\n');
    final bool removing = lines.every((String l) => l.startsWith(prefix));

    final List<String> updated = lines.map((String line) {
      if (removing) return line.substring(prefix.length);
      // Swap any existing block marker for the new one.
      final String bare = line.replaceFirst(
        RegExp(r'^(#{1,3}\s|>\s?|-\s\[[ xX]\]\s|[-*]\s)'),
        '',
      );
      return '$prefix$bare';
    }).toList();

    final String replacement = updated.join('\n');
    final int caret = lineStart + replacement.length;

    value = TextEditingValue(
      text: source.substring(0, lineStart) +
          replacement +
          source.substring(lineEnd),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
