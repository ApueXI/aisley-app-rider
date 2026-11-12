import '../../../shared/presentation/destination_scope.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/presentation/courier_status_badge.dart';
import '../../../shared/presentation/courier_surface_card.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/chat_models.dart';
import 'controllers/chat_controller.dart';
import 'chat_thread_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({
    required this.controller,
    required this.authController,
    super.key,
  });

  final ChatController controller;
  final AuthController authController;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with WidgetsBindingObserver {
  bool _destinationVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = DestinationScope.of(context)?.visible ?? true;
    if (_destinationVisible == visible) return;
    _destinationVisible = visible;
    if (!visible) {
      widget.controller.stopPolling();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isVisible()) return;
        unawaited(widget.controller.loadInbox());
        widget.controller.startPollingInbox(isVisible: _isVisible);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_leaveOnSessionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.loadInbox());
      if (_isVisible()) {
        widget.controller.startPollingInbox(isVisible: _isVisible);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isVisible()) return;
      unawaited(widget.controller.loadInbox());
      widget.controller.startPollingInbox(isVisible: _isVisible);
    } else {
      widget.controller.stopPolling();
    }
  }

  bool _isVisible() =>
      mounted &&
      _destinationVisible &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_leaveOnSessionChange);
    widget.controller.stopPolling();
    super.dispose();
  }

  void _leaveOnSessionChange() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _open(ChatThread thread) async {
    widget.controller.stopPolling();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          controller: widget.controller,
          authController: widget.authController,
          thread: thread,
        ),
      ),
    );
    if (!mounted || widget.authController.status != AuthStatus.authenticated) {
      return;
    }
    unawaited(widget.controller.loadInbox());
    if (_isVisible()) {
      widget.controller.startPollingInbox(isVisible: _isVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.authController]),
      builder: (context, child) {
        final controller = widget.controller;
        if (widget.authController.status != AuthStatus.authenticated) {
          return const Scaffold(body: Center(child: Text('Session ended.')));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Task messages')),
          body: RefreshIndicator(
            onRefresh: controller.loadInbox,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.inboxStatus == ChatLoadStatus.loading &&
                    controller.threads.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                if (controller.inboxError case final error?)
                  _ChatInboxNotice(
                    message: error,
                    onRetry: controller.canRetry ? controller.loadInbox : null,
                  ),
                if (controller.inboxStatus == ChatLoadStatus.empty)
                  const _ChatInboxNotice(
                    message: 'No task conversations yet. Open an eligible task to message Logistics.',
                  ),
                for (final thread in controller.threads) ...[
                  _ChatInboxRow(thread: thread, onTap: () => _open(thread)),
                  const SizedBox(height: 10),
                ],
                if (controller.canLoadMoreInbox)
                  OutlinedButton(
                    onPressed: controller.loadingMoreInbox
                        ? null
                        : controller.loadMoreInbox,
                    child: Text(
                      controller.loadingMoreInbox
                          ? 'Loading…'
                          : 'Load older conversations',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatInboxRow extends StatelessWidget {
  const _ChatInboxRow({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = thread.counterpartyLabel ?? _label(thread.counterpartyRole);
    final reference =
        thread.taskReference ??
        thread.orderReference ??
        'Task reference unavailable';
    final unreadLabel = thread.unreadCount == 0
        ? 'Read'
        : '${thread.unreadCount} unread';

    return Semantics(
      button: true,
      label: '$title, $reference, $unreadLabel. Open task conversation.',
      child: CourierSurfaceCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _counterpartyIcon(thread.counterpartyRole),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (thread.lastMessageAt case final sentAt?) ...[
                  const SizedBox(width: 8),
                  Text(
                    _chatTime(context, sentAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(reference, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CourierStatusBadge(
                  label: thread.leg == 'first_mile'
                      ? 'First mile'
                      : 'Final mile',
                  tone: CourierStatusTone.info,
                ),
                CourierStatusBadge(
                  label: unreadLabel,
                  tone: thread.unreadCount == 0
                      ? CourierStatusTone.neutral
                      : CourierStatusTone.warning,
                ),
                if (thread.sendAllowed == false)
                  const CourierStatusBadge(label: 'Read-only'),
              ],
            ),
            if (thread.lastMessagePreview case final preview?) ...[
              const SizedBox(height: 10),
              Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

String _label(String role) => switch (role) {
  'customer' => 'Buyer',
  'seller' => 'Seller',
  _ => 'Logistics',
};

IconData _counterpartyIcon(String role) => switch (role) {
  'logistics' => Icons.hub_outlined,
  'seller' => Icons.storefront_outlined,
  'customer' => Icons.person_outline,
  _ => Icons.chat_bubble_outline,
};

String _chatTime(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));
}

class _ChatInboxNotice extends StatelessWidget {
  const _ChatInboxNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
