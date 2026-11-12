import '../../core/widgets/widgets.dart';

/// Data contoh realistis untuk Component Gallery (DESIGN.md bagian 11).
abstract final class GallerySampleData {
  static final List<BannerItem> banners = [
    const BannerItem(
      imageUrl: '',
      eventName: 'Nada Senja Live in Surabaya',
      keyword: 'Nada Senja',
    ),
    const BannerItem(
      imageUrl: '',
      eventName: 'Gelora Rock Fest 2026',
      keyword: 'Gelora Rock',
    ),
    const BannerItem(
      imageUrl: '',
      eventName: 'Liga Nusantara: Persebaya vs Persib',
      keyword: 'Persebaya',
    ),
  ];

  static final List<ListingData> listings = [
    ListingData(
      id: 'lst-1',
      eventName: 'Nada Senja Live in Surabaya',
      venueName: 'Grand City Convention Hall',
      city: 'Surabaya',
      eventDate: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
      pricePerTicket: 450000,
      ticketCount: 2,
      distanceKm: 1.2,
      type: TicketType.lastMinute,
      isSaved: true,
      discountPercent: 25,
    ),
    ListingData(
      id: 'lst-2',
      eventName: 'Gelora Rock Fest 2026',
      venueName: 'Stadion Gelora Bung Tomo',
      city: 'Surabaya',
      eventDate: DateTime.now().add(const Duration(hours: 5)),
      pricePerTicket: 850000,
      ticketCount: 1,
      distanceKm: 8.4,
      type: TicketType.limited,
      isSaved: false,
    ),
    ListingData(
      id: 'lst-3',
      eventName: 'Pekan Sinema Indie — Malam Pembuka',
      venueName: 'XXI Tunjungan Plaza 5',
      city: 'Surabaya',
      eventDate: DateTime.now().add(const Duration(hours: 1, minutes: 40)),
      pricePerTicket: 65000,
      ticketCount: 3,
      distanceKm: 0.9,
      type: TicketType.lastMinute,
      isSaved: false,
      discountPercent: 40,
    ),
    ListingData(
      id: 'lst-4',
      eventName: 'Senandika Akustik Tour Bandung',
      venueName: 'Eldorado Dome',
      city: 'Bandung',
      eventDate: DateTime.now().add(const Duration(days: 3)),
      pricePerTicket: 325000,
      ticketCount: 2,
      distanceKm: null,
      type: TicketType.limited,
      isSaved: true,
    ),
    ListingData(
      id: 'lst-5',
      eventName: 'Festival Lampion Taman Pelangi',
      venueName: 'Monjali',
      city: 'Yogyakarta',
      eventDate: DateTime.now().add(const Duration(days: 5)),
      pricePerTicket: 120000,
      ticketCount: 4,
      distanceKm: null,
      type: TicketType.limited,
      isSaved: false,
    ),
  ];

  static final List<ConversationData> conversations = [
    ConversationData(
      id: 'conv-1',
      otherName: 'Raka Pratama',
      eventName: 'Nada Senja Live in Surabaya',
      lastMessage: 'Tiket digital masih ada 2 kak, siap kirim.',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 4)),
      unreadCount: 2,
      isUnread: true,
    ),
    ConversationData(
      id: 'conv-2',
      otherName: 'Dina Larasati',
      eventName: 'Gelora Rock Fest 2026',
      lastMessage: 'Bisa ketemuan di gerbang timur jam 5?',
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
      isUnread: false,
    ),
  ];
}
