/// Model pengguna Droptix.
class UserModel {
  const UserModel({
    required this.id,
    required this.nama,
    required this.email,
    this.noWa,
    this.kota,
    this.createdAt,
  });

  final int id;
  final String nama;
  final String email;
  final String? noWa;
  final String? kota;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      email: json['email'] as String,
      noWa: json['no_wa'] as String?,
      kota: json['kota'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'email': email,
        'no_wa': noWa,
        'kota': kota,
        'created_at': createdAt?.toIso8601String(),
      };
}

