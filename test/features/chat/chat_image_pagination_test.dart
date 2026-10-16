import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show SemanticsAction;

import 'package:aisley_app/core/chat_media/attachment.dart';
import 'package:aisley_app/core/chat_media/private_image.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/chat_image_identity.dart';
import 'chat_image_fixture.dart';

void main() {
  for (final role in ['logistics', 'seller', 'customer']) {
    for (final hasMore in [false, true]) {
      testWidgets(
        '$role pagination keeps thumbnails with their message; more=$hasMore',
        (tester) async {
          final fixture = ChatImageThreadFixture(role);
          final red = imageAttachment(),
              green = imageAttachment(id: greenAssetId);
          fixture.repo.latest = ChatPage(
            items: [
              _message(2, [red]),
            ],
            nextCursor: 'older',
          );
          fixture.repo.older = ChatPage(
            items: [
              _message(1, [green], role),
              _message(2, [red]),
            ],
            nextCursor: hasMore ? 'earlier' : null,
          );
          await fixture.mount(tester);
          expect(_preview(tester, 2).bytes, same(fixture.images.red));
          final state = tester.state(_attachment(redAssetId));
          await tester.tap(find.text('Load older messages'));
          await tester.pumpAndSettle();
          expect(fixture.repo.cursors, [null, 'older']);
          expect(fixture.chat.messages.map((message) => message.sequence), [
            1,
            2,
          ]);
          expect(_preview(tester, 1).bytes, same(fixture.images.green));
          expect(_preview(tester, 2).bytes, same(fixture.images.red));
          expect(tester.state(_attachment(redAssetId)), same(state));
          expect(
            find.text('Load older messages'),
            hasMore ? findsOneWidget : findsNothing,
          );
          await tester.tap(
            find.descendant(of: _row(1), matching: find.byType(InkWell)).first,
          );
          await tester.pumpAndSettle();
          expect(
            imageProvider(tester, find.byType(AlertDialog)).bytes,
            same(fixture.images.green),
          );
          expect(fixture.images.requests.last, green.contentUrl);
          await fixture.unmount(tester);
        },
      );
    }
  }

  testWidgets(
    'bounded history trims old rows without reassigning retained images',
    (tester) async {
      final fixture = ChatImageThreadFixture('logistics');
      fixture.repo.latest = ChatPage(
        items: [
          _message(1, [imageAttachment()]),
          _message(2, [imageAttachment(id: greenAssetId)]),
          for (
            var sequence = 3;
            sequence <= ChatController.maxInMemoryMessages;
            sequence++
          )
            _message(sequence),
        ],
        nextCursor: null,
      );
      await fixture.mount(tester);
      expect(_preview(tester, 1).bytes, same(fixture.images.red));
      expect(_preview(tester, 2).bytes, same(fixture.images.green));
      final discarded = _preview(tester, 1);
      fixture.repo.latest = ChatPage(
        items: [
          _message(101, [
            imageAttachment(id: '33333333-3333-4333-8333-333333333333'),
          ]),
        ],
        nextCursor: null,
      );
      await fixture.chat.refreshActive(silent: true);
      await tester.pumpAndSettle();
      expect(fixture.chat.messages, hasLength(100));
      expect(fixture.chat.messages.first.sequence, 2);
      expect(find.text('Message 1'), findsNothing);
      expect(_preview(tester, 2).bytes, same(fixture.images.green));
      expect(
        (await discarded.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.tracked,
        isFalse,
      );
      await tester.scrollUntilVisible(
        find.text('Message 101'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(_preview(tester, 101).bytes, same(fixture.images.red));
      await fixture.unmount(tester);
    },
  );

  testWidgets(
    'attachment reorder preserves identity and text/format transitions clear images',
    (tester) async {
      final fixture = ChatImageThreadFixture('seller');
      final red = imageAttachment(), green = imageAttachment(id: greenAssetId);
      fixture.repo.latest = ChatPage(
        items: [
          _message(1, [red, green]),
        ],
        nextCursor: null,
      );
      await fixture.mount(tester);
      final redState = tester.state(_attachment(redAssetId));
      fixture.repo.latest = ChatPage(
        items: [
          _message(1, [green, red]),
        ],
        nextCursor: null,
      );
      await fixture.chat.refreshActive(silent: true);
      await tester.pumpAndSettle();
      expect(tester.state(_attachment(redAssetId)), same(redState));
      expect(
        imageProvider(tester, _attachment(redAssetId)).bytes,
        same(fixture.images.red),
      );
      expect(
        imageProvider(tester, _attachment(greenAssetId)).bytes,
        same(fixture.images.green),
      );
      final providers = [
        _preview(tester, 1, index: 0),
        _preview(tester, 1, index: 1),
      ];
      fixture.repo.latest = ChatPage(items: [_message(1)], nextCursor: null);
      await fixture.chat.refreshActive(silent: true);
      await tester.pumpAndSettle();
      expect(find.byType(PrivateChatImage), findsNothing);
      for (final provider in providers) {
        expect(
          (await provider.obtainCacheStatus(
            configuration: ImageConfiguration.empty,
          ))?.tracked,
          isFalse,
        );
      }
      fixture.repo.latest = ChatPage(
        items: [
          _message(1, [imageAttachment(kind: 'video')]),
        ],
        nextCursor: null,
      );
      await fixture.chat.refreshActive(silent: true);
      await tester.pumpAndSettle();
      expect(find.textContaining('unavailable or unsupported'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      fixture.repo.latest = ChatPage(
        items: [
          _message(1, [green]),
        ],
        nextCursor: null,
      );
      await fixture.chat.refreshActive(silent: true);
      await tester.pumpAndSettle();
      expect(_preview(tester, 1).bytes, same(fixture.images.green));
      await fixture.unmount(tester);
    },
  );

  for (final consent in [false, true]) {
    testWidgets(
      '${consent ? 'consent denial' : 'logout'} clears viewer and late paged thumbnails',
      (tester) async {
        final fixture = ChatImageThreadFixture('customer');
        final red = imageAttachment(),
            green = imageAttachment(id: greenAssetId);
        fixture.repo.latest = ChatPage(
          items: [
            _message(2, [red]),
          ],
          nextCursor: 'older',
        );
        fixture.repo.older = ChatPage(
          items: [
            _message(1, [green]),
          ],
          nextCursor: null,
        );
        await fixture.mount(tester);
        final pending = Completer<Uint8List>();
        fixture.images.responses[green.previewUrl!] = pending.future;
        await tester.tap(find.text('Load older messages'));
        await tester.pump();
        await tester.pump();
        await tester.tap(
          find.descendant(of: _row(2), matching: find.byType(InkWell)).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          imageProvider(tester, find.byType(AlertDialog)).bytes,
          same(fixture.images.red),
        );
        if (consent) {
          fixture.repo.error = const ApiException(
            message: 'Consent required',
            statusCode: 403,
            code: 'POLICY_CONSENT_REQUIRED',
          );
          await fixture.chat.refreshActive();
          expect(fixture.chat.threadStatus, ChatLoadStatus.consentRequired);
        } else {
          expect(await fixture.auth.signOut(), isTrue);
        }
        pending.complete(fixture.images.green);
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(fixture.chat.messages, isEmpty);
        expect(tester.takeException(), isNull);
        await fixture.unmount(tester);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '320px doubled-text $brightness preserves image labels and controls',
      (tester) async {
        final fixture = ChatImageThreadFixture('logistics');
        fixture.repo.latest = ChatPage(
          items: [
            _message(2, [imageAttachment()]),
          ],
          nextCursor: 'older',
        );
        fixture.repo.older = ChatPage(
          items: [
            _message(1, [imageAttachment(id: greenAssetId)]),
          ],
          nextCursor: null,
        );
        final semantics = tester.ensureSemantics();
        try {
          await fixture.mount(
            tester,
            size: const Size(320, 640),
            textScale: 2,
            brightness: brightness,
          );
          expect(find.byTooltip('Back'), findsOneWidget);
          expect(find.text('Message Logistics'), findsOneWidget);
          await tester.ensureVisible(find.text('Load older messages'));
          await tester.tap(find.text('Load older messages'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(_attachment(greenAssetId));
          await tester.pumpAndSettle();
          expect(_preview(tester, 1).bytes, same(fixture.images.green));
          final imageTap = find.descendant(
            of: _attachment(greenAssetId),
            matching: find.byType(InkWell),
          );
          final imageSemantics = tester
              .getSemantics(imageTap)
              .getSemanticsData();
          expect(imageSemantics.label, contains('View $greenAssetId.png'));
          expect(imageSemantics.hasAction(SemanticsAction.tap), isTrue);
          expect(
            tester.getSize(imageTap).shortestSide,
            greaterThanOrEqualTo(44),
          );
          await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
          await tester.pumpAndSettle();
          expect(find.text('First mile · TASK-1'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await fixture.unmount(tester);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

Finder _row(int sequence) =>
    find.byKey(ValueKey(('thread-1', 'message-$sequence')));
Finder _attachment(String id) => find.byKey(ValueKey(id));
MemoryImage _preview(WidgetTester tester, int sequence, {int index = 0}) =>
    tester
            .widget<Image>(
              find
                  .descendant(of: _row(sequence), matching: find.byType(Image))
                  .at(index),
            )
            .image
        as MemoryImage;

ChatMessage _message(
  int sequence, [
  List<ChatAttachment> attachments = const [],
  String senderRole = 'courier',
]) => ChatMessage(
  id: 'message-$sequence',
  conversationId: 'thread-1',
  sequence: sequence,
  senderRole: senderRole,
  mine: senderRole == 'courier',
  body: 'Message $sequence',
  createdAt: DateTime.utc(2026, 10, 12),
  attachments: attachments,
);
