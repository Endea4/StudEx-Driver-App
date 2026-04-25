class Reputation {
  final double score;
  final int totalReviews;
  final DateTime lastUpdated;
  final List<Review> reviews;

  Reputation({
    required this.score,
    required this.totalReviews,
    required this.lastUpdated,
    this.reviews = const [],
  });

  factory Reputation.fromJson(Map<String, dynamic> json) {
    return Reputation(
      score: (json['score'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      lastUpdated: DateTime.parse(
        json['last_updated'] ?? DateTime.now().toIso8601String(),
      ),
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((r) => Review.fromJson(r))
              .toList() ??
          [],
    );
  }
}

class Review {
  final String raterName;
  final int score;
  final String review;
  final DateTime createdAt;

  Review({
    required this.raterName,
    required this.score,
    required this.review,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      raterName: json['rater_name'] ?? '',
      score: json['score'] ?? 0,
      review: json['review'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
