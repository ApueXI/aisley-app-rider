import 'dart:convert';
import 'dart:typed_data';

import 'package:aisley_app/core/chat_media/attachment.dart';
import 'package:aisley_app/core/chat_media/draft_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_media_fake.dart';

const redAssetId = '11111111-1111-4111-8111-111111111111';
const greenAssetId = '22222222-2222-4222-8222-222222222222';

ChatAttachment imageAttachment({
  String id = redAssetId,
  String kind = 'image',
  String state = 'ready',
  String? preview,
}) => ChatAttachment(
  id: id,
  kind: kind,
  filename: '$id.png',
  mimeType: 'image/png',
  byteSize: 80,
  state: state,
  previewUrl: preview ?? '/api/v1/courier/chat-attachments/$id/preview',
  contentUrl: '/api/v1/courier/chat-attachments/$id/content',
);

class IdentityMediaFake extends MediaFake {
  final red = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAEklEQVR4nGP4z8DwHx9mGBkKAMLXf4EvceABAAAAAElFTkSuQmCC',
  );
  final green = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAD0lEQVR4nGNg+E8AjgwFAIMXf4H6lHc8AAAAAElFTkSuQmCC',
  );
  final requests = <String>[];
  final responses = <String, Future<Uint8List>>{};

  @override
  Future<Uint8List> image(String url) async {
    requests.add(url);
    return responses[url] ?? (url.contains(greenAssetId) ? green : red);
  }
}

MemoryImage imageProvider(WidgetTester tester, Finder within) =>
    tester
            .widget<Image>(
              find.descendant(of: within, matching: find.byType(Image)),
            )
            .image
        as MemoryImage;

class ObservableMediaController extends ChatMediaDraftController {
  ObservableMediaController(super.repository);
  bool get listening => hasListeners;
}
