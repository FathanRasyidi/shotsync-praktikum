import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:danielshotsync/config/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../models/scene.dart';
import '../../models/user.dart';
import '../../models/task.dart';
import '../../models/equipment.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/map_location_picker.dart';

/// Model untuk task yang belum disimpan atau existing task
class PendingTask {
  final String? id; // null kalo baru, ada kalo existing task
  final String title;
  final String? description;
  final String assignedToId;
  final String assignedToName;
  final String? assignedToRole;
  final DateTime? dueDate;
  final String status;

  PendingTask({
    this.id,
    required this.title,
    this.description,
    required this.assignedToId,
    required this.assignedToName,
    this.assignedToRole,
    this.dueDate,
    required this.status,
  });
}

/// Model untuk equipment yang belum disimpan atau existing equipment
class PendingEquipment {
  final String? id; // null kalo baru
  final String equipmentName;
  final String? category;
  final int quantity;
  final double? price;

  PendingEquipment({
    this.id,
    required this.equipmentName,
    this.category,
    required this.quantity,
    this.price,
  });
}

/// Controller buat handle logic Edit Scene
class EditSceneController extends GetxController {
  final Scene scene;

  var isLoading = false.obs;
  var isLoadingUsers = true.obs;
  var isLoadingData = true.obs;

  // Computed: Check if initial loading is still in progress
  bool get isInitialLoading => isLoadingUsers.value || isLoadingData.value;

  // Form controllers - Scene
  final sceneNumberController = TextEditingController();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationNameController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  // Form controllers - Task
  final taskTitleController = TextEditingController();
  final taskDescriptionController = TextEditingController();

  // Form controllers - Equipment
  final equipmentNameController = TextEditingController();
  final equipmentQuantityController = TextEditingController();
  final equipmentPriceController = TextEditingController();

  // Form data - Scene
  var scheduledDate = Rx<DateTime?>(null);

  // Untuk reactive location display (biar UI update pas pilih map)
  var selectedLocationName = ''.obs;
  var selectedLatitude = ''.obs;
  var selectedLongitude = ''.obs;

  // Form data - Task
  var selectedUser = Rx<User?>(null);
  var taskDueDate = Rx<DateTime?>(null);
  var taskStatus = 'pending'.obs;
  var users = <User>[].obs;
  var pendingTasks = <PendingTask>[].obs;
  var tasksToDelete = <String>[].obs; // IDs of tasks to delete

  // Form data - Equipment
  var selectedCategory = Rx<String?>(null);
  var pendingEquipments = <PendingEquipment>[].obs;
  var equipmentsToDelete = <String>[].obs; // IDs of equipments to delete

  final equipmentCategories = [
    'Camera',
    'Lighting',
    'Audio',
    'Grip',
    'Props',
    'Costume',
    'Makeup',
    'Other',
  ];

  EditSceneController({required this.scene}) {
    _loadSceneData();
    loadUsers();
    _loadExistingTasksAndEquipments();
  }

  void _loadSceneData() {
    sceneNumberController.text = scene.sceneNumber.toString();
    titleController.text = scene.title;
    descriptionController.text = scene.description ?? '';
    locationNameController.text = scene.locationName ?? '';

    // Initialize observable location variables
    selectedLocationName.value = scene.locationName ?? '';

    if (scene.latitude != null) {
      latitudeController.text = scene.latitude.toString();
      selectedLatitude.value = scene.latitude.toString();
    }
    if (scene.longitude != null) {
      longitudeController.text = scene.longitude.toString();
      selectedLongitude.value = scene.longitude.toString();
    }

    scheduledDate.value = scene.scheduledDate;
  }

  /// Load semua users buat pilihan assign task
  /// Sorted by full_name ascending
  Future<void> loadUsers() async {
    isLoadingUsers.value = true;
    try {
      // Ambil array staff dari tabel project
      final projectResponse = await SupabaseConfig.client
          .from('projects')
          .select('staff')
          .eq('id', scene.projectId)
          .maybeSingle();
      final List staffIds =
          projectResponse != null && projectResponse['staff'] != null
          ? List<String>.from(projectResponse['staff'] as List)
          : [];
      if (staffIds.isEmpty) {
        users.value = [];
        isLoadingUsers.value = false;
        return;
      }
      // Ambil user yang id-nya ada di staff
      final usersResponse = await SupabaseConfig.client
          .from('users')
          .select()
          .inFilter('id', staffIds)
          .order('full_name', ascending: true);
      users.value = (usersResponse as List)
          .map((json) => User.fromJson(json))
          .toList();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load users. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingUsers.value = false;
    }
  }

