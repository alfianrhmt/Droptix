/// Model pengguna Droptix.
class UserModel {
  const UserModel({
    required this.id,
    required this.nama,
    required this.email,
    this.noWa,
    this.kota,
    this.fotoUrl,
    this.createdAt,
  });

  final int id;
  final String nama;
  final String email;
  final String? noWa;
  final String? kota;
  final String? fotoUrl;
  final DateTime? createdAt;

  UserModel copyWith({
    int? id,
    String? nama,
    String? email,
    String? noWa,
    String? kota,
    String? fotoUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      noWa: noWa ?? this.noWa,
      kota: kota ?? this.kota,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      email: json['email'] as String,
      noWa: json['no_wa'] as String?,
      kota: json['kota'] as String?,
      fotoUrl: json['foto_url'] as String?,
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
        'foto_url': fotoUrl,
        'created_at': createdAt?.toIso8601String(),
      };
}

