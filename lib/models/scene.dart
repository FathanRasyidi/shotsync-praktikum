import 'package:flutter/material.dart';

class Scene {
  final String id;
  final String projectId;
  final int sceneNumber;
  final String title;
  final String? description;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime scheduledDate;
  final String status; // 'pending', 'on progress', 'completed'
  final DateTime? updatedAt;

  Scene({
    required this.id,
    required this.projectId,
    required this.sceneNumber,
    required this.title,
    this.description,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.scheduledDate,
    required this.status,
    this.updatedAt,
  });

  // Parsing data dari JSON yang dikasih Supabase
  factory Scene.fromJson(Map<String, dynamic> json) {
    // Parse scheduled_date dari UTC dan convert ke WIB (UTC+7)
    final scheduledDateUTC = DateTime.parse(json['scheduled_date'] as String);
    final scheduledDateWIB = scheduledDateUTC.add(const Duration(hours: 7));
    
    return Scene(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      sceneNumber: json['scene_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      locationName: json['location_name'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      scheduledDate: scheduledDateWIB,
      status: json['status'] as String? ?? 'pending',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Method untuk convert ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'scene_number': sceneNumber,
      'title': title,
      'description': description,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'scheduled_date': scheduledDate.toIso8601String(),
      'status': status,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Ngambil warna status buat UI
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFF9800); // Orange
      case 'on progress':
        return const Color(0xFF2196F3); // Blue
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF8B8B8B); // Grey for unknown
    }
  }

  // Text status yang user-friendly buat ditampilkan
  String get statusText {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'on progress':
        return 'On Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  // Cek apakah scene ini punya koordinat lokasi (GPS)
  bool get hasCoordinates {
    return latitude != null && longitude != null;
  }

  // Helper untuk format tanggal jadwal
  String get scheduledDateText {
    final date = scheduledDate;
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  // Helper untuk format tanggal jadwal dengan waktu
  String get scheduledDateTimeText {
    final date = scheduledDate;
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Helper untuk format koordinat
  String get coordinatesText {
    if (!hasCoordinates) return '-';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }
}
