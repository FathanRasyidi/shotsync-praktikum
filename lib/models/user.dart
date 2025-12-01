class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final String? timezone;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.timezone,
  });

  // Factory constructor untuk parsing dari JSON Supabase
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  // Method untuk convert ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'phone': phone,
      'timezone': timezone,
    };
  }
}
