import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/chat_models.dart';
import 'controllers/chat_controller.dart';
import 'chat_thread_body.dart';
import '../../../shared/presentation/unsaved_changes_guard.dart';
import '../../../shared/presentation/destination_scope.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    required this.controller,
    required this.authController,
    this.thread,
    this.task,
    super.key,
  }) : assert(thread != null || task != null);

  final ChatController controller;
  final AuthController authController;
  final ChatThread? thread;
  final ChatTaskContext? task;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver, RouteAware {
  final _leaveGuard = GlobalKey<UnsavedChangesGuardState>();
  ModalRoute<void>? _route;
  final _text = TextEditingController();
  bool _leaving = false;
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    if (widget.controller.pendingAttempt == null) {
      _leaving = false;
      await _leaveGuard.currentState?.requestLeave();
      return;
    }
    final hasDraft =
        _text.text.isNotEmpty ||
        widget.controller.pendingAttempt != null ||
        widget.controller.media?.hasImages == true;
    final leave =
        !hasDraft ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Leave conversation?'),
                content: Text(
                  widget.controller.pendingAttempt != null
                      ? 'The unresolved send stays in this session. Return to retry the same message.'
                      : 'Discard this unsent message and selected images?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    autofocus: true,
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Leave'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted) return;
    if (!leave) {
      _leaving = false;
      return;
    }
    if (widget.controller.pendingAttempt == null) {
      _text.clear();
      widget.controller.media?.clear();
    }
    await _leaveGuard.currentState?.leaveWithoutConfirmation();
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(_draftChanged);
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_clearDraftOnSessionChange);
    widget.controller.addListener(_clearDraftOnScopeChange);
    widget.controller.media?.addListener(_mediaChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.thread case final thread?) {
        await widget.controller.openThread(thread);
      } else if (widget.task case final task?) {
        await widget.controller.openTask(task);
      }
      if (!mounted) return;
      final attempt = widget.controller.pendingAttempt;
      if (attempt != null &&
          attempt.taskId == widget.controller.activeTask?.taskId &&
          attempt.counterpartyRole ==
              widget.controller.activeTask?.counterpartyRole) {
        _text.text = attempt.body;
      }
      if (_isVisible()) {
        widget.controller.startPollingThread(isVisible: _isVisible);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isVisible()) return;
      unawaited(widget.controller.refreshActive());
      widget.controller.startPollingThread(isVisible: _isVisible);
    } else {
      widget.controller.stopPolling();
    }
  }

  bool _isVisible() =>
      mounted &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      ModalRoute.of(context)?.isCurrent == true;

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    courierRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) courierRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => widget.controller.stopPolling();
  @override
  void didPopNext() {
    if (_isVisible()) {
      widget.controller.startPollingThread(isVisible: _isVisible);
    }
  }

  @override
  void dispose() {
    courierRouteObserver.unsubscribe(this);
    _text.removeListener(_draftChanged);
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_clearDraftOnSessionChange);
    widget.controller.removeListener(_clearDraftOnScopeChange);
    widget.controller.media?.removeListener(_mediaChanged);
    widget.controller.stopPolling();
    _text.dispose();
    super.dispose();
  }

  void _clearDraftOnSessionChange() {
    if (widget.authController.status != AuthStatus.authenticated) {
      _text.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  void _clearDraftOnScopeChange() {
    if (widget.controller.activeTask == null) _text.clear();
  }

  Future<void> _send() async {
    final sent = await widget.controller.sendMessage(_text.text);
    if (sent && mounted) _text.clear();
  }

  Future<void> _discardPending() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard pending retry?'),
        content: const Text(
          'The previous message may have been saved. Refresh the conversation before sending different text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard retry'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.controller.discardPendingAttempt();
      await widget.controller.refreshActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.authController]),
      builder: (context, child) {
        if (widget.authController.status != AuthStatus.authenticated) {
          return const Scaffold(body: Center(child: Text('Session ended.')));
        }
        final controller = widget.controller;
        final thread = controller.activeThread;
        final task = controller.activeTask;
        final role =
            thread?.counterpartyRole ?? task?.counterpartyRole ?? 'logistics';
        final title = switch (role) {
          'seller' => 'Seller',
          'customer' => 'Buyer',
          _ => 'Logistics',
        };
        final sendable =
            task?.canCompose == true &&
            (controller.threadStatus == ChatLoadStatus.loaded ||
                controller.threadStatus == ChatLoadStatus.empty) &&
            controller.sendStatus != ChatSendStatus.conflict &&
            (thread == null
                ? task != null &&
                      controller.threadStatus == ChatLoadStatus.empty
                : thread.sendAllowed == true);
        return UnsavedChangesGuard(
          key: _leaveGuard,
          hasUnsavedChanges:
              _text.text.isNotEmpty ||
              controller.media?.hasImages == true ||
              controller.pendingAttempt != null,
          onBack: _leave,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Message $title'),
              leading: IconButton(
                tooltip: 'Back',
                onPressed: _leave,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: ChatThreadBody(
              controller: controller,
              text: _text,
              title: title,
              sendable: sendable,
              onSend: _send,
              onDiscardPending: _discardPending,
            ),
          ),
        );
      },
    );
  }
}
