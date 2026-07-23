/// Turns an opaque id/UUID into a short, human-readable code for display.
/// Returns the last 6 characters uppercased, prefixed with '#'
/// (e.g. "d520cafb-62ed-4139-a14e-9ab847292380" -> "#292380").
/// Returns '' for an empty/blank id.
String shortCode(dynamic id) {
  final s = (id ?? '').toString().trim();
  if (s.isEmpty) return '';
  final tail = s.length <= 6 ? s : s.substring(s.length - 6);
  return '#${tail.toUpperCase()}';
}

String formatMoney(dynamic amount) {
  final num value = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
  // Integer amount - use dot separator: 13.000
  final str = value.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
    buf.write(str[i]);
  }
  return buf.toString();
}
