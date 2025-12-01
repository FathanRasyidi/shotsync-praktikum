import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/note.dart';
import '../../controllers/notes_controller.dart';

// Display and manage user notes stored locally with Hive
class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final NotesController controller = Get.put(NotesController());

    return Obx(() {
      if (controller.isLoading.value) {
        return Container(
          color: const Color(0xFF0F1828),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFF0F1828),
        body: controller.notes.isEmpty
            ? _buildEmptyState(controller)
            : _buildNotesList(controller),
        floatingActionButton: _buildFloatingActionButton(controller),
      );
    });
  }

  /// Build floating action button
  Widget _buildFloatingActionButton(NotesController controller) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showNoteDialog(controller),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Note',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Build empty state when no notes exist
  Widget _buildEmptyState(NotesController controller) {
    return Container(
      color: const Color(0xFF0F1828),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF152033),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1F2937),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.note_outlined,
                size: 64,
                color: Color(0xFF00D9FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Notes Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your first note',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8B8B8B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build list of notes
  Widget _buildNotesList(NotesController controller) {
    return Container(
      color: const Color(0xFF0F1828),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.notes.length,
        itemBuilder: (context, index) {
          final note = controller.notes[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF152033),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1F2937),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () => _showNoteDialog(controller, note: note),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.note_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            note.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _showDeleteDialog(controller, note),
                          color: const Color(0xFFFF5252),
                          iconSize: 20,
                          tooltip: 'Delete note',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      note.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFCCCCCC),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Color(0xFF8B8B8B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Updated: ${_formatDate(note.updatedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B8B8B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Show dialog to create or edit a note
  void _showNoteDialog(NotesController controller, {Note? note}) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    final isEditing = note != null;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF152033),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF1F2937),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.note_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Note' : 'New Note',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1F2937),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00D9FF),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F1828),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Content',
                  labelStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1F2937),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00D9FF),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F1828),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B8B8B),
            ),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () {
                // Validate title
                if (titleController.text.trim().isEmpty) {
                  Get.snackbar(
                    'Error',
                    'Title cannot be empty',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFFFF5252),
                    colorText: const Color(0xFFFFFFFF),
                    borderRadius: 8,
                    margin: const EdgeInsets.all(16),
                  );
                  return;
                }

                // Validate content
                if (contentController.text.trim().isEmpty) {
                  Get.snackbar(
                    'Error',
                    'Content cannot be empty',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFFFF5252),
                    colorText: const Color(0xFFFFFFFF),
                    borderRadius: 8,
                    margin: const EdgeInsets.all(16),
                  );
                  return;
                }

                // Close dialog first
                Get.back();

                // Then perform create/update
                if (isEditing) {
                  controller.updateNote(
                    note: note,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                  );
                } else {
                  controller.createNote(
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isEditing ? 'Update' : 'Create',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog(NotesController controller, Note note) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF152033),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF1F2937),
            width: 1,
          ),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_outlined,
              color: Color(0xFFFF5252),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Delete Note',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFCCCCCC),
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: '"${note.title}"',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B8B8B),
            ),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () {
                controller.deleteNote(note);
                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm').format(date);
    } else {
      return DateFormat('dd MMM yyyy HH:mm').format(date);
    }
  }
}
