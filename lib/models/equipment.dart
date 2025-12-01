class Equipment {
  final String id;
  final String sceneId;
  final String equipmentName;
  final String? category;
  final int quantity;
  final double price;

  Equipment({
    required this.id,
    required this.sceneId,
    required this.equipmentName,
    this.category,
    required this.quantity,
    required this.price,
  });

  // Factory constructor untuk parsing dari JSON Supabase
  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      sceneId: json['scene_id'] as String,
      equipmentName: json['equipment_name'] as String,
      category: json['category'] as String?,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
    );
  }

  // Method untuk convert ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scene_id': sceneId,
      'equipment_name': equipmentName,
      'category': category,
      'quantity': quantity,
      'price': price,
    };
  }

  // Helper untuk total harga
  double get totalPrice {
    return price * quantity;
  }
}
