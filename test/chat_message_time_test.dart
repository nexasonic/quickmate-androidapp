import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickmate/chat_detail_screen.dart';
import 'package:quickmate/core/app_theme.dart';
import 'package:quickmate/core/storage_service.dart';
import 'package:quickmate/models/chat_model.dart';

class _MockChatHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockChatHttpClient();
}

class _MockChatHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockChatHttpRequest(method, url);
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

class _MockChatHttpRequest implements HttpClientRequest {
  @override
  final String method;
  final Uri url;
  final List<int> _bodyBytes = [];
  final Completer<HttpClientResponse> _doneCompleter = Completer<HttpClientResponse>();

  _MockChatHttpRequest(this.method, this.url);

  @override
  final HttpHeaders headers = _MockChatHttpHeaders();

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
    if (method == 'POST' && url.path.endsWith('/messages')) {
      final decoded = jsonDecode(utf8.decode(_bodyBytes)) as Map<String, dynamic>;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      response = _MockChatHttpResponse(
        201,
        jsonEncode({
          'success': true,
          'data': {
            'id': 202,
            'conversation_id': 1,
            'sender_id': 1,
            'is_from_me': true,
            'body': decoded['body'],
            // Simulate backend POST response omitting created_at_human and sending ISO UTC with 000000Z
            'created_at': '${nowIso.split('.').first}.000000Z',
          },
        }),
      );
    } else if (url.path.endsWith('/messages')) {
      response = _MockChatHttpResponse(
        200,
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 201,
              'conversation_id': 1,
              'sender_id': 1,
              'is_from_me': true,
              'body': 'hi',
              'created_at': '2026-11-27T12:34:43.000000Z',
              'created_at_human': '11 seconds ago',
            },
          ],
        }),
      );
    } else {
      response = _MockChatHttpResponse(200, jsonEncode({'success': true, 'data': {}}));
    }

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(response);
    }
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockChatHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockChatHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> _bytes;

  _MockChatHttpResponse(this.statusCode, String body) : _bytes = utf8.encode(body);

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _MockChatHttpHeaders();

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
  test('ChatMessageModel formats raw ISO created_at when created_at_human is missing or ISO', () {
    final nowUtc = DateTime.now().toUtc();
    final freshIso = '${nowUtc.toIso8601String().split('.').first}.000000Z';

    final msgMissingHuman = ChatMessageModel.fromJson({
      'id': 1,
      'conversation_id': 10,
      'sender_id': 2,
      'is_from_me': true,
      'body': 'Hi',
      'created_at': freshIso,
    });
    expect(msgMissingHuman.createdAtHuman, equals('Just now'));
    expect(msgMissingHuman.createdAtHuman, isNot(contains('000000Z')));

    final msgIsoInHuman = ChatMessageModel.fromJson({
      'id': 2,
      'conversation_id': 10,
      'sender_id': 2,
      'is_from_me': true,
      'body': 'Hi',
      'created_at_human': freshIso,
    });
    expect(msgIsoInHuman.createdAtHuman, equals('Just now'));

    final msgWithServerHuman = ChatMessageModel.fromJson({
      'id': 3,
      'conversation_id': 10,
      'sender_id': 2,
      'is_from_me': true,
      'body': 'hi',
      'created_at': '2026-11-27T12:34:43.000000Z',
      'created_at_human': '11 seconds ago',
    });
    expect(msgWithServerHuman.createdAtHuman, equals('11 seconds ago'));

    final fixedNow = DateTime.utc(2026, 11, 27, 12, 40, 0).toLocal();
    expect(
      ChatMessageModel.formatCreatedAtHuman(null, '2026-11-27T12:35:00.000000Z', now: fixedNow),
      equals('5 m ago'),
    );
  });

  testWidgets('ChatDetailScreen displays Just now instead of raw 000000Z after sending a message', (tester) async {
    HttpOverrides.global = _MockChatHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);

    SharedPreferences.setMockInitialValues({'auth_token': 'mock-token'});
    await StorageService.init();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ChatDetailScreen(
          conversationId: 1,
          chatData: {'id': '2', 'name': 'MUSICAFE'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('11 seconds ago'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
    expect(find.textContaining('000000Z'), findsNothing);
    expect(find.textContaining('T12:'), findsNothing);
  });
}
