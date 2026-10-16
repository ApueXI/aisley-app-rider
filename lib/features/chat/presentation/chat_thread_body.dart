import 'package:flutter/material.dart';

import '../../../core/chat_media/image_widgets.dart';
import 'chat_message_row.dart';
import 'controllers/chat_controller.dart';

class ChatThreadBody extends StatelessWidget {
  const ChatThreadBody({
    required this.controller,
    required this.text,
    required this.title,
    required this.sendable,
    required this.onSend,
    required this.onDiscardPending,
    super.key,
  });
  final ChatController controller;
  final TextEditingController text;
  final String title;
  final bool sendable;
  final VoidCallback onSend, onDiscardPending;

  @override
  Widget build(BuildContext context) {
    final thread = controller.activeThread, task = controller.activeTask;
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshActive,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      thread?.counterpartyLabel ?? title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${task?.leg == 'first_mile' ? 'First mile' : 'Final mile'} · ${thread?.taskReference ?? task?.reference ?? thread?.orderReference ?? 'Task'}',
                    ),
                    const SizedBox(height: 16),
                    if ((thread != null && thread.sendAllowed != true) ||
                        task?.canCompose == false)
                      const Text(
                        'Read-only conversation. Replies are unavailable here.',
                      ),
                    if (controller.threadError case final error?) ...[
                      Text(error),
                      if (controller.canRetry)
                        TextButton(
                          onPressed: controller.refreshActive,
                          child: const Text('Retry'),
                        ),
                    ],
                    if (controller.threadStatus == ChatLoadStatus.loading &&
                        controller.messages.isEmpty)
                      const Center(child: CircularProgressIndicator()),
                    if (controller.threadStatus == ChatLoadStatus.empty)
                      const Text(
                        'No messages yet. Send a message to start this task conversation.',
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
                    if (controller.media != null && sendable)
                      ChatImageComposer(
                        controller: controller.media!,
                        contextValue: controller.mediaContext,
                        enabled: controller.pendingAttempt == null,
                      ),
                  ],
                ),
              ),
            ),
            if (sendable ||
                controller.sendError != null ||
                controller.pendingAttempt != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.65,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.sendError case final error?)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(error),
                          ),
                        ),
                      if (controller.pendingAttempt != null &&
                          controller.sendStatus != ChatSendStatus.sending &&
                          !controller.unresolvedSend)
                        TextButton(
                          onPressed: onDiscardPending,
                          child: const Text('Discard pending retry'),
                        ),
                      if (sendable)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: text,
                                enabled:
                                    controller.pendingAttempt == null &&
                                    controller.sendStatus !=
                                        ChatSendStatus.sending,
                                maxLength: 2000,
                                minLines: 1,
                                maxLines:
                                    MediaQuery.viewInsetsOf(context).bottom > 0
                                    ? 2
                                    : 4,
                                textCapitalization:
                                    TextCapitalization.sentences,
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
                                  : onSend,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
