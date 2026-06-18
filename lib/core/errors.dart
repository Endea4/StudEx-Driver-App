String friendlyError(Object e) {
  final msg = e.toString();
  // Network errors
  if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('Connection reset')) {
    return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
  }
  if (msg.contains('timeout') || msg.contains('Timeout')) {
    return 'Koneksi timeout. Silakan coba lagi.';
  }
  if (msg.contains('ClientException')) {
    return 'Koneksi terputus. Silakan coba lagi.';
  }
  // Auth errors
  if (msg.contains('401') || msg.contains('unauthorized') || msg.contains('invalid credentials')) {
    return 'Nomor atau password salah.';
  }
  if (msg.contains('403') || msg.contains('forbidden')) {
    return 'Anda tidak memiliki akses.';
  }
  // Server errors
  if (msg.contains('500') || msg.contains('internal server error')) {
    return 'Server sedang bermasalah. Silakan coba lagi nanti.';
  }
  if (msg.contains('503') || msg.contains('service unavailable')) {
    return 'Layanan sedang maintenance. Silakan coba lagi nanti.';
  }
  // Data errors
  if (msg.contains('FormatException') || msg.contains('JSON')) {
    return 'Terjadi kesalahan data. Silakan coba lagi.';
  }
  // Generic fallback
  if (msg.contains('Failed to')) {
    return msg.replaceAll('Exception: ', '');
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}
