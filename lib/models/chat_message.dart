// Model buat ChatMessage - struktur data pesan chat
class ChatMessage {
  final String id; // ID unik pesan (auto-generate dari database)
  final String projectId; // Project mana pesannya
  final String senderId; // ID orang yang kirim
  final String senderName; // Nama orang yang kirim
  final String message; // Isi pesannya
  final DateTime timestamp; // Kapan dikirimnya
  final bool isMe; // Apakah pesan ini dari gue sendiri atau orang lain
  final List<String> readBy; // Array berisi ID user yang udah baca pesan ini

  ChatMessage({
    required this.id,
    required this.projectId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isMe,
    this.readBy = const [], // Default: array kosong (belum ada yang baca)
  });

  // Factory constructor buat convert JSON dari database jadi object ChatMessage
  factory ChatMessage.fromJson(
    Map<String, dynamic> json,
    String currentUserId, // ID user yang lagi login (buat tentuin isMe)
  ) {
    // Parse array read_by dari database
    final readByData = json['read_by'];
    List<String> readByList = [];
    if (readByData != null) {
      if (readByData is List) {
        // Convert semua element jadi String
        readByList = readByData.map((e) => e.toString()).toList();
      }
    }

    return ChatMessage(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['created_at'] as String),
      isMe:
          json['sender_id'] ==
          currentUserId, // Cek apakah pengirim = user login
      readBy: readByList,
    );
  }

  // Helper method buat cek apakah user tertentu udah baca pesan ini
  bool isReadBy(String userId) => readBy.contains(userId);

  // Convert object jadi JSON buat insert ke database
  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
