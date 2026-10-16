part of '../policy_screen.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({
    required this.authController,
    required this.policyController,
    this.onConsentComplete,
    this.requiredForAccess = false,
    this.showSignOutAction = false,
    super.key,
  });

  final AuthController authController;
  final PolicyController policyController;
  final Future<void> Function()? onConsentComplete;
  final bool requiredForAccess;
  final bool showSignOutAction;

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen>
    with WidgetsBindingObserver {
  bool _confirmingSignOut = false;
  final Map<PolicyType, int> _confirmedVersions = <PolicyType, int>{};

  void _updateConfirmation(VoidCallback callback) => setState(callback);

  PolicyController get controller => widget.policyController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(controller.refreshIfStale());
    }
  }

  Future<void> _load() async {
    await controller.load();
    if (!mounted) {
      return;
    }
    _clearOutdatedConfirmations();
    if (controller.consentStatus?.allRequiredAccepted == true) {
      await widget.onConsentComplete?.call();
      if (!mounted) {
        return;
      }
    }
    await _closeIfSessionEnded();
  }

  void _clearOutdatedConfirmations() {
    _confirmedVersions.removeWhere((type, version) {
      return controller.consentFor(type)?.currentVersion != version;
    });
  }

  Future<void> _accept(PolicyType type) async {
    await controller.accept(type);
    if (!mounted) {
      return;
    }
    _clearOutdatedConfirmations();
    if (controller.consentStatus?.allRequiredAccepted == true) {
      await widget.onConsentComplete?.call();
      if (!mounted) {
        return;
      }
    }
    await _closeIfSessionEnded();
  }

  Future<void> _signOut() async {
    if (_confirmingSignOut || widget.authController.isSigningOut) return;
    _confirmingSignOut = true;
    final confirmed = await confirmCourierSignOut(context);
    _confirmingSignOut = false;
    if (!mounted || !confirmed) return;
    final didSignOut = await widget.authController.signOut();
    if (!mounted || didSignOut) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign out could not be completed. Your session remains active.',
        ),
      ),
    );
  }

  Future<void> _openHistory(PolicyType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyHistoryScreen(
          authController: widget.authController,
          policyController: controller,
          type: type,
        ),
      ),
    );
  }

  Future<void> _closeIfSessionEnded() async {
    if (!mounted || widget.authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Policy & consent'),
            actions: [
              if (widget.showSignOutAction)
                IconButton(
                  onPressed: widget.authController.isSigningOut
                      ? null
                      : _signOut,
                  tooltip: 'Sign out',
                  icon: widget.authController.isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                ),
            ],
          ),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = controller.state;
    if (state == PolicyViewState.signedOut ||
        state == PolicyViewState.unauthorized) {
      return const _PolicyStateView(
        icon: Icons.lock_outline,
        title: 'Sign in required',
        message: 'Sign in again to view and manage your policy consent.',
        onRetry: null,
      );
    }
    if (state == PolicyViewState.forbidden) {
      return _PolicyStateView(
        icon: Icons.support_agent_outlined,
        title: 'Policy consent is unavailable',
        message: controller.errorMessage ?? 'Your Courier account or Logistics affiliation is not currently eligible. Contact your Logistics organization for help.',
        onRetry: null,
      );
    }
    if (controller.consentStatus == null &&
        (state == PolicyViewState.loadingStatus ||
            state == PolicyViewState.loadingDocument)) {
      return const _PolicyLoadingView();
    }
    if (controller.consentStatus == null) {
      return _PolicyStateView(
        icon: Icons.policy_outlined,
        title: 'Policy information unavailable',
        message:
            controller.errorMessage ??
            'We could not load the current policies.',
        onRetry:
            controller.isBusy ||
                (state == PolicyViewState.rateLimited &&
                    !controller.canRetryRateLimit)
            ? null
            : () => controller.retry(),
      );
    }

    return _buildPolicyList(context);
  }

  Widget _buildPolicyList(BuildContext context) {
    final status = controller.consentStatus!;
    final items = status.supportedPolicies.toList(growable: false);
    final state = controller.state;
    final showRetry =
        state == PolicyViewState.timeout ||
        state == PolicyViewState.offline ||
        state == PolicyViewState.retryableError ||
        state == PolicyViewState.rateLimited ||
        state == PolicyViewState.validationError ||
        state == PolicyViewState.staleVersion;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Platform policies',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Read the current Terms of Service and Privacy Policy.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (widget.requiredForAccess) ...[
          const SizedBox(height: 16),
          const _PolicyBanner(
            message: 'Accept the required policies to continue to your work.',
            isError: false,
          ),
        ],
        if (state == PolicyViewState.loadingStatus ||
            state == PolicyViewState.loadingDocument) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (controller.successMessage != null) ...[
          const SizedBox(height: 16),
          _PolicyBanner(message: controller.successMessage!, isError: false),
        ],
        if (controller.errorMessage != null && showRetry) ...[
          const SizedBox(height: 16),
          _PolicyBanner(message: controller.errorMessage!, isError: true),
        ],
        if (controller.hasUnsupportedRequiredPolicy) ...[
          const SizedBox(height: 16),
          const _PolicyBanner(
            message: 'A required policy type is not supported by this app version. Please update the app or contact support.',
            isError: true,
          ),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _NoPublishedPolicyView()
        else
          ...items.map((item) => _buildPolicyCard(context, item)),
        if (showRetry) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                controller.isBusy ||
                    (state == PolicyViewState.rateLimited &&
                        !controller.canRetryRateLimit)
                ? null
                : () => controller.retry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh policies'),
          ),
        ],
      ],
    );
  }
}
