import 'dart:async';
import 'dart:typed_data';

import 'package:aisley_app/core/chat_media/private_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chat_image_identity.dart';

void main() {
  testWidgets(
    'replacement evicts old bytes and equivalent DTOs do not reload',
    (tester) async {
      final repo = IdentityMediaFake();
      final controller = ObservableMediaController(repo);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      final oldProvider = _provider(tester);
      expect(oldProvider.bytes, same(repo.red));
      expect(
        (await oldProvider.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.tracked,
        isTrue,
      );

      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      expect(repo.requests, hasLength(1));
      expect(_provider(tester), same(oldProvider));

      await tester.pumpWidget(_page(controller, id: greenAssetId));
      await tester.pumpAndSettle();
      expect(_provider(tester).bytes, same(repo.green));
      expect(
        (await oldProvider.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.tracked,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('changed URL and state under the same ID reload the preview', (
    tester,
  ) async {
    final repo = IdentityMediaFake();
    final controller = ObservableMediaController(repo);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.pumpAndSettle();
    final newUrl = imageAttachment(id: greenAssetId).previewUrl!;
    await tester.pumpWidget(_page(controller, preview: newUrl));
    await tester.pumpAndSettle();
    expect(_provider(tester).bytes, same(repo.green));
    await tester.pumpWidget(
      _page(controller, preview: newUrl, state: 'deleted'),
    );
    await tester.pumpAndSettle();
    expect(repo.requests, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kind in ['video', 'document']) {
    testWidgets('image to $kind and back clears and reloads the preview', (
      tester,
    ) async {
      final repo = IdentityMediaFake();
      final controller = ObservableMediaController(repo);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      final oldProvider = _provider(tester);
      await tester.pumpWidget(_page(controller, kind: kind));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('not supported yet'), findsOneWidget);
      expect(
        (await oldProvider.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.tracked,
        isFalse,
      );
      await tester.pumpWidget(_page(controller, id: greenAssetId));
      await tester.pumpAndSettle();
      expect(_provider(tester).bytes, same(repo.green));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final fail in [false, true]) {
    testWidgets(
      'obsolete ${fail ? 'failure' : 'success'} cannot replace a new load',
      (tester) async {
        final repo = IdentityMediaFake();
        final oldResponse = Completer<Uint8List>();
        final newResponse = Completer<Uint8List>();
        repo.responses[imageAttachment().previewUrl!] = oldResponse.future;
        repo.responses[imageAttachment(id: greenAssetId).previewUrl!] =
            newResponse.future;
        final controller = ObservableMediaController(repo);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_page(controller));
        await tester.pumpWidget(_page(controller, id: greenAssetId));
        if (fail) {
          oldResponse.completeError(StateError('obsolete'));
        } else {
          oldResponse.complete(repo.red);
        }
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('unavailable'), findsNothing);
        newResponse.complete(repo.green);
        await tester.pumpAndSettle();
        expect(_provider(tester).bytes, same(repo.green));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'controller replacement ignores late ${fail ? 'failure' : 'success'}',
      (tester) async {
        final oldRepo = IdentityMediaFake();
        final newRepo = IdentityMediaFake();
        final pending = Completer<Uint8List>();
        oldRepo.responses[imageAttachment().previewUrl!] = pending.future;
        final oldController = ObservableMediaController(oldRepo);
        final newController = ObservableMediaController(newRepo);
        addTearDown(oldController.dispose);
        addTearDown(newController.dispose);
        expect(
          oldController.privateGeneration,
          newController.privateGeneration,
        );
        await tester.pumpWidget(_page(oldController));
        await tester.pumpWidget(_page(newController));
        await tester.pumpAndSettle();
        expect(oldController.listening, isFalse);
        oldController.clear();
        if (fail) {
          pending.completeError(StateError('old controller'));
        } else {
          pending.complete(oldRepo.green);
        }
        await tester.pumpAndSettle();
        expect(_provider(tester).bytes, same(newRepo.red));
        expect(find.textContaining('unavailable'), findsNothing);
        newController.clear();
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(find.text('Image access ended.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(newController.listening, isFalse);
      },
    );

    testWidgets(
      'scope loss blocks late ${fail ? 'failure' : 'success'} and attachment updates',
      (tester) async {
        final repo = IdentityMediaFake();
        final pending = Completer<Uint8List>();
        repo.responses[imageAttachment().previewUrl!] = pending.future;
        final controller = ObservableMediaController(repo);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_page(controller));
        controller.clear();
        await tester.pumpWidget(_page(controller, id: greenAssetId));
        if (fail) {
          pending.completeError(StateError('scope ended'));
        } else {
          pending.complete(repo.red);
        }
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(find.text('Image access ended.'), findsOneWidget);
        expect(find.text('Retry image'), findsNothing);
        expect(repo.requests, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'disposal ignores outstanding requests and evicts image providers',
    (tester) async {
      final repo = IdentityMediaFake();
      final controller = ObservableMediaController(repo);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      final provider = _provider(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        (await provider.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.tracked,
        isFalse,
      );
      final pending = Completer<Uint8List>();
      repo.responses[imageAttachment().previewUrl!] = pending.future;
      await tester.pumpWidget(_page(controller));
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(repo.red);
      await tester.pumpAndSettle();
      expect(controller.listening, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'current failure allows explicit retry of the current attachment',
    (tester) async {
      final repo = IdentityMediaFake();
      final pending = Completer<Uint8List>();
      final url = imageAttachment().previewUrl!;
      repo.responses[url] = pending.future;
      final controller = ObservableMediaController(repo);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Retry when connected'), findsOneWidget);
      repo.responses.remove(url);
      await tester.tap(find.text('Retry image'));
      await tester.pumpAndSettle();
      expect(_provider(tester).bytes, same(repo.red));
      expect(repo.requests, [url, url]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'viewer uses current content and clears both images on scope loss',
    (tester) async {
      final repo = IdentityMediaFake();
      final controller = ObservableMediaController(repo);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_page(controller, id: greenAssetId));
      await tester.pumpAndSettle();
      final openViewer = tester
          .widget<InkWell>(find.byType(InkWell).first)
          .onTap!;
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      final viewer = find.byType(AlertDialog);
      expect(imageProvider(tester, viewer).bytes, same(repo.green));
      expect(repo.requests.last, imageAttachment(id: greenAssetId).contentUrl);
      final providers = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image as MemoryImage)
          .toList();
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Image access ended.'), findsNWidgets(2));
      for (final provider in providers) {
        expect(
          (await provider.obtainCacheStatus(
            configuration: ImageConfiguration.empty,
          ))?.tracked,
          isFalse,
        );
      }
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      final requests = repo.requests.length;
      openViewer();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.requests, hasLength(requests));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _page(
  ObservableMediaController controller, {
  String id = redAssetId,
  String kind = 'image',
  String state = 'ready',
  String? preview,
}) => MaterialApp(
  home: Scaffold(
    body: PrivateChatImage(
      attachment: imageAttachment(
        id: id,
        kind: kind,
        state: state,
        preview: preview,
      ),
      controller: controller,
    ),
  ),
);

MemoryImage _provider(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image as MemoryImage;
