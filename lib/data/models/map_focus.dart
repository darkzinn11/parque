class MapFocus {
  final int parkId;
  final String name;
  final double? lat;
  final double? lng;

  const MapFocus({
    required this.parkId,
    required this.name,
    this.lat,
    this.lng,
  });

  bool get hasCoords => lat != null && lng != null;
}
