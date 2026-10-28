import 'package:widgetbook/widgetbook.dart';

import 'components.g.dart';

/// Runs the FO-11 component catalog; pages arrive as `*.stories.dart`
/// files in later tasks, and M1-T3 replaces this `Config` with the themed
/// one.
void main() {
  runWidgetbook(Config(components: components));
}
