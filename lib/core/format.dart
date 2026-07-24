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

const _monthsId = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Formats a backend timestamp as e.g. "24 Jul 2026, 08:05".
///
/// Raw ISO strings ("2026-07-24T01:05:00Z") were being shown to drivers; this
/// renders local time in a readable form. Returns '' for unparseable input.
String formatDateTime(dynamic raw) {
  final s = raw?.toString() ?? '';
  if (s.isEmpty) return '';
  final dt = DateTime.tryParse(s)?.toLocal();
  if (dt == null) return s;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_monthsId[dt.month - 1]} ${dt.year}, $hh:$mm';
}
