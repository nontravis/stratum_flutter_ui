import 'package:flutter/material.dart';

import 'fixtures/fixtures.dart';

/// Hosts one fixture, opened by route id.
///
/// The Navigator builds exactly one route from [fixtureId] and ignores the
/// platform `defaultRouteName`, which `WidgetsApp` would otherwise split into
/// stacked routes ahead of `initialRoute`.
class FixtureApp extends StatelessWidget {
  const FixtureApp({required this.fixtureId, super.key});

  /// The `<category>/<widget>` fixture to open, or null for the unknown page.
  final String? fixtureId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stratum UI Test App',
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

class _FixturePage extends StatelessWidget {
  const _FixturePage({required this.fixtureId});

  final String? fixtureId;

  @override
  Widget build(BuildContext context) {
    final builder = fixtures[fixtureId];
    return Scaffold(
      body: builder == null ? _UnknownFixture(id: fixtureId) : builder(context),
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
