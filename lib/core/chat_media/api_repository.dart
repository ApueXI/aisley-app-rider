import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../networking/api_client.dart';
import '../networking/multipart_file_selection.dart';
import '../security/token_storage.dart';
import 'attachment.dart';
import 'content_repository.dart';

class ApiChatMediaRepository
    implements ChatMediaRepository, ChatMediaContentRepository {
  ApiChatMediaRepository(this.client, {this.onDenial, this.generation});
  final ApiClient client;
  final int Function()? generation;
  final Future<void> Function(ApiException)? onDenial;
  static const base = '/courier/chat-attachments';
  Future<T> _call<T>(Future<T> Function() action) async {
    final stamp = generation?.call();
    try {
      return await action();
    } on ApiException catch (e) {
      if ((e.statusCode == 401 || e.statusCode == 403) &&
          stamp == generation?.call()) {
        await onDenial?.call(e);
      }
      throw ChatMediaFailure(
        'Image request failed. Retry when connected.',
        status: e.statusCode,
        retryAfter: e.retryAfter,
      );
    } on TokenStorageException {
      throw const ChatMediaFailure(
        'Secure session storage is unavailable.',
        status: 401,
      );
    } on FormatException {
      throw const ChatMediaFailure(
        'The image response was not understood. Retry the original request.',
      );
    }
  }

  Future<ChatAttachment> _json(String method, String path) => _call(() async {
    final response = method == 'GET'
        ? await client.get(path, authenticated: true)
        : await client.postJson(path, authenticated: true);
    return ChatAttachment.parse((jsonDecode(response.body) as Map)['data']);
  });
  @override
  Future<bool> capabilities() => _call(() async {
    final value = jsonDecode(
      (await client.get(base, authenticated: true)).body,
    );
    final data = value is Map ? value['data'] : null;
    if (data is! Map || data['enabled'] is! bool) throw const FormatException();
    return data['enabled'] as bool;
  });
  @override
  Future<SelectedChatImage?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Chat image',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        ),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length < 1 || length > 8000000) {
      throw const ChatMediaFailure(
        'Choose an image at most 8 MB (8,000,000 bytes).',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final bytes in file.openRead(0, length)) {
      if (builder.length + bytes.length > 8000000) {
        throw const ChatMediaFailure(
          'Choose an image at most 8 MB (8,000,000 bytes).',
        );
      }
      builder.add(bytes);
    }
    final bytes = builder.takeBytes();
    if (bytes.length != length || await file.length() != length) {
      throw const ChatMediaFailure('The file changed. Select it again.');
    }
    final mime = switch (file.name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => '',
    };
    return SelectedChatImage(bytes, file.name, mime);
  }

  @override
  Future<ChatAttachment> upload(
    SelectedChatImage image,
    Map<String, Object?> context,
    String key,
  ) => _call(() async {
    final response = await client.postMultipart(
      base,
      fields: {'context': jsonEncode(context)},
      files: {
        'file': MultipartFileSelection(
          path: null,
          fileName: image.filename,
          bytes: image.bytes,
        ),
      },
      authenticated: true,
      requestHeaders: {'Idempotency-Key': key},
    );
    return ChatAttachment.parse((jsonDecode(response.body) as Map)['data']);
  });
  @override
  Future<ChatAttachment> status(String id) => _json('GET', '$base/$id');
  @override
  Future<ChatAttachment> retry(String id) => _json('POST', '$base/$id/retry');
  @override
  Future<void> remove(String id) => _call(() async {
    await client.delete('$base/$id', authenticated: true);
  });
  @override
  Future<Uint8List> image(String url) => _call(() async {
    chatImagePath(url, 'courier');
    final read = ChatMediaRead();
    final stamp = generation?.call();
    try {
      return await client.privateMediaBytes(
        url,
        maxBytes: 10485759,
        mimeType: 'image/*',
        isCurrent: () => read.isCurrent && stamp == generation?.call(),
        cancelled: read.cancelled,
      );
    } finally {
      read.cancel();
    }
  });
  @override
  Future<Uint8List> content(
    ChatAttachment attachment,
    ChatMediaRead read, {
    bool preview = false,
  }) => _call(() async {
    attachmentPath(attachment, 'courier', preview);
    final stamp = generation?.call();
    return client.privateMediaBytes(
      preview ? attachment.previewUrl! : attachment.contentUrl!,
      maxBytes: preview ? 10485759 : historicalMediaLimit(attachment),
      mimeType: preview ? 'image/jpeg' : attachment.mimeType,
      expectedBytes: preview ? null : attachment.byteSize,
      isCurrent: () => read.isCurrent && stamp == generation?.call(),
      cancelled: read.cancelled,
    );
  });
}
