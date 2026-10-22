import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;

import 'package:stratum_ui/stratum_ui.dart' show StratumThemeController;

import 'fixture_app.dart';
import 'fixture_route.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // The web semantics tree then exists with no opt-in.
  SemanticsBinding.instance.ensureSemantics();

  // No wait for Google fonts: a fixture must not depend on the network.
  final themeController = await StratumThemeController.preload(
    googleFontsTimeout: Duration.zero,
  );

  runApp(
    FixtureApp(
      themeController: themeController,
      fixtureId: fixtureIdFrom(
        args: args,
        defaultRouteName: PlatformDispatcher.instance.defaultRouteName,
      ),
    ),
  );
}
