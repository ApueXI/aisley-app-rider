part of 'chat_controller.dart';

extension ChatControllerSends on ChatController {
  Future<bool> sendMessage(String text) async {
    final task = activeTask;
    final thread = activeThread;
    final body = text.trim();
    if (sendStatus == ChatSendStatus.conflict) return false;
    if (task == null ||
        (body.isEmpty && media?.hasImages != true) ||
        body.length > 2000 ||
        !task.canCompose ||
        (threadStatus != ChatLoadStatus.loaded &&
            threadStatus != ChatLoadStatus.empty) ||
        (thread != null &&
            (thread.counterpartyRole != task.counterpartyRole ||
                thread.sendAllowed != true))) {
      sendStatus = ChatSendStatus.validation;
      sendError = 'Enter a message of 1–2,000 characters in an active task conversation.';
      _notify();
      return false;
    }
    if (!canRetry || sendStatus == ChatSendStatus.sending) return false;
    if (media != null && !media!.ready) return false;
    var attempt = pendingAttempt;
    if (attempt != null &&
        (attempt.body != body ||
            attempt.leg != task.leg ||
            attempt.taskId != task.taskId ||
            attempt.counterpartyRole != task.counterpartyRole ||
            (attempt.threadId != null && attempt.threadId != thread?.id))) {
      unresolvedSend = true;
      sendStatus = ChatSendStatus.uncertain;
      sendError =
          'Retry the same message, or discard the pending attempt first.';
      _notify();
      return false;
    }
    attempt ??= ChatSendAttempt(
      body: body,
      key: ChatController._newUuid(),
      leg: task.leg,
      taskId: task.taskId,
      counterpartyRole: task.counterpartyRole,
      threadId: thread?.id,
      attachmentIds: media?.hasImages == true ? media!.ids : const [],
    );
    pendingAttempt = attempt;
    if (media != null) media!.locked = true;
    sendStatus = ChatSendStatus.sending;
    sendError = null;
    _notify();
    final epoch = _epoch;
    try {
      if (attempt.threadId != null && task.counterpartyRole == 'customer') {
        final current = await repository.detail(attempt.threadId!);
        if (epoch != _epoch) return false;
        if (current.id != attempt.threadId ||
            current.taskId != attempt.taskId ||
            current.leg != attempt.leg ||
            current.counterpartyRole != attempt.counterpartyRole) {
          throw const ApiContractException('chat.send.context');
        }
        _replaceThread(current);
        if (current.sendAllowed != true) {
          if (!unresolvedSend) {
            pendingAttempt = null;
            media?.clear();
          }
          sendStatus = ChatSendStatus.conflict;
          sendError =
              'This conversation is read-only. Replies are unavailable.';
          _notify();
          return false;
        }
      }
      final result = attempt.threadId == null
          ? await repository.start(
              leg: attempt.leg,
              taskId: attempt.taskId,
              counterpartyRole: attempt.counterpartyRole,
              body: attempt.body,
              idempotencyKey: attempt.key,
              attachmentIds: attempt.attachmentIds,
            )
          : await repository.send(
              id: attempt.threadId!,
              body: attempt.body,
              idempotencyKey: attempt.key,
              attachmentIds: attempt.attachmentIds,
            );
      if (epoch != _epoch) return false;
      if (result.thread.leg != attempt.leg ||
          result.thread.taskId != attempt.taskId ||
          result.thread.counterpartyRole != attempt.counterpartyRole ||
          (attempt.threadId != null && result.thread.id != attempt.threadId)) {
        throw const ApiContractException('chat.send.context');
      }
      _threadRequestId++;
      _replaceThread(result.thread);
      _mergeMessages([result.message]);
      pendingAttempt = null;
      unresolvedSend = false;
      media?.clear(preserveHistory: true);
      sendStatus = ChatSendStatus.saved;
      threadStatus = ChatLoadStatus.loaded;
      _notify();
      unawaited(refreshActive(silent: true));
      return true;
    } on ApiException catch (error) {
      if (epoch != _epoch) return false;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _authorizationFailure(error);
        return false;
      }
      if (error.statusCode == 404) {
        pendingAttempt = null;
        sendStatus = ChatSendStatus.failed;
        await _readFailure(error, inbox: false);
        return false;
      }
      if (error.statusCode == 422 && !unresolvedSend) {
        pendingAttempt = null;
        if (media != null) media!.locked = false;
        sendStatus = ChatSendStatus.validation;
        sendError = 'The message was rejected. Check its length and retry.';
      } else if (error.statusCode == 409) {
        sendStatus = ChatSendStatus.conflict;
        threadStatus = ChatLoadStatus.stale;
        sendError =
            error.code == 'TASK_NOT_ACTIVE' ||
                error.code == 'CONVERSATION_READ_ONLY'
            ? 'This task no longer permits replies. Refresh to check its current state.'
            : 'This conversation changed. Refresh before sending again.';
        unawaited(refreshActive());
      } else {
        unresolvedSend = true;
        sendStatus = ChatSendStatus.uncertain;
        sendError = error.statusCode == 429
            ? 'Too many messages. Wait before retrying this exact message.'
            : 'The message may not have been saved. Retry this exact message.';
      }
      if (error.statusCode == 429) _startRetryDelay(error.retryAfter);
      _notify();
      return false;
    } on ApiContractException {
      if (epoch != _epoch) return false;
      unresolvedSend = true;
      sendStatus = ChatSendStatus.uncertain;
      sendError =
          'The send response was not understood. Retry this exact message.';
      _notify();
      return false;
    } on TokenStorageException {
      if (epoch != _epoch) return false;
      clear();
      sendStatus = ChatSendStatus.failed;
      sendError = 'Secure session storage is unavailable.';
      _notify();
      return false;
    }
  }

  void discardPendingAttempt() {
    if (unresolvedSend || sendStatus == ChatSendStatus.sending) return;
    media?.clear();
    pendingAttempt = null;
    sendStatus = ChatSendStatus.idle;
    sendError = null;
    _notify();
  }
}
