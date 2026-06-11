String stripMessageMarkdown(String source) {
  if (source.isEmpty) return source;
  var s = source;
  s = s.replaceAll(RegExp(r'```[\s\S]*?```'), '[code]');
  s = s.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
  s = s.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
  s = s.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
  s = s.replaceAllMapped(
    RegExp(r'(^|[^A-Za-z0-9_])[*_]([^\s*_][^*_]*?)[*_]'),
    (m) => '${m.group(1)}${m.group(2)}',
  );
  s = s.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
  s = s.replaceAll('\n', ' ');
  return s.trim();
}
