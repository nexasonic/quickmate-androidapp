import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickmate/core/app_theme.dart';
import 'package:quickmate/core/storage_service.dart';
import 'package:quickmate/my_cards_screen.dart';

class _MockHttpOverrides extends HttpOverrides {
  final List<Map<String, dynamic>> postedCards = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient(postedCards);
  }
}

class _MockHttpClient implements HttpClient {
  final List<Map<String, dynamic>> postedCards;
  _MockHttpClient(this.postedCards);

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest(method, url, postedCards);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final String method;
  final Uri url;
  final List<Map<String, dynamic>> postedCards;
  final List<int> _bodyBytes = [];
  final Completer<HttpClientResponse> _doneCompleter = Completer<HttpClientResponse>();

  _MockHttpClientRequest(this.method, this.url, this.postedCards);

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Encoding encoding = utf8;

  @override
  bool bufferOutput = true;

  @override
  int contentLength = -1;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  Uri get uri => url;

  @override
  Future<HttpClientResponse> get done => _doneCompleter.future;

  @override
  void add(List<int> data) => _bodyBytes.addAll(data);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    late final HttpClientResponse response;
    if (method == 'POST' && url.path.endsWith('/my-cards/live-work')) {
      final decoded = jsonDecode(utf8.decode(_bodyBytes)) as Map<String, dynamic>;
      postedCards.add(decoded);
      response = _MockHttpClientResponse(
        201,
        jsonEncode({'success': true, 'message': 'Created', 'data': {'id': 99}}),
      );
    } else if (url.path.endsWith('/categories')) {
      response = _MockHttpClientResponse(
        200,
        jsonEncode({
          'success': true,
          'data': [
            {'id': 1, 'name': 'Driving', 'type': 'live-work'},
            {'id': 2, 'name': 'Plumbing', 'type': 'live-work'},
            {'id': 3, 'name': 'Electrical', 'type': 'live-work'},
          ],
        }),
      );
    } else if (url.path.endsWith('/my-cards')) {
      response = _MockHttpClientResponse(
        200,
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 10,
              'title': 'Existing Plumbing Card',
              'description': 'Fix pipes',
              'price': 350,
              'price_type': 'per_hour',
              'status': 1,
              'category': {'id': 2, 'name': 'Plumbing', 'type': 'live-work'},
            },
          ],
        }),
      );
    } else {
      response = _MockHttpClientResponse(200, jsonEncode({'success': true, 'data': []}));
    }

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(response);
    }
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> _bytes;

  _MockHttpClientResponse(this.statusCode, String body) : _bytes = utf8.encode(body);

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _MockHttpOverrides mockHttp;

  setUp(() async {
    mockHttp = _MockHttpOverrides();
    HttpOverrides.global = mockHttp;
    SharedPreferences.setMockInitialValues({'auth_token': 'mock-token'});
    await StorageService.init();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  Widget buildTestApp() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const MyCardsScreen(),
    );
  }

  testWidgets('Create Live Work Card uses Choose one defaults, full-size category picker, and required validation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Open Create Live Work Card modal
    await tester.tap(find.text('Create Card'));
    await tester.pumpAndSettle();

    expect(find.text('Create Live Work Card'), findsOneWidget);

    // Neither Category nor Budget Type should pre-select the first option; both must display "Choose one"
    expect(find.text('Choose one'), findsNWidgets(2));
    expect(find.text('Driving'), findsNothing);
    expect(find.text('Negotiable'), findsNothing);
    expect(find.text('PRICE / AMOUNT (INR) *'), findsNothing);
    expect(find.textContaining('PRICE / AMOUNT (INR)', findRichText: true), findsNothing);

    // Expiry Time retains default
    expect(find.text('24 hours (Default)'), findsOneWidget);

    // Enter Task Title
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Need a Plumber for kitchen leak repair'),
      'Fix kitchen sink pipe',
    );
    await tester.pump();

    // Try submitting without selecting Category -> must warn and not submit
    await tester.ensureVisible(find.text('Publish Card'));
    await tester.tap(find.text('Publish Card'));
    await tester.pump();
    expect(find.text('Please select a Category.'), findsOneWidget);
    expect(mockHttp.postedCards, isEmpty);

    // Let auto-dismiss toast timer finish cleanly
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Tap Category box ("Choose one") to open full-size category selection view
    await tester.ensureVisible(find.textContaining('CATEGORY', findRichText: true));
    await tester.tap(find.text('Choose one').first);
    await tester.pumpAndSettle();

    // Verify full-size view fills the screen and lists categories + search
    expect(find.text('Select category'), findsOneWidget);
    final scaffoldBox = tester.getSize(find.byType(Scaffold).last);
    expect(scaffoldBox.width, equals(412));
    expect(scaffoldBox.height, equals(915));
    expect(find.text('Driving'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);

    // Test search filtering in full-size category view
    await tester.enterText(
      find.widgetWithText(TextField, 'Search categories...'),
      'Plumb',
    );
    await tester.pump();
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Driving'), findsNothing);

    // Select Plumbing
    await tester.tap(find.text('Plumbing'));
    await tester.pumpAndSettle();

    // Back in Create Live Work Card: Category is now "Plumbing", Budget Type still "Choose one"
    expect(find.text('Create Live Work Card'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('Plumbing')),
      findsOneWidget,
    );
    expect(find.text('Choose one'), findsOneWidget);

    // Try submitting without choosing Budget Type -> must warn and not submit
    await tester.ensureVisible(find.text('Publish Card'));
    await tester.tap(find.text('Publish Card'));
    await tester.pump();
    expect(find.text('Please select a Budget Type.'), findsOneWidget);
    expect(mockHttp.postedCards, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Select Budget Type -> Fixed Price
    await tester.ensureVisible(find.textContaining('BUDGET TYPE', findRichText: true));
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixed Price').last);
    await tester.pumpAndSettle();

    // Price field now appears
    expect(find.textContaining('PRICE / AMOUNT (INR)', findRichText: true), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 500'), '750');
    await tester.pump();

    // Publish Card succeeds now that required selections are chosen
    await tester.ensureVisible(find.text('Publish Card'));
    await tester.tap(find.text('Publish Card'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(mockHttp.postedCards, hasLength(1));
    expect(mockHttp.postedCards.first['title'], equals('Fix kitchen sink pipe'));
    expect(mockHttp.postedCards.first['category_id'], equals(2));
    expect(mockHttp.postedCards.first['price_type'], equals('fixed'));
    expect(mockHttp.postedCards.first['price'], equals(750.0));
  });

  testWidgets('Edit Live Work Card pre-populates existing Category and Budget Type', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Card'), findsOneWidget);
    expect(find.text('Choose one'), findsNothing);
    expect(find.text('Plumbing'), findsWidgets);
    expect(find.text('Per Hour'), findsOneWidget);
    expect(find.textContaining('PRICE / AMOUNT (INR)', findRichText: true), findsOneWidget);
  });
}
