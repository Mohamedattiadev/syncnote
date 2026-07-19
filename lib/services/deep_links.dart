// Parse syncnote:// URIs. Handled by main app on startup / when brought to
// foreground via platform integration (not wired platform-side yet).

class DeepLink {
  final String path; // 'note', 'chat', 'tag'
  final String? value;
  const DeepLink(this.path, this.value);

  static DeepLink? parse(String uri) {
    try {
      final u = Uri.parse(uri);
      if (u.scheme != 'syncnote') return null;
      final seg = u.pathSegments;
      if (u.host == 'note' || (seg.isNotEmpty && seg.first == 'note')) {
        return DeepLink('note', seg.length >= 2 ? seg[1] : (u.host == 'note' && seg.isNotEmpty ? seg.first : null));
      }
      if (u.host == 'tag' || (seg.isNotEmpty && seg.first == 'tag')) {
        return DeepLink('tag', seg.length >= 2 ? seg[1] : null);
      }
      if (u.host == 'chat' || (seg.isNotEmpty && seg.first == 'chat')) {
        return DeepLink('chat', null);
      }
    } catch (_) {}
    return null;
  }
}
