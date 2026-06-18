import 'package:flutter/foundation.dart';
import '../models/pending_rating.dart';
import '../services/rating_service.dart';
import '../core/errors.dart';

class RatingProvider extends ChangeNotifier {
  final RatingService _service;

  List<PendingRating> _pendingRatings = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<PendingRating> get pendingRatings => _pendingRatings;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  int get pendingCount => _pendingRatings.where((r) => !r.driverResponded).length;

  RatingProvider(this._service);

  Future<void> fetchPendingRatings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _pendingRatings = await _service.getPendingRatings();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitRating(String ratingId, int score, {String? review}) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await _service.submitRating(ratingId, score, review: review);
      await fetchPendingRatings();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
