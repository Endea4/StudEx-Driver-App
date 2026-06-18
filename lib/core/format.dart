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
