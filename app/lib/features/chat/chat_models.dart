import '../../core/network/api_config.dart';
import '../../core/widgets/chat_widgets.dart';

class ConversationListingModel {
  const ConversationListingModel({
    required this.id,
    required this.judul,
    this.posterUrl,
    required this.harga,
    required this.status,
  });

  final int id;
  final String judul;
  final String? posterUrl;
  final int harga;
  final String status;

  String? get fullPosterUrl {
    if (posterUrl == null || posterUrl!.isEmpty) return null;
    if (posterUrl!.startsWith('http://') || posterUrl!.startsWith('https://')) {
      return posterUrl;
    }
    return '${ApiConfig.hostUrl}$posterUrl';
  }

  factory ConversationListingModel.fromJson(Map<String, dynamic> json) {
    return ConversationListingModel(
      id: json['id'] as int,
      judul: json['judul'] as String? ?? '',
      posterUrl: json['poster_url'] as String?,
      harga: (json['harga'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'tersedia',
    );
  }
}

class ConversationUserModel {
  const ConversationUserModel({
    required this.id,
    required this.nama,
    this.username,
  });

  final int id;
  final String nama;
  final String? username;

  factory ConversationUserModel.fromJson(Map<String, dynamic> json) {
    return ConversationUserModel(
      id: json['id'] as int,
      nama: json['nama'] as String? ?? '',
      username: json['username'] as String?,
    );
  }
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.listing,
    required this.lawan,
    required this.peran,
    this.pesanTerakhir,
    this.waktuPesanTerakhir,
    this.belumDibaca = 0,
    this.izinkanWa = false,
  });

  final int id;
  final ConversationListingModel listing;
  final ConversationUserModel lawan;
  final String peran; // 'pembeli' | 'penjual'
  final String? pesanTerakhir;
  final DateTime? waktuPesanTerakhir;
  final int belumDibaca;
  final bool izinkanWa;

  bool get isBuyer => peran == 'pembeli';

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      listing: ConversationListingModel.fromJson(
        json['listing'] as Map<String, dynamic>,
      ),
      lawan: ConversationUserModel.fromJson(
        json['lawan'] as Map<String, dynamic>,
      ),
      peran: json['peran'] as String? ?? 'pembeli',
      pesanTerakhir: json['pesan_terakhir'] as String?,
      waktuPesanTerakhir: json['waktu_pesan_terakhir'] != null
          ? DateTime.tryParse(json['waktu_pesan_terakhir'] as String)?.toLocal()
          : null,
      belumDibaca: (json['belum_dibaca'] as num?)?.toInt() ?? 0,
      izinkanWa: json['izinkan_wa'] as bool? ?? false,
    );
  }

  ConversationData toConversationData() {
    return ConversationData(
      id: id.toString(),
      otherName: lawan.nama,
      eventName: listing.judul,
      lastMessage: pesanTerakhir ?? '',
      updatedAt: waktuPesanTerakhir ?? DateTime.now(),
      posterUrl: listing.fullPosterUrl,
      unreadCount: belumDibaca,
      isUnread: belumDibaca > 0,
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isi,
    required this.createdAt,
    this.sendStatus = MessageSendStatus.sent,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final String isi;
  final DateTime createdAt;
  final MessageSendStatus sendStatus;

  ChatMessageModel copyWith({
    int? id,
    int? conversationId,
    int? senderId,
    String? isi,
    DateTime? createdAt,
    MessageSendStatus? sendStatus,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      isi: isi ?? this.isi,
      createdAt: createdAt ?? this.createdAt,
      sendStatus: sendStatus ?? this.sendStatus,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as int,
      isi: json['isi'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      sendStatus: MessageSendStatus.sent,
    );
  }
}
