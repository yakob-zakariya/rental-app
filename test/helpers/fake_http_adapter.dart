import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A stand-in for dio's real network layer in tests.
///
/// Each request gets the next queued reply: either a response
/// ([FakeHttpAdapter.reply]) or an error ([FakeHttpAdapter.fail]).
/// Every request is recorded in [requests].
class FakeHttpAdapter implements HttpClientAdapter {
  final _replies = <_Reply>[];
  final requests = <RequestOptions>[];

  /// Queues a response. [json] is encoded as the body (omit it for no body).
  void reply(
    int statusCode, {
    Object? json,
    String? text,
    Map<String, List<String>> headers = const {},
  }) {
    _replies.add(
      _Reply(
        statusCode: statusCode,
        body: json != null ? jsonEncode(json) : (text ?? ''),
        headers: {
          if (json != null)
            Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      ),
    );
  }

  /// Queues a failure: [build] receives the request and returns the error.
  void fail(DioException Function(RequestOptions options) build) {
    _replies.add(_Reply(error: build));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_replies.isEmpty) {
      throw StateError('FakeHttpAdapter: no reply queued for ${options.path}');
    }
    final reply = _replies.removeAt(0);
    if (reply.error != null) throw reply.error!(options);
    return ResponseBody.fromString(
      reply.body!,
      reply.statusCode!,
      headers: reply.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Reply {
  _Reply({this.statusCode, this.body, this.headers = const {}, this.error});

  final int? statusCode;
  final String? body;
  final Map<String, List<String>> headers;
  final DioException Function(RequestOptions options)? error;
}
