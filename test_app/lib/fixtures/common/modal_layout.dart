import 'package:stratum_ui/stratum_ui.dart';

/// The value the modal's first control closes it with (FO-06 US-20 FR-02).
const _chooseA = 'Choose A';

/// The value the modal's second control closes it with.
const _chooseB = 'Choose B';

/// Modal fixture for the page-behind block and the result of a
/// `ModalLayout` shown by `showModalLayout` (FO-06 US-20 FR-02 E03, E04).
///
/// A page with button `Page control` (id `modal_layout.page_button`) that
/// counts in text `page taps: <n>` (id `modal_layout.page_taps`), button
/// `Open modal` (id `modal_layout.open`), and text `result: none`, then
/// `result: <value>` or `result: dismissed` once the modal closes (id
/// `modal_layout.result`). The open modal holds buttons `Choose A` (id
/// `modal_layout.choose_a`) and `Choose B` (id `modal_layout.choose_b`),
/// each closing it with its own text, and the built-in close button.
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
        _button('modal_layout.page_button', 'Page control', _tapPage),
        Semantics(
          identifier: 'modal_layout.page_taps',
          child: Text('page taps: $_pageTaps'),
        ),
        _button('modal_layout.open', 'Open modal', _openModal),
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
            _button(
              'modal_layout.choose_a',
              _chooseA,
              () => Navigator.of(modalContext).pop(_chooseA),
            ),
            _button(
              'modal_layout.choose_b',
              _chooseB,
              () => Navigator.of(modalContext).pop(_chooseB),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _result = value ?? 'dismissed');
  }

  Widget _button(String id, String label, VoidCallback onPressed) {
    return Semantics(
      identifier: id,
      button: true,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
