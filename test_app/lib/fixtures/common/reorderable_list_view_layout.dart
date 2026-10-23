import 'package:stratum_ui/stratum_ui.dart';

/// The original number of the one disabled row, last in the list.
const _disabledNumber = 6;

/// How many log entries the fixture keeps, newest last.
const _logLength = 6;

/// Reorder list fixture mirroring the reorder check of the screen reader demo.
///
/// Rows `Item 1` to `Item 6`, `Item 6` disabled. Each row carries no id: a
/// semantics identifier would split its label, button role, and tap from its
/// move actions onto two nodes, so a test finds a row by its label `Item <n>`
/// (the original number). Text `Log: nothing yet.` or the entries joined by
/// `"; "` after `Log: ` (id `reorder.log`). A tap logs `Item <n> tapped`; a
/// move logs `Item <n> moved to position <p>`.
class ReorderableListViewLayoutFixture extends StatefulWidget {
  const ReorderableListViewLayoutFixture({super.key});

  @override
  State<ReorderableListViewLayoutFixture> createState() =>
      _ReorderableListViewLayoutFixtureState();
}

class _ReorderableListViewLayoutFixtureState
    extends State<ReorderableListViewLayoutFixture> {
  /// Original item numbers in their current order.
  final _numbers = [1, 2, 3, 4, 5, 6];

  /// Log entries, newest last, cut to the last [_logLength].
  var _log = const <String>[];

  void _record(String entry) {
    final next = [..._log, entry];
    _log = next.length > _logLength
        ? next.sublist(next.length - _logLength)
        : next;
  }

  void _tap(int number) => setState(() => _record('Item $number tapped'));

  void _move(int from, int to) {
    setState(() {
      final number = _numbers.removeAt(from);
      _numbers.insert(to, number);
      _record('Item $number moved to position ${to + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableListViewLayout.builder(
          shrinkWrap: true,
          primary: false,
          itemCount: _numbers.length,
          itemExtent: 48,
          onReorderItem: _move,
          itemBuilder: (context, index) {
            final number = _numbers[index];
            return ContainerLayout(
              key: ValueKey(number),
              style: const WidgetStyle(
                height: 48,
                padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
                alignment: AlignmentDirectional.centerStart,
              ),
              interaction: Interaction(
                onTap: () => _tap(number),
                disabled: number == _disabledNumber,
              ),
              child: Text('Item $number'),
            );
          },
        ),
        Semantics(
          identifier: 'reorder.log',
          child: Text(
            _log.isEmpty ? 'Log: nothing yet.' : 'Log: ${_log.join('; ')}',
          ),
        ),
      ],
    );
  }
}
