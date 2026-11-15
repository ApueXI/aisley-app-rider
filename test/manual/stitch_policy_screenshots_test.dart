import 'dart:io';
import 'dart:ui' as ui;

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_batch_acceptance.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';
import 'package:aisley_app/features/policy/presentation/controllers/policy_controller.dart';
import 'package:aisley_app/features/policy/presentation/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/fixtures/registration_screen_fixture.dart';

const _captureEnabled = bool.fromEnvironment(
  'CAPTURE_STITCH_IDENTITY',
  defaultValue: false,
);
const _captureDirectory = String.fromEnvironment(
  'STITCH_CAPTURE_DIRECTORY',
  defaultValue: 'build/stitch-ui/policy',
);
const _sdkFonts = String.fromEnvironment(
  'FLUTTER_FONT_DIR',
  defaultValue: '/home/cred/develop/flutter/bin/cache/artifacts/material_fonts',
);

void main() {
  if (!_captureEnabled) return;

  setUpAll(() async {
    final body = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      body.addFont(
        File('$_sdkFonts/$file')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await body.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$_sdkFonts/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });

  testWidgets('captures current policy consent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authFixture = RegistrationScreenFixture();
    final auth = authFixture.auth..status = AuthStatus.authenticated;
    final policy = PolicyController(policyApi: _ScreenshotPolicyApi());
    final boundary = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(Brightness.light),
        home: _CaptureRouteLauncher(
          boundary: boundary,
          screen: PolicyScreen(
            authController: auth,
            policyController: policy,
            requiredForAccess: true,
            showSignOutAction: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Review current policies'), findsOneWidget);
    await _capture(tester, boundary, 'policies-consent');
    final policyList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Privacy Policy'),
      420,
      scrollable: policyList,
    );
    await tester.scrollUntilVisible(
      find.text('Your confirmation'),
      420,
      scrollable: policyList,
    );
    for (
      var attempt = 0;
      attempt < 8 && find.byType(CheckboxListTile).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(policyList, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((tile) => tile.value),
      [false, false],
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Accept'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, boundary, 'policies-consent-confirmation');
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    policy.dispose();
  });
}

class _CaptureRouteLauncher extends StatefulWidget {
  const _CaptureRouteLauncher({required this.boundary, required this.screen});

  final GlobalKey boundary;
  final Widget screen;

  @override
  State<_CaptureRouteLauncher> createState() => _CaptureRouteLauncherState();
}

class _CaptureRouteLauncherState extends State<_CaptureRouteLauncher> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RepaintBoundary(key: widget.boundary, child: widget.screen),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(_captureDirectory);
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}

class _ScreenshotPolicyApi implements PolicyApi {
  @override
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    return _document(type);
  }

  @override
  Future<PolicyHistory> fetchHistory(
    PolicyType type, {
    bool forceRefresh = false,
  }) async =>
      PolicyHistory(type: type, label: type.fallbackLabel, versions: const []);

  @override
  Future<PolicyDocument> fetchHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  }) async => _document(type, version: version);

  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async =>
      const PolicyConsentStatus(
        policies: [
          PolicyConsentItem(
            rawType: 'terms_of_service',
            label: 'Terms of Service',
            required: true,
            accepted: false,
            acceptedAt: null,
            currentVersion: 3,
            acceptedVersion: null,
          ),
          PolicyConsentItem(
            rawType: 'privacy_policy',
            label: 'Privacy Policy',
            required: true,
            accepted: false,
            acceptedAt: null,
            currentVersion: 2,
            acceptedVersion: null,
          ),
        ],
        allRequiredAccepted: false,
      );

  @override
  Future<PolicyAcceptance> accept({
    required PolicyType type,
    required int version,
  }) async => throw StateError('Screenshot only');

  @override
  Future<PolicyBatchAcceptance> acceptTogether(
    Map<PolicyType, int> versions,
  ) async => throw StateError('Screenshot only');

  @override
  void clearPublicCache() {}
}

PolicyDocument _document(PolicyType type, {int? version}) {
  final number = version ?? (type == PolicyType.termsOfService ? 3 : 2);
  return PolicyDocument(
    type: type,
    label: type.fallbackLabel,
    version: PolicyVersion(
      id: 'screenshot-${type.apiValue}-$number',
      version: number,
      title: type.fallbackLabel,
      content: List.filled(
        8,
        'Neutral demonstration text used only by the screenshot fixture; this is not an AISLEY policy.',
      ).join('\n\n'),
      status: 'published',
      changeSummary: null,
      requiresReconsent: true,
      publishedAt: DateTime.utc(2026, 11, 1),
    ),
  );
}
