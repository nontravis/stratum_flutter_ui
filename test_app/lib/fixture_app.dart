import 'package:stratum_ui/stratum_ui.dart';

import 'fixtures/fixtures.dart';

/// Hosts one fixture, opened by route id.
///
/// The Navigator builds exactly one route from [fixtureId] and ignores the
/// platform `defaultRouteName`, which `WidgetsApp` would otherwise split into
/// stacked routes ahead of `initialRoute`.
///
/// With a [themeController], every fixture renders under that Stratum theme
/// in light mode; without one, no Stratum theme is published.
class FixtureApp extends StatelessWidget {
  const FixtureApp({required this.fixtureId, this.themeController, super.key});

  /// The `<category>/<widget>` fixture to open, or null for the unknown page.
  final String? fixtureId;

  /// The preloaded theme every fixture renders under, or null for none.
  final StratumThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stratum UI Test App',
      builder: (context, child) {
        final controller = themeController;
        if (controller == null) return child!;
        return StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: child!,
        );
      },
      onGenerateInitialRoutes: (_) => [_pageRoute()],
      onGenerateRoute: (_) => _pageRoute(),
    );
  }

  Route<void> _pageRoute() {
    return MaterialPageRoute<void>(
      builder: (context) => _FixturePage(fixtureId: fixtureId),
    );
  }
}

/// Hosts one fixture inside the safe area, so an edge-to-edge window never
/// hides content under a system bar; [edgeToEdgeFixtures] opt out.
class _FixturePage extends StatelessWidget {
  const _FixturePage({required this.fixtureId});

  final String? fixtureId;

  @override
  Widget build(BuildContext context) {
    final builder = fixtures[fixtureId];
    final content = builder == null
        ? _UnknownFixture(id: fixtureId)
        : builder(context);
    return Scaffold(
      body: edgeToEdgeFixtures.contains(fixtureId)
          ? content
          : SafeArea(child: content),
    );
  }
}

class _UnknownFixture extends StatelessWidget {
  const _UnknownFixture({required this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        identifier: 'fixture.unknown',
        child: Text('unknown fixture: $id'),
      ),
    );
  }
}
