import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

/// Widget map picker buat pilih lokasi
/// Fitur:
/// - Search lokasi pake Nominatim OSM
/// - Drag marker buat pindahin lokasi
/// - Detect lokasi sekarang (current location)
/// - Return lat, lng, dan nama tempat
class MapLocationPicker extends StatelessWidget {
  final LatLng? initialLocation;
  final String? initialLocationName;

  const MapLocationPicker({
    super.key,
    this.initialLocation,
    this.initialLocationName,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      MapLocationPickerController(
        initialLocation: initialLocation,
        initialLocationName: initialLocationName,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        title: const Text(
          'Select Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF152033),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              // Return selected location
              Get.back(
                result: {
                  'lat': controller.selectedLocation.value.latitude,
                  'lng': controller.selectedLocation.value.longitude,
                  'name': controller.locationName.value,
                },
              );
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialCenter: controller.selectedLocation.value,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                // Update location saat map dipindahkan (drag)
                if (hasGesture && position.center != null) {
                  controller.onMapMoved(position.center!);
                }
              },
            ),
            children: [
              // Tile layer dari OSM
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.linug.shotsync',
              ),
              // Marker tetap di tengah (tidak bergerak saat drag)
              // Marker akan selalu di posisi center map
            ],
          ),

          // Marker Icon di tengah layar (static)
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 40), // Offset untuk icon
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFFF5252),
                size: 50,
              ),
            ),
          ),

          // Search Bar di atas
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF152033),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller.searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      hintStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF00D9FF),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF8B8B8B)),
                        onPressed: () {
                          controller.searchController.clear();
                          controller.searchResults.clear();
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        controller.searchLocation(value);
                      }
                    },
                  ),
                ),

                // Search results
                Obx(() {
                  if (controller.isSearching.value) {
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF152033),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00D9FF),
                        ),
                      ),
                    );
                  }

                  if (controller.searchResults.isEmpty) {
                    return const SizedBox();
                  }

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152033),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: controller.searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFF1F2937), height: 1),
                      itemBuilder: (context, index) {
                        final result = controller.searchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.place,
                            color: Color(0xFF00D9FF),
                          ),
                          title: Text(
                            result['display_name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            final lat = double.parse(result['lat']);
                            final lng = double.parse(result['lon']);
                            controller.selectSearchResult(
                              LatLng(lat, lng),
                              result['display_name'],
                            );
                          },
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Info Box + Actions di bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF152033),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF00D9FF),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Selected Location',
                        style: TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Button untuk detect current location
                      IconButton(
                        onPressed: controller.getCurrentLocation,
                        icon: const Icon(
                          Icons.my_location,
                          color: Color(0xFF00D9FF),
                        ),
                        tooltip: 'Use my location',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00D9FF).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.locationName.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.pin_drop,
                                size: 14,
                                color: Color(0xFF8B8B8B),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Lat: ${controller.selectedLocation.value.latitude.toStringAsFixed(6)}, '
                                  'Lon: ${controller.selectedLocation.value.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    color: Color(0xFF8B8B8B),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Color(0xFF00D9FF),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Drag the map to change location',
                            style: TextStyle(
                              color: Color(0xFF00D9FF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapLocationPickerController extends GetxController {
  final LatLng? initialLocation;
  final String? initialLocationName;

  MapLocationPickerController({this.initialLocation, this.initialLocationName});

  final mapController = MapController();
  final searchController = TextEditingController();

  // Lokasi yang dipilih (default Jakarta kalo ga ada initial)
  late var selectedLocation = Rx<LatLng>(
    initialLocation ?? LatLng(-6.2088, 106.8456),
  );

  var locationName = ''.obs;
  var searchResults = <Map<String, dynamic>>[].obs;
  var isSearching = false.obs;
  var isUpdatingLocation = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (initialLocationName != null && initialLocationName!.isNotEmpty) {
      locationName.value = initialLocationName!;
    } else {
      // Untuk reverse geocode lokasi awal
      reverseGeocode(selectedLocation.value);
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Dipanggil saat map selesai dipindahkan (drag)
  void onMapMoved(LatLng center) {
    // Debounce untuk menghindari terlalu banyak request
    if (!isUpdatingLocation.value) {
      isUpdatingLocation.value = true;
      selectedLocation.value = center;

      // Delay untuk reverse geocode
      Future.delayed(const Duration(milliseconds: 500), () {
        reverseGeocode(center);
        isUpdatingLocation.value = false;
      });
    }
  }

  /// Untuk update lokasi (digunakan dari search result)
  void updateLocation(LatLng point) {
    selectedLocation.value = point;
    mapController.move(point, 15.0);

    // Reverse geocode buat dapetin nama tempat
    reverseGeocode(point);

    // Clear search results
    searchResults.clear();
  }

  /// Untuk search lokasi pake Nominatim OSM API
  /// API: https://nominatim.openstreetmap.org/search
  Future<void> searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    isSearching.value = true;
    searchResults.clear();

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&'
        'limit=5&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'ShotSync/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        searchResults.value = results.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to search location. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSearching.value = false;
    }
  }

  /// Untuk pilih hasil search
  void selectSearchResult(LatLng location, String name) {
    selectedLocation.value = location;
    locationName.value = name;
    mapController.move(location, 15.0);
    searchResults.clear();
    searchController.clear();
  }

  /// Untuk reverse geocode (lat/lng -> nama tempat)
  /// API: https://nominatim.openstreetmap.org/reverse
  Future<void> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${location.latitude}&'
        'lon=${location.longitude}&'
        'format=json',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'ShotSync/1.0'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        locationName.value = result['display_name'] ?? 'Unknown Location';
      }
    } catch (e) {
      locationName.value = 'Lat: ${location.latitude.toStringAsFixed(4)}, '
          'Lng: ${location.longitude.toStringAsFixed(4)}';
    }
  }

  /// Untuk ngambil lokasi sekarang (current location)
  Future<void> getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Permission Denied',
            'Location permission is required',
            duration: Duration(seconds: 1, milliseconds: 500),
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Permission Denied',
          'Please enable location permission in settings',
          duration: Duration(seconds: 1, milliseconds: 500),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Get current position
      Get.snackbar(
        'Detecting Location',
        'Getting your current location...',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF2196F3),
        colorText: Colors.white,
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = LatLng(position.latitude, position.longitude);
      updateLocation(location);

      Get.snackbar(
        'Success',
        'Location detected',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get current location. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
