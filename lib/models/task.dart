import 'package:flutter/material.dart';

class Task {
  final String id;
  final String sceneId;
  final String title;
  final String? description;
  final String assignedTo;
  final String status; // 'pending', 'in-progress', 'completed'
  final DateTime dueDate;

  Task({
    required this.id,
    required this.sceneId,
    required this.title,
    this.description,
    required this.assignedTo,
    required this.status,
    required this.dueDate,
  });

  // Factory constructor untuk parsing dari JSON Supabase
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      sceneId: json['scene_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      assignedTo: json['assigned_to'] as String,
      status: json['status'] as String? ?? 'pending',
      dueDate: DateTime.parse(json['due_date'] as String)
    );
  }

  // Method untuk convert ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scene_id': sceneId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'status': status,
      'due_date': dueDate.toIso8601String(),
    };
  }

  // Ngambil warna status buat UI
  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800); // Orange
      case 'in-progress':
        return const Color(0xFF2196F3); // Blue
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF8B8B8B); // Grey
    }
  }

  // Text status dalam bahasa Inggris
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  // Helper untuk format tanggal deadline
  String get dueDateText {
    final date = dueDate;
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  // Helper untuk cek apakah sudah lewat deadline
  bool get isOverdue {
    return DateTime.now().isAfter(dueDate);
  }

  // Helper untuk mendapatkan icon status
  IconData get statusIcon {
    switch (status) {
      case 'pending':
        return Icons.pending_outlined;
      case 'in-progress':
        return Icons.autorenew;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }
}
