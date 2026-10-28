part of '../history_screen.dart';

class _HistoryReferenceSearch extends StatefulWidget {
  const _HistoryReferenceSearch({required this.controller});

  final HistoryController controller;

  @override
  State<_HistoryReferenceSearch> createState() =>
      _HistoryReferenceSearchState();
}

class _HistoryReferenceSearchState extends State<_HistoryReferenceSearch> {
  late final TextEditingController _reference;
  final FocusNode _focus = FocusNode();
  late int _accountScopeGeneration;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(
      text: widget.controller.activeReference ?? '',
    );
    _accountScopeGeneration = widget.controller.accountScopeGeneration;
    widget.controller.addListener(_onHistoryChanged);
  }

  void _onHistoryChanged() {
    if (_accountScopeGeneration != widget.controller.accountScopeGeneration) {
      _accountScopeGeneration = widget.controller.accountScopeGeneration;
      _reference.clear();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onHistoryChanged);
    _reference.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search() {
    if (!widget.controller.canSearch) return;
    widget.controller.search(_reference.text);
  }

  void _clear() {
    _reference.clear();
    _focus.requestFocus();
    widget.controller.clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reference,
            focusNode: _focus,
            decoration: const InputDecoration(labelText: 'Order reference'),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          const Text('Enter the full order reference. It must match exactly.'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: controller.canSearch ? _search : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: const Text('Search'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _clear,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              ),
            ],
          ),
          if (!controller.canRetryRateLimit) ...[
            const SizedBox(height: 8),
            const Text('Wait before searching or refreshing again.'),
          ],
          if (controller.activeReference != null) ...[
            const SizedBox(height: 8),
            Text('Results for order reference: ${controller.activeReference}'),
          ],
        ],
      ),
    );
  }
}
