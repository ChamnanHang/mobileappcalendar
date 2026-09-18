/// Pure markdown text helpers, deliberately free of any Flutter import so the
/// model layer can use them without pulling in the widget library.
library;

final RegExp _mdHeading = RegExp(r'^\s*#{1,6}\s*', multiLine: true);
final RegExp _mdQuote = RegExp(r'^\s*>\s?', multiLine: true);
final RegExp _mdTask = RegExp(r'^\s*-\s\[[ xX]\]\s*', multiLine: true);
final RegExp _mdBullet = RegExp(r'^\s*[-*]\s+', multiLine: true);
final RegExp _mdBold = RegExp(r'\*\*([^*\n]+)\*\*');
final RegExp _mdItalic = RegExp(r'\*([^*\n]+)\*');
final RegExp _mdStrike = RegExp(r'~~([^~\n]+)~~');
final RegExp _mdCode = RegExp(r'`([^`\n]+)`');

/// Removes markdown syntax so card previews read as clean prose.
///
/// This runs the same eight passes it always has, but callers should prefer
/// the cached `Note.plainPreview` rather than calling it inside `build`.
String stripMarkdown(String source) {
  if (source.isEmpty) return '';
  return source
      .replaceAll(_mdHeading, '')
      .replaceAll(_mdQuote, '')
      .replaceAll(_mdTask, '')
      .replaceAll(_mdBullet, '• ')
      // `replaceAll` does not expand capture groups — these must be mapped.
      .replaceAllMapped(_mdBold, _group1)
      .replaceAllMapped(_mdItalic, _group1)
      .replaceAllMapped(_mdStrike, _group1)
      .replaceAllMapped(_mdCode, _group1)
      .trim();
}

String _group1(Match match) => match.group(1) ?? '';