  Future<void> _loadExistingTasksAndEquipments() async {
    isLoadingData.value = true;
    try {
      // Clear existing lists to prevent duplicates on refresh
      pendingTasks.clear();
      pendingEquipments.clear();

      // Load existing tasks
      final tasksResponse = await SupabaseConfig.client
          .from('tasks')
          .select()
          .eq('scene_id', scene.id);

      final tasks = (tasksResponse as List)
          .map((json) => Task.fromJson(json))
          .toList();

      // Convert to PendingTask
      for (var task in tasks) {
        final user = users.firstWhereOrNull((u) => u.id == task.assignedTo);
        pendingTasks.add(
          PendingTask(
            id: task.id,
            title: task.title,
            description: task.description,
            assignedToId: task.assignedTo,
            assignedToName: user?.fullName ?? 'Unknown',
            assignedToRole: user?.role,
            dueDate: task.dueDate,
            status: task.status,
          ),
        );
      }

      // Load existing equipments
      final equipmentsResponse = await SupabaseConfig.client
          .from('equipment')
          .select()
          .eq('scene_id', scene.id);

      final equipments = (equipmentsResponse as List)
          .map((json) => Equipment.fromJson(json))
          .toList();

      // Convert to PendingEquipment
      for (var equipment in equipments) {
        pendingEquipments.add(
          PendingEquipment(
            id: equipment.id,
            equipmentName: equipment.equipmentName,
            category: equipment.category,
            quantity: equipment.quantity,
            price: equipment.price,
          ),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load data. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingData.value = false;
    }
  }

  @override
  void onClose() {
    sceneNumberController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    locationNameController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    taskTitleController.dispose();
    taskDescriptionController.dispose();
    equipmentNameController.dispose();
    equipmentQuantityController.dispose();
    equipmentPriceController.dispose();
    super.onClose();
  }

  // Task Methods
  void addTaskToList() {
    if (taskTitleController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Task title must be filled!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (selectedUser.value == null) {
      Get.snackbar(
        'Error',
        'Assigned person must be selected!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (taskDueDate.value == null) {
      Get.snackbar(
        'Error',
        'Deadline must be selected!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final task = PendingTask(
      title: taskTitleController.text.trim(),
      description: taskDescriptionController.text.trim().isEmpty
          ? null
          : taskDescriptionController.text.trim(),
      assignedToId: selectedUser.value!.id,
      assignedToName: selectedUser.value!.fullName,
      assignedToRole: selectedUser.value!.role,
      dueDate: taskDueDate.value,
      status: taskStatus.value,
    );

    pendingTasks.add(task);

    // Reset task form
    taskTitleController.clear();
    taskDescriptionController.clear();
    selectedUser.value = null;
    taskDueDate.value = null;
    taskStatus.value = 'pending';

    Get.back();
  }

  void removeTaskFromList(int index) {
    final task = pendingTasks[index];

    // If task has ID, mark for deletion
    if (task.id != null) {
      tasksToDelete.add(task.id!);
    }

    pendingTasks.removeAt(index);
  }

  Future<void> selectTaskDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: taskDueDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              onPrimary: Colors.white,
              surface: Color(0xFF152033),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF152033),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      taskDueDate.value = picked;
    }
  }

  // Equipment Methods
  void addEquipmentToList() {
    if (equipmentNameController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Equipment name must be filled!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (equipmentQuantityController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Quantity must be filled!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final quantity = int.tryParse(equipmentQuantityController.text);
    if (quantity == null || quantity < 1) {
      Get.snackbar(
        'Error',
        'Quantity must be a positive number!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (equipmentPriceController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Price must be filled!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    double? price = double.tryParse(equipmentPriceController.text);
    if (price == null) {
      Get.snackbar(
        'Error',
        'Price must be a number!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final equipment = PendingEquipment(
      equipmentName: equipmentNameController.text.trim(),
      category: selectedCategory.value,
      quantity: quantity,
      price: price,
    );

    pendingEquipments.add(equipment);

    // Reset equipment form
    equipmentNameController.clear();
    equipmentQuantityController.clear();
    equipmentPriceController.clear();
    selectedCategory.value = null;

    Get.back();
  }

  void removeEquipmentFromList(int index) {
    final equipment = pendingEquipments[index];

    // If equipment has ID, mark for deletion
    if (equipment.id != null) {
      equipmentsToDelete.add(equipment.id!);
    }

    pendingEquipments.removeAt(index);
  }

  double get totalEquipmentCost {
    return pendingEquipments.fold<double>(
      0.0,
      (sum, eq) => sum + (eq.price ?? 0) * eq.quantity,
    );
  }

  // Scene Methods
  Future<void> pickScheduledDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: scheduledDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              onPrimary: Colors.white,
              surface: Color(0xFF152033),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF152033),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: scheduledDate.value != null
            ? TimeOfDay.fromDateTime(scheduledDate.value!)
            : TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF00D9FF),
                onPrimary: Colors.white,
                surface: Color(0xFF152033),
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: const Color(0xFF152033),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        scheduledDate.value = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
  }

  Future<void> updateScene() async {
    // Validasi
    if (sceneNumberController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Scene number must be filled!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final sceneNumber = int.tryParse(sceneNumberController.text);
    if (sceneNumber == null) {
      Get.snackbar(
        'Error',
        'Scene number must be a number!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      // Convert scheduled_date from WIB (UTC+7) to UTC before saving
      DateTime? scheduledDateUTC;
      if (scheduledDate.value != null) {
        scheduledDateUTC = scheduledDate.value!.subtract(
          const Duration(hours: 7),
        );
      }

      // 1. Update Scene
      final sceneData = {
        'scene_number': sceneNumber,
        'title': titleController.text.isEmpty
            ? null
            : titleController.text.trim(),
        'description': descriptionController.text.isEmpty
            ? null
            : descriptionController.text.trim(),
        'location_name': locationNameController.text.isEmpty
            ? null
            : locationNameController.text.trim(),
        'latitude': latitudeController.text.isEmpty
            ? null
            : double.tryParse(latitudeController.text),
        'longitude': longitudeController.text.isEmpty
            ? null
            : double.tryParse(longitudeController.text),
        'scheduled_date': scheduledDateUTC?.toIso8601String(),
        // Status tidak diubah di sini, diatur lewat dropdown menu di tasks_tab
      };

      await SupabaseConfig.client
          .from('scenes')
          .update(sceneData)
          .eq('id', scene.id);

      // 2. Delete removed tasks
      for (String taskId in tasksToDelete) {
        await SupabaseConfig.client.from('tasks').delete().eq('id', taskId);
      }

      // 3. Delete removed equipments
      for (String equipmentId in equipmentsToDelete) {
        await SupabaseConfig.client
            .from('equipment')
            .delete()
            .eq('id', equipmentId);
      }

      // 4. Update or Insert Tasks
      for (var task in pendingTasks) {
        if (task.id != null) {
          // Update existing task
          await SupabaseConfig.client
              .from('tasks')
              .update({
                'title': task.title,
                'description': task.description,
                'assigned_to': task.assignedToId,
                'due_date': task.dueDate?.toIso8601String(),
                'status': task.status,
              })
              .eq('id', task.id!);
        } else {
          // Insert new task
          await SupabaseConfig.client.from('tasks').insert({
            'scene_id': scene.id,
            'title': task.title,
            'description': task.description,
            'assigned_to': task.assignedToId,
            'due_date': task.dueDate?.toIso8601String(),
            'status': task.status,
          });
        }
      }

      // 5. Update or Insert Equipments
      for (var equipment in pendingEquipments) {
        if (equipment.id != null) {
          // Update existing equipment
          await SupabaseConfig.client
              .from('equipment')
              .update({
                'equipment_name': equipment.equipmentName,
                'category': equipment.category,
                'quantity': equipment.quantity,
                'price': equipment.price,
              })
              .eq('id', equipment.id!);
        } else {
          // Insert new equipment
          await SupabaseConfig.client.from('equipment').insert({
            'scene_id': scene.id,
            'equipment_name': equipment.equipmentName,
            'category': equipment.category,
            'quantity': equipment.quantity,
            'price': equipment.price,
          });
        }
      }

      isLoading.value = false;

      Get.back(result: true);

      Get.snackbar(
        'Success',
        'Scene successfully updated',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to update scene. Please check your internet connection.',
        duration: Duration(seconds: 1, milliseconds: 500),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

class EditScenePage extends StatelessWidget {
  final Scene scene;

  const EditScenePage({super.key, required this.scene});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditSceneController(scene: scene));
    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),
      appBar: AppBar(
        title: const Text(
          'Edit Scene',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF152033),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await controller._loadExistingTasksAndEquipments();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scene Number
                      const Text(
                        'Scene Number',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller.sceneNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 15,
                        buildCounter:
                            (
                              BuildContext context, {
                              required int currentLength,
                              required bool isFocused,
                              required int? maxLength,
                            }) {
                              return null;
                            },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Example: 1',
                          hintStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                          filled: true,
                          fillColor: const Color(0xFF152033),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF00D9FF),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title
                      const Text(
                        'Scene Title',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller.titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Example: Opening Scene',
                          hintStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                          filled: true,
                          fillColor: const Color(0xFF152033),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF00D9FF),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller.descriptionController,
                        maxLines: null,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Scene description...',
                          hintStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                          filled: true,
                          fillColor: const Color(0xFF152033),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF00D9FF),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Location (Map Selector)
                      const Text(
                        'Shooting Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Button buat buka map picker
                      Obx(
                        () => InkWell(
                          onTap: () async {
                            // Untuk buka map picker dengan lokasi existing
                            LatLng? initialLocation;
                            if (controller.selectedLatitude.value.isNotEmpty &&
                                controller.selectedLongitude.value.isNotEmpty) {
                              final lat = double.tryParse(
                                controller.selectedLatitude.value,
                              );
                              final lng = double.tryParse(
                                controller.selectedLongitude.value,
                              );
                              if (lat != null && lng != null) {
                                initialLocation = LatLng(lat, lng);
                              }
                            }

                            final result = await Get.to(
                              () => MapLocationPicker(
                                initialLocation: initialLocation,
                                initialLocationName:
                                    controller
                                        .selectedLocationName
                                        .value
                                        .isEmpty
                                    ? null
                                    : controller.selectedLocationName.value,
                              ),
                            );

                            // Untuk update field pas user pilih lokasi di map
                            if (result != null &&
                                result is Map<String, dynamic>) {
                              // Update observable variables biar UI reactive
                              controller.selectedLocationName.value =
                                  result['name'] ?? '';
                              controller.selectedLatitude.value = result['lat']
                                  .toString();
                              controller.selectedLongitude.value = result['lng']
                                  .toString();

                              // Update text controllers juga (buat save ke DB)
                              controller.locationNameController.text =
                                  result['name'] ?? '';
                              controller.latitudeController.text = result['lat']
                                  .toString();
                              controller.longitudeController.text =
                                  result['lng'].toString();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF152033),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF00D9FF,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.map,
                                        color: Color(0xFF00D9FF),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller
                                                    .selectedLocationName
                                                    .value
                                                    .isEmpty
                                                ? 'Select location on map'
                                                : controller
                                                      .selectedLocationName
                                                      .value,
                                            style: TextStyle(
                                              color:
                                                  controller
                                                      .selectedLocationName
                                                      .value
                                                      .isEmpty
                                                  ? const Color(0xFF8B8B8B)
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                                  controller
                                                      .selectedLocationName
                                                      .value
                                                      .isEmpty
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (controller
                                                  .selectedLatitude
                                                  .value
                                                  .isNotEmpty &&
                                              controller
                                                  .selectedLongitude
                                                  .value
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Lat: ${controller.selectedLatitude.value}, '
                                              'Lon: ${controller.selectedLongitude.value}',
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF00D9FF),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Scheduled Date
                      const Text(
                        'Shooting Schedule (WIB)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => InkWell(
                          onTap: () => controller.pickScheduledDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF152033),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF00D9FF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  controller.scheduledDate.value != null
                                      ? '${controller.scheduledDate.value!.day.toString().padLeft(2, '0')}-${controller.scheduledDate.value!.month.toString().padLeft(2, '0')}-${controller.scheduledDate.value!.year} ${controller.scheduledDate.value!.hour.toString().padLeft(2, '0')}:${controller.scheduledDate.value!.minute.toString().padLeft(2, '0')}'
                                      : 'Select date and time (WIB)',
                                  style: TextStyle(
                                    color:
                                        controller.scheduledDate.value != null
                                        ? Colors.white
                                        : const Color(0xFF8B8B8B),
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                if (controller.scheduledDate.value != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Color(0xFF8B8B8B),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      controller.scheduledDate.value = null;
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ==================== TASKS SECTION ====================
                      _buildTasksSection(context, controller),

                      const SizedBox(height: 24),

                      // ==================== EQUIPMENT SECTION ====================
                      _buildEquipmentSection(context, controller),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: controller.updateScene,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ==================== TASKS SECTION ====================
  Widget _buildTasksSection(
    BuildContext context,
    EditSceneController controller,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF00D9FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Tasks for This Scene',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.pendingTasks.length}',
                    style: const TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Add tasks that need to be done (optional)',
            style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // List of pending tasks
          Obx(() {
            if (controller.pendingTasks.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1828),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1F2937),
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No tasks added yet',
                    style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.pendingTasks.length,
              itemBuilder: (context, index) {
                final task = controller.pendingTasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1828),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Badge: New or Existing
                                if (task.id == null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'New',
                                      style: TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: task.status == 'pending'
                                        ? const Color(
                                            0xFFFF9800,
                                          ).withOpacity(0.2)
                                        : const Color(
                                            0xFF2196F3,
                                          ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.status == 'pending'
                                        ? 'Pending'
                                        : task.status == 'in-progress'
                                        ? 'In Progress'
                                        : 'Completed',
                                    style: TextStyle(
                                      color: task.status == 'pending'
                                          ? const Color(0xFFFF9800)
                                          : const Color(0xFF2196F3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              task.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (task.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8B8B8B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF00D9FF),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    task.assignedToName,
                                    style: const TextStyle(
                                      color: Color(0xFF00D9FF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (task.dueDate != null) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Color(0xFF8B8B8B),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateFormat.format(task.dueDate!),
                                    style: const TextStyle(
                                      color: Color(0xFF8B8B8B),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFFF5252),
                          size: 20,
                        ),
                        onPressed: () => controller.removeTaskFromList(index),
                      ),
                    ],
                  ),
                );
              },
            );
          }),

          const SizedBox(height: 16),

          // Button to add task
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddTaskDialog(context, controller),
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF00D9FF),
                size: 20,
              ),
              label: const Text(
                'Add New Task',
                style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00D9FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EQUIPMENT SECTION ====================
  Widget _buildEquipmentSection(
    BuildContext context,
    EditSceneController controller,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF00D9FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Equipment for This Scene',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.pendingEquipments.length}',
                    style: const TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Add equipment needed (optional)',
            style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // List of pending equipment
          Obx(() {
            if (controller.pendingEquipments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1828),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1F2937),
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No equipment added yet',
                    style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.pendingEquipments.length,
                  itemBuilder: (context, index) {
                    final equipment = controller.pendingEquipments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1828),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D9FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.inventory_2,
                              color: Color(0xFF00D9FF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Badge: New or Existing
                                    if (equipment.id == null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'New',
                                          style: TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (equipment.category != null) ...[
                                      if (equipment.id == null)
                                        const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2196F3,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          equipment.category!,
                                          style: const TextStyle(
                                            color: Color(0xFF2196F3),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  equipment.equipmentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.numbers,
                                      color: Color(0xFF8B8B8B),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Quantity: ${equipment.quantity}',
                                      style: const TextStyle(
                                        color: Color(0xFF8B8B8B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (equipment.price != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        'Rp ${currencyFormat.format(equipment.price)}',
                                        style: const TextStyle(
                                          color: Color(0xFF4CAF50),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFFF5252),
                              size: 20,
                            ),
                            onPressed: () =>
                                controller.removeEquipmentFromList(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Total cost
                Obx(() {
                  if (controller.totalEquipmentCost > 0) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Estimated Cost:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "Rp ${currencyFormat.format(controller.totalEquipmentCost)}",
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            );
          }),

          const SizedBox(height: 16),

          // Button to add equipment
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddEquipmentDialog(context, controller),
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF00D9FF),
                size: 20,
              ),
              label: const Text(
                'Add New Equipment',
                style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00D9FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ADD TASK DIALOG ====================
  void _showAddTaskDialog(
    BuildContext context,
    EditSceneController controller,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 650),
          decoration: BoxDecoration(
            color: const Color(0xFF152033),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_task,
                      color: Color(0xFF00D9FF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add New Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8B8B8B)),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul Task
                      const Text(
                        'Task Title',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller.taskTitleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Enter task title'),
                      ),
                      const SizedBox(height: 16),

                      // Deskripsi
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller.taskDescriptionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: _inputDecoration(
                          'Task description (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pilih User
                      const Text(
                        'Assigned To',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => InkWell(
                          onTap: () => _showUserPicker(context, controller),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1828),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF00D9FF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    controller.selectedUser.value == null
                                        ? 'Select person to assign'
                                        : controller
                                              .selectedUser
                                              .value!
                                              .fullName,
                                    style: TextStyle(
                                      color:
                                          controller.selectedUser.value == null
                                          ? const Color(0xFF4A5568)
                                          : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF8B8B8B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Deadline
                      const Text(
                        'Deadline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => InkWell(
                          onTap: () => controller.selectTaskDueDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1828),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF00D9FF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  controller.taskDueDate.value == null
                                      ? 'Select deadline'
                                      : dateFormat.format(
                                          controller.taskDueDate.value!,
                                        ),
                                  style: TextStyle(
                                    color: controller.taskDueDate.value == null
                                        ? const Color(0xFF4A5568)
                                        : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1F2937))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1F2937)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF8B8B8B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: controller.addTaskToList,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(color: Colors.white),
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
    );
  }

  // ==================== ADD EQUIPMENT DIALOG ====================
  void _showAddEquipmentDialog(
    BuildContext context,
    EditSceneController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF152033),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_box,
                      color: Color(0xFF00D9FF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add New Equipment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8B8B8B)),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Equipment Name
                      const Text(
                        'Equipment Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller.equipmentNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Example: Canon EOS R5'),
                      ),
                      const SizedBox(height: 16),

                      // Category
                      const Text(
                        'Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1828),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1F2937)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controller.selectedCategory.value,
                              hint: const Text(
                                'Select category',
                                style: TextStyle(color: Color(0xFF4A5568)),
                              ),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF152033),
                              style: const TextStyle(color: Colors.white),
                              items: controller.equipmentCategories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                controller.selectedCategory.value = value;
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quantity & Price in Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quantity',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller:
                                      controller.equipmentQuantityController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter
                                        .digitsOnly, // Hanya izinkan angka 0-9
                                  ],
                                  maxLength: 15,
                                  buildCounter:
                                      (
                                        BuildContext context, {
                                        required int currentLength,
                                        required bool isFocused,
                                        required int? maxLength,
                                      }) {
                                        return null;
                                      },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration('1'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Price',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller:
                                      controller.equipmentPriceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  maxLength: 15,
                                  buildCounter:
                                      (
                                        BuildContext context, {
                                        required int currentLength,
                                        required bool isFocused,
                                        required int? maxLength,
                                      }) {
                                        return null;
                                      },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration('Rp.'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1F2937))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1F2937)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF8B8B8B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          controller.addEquipmentToList();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(color: Colors.white),
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
    );
  }

  // Helper methods
  void _showUserPicker(BuildContext context, EditSceneController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF152033),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Person to Assign',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (controller.isLoadingUsers.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: controller.users.length,
                itemBuilder: (context, index) {
                  final user = controller.users[index];
                  return ListTile(
                    leading: ProfileAvatar(
                      userId: user.id,
                      userName: user.fullName,
                      radius: 20,
                      backgroundColor: const Color(0xFF2196F3),
                    ),
                    title: Text(
                      user.fullName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      user.role,
                      style: const TextStyle(color: Color(0xFF8B8B8B)),
                    ),
                    onTap: () {
                      controller.selectedUser.value = user;
                      Get.back();
                    },
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4A5568)),
      filled: true,
      fillColor: const Color(0xFF0F1828),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1F2937)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1F2937)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00D9FF)),
      ),
    );
  }
}
