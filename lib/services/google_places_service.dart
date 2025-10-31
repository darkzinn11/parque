// lib/services/google_places_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Pegamos a API Key via --dart-define=GOOGLE_PLACES_API_KEY=xxxx
const String kGooglePlacesApiKey =
    String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');

class GooglePlacesService {
  final String apiKey;
  GooglePlacesService({String? apiKey}) : apiKey = apiKey ?? kGooglePlacesApiKey;

  Future<PlaceDetails?> getDetails(String placeId) async {
    if (apiKey.isEmpty) return null;

    final fields = [
      'rating',
      'user_ratings_total',
      'geometry/location',
      'photos',
      'reviews', // alguns ambientes aceitam 'reviews' (plural); manter assim
      'editorial_summary',
    ].join(',');

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&language=pt-BR'
      '&fields=$fields'
      '&key=$apiKey',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = json.decode(res.body) as Map<String, dynamic>;
    if ((data['status'] ?? '') != 'OK') return null;

    final r = data['result'] as Map<String, dynamic>;

    final rating = (r['rating'] as num?)?.toDouble();
    final total = r['user_ratings_total'] as int?;
    final lat = (r['geometry']?['location']?['lat'] as num?)?.toDouble();
    final lng = (r['geometry']?['location']?['lng'] as num?)?.toDouble();

    final photos = <String>[];
    if (r['photos'] is List) {
      for (final p in (r['photos'] as List)) {
        final ref = (p as Map?)?['photo_reference']?.toString();
        if (ref != null && ref.isNotEmpty) photos.add(ref);
      }
    }

    final reviews = <PlaceReview>[];
    if (r['reviews'] is List) {
      for (final rv in (r['reviews'] as List)) {
        final m = rv as Map<String, dynamic>;
        reviews.add(
          PlaceReview(
            authorName: m['author_name']?.toString() ?? 'Visitante',
            rating: (m['rating'] as num?)?.toDouble(),
            text: m['text']?.toString() ?? '',
            relativeTimeDescription: m['relative_time_description']?.toString(),
            profilePhotoUrl: m['profile_photo_url']?.toString(),
          ),
        );
      }
    }

    return PlaceDetails(
      rating: rating,
      userRatingsTotal: total,
      lat: lat,
      lng: lng,
      photoRefs: photos,
      reviews: reviews,
    );
  }

  /// Constrói URL de foto do Places a partir do `photo_reference`.
  String buildPhotoUrl(String photoReference, {int maxWidth = 800}) {
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=$apiKey';
  }
}

class PlaceDetails {
  final double? rating;
  final int? userRatingsTotal;
  final double? lat;
  final double? lng;
  final List<String> photoRefs;
  final List<PlaceReview> reviews;

  const PlaceDetails({
    this.rating,
    this.userRatingsTotal,
    this.lat,
    this.lng,
    this.photoRefs = const [],
    this.reviews = const [],
  });
}

class PlaceReview {
  final String authorName;
  final double? rating;
  final String text;
  final String? relativeTimeDescription;
  final String? profilePhotoUrl;

  const PlaceReview({
    required this.authorName,
    this.rating,
    required this.text,
    this.relativeTimeDescription,
    this.profilePhotoUrl,
  });
}
