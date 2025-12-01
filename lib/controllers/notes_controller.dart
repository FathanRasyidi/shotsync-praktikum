import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NotesController extends GetxController {
  static const String _boxName = 'notes';

  // Observable variables
  var notes = <Note>[].obs;
  var isLoading = true.obs;
  var userId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initializeNotes();
  }

  /// Initialize Hive dan load user notes
  Future<void> initializeNotes() async {
    try {
      isLoading.value = true;

      // Get user ID
      final prefs = await SharedPreferences.getInstance();
      userId.value = prefs.getString('user_id') ?? '';

      await Hive.openBox<Note>(_boxName);
      loadNotes();
    } 
    catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to load notes. Please restart the app.',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF5252),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    }
  }


  void loadNotes() {
    try {
      final box = Hive.box<Note>(_boxName);

      // Ambil note sesuai userId
      final allNotes = box.values
          .where((note) => note.userId == userId.value)
          .toList();

      allNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      notes.value = allNotes;
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
    }
  }

  /// Create note baru (simpan sebagai objek Note)
  Future<void> createNote({
    required String title,
    required String content,
  }) async {
    try {
      final box = Hive.box<Note>(_boxName);

      // Generate unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final note = Note(
        id: id,
        userId: userId.value,
        title: title,
        content: content,
        updatedAt: DateTime.now(),
      );

      await box.put(id, note);
      loadNotes();

      Get.snackbar(
        'Success',
        'Note created successfully',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create note',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF5252),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> updateNote({
    required Note note, 
    required String title,
    required String content,
  }) async {
    try {
      // Langsung modifikasi objek Note
      note.title = title;
      note.content = content;
      note.updatedAt = DateTime.now();

      await note.save();
      loadNotes();

      Get.snackbar(
        'Success',
        'Note updated successfully',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update note',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF5252),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  /// Delete note
  Future<void> deleteNote(Note note) async {
    try {
      await note.delete();
      loadNotes();

      Get.snackbar(
        'Success',
        'Note deleted successfully',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete note',
        duration: Duration(seconds: 1, milliseconds: 500),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF5252),
        colorText: const Color(0xFFFFFFFF),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  void onClose() {
    super.onClose();
  }
}