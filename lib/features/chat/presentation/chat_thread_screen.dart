import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/chat_models.dart';
import '../../../core/chat_media/image_widgets.dart';
import 'controllers/chat_controller.dart';
import 'chat_message_row.dart';

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
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  bool _allowPop = false, _leaving = false;
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final hasDraft =
        _text.text.isNotEmpty ||
        widget.controller.pendingAttempt != null ||
        widget.controller.media?.hasImages == true;
    final leave =
        !hasDraft ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Leave conversation?'),
                content: Text(
                  widget.controller.pendingAttempt != null
                      ? 'The unresolved send stays in this session. Return to retry the same message.'
                      : 'Discard this unsent message and selected images?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
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
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
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
        return PopScope(
          canPop:
              _allowPop ||
              _text.text.isEmpty &&
                  controller.pendingAttempt == null &&
                  controller.media?.hasImages != true,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('Message $title'),
              leading: IconButton(
                tooltip: 'Back',
                onPressed: _leave,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: Column(
              children: [
                ListTile(
                  title: Text(thread?.counterpartyLabel ?? title),
                  subtitle: Text(
                    '${task?.leg == 'first_mile' ? 'First mile' : 'Final mile'} · ${thread?.taskReference ?? task?.reference ?? thread?.orderReference ?? 'Task'}',
                  ),
                ),
                if ((thread != null && thread.sendAllowed != true) ||
                    task?.canCompose == false)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Read-only conversation. Replies are unavailable here.',
                    ),
                  ),
                if (controller.threadError case final error?)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(error),
                        if (controller.canRetry)
                          TextButton(
                            onPressed: controller.refreshActive,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: controller.refreshActive,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (controller.threadStatus == ChatLoadStatus.loading &&
                            controller.messages.isEmpty)
                          const Center(child: CircularProgressIndicator()),
                        if (controller.threadStatus == ChatLoadStatus.empty)
                          const Text(
                            'No task conversation found in the current inbox. Your first message will open or resume the server-authorized thread.',
                          ),
                        if (controller.canLoadOlder)
                          TextButton(
                            onPressed: controller.loadOlder,
                            child: const Text('Load older messages'),
                          ),
                        for (final message in controller.messages)
                          ChatMessageRow(
                            key: ValueKey((message.conversationId, message.id)),
                            message: message,
                            media: controller.media,
                          ),
                        if (controller.media != null)
                          ChatImageComposer(
                            controller: controller.media!,
                            contextValue: controller.mediaContext,
                            enabled:
                                sendable && controller.pendingAttempt == null,
                          ),
                      ],
                    ),
                  ),
                ),
                if (controller.sendError case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Semantics(liveRegion: true, child: Text(error)),
                  ),
                if (controller.pendingAttempt != null &&
                    controller.sendStatus != ChatSendStatus.sending &&
                    !controller.unresolvedSend)
                  TextButton(
                    onPressed: _discardPending,
                    child: const Text('Discard pending retry'),
                  ),
                if (sendable)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _text,
                              enabled:
                                  controller.pendingAttempt == null &&
                                  controller.sendStatus !=
                                      ChatSendStatus.sending,
                              maxLength: 2000,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                hintText: 'Type a message',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: controller.pendingAttempt == null
                                ? 'Send message'
                                : 'Retry same message',
                            onPressed:
                                controller.sendStatus ==
                                        ChatSendStatus.sending ||
                                    !controller.canRetry ||
                                    (controller.media != null &&
                                        !controller.media!.ready)
                                ? null
                                : _send,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
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
