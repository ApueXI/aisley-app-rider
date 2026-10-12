import 'package:flutter/material.dart';

import '../../../core/chat_media/draft_controller.dart';
import '../../../core/chat_media/private_image.dart';
import '../domain/chat_models.dart';

class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({super.key, required this.message, this.media});

  final ChatMessage message;
  final ChatMediaDraftController? media;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${message.mine ? 'You' : message.senderRole}: ${message.body}',
      child: Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: message.mine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.body),
              if (media != null)
                for (final attachment in message.attachments)
                  PrivateChatImage(
                    key: ValueKey(attachment.id),
                    attachment: attachment,
                    controller: media!,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
