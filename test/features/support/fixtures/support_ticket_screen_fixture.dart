import 'dart:async';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/support/data/support_ticket_repository.dart';
import 'package:aisley_app/features/support/domain/support_ticket_models.dart';

AuthController supportAuthController() {
  return AuthController(
    authRepository: _UnusedAuthRepository(),
    dashboardRepository: _UnusedDashboardRepository(),
  )..status = AuthStatus.authenticated;
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedDashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class WidgetSupportRepository implements SupportTicketRepository {
  bool offlineCreate = false;
  ApiException? listError;
  Completer<SupportTicketPage>? pendingList;
  bool showTicket = false;
  int createCount = 0;
  int replyCount = 0;
  int? readSequence;
  List<SupportTicketEvent> detailEvents = [supportEvent()];

  @override
  Future<SupportTicketPage> list({
    SupportTicketStatusFilter status = SupportTicketStatusFilter.all,
    SupportTicketCategoryFilter category = SupportTicketCategoryFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    if (pendingList case final pending?) return pending.future;
    if (listError case final error?) throw error;
    return SupportTicketPage(
      items: showTicket ? [supportTicket(unreadCount: 2)] : const [],
      nextCursor: null,
    );
  }

  @override
  Future<SupportTicketMutation> create({
    required String subject,
    required String category,
    required String body,
    required String idempotencyKey,
  }) async {
    createCount++;
    if (offlineCreate) {
      throw const ApiException.network('private offline');
    }
    showTicket = true;
    return SupportTicketMutation(
      ticket: supportTicket(subject: subject, category: category),
      event: supportEvent(body: body),
    );
  }

  @override
  Future<SupportTicketDetailPage> detail(
    String ticketId, {
    String? cursor,
    int limit = 20,
  }) async {
    return SupportTicketDetailPage(
      ticket: const SupportTicketDetailRecord(
        id: 'ticket-1',
        reference: 'SUP-0001',
        status: 'open',
        revision: 1,
      ),
      events: detailEvents,
      nextCursor: null,
    );
  }

  @override
  Future<SupportTicketSummary> markRead({
    required String ticketId,
    required int lastReadSequence,
  }) async {
    readSequence = lastReadSequence;
    return supportTicket(unreadCount: 0);
  }

  @override
  Future<SupportTicketMutation> reply({
    required String ticketId,
    required String body,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    replyCount++;
    return SupportTicketMutation(
      ticket: supportTicket(revision: expectedRevision + 1),
      event: supportEvent(id: 'event-2', sequence: 2, body: body),
    );
  }
}

SupportTicketSummary supportTicket({
  String subject = 'Task help',
  String category = 'delivery',
  int revision = 1,
  int unreadCount = 0,
}) {
  return SupportTicketSummary(
    id: 'ticket-1',
    reference: 'SUP-0001',
    subject: subject,
    category: category,
    status: 'open',
    revision: revision,
    requesterRole: 'courier',
    unreadCount: unreadCount,
  );
}

SupportTicketEvent supportEvent({
  String id = 'event-1',
  int sequence = 1,
  String body = 'Initial message',
}) {
  return SupportTicketEvent(
    id: id,
    sequence: sequence,
    type: 'reply',
    actorRole: 'courier',
    isMine: true,
    assignmentChanged: false,
    body: body,
  );
}
