class UserModel {
  final String id;
  final String nama;
  final String email;
  final String role;
  final String nomorWa;
  final String? cleanerId;
  final String? token;

  const UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.nomorWa = '-',
    this.cleanerId,
    this.token,
  });

  bool get isCustomer => role.toLowerCase() == 'customer';
  bool get isCleaner => role.toLowerCase() == 'cleaner';
  bool get isAdmin => role.toLowerCase() == 'admin';

  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'cleaner':
        return 'Petugas Kebersihan';
      case 'admin':
        return 'Administrator';
      case 'customer':
      default:
        return 'Pelanggan';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      nama: json['nama'] as String? ?? 'Pengguna',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      nomorWa: json['nomor_wa'] as String? ?? '-',
      cleanerId: json['cleaner_id'] as String?,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'email': email,
      'role': role,
      'nomor_wa': nomorWa,
      if (cleanerId != null) 'cleaner_id': cleanerId,
      if (token != null) 'token': token,
    };
  }
}
