part of 'api_client.dart';

extension PrivateMediaTransport on ApiClient {
  Future<Uint8List> privateMediaBytes(
    String url, {
    required int maxBytes,
    required String mimeType,
    required bool Function() isCurrent,
    required Future<void> cancelled,
    int? expectedBytes,
  }) async {
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    unawaited(cancelled.then((_) => cancel()));
    final timer = Timer(const Duration(seconds: 60), cancel);
    try {
      if (!isCurrent()) throw const FormatException('Access ended.');
      final token = await _tokenStorage.read();
      if (!isCurrent()) throw const FormatException('Access ended.');
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'A valid session is required.',
        );
      }
      final request =
          http.AbortableRequest(
              'GET',
              _resolveServerUrl(url),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Accept': mimeType,
              'Cache-Control': 'no-store',
            });
      final response = await _client.send(request).timeout(requestTimeout);
      if (response.statusCode != 200) {
        final error = BytesBuilder(copy: false);
        if (response.statusCode >= 400) {
          await for (final chunk in response.stream.timeout(requestTimeout)) {
            if (!isCurrent() || error.length + chunk.length > 65536) break;
            error.add(chunk);
          }
        }
        cancel();
        throw ApiException.fromResponse(
          http.Response.bytes(
            error.takeBytes(),
            response.statusCode,
            headers: response.headers,
          ),
        );
      }
      final type = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final lengthHeader = response.headers['content-length'];
      final length = lengthHeader == null ? null : int.tryParse(lengthHeader);
      if ((mimeType == 'image/*'
              ? !const ['image/jpeg', 'image/png', 'image/webp'].contains(type)
              : type != mimeType) ||
          (lengthHeader != null && length == null) ||
          (length != null &&
              (length < 1 ||
                  length > maxBytes ||
                  expectedBytes != null && length != expectedBytes))) {
        throw const FormatException('Invalid media response.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(requestTimeout)) {
        if (!isCurrent() ||
            abort.isCompleted ||
            builder.length + chunk.length > maxBytes ||
            expectedBytes != null &&
                builder.length + chunk.length > expectedBytes) {
          throw const FormatException('Media unavailable.');
        }
        builder.add(chunk);
      }
      if (!isCurrent() ||
          abort.isCompleted ||
          builder.isEmpty ||
          length != null && builder.length != length ||
          expectedBytes != null && builder.length != expectedBytes) {
        throw const FormatException('Incomplete media.');
      }
      return builder.takeBytes();
    } on http.ClientException {
      throw const ApiException.network('Attachment unavailable.');
    } on TimeoutException {
      throw const ApiException.network('Attachment request timed out.');
    } finally {
      timer.cancel();
      cancel();
    }
  }
}
