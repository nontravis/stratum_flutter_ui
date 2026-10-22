import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;

import 'fixture_app.dart';
import 'fixture_route.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // The web semantics tree then exists with no opt-in.
  SemanticsBinding.instance.ensureSemantics();

  runApp(
    FixtureApp(
      fixtureId: fixtureIdFrom(
        args: args,
        defaultRouteName: PlatformDispatcher.instance.defaultRouteName,
      ),
    ),
  );
}
