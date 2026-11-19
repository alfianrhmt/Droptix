import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';
import 'package:droptix/features/events/event_models.dart';
import 'package:droptix/features/events/event_picker_sheet.dart';
import 'package:droptix/features/events/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEventAdapter implements HttpClientAdapter {
  bool forcedCalled = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;

    if (method == 'GET' && path == '/categories') {
      return _jsonResponse({
        'data': [
          {
            'id': 2,
            'slug': 'bioskop',
            'nama': 'Bioskop',
            'ikon': 'movie',
            'urutan': 2,
          },
          {
            'id': 1,
            'slug': 'konser-festival',
            'nama': 'Konser & Festival',
            'ikon': 'music_note',
            'urutan': 1,
          },
        ],
      });
    }

    if (method == 'GET' && path == '/venues') {
      return _jsonResponse({
        'data': [
          {
            'id': 1,
            'nama': 'Grand City Convention Hall',
            'kota': 'Surabaya',
          },
        ],
      });
    }

    if (method == 'GET' && path == '/events') {
      return _jsonResponse({
        'data': [
          {
            'id': 7,
            'nama': 'Nada Senja Live in Surabaya',
            'poster_url': null,
            'category': {
              'id': 2,
              'slug': 'bioskop',
              'nama': 'Bioskop',
              'ikon': 'movie',
            },
            'venue': null,
            'tanggal': null,
          },
        ],
      });
    }

    if (method == 'POST' && path == '/events') {
      final body = options.data as Map<String, dynamic>;
      if (body['force'] != true) {
        return _jsonResponse(
          {
            'error': {
              'code': 'SIMILAR_EVENT_EXISTS',
              'message': 'Ada event yang mirip',
              'similar': [
                {
                  'id': 7,
                  'nama': 'Nada Senja Live in Surabaya',
                  'poster_url': null,
                },
              ],
            },
          },
          status: 409,
        );
      }

      forcedCalled = true;
      return _jsonResponse(
        {
          'data': {
            'id': 8,
            'nama': body['nama'],
            'poster_url': null,
            'category': {
              'id': 2,
              'slug': 'bioskop',
              'nama': 'Bioskop',
              'ikon': 'movie',
            },
            'venue': null,
            'tanggal': null,
          },
        },
        status: 201,
      );
    }

    return _jsonResponse({'error': {'code': 'NOT_FOUND', 'message': '404'}}, status: 404);
  }

  ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('EventPoster menampilkan poster cadangan saat posterUrl null',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Center(
            child: EventPoster(
              title: 'Nada Senja',
              categorySlug: 'konser-festival',
              width: 100,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nada Senja'), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets(
      'EventPickerSheet: Tambah baru -> dialog "Maksudmu ini?" -> Tetap buat event baru (force: true) di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adapter = _FakeEventAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;
    final repo = EventRepository(
      ApiClient(tokenStorage: TokenStorage(), dio: dio),
    );

    EventItem? pickedEvent;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  pickedEvent = await showEventPickerSheet(
                    context,
                    repository: repo,
                  );
                },
                child: const Text('Buka Pemilih Event'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Pemilih Event'));
    await tester.pumpAndSettle();

    expect(find.text('Nada Senja Live in Surabaya'), findsOneWidget);

    await tester.tap(find.text('Tambah baru'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Nada Senja Surabaya',
    );
    await tester.ensureVisible(find.text('Simpan Event'));
    await tester.tap(find.text('Simpan Event'));
    await tester.pumpAndSettle();

    expect(find.text('Maksudmu ini?'), findsOneWidget);
    await tester.tap(find.text('Tetap buat event baru'));
    await tester.pumpAndSettle();

    expect(adapter.forcedCalled, isTrue);
    expect(pickedEvent, isNotNull);
    expect(pickedEvent!.id, 8);
    expect(pickedEvent!.nama, 'Nada Senja Surabaya');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'EventPickerSheet: live search debounce memperbarui pencarian otomatis tanpa enter',
      (tester) async {
    final adapter = _FakeEventAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;
    final repo = EventRepository(
      ApiClient(tokenStorage: TokenStorage(), dio: dio),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEventPickerSheet(context, repository: repo),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    // Input text di kolom cari event
    await tester.enterText(find.byType(TextField).first, 'Nada');
    // Tunggu debounce 250ms selesai
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Nada Senja Live in Surabaya'), findsOneWidget);
  });
}

