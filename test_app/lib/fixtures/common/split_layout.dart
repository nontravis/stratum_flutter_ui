import 'package:stratum_ui/stratum_ui.dart';

/// Adjustable-value fixture for the divider of a `SplitLayout` (FO-06 US-21
/// FR-04 E01).
///
/// A list pane with text `List` (id `split.list_pane`) takes 30% of the
/// split, a detail pane with text `Detail` (id `split.detail_pane`) the
/// rest, whatever the window size. The divider between them reads as a
/// slider at `30%` under the built-in label `Resize panes`; it adds no
/// semantics identifier of its own, since `SplitLayout` offers none.
class SplitLayoutFixture extends StatelessWidget {
  const SplitLayoutFixture({super.key});

  @override
  Widget build(BuildContext context) {
    return SplitLayout(
      panes: [
        SplitPane(flex: 3, child: _pane('split.list_pane', 'List')),
        SplitPane(flex: 7, child: _pane('split.detail_pane', 'Detail')),
      ],
    );
  }

  // MARK: - Private Methods

  Widget _pane(String id, String label) {
    return Semantics(
      identifier: id,
      child: ContainerLayout(
        style: const WidgetStyle(
          padding: EdgeInsetsDirectional.all(12),
          alignment: AlignmentDirectional.topStart,
        ),
        child: Text(label),
      ),
    );
  }
}
