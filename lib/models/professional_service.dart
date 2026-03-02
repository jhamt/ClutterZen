import 'package:flutter/foundation.dart';

@immutable
class ProfessionalService {
  const ProfessionalService({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.ratePerHour,
    required this.phone,
    required this.email,
    required this.serviceAreas,
    required this.description,
    required this.experienceYears,
    this.website,
    this.imageUrl,
    this.reviews = const [],
    this.stripeAccountId,
    this.address,
    this.distanceMeters,
    this.mapsUrl,
    this.placeId,
    this.verifiedSource,
    this.isOperational,
    this.userRatingsTotal,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int ratePerHour;
  final String? phone;
  final String? email;
  final List<String> serviceAreas;
  final String description;
  final int experienceYears;
  final String? website;
  final String? imageUrl;
  final List<ServiceReview> reviews;
  final String? stripeAccountId; // Stripe Connect account ID
  final String? address;
  final int? distanceMeters;
  final String? mapsUrl;
  final String? placeId;
  final String? verifiedSource;
  final bool? isOperational;
  final int? userRatingsTotal;

  factory ProfessionalService.fromJson(Map<String, dynamic> json) {
    final rawReviews = json['reviews'] as List<dynamic>? ?? const [];
    return ProfessionalService(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Service',
      specialty: json['specialty']?.toString() ?? 'Home organization',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratePerHour: (json['ratePerHour'] as num?)?.toInt() ?? 0,
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      serviceAreas: (json['serviceAreas'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false),
      description: json['description']?.toString() ?? '',
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      website: json['website']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      reviews: rawReviews
          .whereType<Map<String, dynamic>>()
          .map(ServiceReview.fromJson)
          .toList(growable: false),
      stripeAccountId: json['stripeAccountId']?.toString(),
      address: json['address']?.toString(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      mapsUrl: json['mapsUrl']?.toString(),
      placeId: json['placeId']?.toString(),
      verifiedSource: json['verifiedSource']?.toString(),
      isOperational: json['isOperational'] as bool?,
      userRatingsTotal: (json['userRatingsTotal'] as num?)?.toInt(),
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get formattedRate => '\$$ratePerHour/hr';

  String get ratingDisplay => rating.toStringAsFixed(1);

  String get distanceDisplay {
    final meters = distanceMeters;
    if (meters == null || meters <= 0) return '';
    if (meters < 1000) return '${meters}m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'rating': rating,
        'ratePerHour': ratePerHour,
        'phone': phone,
        'email': email,
        'serviceAreas': serviceAreas,
        'description': description,
        'experienceYears': experienceYears,
        'website': website,
        'imageUrl': imageUrl,
        'reviews': reviews.map((entry) => entry.toJson()).toList(),
        'stripeAccountId': stripeAccountId,
        'address': address,
        'distanceMeters': distanceMeters,
        'mapsUrl': mapsUrl,
        'placeId': placeId,
        'verifiedSource': verifiedSource,
        'isOperational': isOperational,
        'userRatingsTotal': userRatingsTotal,
      };
}

@immutable
class ServiceReview {
  const ServiceReview({
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String reviewerName;
  final double rating;
  final String comment;
  final DateTime date;

  factory ServiceReview.fromJson(Map<String, dynamic> json) => ServiceReview(
        reviewerName: json['reviewerName']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        comment: json['comment']?.toString() ?? '',
        date: DateTime.tryParse(json['date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'reviewerName': reviewerName,
        'rating': rating,
        'comment': comment,
        'date': date.toIso8601String(),
      };
}

@immutable
class NearbyProfessionalsMeta {
  const NearbyProfessionalsMeta({
    this.source,
    this.radiusMeters,
    this.reason,
    this.resolvedLocation,
    this.quality,
  });

  final String? source;
  final int? radiusMeters;
  final String? reason;
  final Map<String, dynamic>? resolvedLocation;
  final Map<String, dynamic>? quality;

  factory NearbyProfessionalsMeta.fromJson(Map<String, dynamic> json) =>
      NearbyProfessionalsMeta(
        source: json['source']?.toString(),
        radiusMeters: (json['radiusMeters'] as num?)?.toInt(),
        reason: json['reason']?.toString(),
        resolvedLocation: json['resolvedLocation'] is Map<String, dynamic>
            ? json['resolvedLocation'] as Map<String, dynamic>
            : null,
        quality: json['quality'] is Map<String, dynamic>
            ? json['quality'] as Map<String, dynamic>
            : null,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'radiusMeters': radiusMeters,
        'reason': reason,
        'resolvedLocation': resolvedLocation,
        'quality': quality,
      };
}

@immutable
class NearbyProfessionalsResponse {
  const NearbyProfessionalsResponse({
    required this.services,
    this.meta,
  });

  final List<ProfessionalService> services;
  final NearbyProfessionalsMeta? meta;
}
