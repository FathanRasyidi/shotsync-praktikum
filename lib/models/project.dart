import 'package:flutter/material.dart';

class Project {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final List<String> staff; // Array of user IDs
  final List<String> projectAdministrator; // Array of user IDs with full access
  final DateTime? updatedAt;
  final String status;
  final String link;

  // Computed fields (akan dihitung dari relasi scenes)
  int totalScenes;
  int completedScenes;

  Project({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.staff,
    this.projectAdministrator = const [],
    this.updatedAt,
    required this.status,
    this.totalScenes = 0,
    this.completedScenes = 0,
    this.link = '',
  });

  // Factory constructor untuk parsing dari JSON Supabase
  factory Project.fromJson(Map<String, dynamic> json) {
    // Debug: Print raw JSON data
    if (json['title'] != null) {
      print('DEBUG Project.fromJson - Parsing: ${json['title']}');
      print(
        'DEBUG Project.fromJson - Has project_administrator key: ${json.containsKey('project_administrator')}',
      );
      print(
        'DEBUG Project.fromJson - project_administrator value: ${json['project_administrator']}',
      );
      print(
        'DEBUG Project.fromJson - project_administrator type: ${json['project_administrator']?.runtimeType}',
      );
    }

    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: _parseDate(json['start_date'] as String),
      endDate: _parseDate(json['end_date'] as String),
      createdBy: json['created_by'] as String,
      staff: List<String>.from(json['staff'] as List? ?? []),
      projectAdministrator: List<String>.from(
        json['project_administrator'] as List? ?? [],
      ),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      status: json['status'] as String,
      link: json['link'] as String? ?? '',
      // totalScenes dan completedScenes akan diset manual atau dari query terpisah
      totalScenes: 0,
      completedScenes: 0,
    );
  }

  // Helper untuk parsing date-only format (yyyy-MM-dd)
  static DateTime _parseDate(String dateString) {
    try {
      // Parse date string (format: yyyy-MM-dd atau yyyy-MM-ddTHH:mm:ss)
      final date = DateTime.parse(dateString);
      // Return hanya tanggal, set waktu ke midnight
      return DateTime(date.year, date.month, date.day);
    } catch (e) {
      return DateTime.now();
    }
  }

  // Method untuk convert ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date':
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'end_date':
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'created_by': createdBy,
      'staff': staff,
      'project_administrator': projectAdministrator,
      'updated_at': updatedAt?.toIso8601String(),
      'link': link,
    };
  }

  // Helper untuk menghitung progress
  double get progress {
    if (totalScenes == 0) return 0.0;
    return (completedScenes / totalScenes * 100);
  }

  // Helper untuk mendapatkan status berdasarkan progress
  String get computedStatus {
    final prog = progress;

    if (prog == 0) {
      return 'Pending';
    } else if (prog < 100) {
      return 'On Progress';
    } else {
      return 'Completed';
    }
  }

  // Helper untuk mendapatkan warna status
  Color get statusColor {
    switch (computedStatus) {
      case 'Pending':
        return const Color(0xFFFF9800); // Orange
      case 'On Progress':
        return const Color(0xFF2196F3); // Blue
      case 'Completed':
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF8B8B8B); // Grey
    }
  }

  // Helper untuk format tanggal
  String get dateRangeText {
    final start =
        '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
    final end =
        '${endDate.day.toString().padLeft(2, '0')}/${endDate.month.toString().padLeft(2, '0')}/${endDate.year}';
    return '$start - $end';
  }

  // Helper untuk mengecek apakah user memiliki full access (owner atau administrator)
  bool hasFullAccess(String userId) {
    return createdBy == userId || projectAdministrator.contains(userId);
  }

  // Helper untuk mengecek apakah user adalah administrator
  bool isAdministrator(String userId) {
    return projectAdministrator.contains(userId);
  }

  // Helper untuk mengecek apakah user adalah owner
  bool isOwner(String userId) {
    return createdBy == userId;
  }
}
