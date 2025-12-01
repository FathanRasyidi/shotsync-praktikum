import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';

/// Widget untuk view lokasi scene (readonly)
/// Fitur:
/// - Tampilkan lokasi scene dengan marker
/// - Tampilkan lokasi user saat ini (jika ada permission)
/// - Hitung dan tampilkan jarak dari user ke lokasi scene
/// - Readonly - tidak bisa edit lokasi
class MapLocationViewer extends StatelessWidget {
  final LatLng sceneLocation;
  final String? locationName;

  const MapLocationViewer({
    super.key,
    required this.sceneLocation,
    this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      MapLocationViewerController(
        sceneLocation: sceneLocation,
        locationName: locationName,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        title: const Text(
          'Scene Location',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF152033),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Refresh button untuk update current location
          Obx(() => IconButton(
            icon: controller.isLoadingLocation.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00D9FF),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF00D9FF)),
            onPressed: controller.isLoadingLocation.value
                ? null
                : () => controller.getCurrentLocation(),
            tooltip: 'Update my location',
          )),
        ],
      ),
      body: Column(
        children: [
          // Map View
          Expanded(
            child: Obx(() {
              final markers = <Marker>[
                // Scene location marker (red) - without label
                Marker(
                  point: sceneLocation,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ];

              // Add current location marker if available (blue) - without label
              if (controller.currentLocation.value != null) {
                markers.add(
                  Marker(
                    point: controller.currentLocation.value!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Color(0xFF00D9FF),
                      size: 40,
                    ),
                  ),
                );
              }

              return FlutterMap(
                mapController: controller.mapController,
                options: MapOptions(
                  initialCenter: sceneLocation,
                  initialZoom: 15.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.shotsync.app',
                  ),
                  MarkerLayer(markers: markers),
                  
                  // Draw line between user and scene if both available
                  if (controller.currentLocation.value != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            controller.currentLocation.value!,
                            sceneLocation,
                          ],
                          strokeWidth: 3.0,
                          color: const Color(0xFF00D9FF).withOpacity(0.6),
                          borderStrokeWidth: 1.0,
                          borderColor: Colors.white.withOpacity(0.3),
                        ),
                      ],
                    ),
                ],
              );
            }),
          ),

          // Info Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF152033),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF1F2937).withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scene Location Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scene Location',
                            style: TextStyle(
                              color: Color(0xFF8B8B8B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locationName ?? 'Unknown Location',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sceneLocation.latitude.toStringAsFixed(6)}, ${sceneLocation.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFF1F2937), height: 1),
                const SizedBox(height: 16),

                // Current Location & Distance Info
                Obx(() {
                  if (controller.isLoadingLocation.value) {
                    return const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00D9FF),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Getting your location...',
                          style: TextStyle(
                            color: Color(0xFF8B8B8B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }

                  if (controller.locationError.value.isNotEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.locationError.value,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (controller.currentLocation.value == null) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF8B8B8B),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap the location icon to get your current position',
                              style: TextStyle(
                                color: Color(0xFF8B8B8B),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Show current location and distance
                  return Column(
                    children: [
                      // Current Location
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D9FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Color(0xFF00D9FF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Location',
                                  style: TextStyle(
                                    color: Color(0xFF8B8B8B),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${controller.currentLocation.value!.latitude.toStringAsFixed(6)}, ${controller.currentLocation.value!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Distance Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00D9FF).withOpacity(0.2),
                              const Color(0xFF2196F3).withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00D9FF).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.straighten,
                              color: Color(0xFF00D9FF),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Distance to Scene',
                                    style: TextStyle(
                                      color: Color(0xFF8B8B8B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    controller.formattedDistance,
                                    style: const TextStyle(
                                      color: Color(0xFF00D9FF),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Button to fit both markers in view
                            IconButton(
                              icon: const Icon(
                                Icons.my_location,
                                color: Color(0xFF00D9FF),
                              ),
                              onPressed: () => controller.fitBothLocations(),
                              tooltip: 'Fit to view',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapLocationViewerController extends GetxController {
  final LatLng sceneLocation;
  final String? locationName;

  MapLocationViewerController({
    required this.sceneLocation,
    this.locationName,
  });

  final mapController = MapController();
  var currentLocation = Rx<LatLng?>(null);
  var isLoadingLocation = false.obs;
  var locationError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Auto-load current location on init
    getCurrentLocation();
  }

  /// Get current user location
  Future<void> getCurrentLocation() async {
    isLoadingLocation.value = true;
    locationError.value = '';

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationError.value = 'Location services are disabled';
        isLoadingLocation.value = false;
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          locationError.value = 'Location permission denied';
          isLoadingLocation.value = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        locationError.value = 'Location permission permanently denied';
        isLoadingLocation.value = false;
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation.value = LatLng(position.latitude, position.longitude);
      
      // Auto fit both locations in view
      fitBothLocations();
      
    } catch (e) {
      locationError.value = 'Failed to get location. Please check your internet connection.';
    } finally {
      isLoadingLocation.value = false;
    }
  }

  /// Calculate distance between current location and scene location
  /// Returns distance in meters
  double get distanceInMeters {
    if (currentLocation.value == null) return 0.0;

    return Geolocator.distanceBetween(
      currentLocation.value!.latitude,
      currentLocation.value!.longitude,
      sceneLocation.latitude,
      sceneLocation.longitude,
    );
  }

  /// Format distance dengan satuan yang sesuai
  /// < 1 km: tampilkan dalam meter
  /// >= 1 km: tampilkan dalam kilometer
  String get formattedDistance {
    if (currentLocation.value == null) return '-- km';

    final distance = distanceInMeters;

    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Fit map to show both current location and scene location
  void fitBothLocations() {
    if (currentLocation.value == null) return;

    try {
      final bounds = LatLngBounds.fromPoints([
        currentLocation.value!,
        sceneLocation,
      ]);

      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      // Silently fail
    }
  }
}
