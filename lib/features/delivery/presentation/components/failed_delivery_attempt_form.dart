import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../pickup/domain/pickup_models.dart';
import '../../domain/failed_delivery_attempt.dart';
import '../controllers/delivery_controller.dart';

class FailedDeliveryAttemptForm extends StatefulWidget {
  const FailedDeliveryAttemptForm({
    required this.task,
    required this.controller,
    required this.authController,
    super.key,
  });
  final PickupTask task;
  final DeliveryController controller;
  final AuthController authController;

  @override
  State<FailedDeliveryAttemptForm> createState() =>
      _FailedDeliveryAttemptFormState();
}

class _FailedDeliveryAttemptFormState extends State<FailedDeliveryAttemptForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _note;
  FailedDeliveryReason? _reason;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    final pending = widget.controller.pendingFailedAttempt(widget.task);
    _reason = pending?.reason;
    _note = TextEditingController(text: pending?.note ?? '');
    widget.authController.addListener(_authChanged);
  }

  void _authChanged() {
    if (widget.authController.status == AuthStatus.authenticated || _allowPop) {
      return;
    }
    _note.clear();
    _reason = null;
    setState(() => _allowPop = true);
    scheduleMicrotask(() {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_authChanged);
    _note.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (widget.controller.isReportingFailedAttempt(widget.task)) return;
    if (!widget.controller.hasPendingFailedAttempt(widget.task) &&
        (_reason != null || _note.text.isNotEmpty)) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this draft?'),
          content: const Text('The visit has not been reported.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard draft'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _submit() async {
    if (widget.authController.status != AuthStatus.authenticated) return;
    final controller = widget.controller;
    final pending = controller.hasPendingFailedAttempt(widget.task);
    if (!pending && !_form.currentState!.validate()) return;
    final success = pending
        ? await controller.retryFailedAttempt(widget.task)
        : await controller.reportFailedAttempt(
            widget.task,
            reason: _reason!,
            note: _note.text,
          );
    if (!mounted || !success) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final pending = controller.hasPendingFailedAttempt(widget.task);
      final busy = controller.isReportingFailedAttempt(widget.task);
      final fields = controller.failedAttemptFieldErrors[widget.task.id];
      final error = controller.failedAttemptErrors[widget.task.id];
      final task = controller.taskById(widget.task.id) ?? widget.task;
      final enabled = pending
          ? controller.canRetryFailedAttempt(task)
          : controller.canReportFailedAttempt(task);
      return PopScope(
        canPop:
            _allowPop ||
            widget.authController.status != AuthStatus.authenticated,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop &&
              widget.authController.status == AuthStatus.authenticated) {
            _back();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Report failed attempt'),
            leading: BackButton(onPressed: busy ? null : _back),
          ),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (task.order?.reference != null)
                  Text('Order ${task.order!.reference}'),
                const SizedBox(height: 12),
                const Text(
                  'Record why this visit could not be completed. This does not cancel the delivery or change parcel custody.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FailedDeliveryReason>(
                  initialValue: _reason,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    errorText: fields?['reason']?.firstOrNull,
                  ),
                  items: FailedDeliveryReason.values
                      .map(
                        (reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason.label),
                        ),
                      )
                      .toList(),
                  onChanged: pending || busy
                      ? null
                      : (value) => setState(() => _reason = value),
                  validator: (value) =>
                      value == null ? 'Choose a reason.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  enabled: !pending && !busy,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    helperMaxLines: 3,
                    helperText: _reason == FailedDeliveryReason.other
                        ? 'Required for Other.'
                        : 'Optional. Include only details needed for delivery.',
                    errorText: fields?['note']?.firstOrNull,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (_reason == FailedDeliveryReason.other && text.isEmpty) {
                      return 'Describe what prevented this delivery.';
                    }
                    return text.runes.length > 500
                        ? 'Use at most 500 characters.'
                        : null;
                  },
                ),
                if (pending)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'This report is unconfirmed. Retry the same report to avoid recording this visit twice.',
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Reporting delivery attempt',
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || !enabled ? null : _submit,
                  child: Text(pending ? 'Retry same report' : 'Submit report'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _back,
                  child: Text(pending ? 'Back to delivery' : 'Cancel'),
                ),
                if (error != null)
                  OutlinedButton.icon(
                    onPressed: busy || !controller.canRetryRateLimit
                        ? null
                        : () => controller.loadDetails(task),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh task'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
