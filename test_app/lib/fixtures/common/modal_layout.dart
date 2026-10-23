import 'package:stratum_ui/stratum_ui.dart';

/// The value the modal's first control closes it with (FO-06 US-20 FR-02).
const _chooseA = 'Choose A';

/// The value the modal's second control closes it with.
const _chooseB = 'Choose B';

/// Modal fixture for the page-behind block and the result of a
/// `ModalLayout` shown by `showModalLayout` (FO-06 US-20 FR-02 E03, E04).
///
/// A page with button `Page control` that counts in text `page taps: <n>`
/// (id `modal_layout.page_taps`), button `Open modal`, and text `result: none`,
/// then `result: <value>` or `result: dismissed` once the modal closes (id
/// `modal_layout.result`). The open modal holds buttons `Choose A` and
/// `Choose B`, each closing it with its own text, and the built-in close
/// button. The buttons carry no id: a semantics identifier would split a
/// button's label and role from its tap onto two nodes, so a test finds each
/// by its label, one node with both.
class ModalLayoutFixture extends StatefulWidget {
  const ModalLayoutFixture({super.key});

  @override
  State<ModalLayoutFixture> createState() => _ModalLayoutFixtureState();
}

class _ModalLayoutFixtureState extends State<ModalLayoutFixture> {
  // MARK: - Properties

  var _pageTaps = 0;

  /// What the last modal closed with, null before one closed.
  String? _result;

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton(onPressed: _tapPage, child: const Text('Page control')),
        Semantics(
          identifier: 'modal_layout.page_taps',
          child: Text('page taps: $_pageTaps'),
        ),
        FilledButton(onPressed: _openModal, child: const Text('Open modal')),
        Semantics(
          identifier: 'modal_layout.result',
          child: Text('result: ${_result ?? 'none'}'),
        ),
      ],
    );
  }

  // MARK: - Private Methods

  void _tapPage() => setState(() => _pageTaps++);

  Future<void> _openModal() async {
    final value = await showModalLayout<String>(
      context,
      builder: (modalContext) => ModalLayout(
        body: ColumnLayout(
          children: [
            FilledButton(
              onPressed: () => Navigator.of(modalContext).pop(_chooseA),
              child: const Text(_chooseA),
            ),
            FilledButton(
              onPressed: () => Navigator.of(modalContext).pop(_chooseB),
              child: const Text(_chooseB),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _result = value ?? 'dismissed');
  }
}
