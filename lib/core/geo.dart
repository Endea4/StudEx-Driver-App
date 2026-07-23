import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

/// Reverse-geocodes coordinates into short human-readable place names, with an
/// in-memory cache so the same point isn't looked up repeatedly.
class GeoCache {
  static final Map<String, String> _cache = {};

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  static String coords(double lat, double lng) =>
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

  static Future<String> address(double lat, double lng) async {
    if (lat == 0 && lng == 0) return '-';
    final k = _key(lat, lng);
    final cached = _cache[k];
    if (cached != null) return cached;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          for (final s in [p.name, p.street, p.subLocality, p.locality])
            if (s != null && s.trim().isNotEmpty && s != 'Unnamed Road') s.trim()
        ];
        final seen = <String>{};
        final dedup = parts.where((s) => seen.add(s)).toList();
        final addr = dedup.isNotEmpty ? dedup.take(2).join(', ') : coords(lat, lng);
        _cache[k] = addr;
        return addr;
      }
    } catch (_) {}
    return coords(lat, lng);
  }
}

/// Shows the reverse-geocoded address for a coordinate, falling back to the
/// coordinate string while loading or if geocoding fails.
class AddressText extends StatelessWidget {
  final double lat;
  final double lng;
  final TextStyle? style;
  final int maxLines;

  const AddressText(this.lat, this.lng, {super.key, this.style, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: GeoCache.address(lat, lng),
      builder: (_, snap) => Text(
        snap.data ?? GeoCache.coords(lat, lng),
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
