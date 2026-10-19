// A page for checking page transitions inside a router's shell by hand
// (F-01 US-10), on any device or browser:
//
//   flutter run -d <device> -t lib/transition_demo.dart
import 'package:go_router/go_router.dart'
    show GoRoute, GoRouter, GoRouterHelper, GoRouterState, ShellRoute;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerGoogleFontLicenses();
  runApp(TransitionDemoApp(themes: await loadTransitionDemoTheme()));
}

/// The package default theme, read from the stratum_ui package assets.
Future<StratumThemeSet> loadTransitionDemoTheme() async {
  final text = await rootBundle.loadString(
    'packages/stratum_ui/assets/themes/default/theme.yaml',
  );
  return StratumThemeSet.fromConfig(
    StratumThemeConfig.parse(
      base: StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: text,
      ),
    ),
  );
}

/// Check 1, its step and the result to expect (US-10 FR-01 E04).
const checkInside =
    '1. Open a page inside the shell: tap "Open inside". The page enters '
    "with the picked transition, or the theme's for this window size, and "
    'the tab bar stays where it is.';

/// Check 2, its step and the result to expect (US-10 FR-01 E04).
const checkFullScreen =
    '2. Open the full-screen page: tap "Open full screen" here or on the '
    'page inside the shell. It enters above the shell and covers it, the '
    'tab bar included.';

/// Check 3, its step and the result to expect (US-10 FR-01 E04).
const checkBack =
    '3. Go back: tap "Back" on the page you opened. It leaves with its '
    'transition, and the page under it shows again.';

/// The page transition demo (F-01 US-10 FR-01): a go_router [ShellRoute]
/// whose shell holds a tab bar outside the shell's own navigator, a
/// picker of the theme's transition and the nineteen
/// [ScreenTransitionType]s, and three numbered checks.
class TransitionDemoApp extends StatefulWidget {
  const TransitionDemoApp({super.key, required this.themes});

  final StratumThemeSet themes;

  @override
  State<TransitionDemoApp> createState() => _TransitionDemoAppState();
}

class _TransitionDemoAppState extends State<TransitionDemoApp> {
  /// The picked transition; null keeps the theme's.
  final _pick = ValueNotifier<ScreenTransitionType?>(null);
  final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  /// Every route builds its page in a `pageBuilder`: go_router's own
  /// default page shows no transition under Flutter's MaterialApp.
  late final GoRouter _router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/a',
    routes: [
      ShellRoute(
        navigatorKey: _shellKey,
        pageBuilder: (context, state, child) => MaterialPage<void>(
          key: state.pageKey,
          child: _Shell(path: state.uri.path, child: child),
        ),
        routes: [
          for (final tab in ['a', 'b'])
            GoRoute(
              path: '/$tab',
              pageBuilder: (context, state) => MaterialPage<void>(
                key: state.pageKey,
                child: _TabPage(tab: tab, pick: _pick),
              ),
              routes: [
                GoRoute(
                  path: 'page',
                  pageBuilder: (context, state) => _inside(
                    state,
                    _OpenedPage(
                      key: const ValueKey('insidePage'),
                      title: 'Page inside the shell, tab ${tab.toUpperCase()}',
                      fullScreen: true,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/full',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const _OpenedPage(
            key: ValueKey('fullScreenPage'),
            title: 'Full-screen page',
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    _pick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stratum page transition demo',
      routerConfig: _router,
      builder: (context, child) => StratumThemeApplication(
        themes: widget.themes,
        themeMode: ThemeMode.light,
        child: child!,
      ),
    );
  }
}

/// The page inside the shell: a plain [MaterialPage], which takes the
/// theme's transition for the window size (US-10 FR-01 E01), or, with a
/// `type` query, a [StratumTransitionPage] of that type (E02).
Page<void> _inside(GoRouterState state, Widget child) {
  final type = ScreenTransitionType.values
      .asNameMap()[state.uri.queryParameters['type']];
  return type == null
      ? MaterialPage<void>(key: state.pageKey, child: child)
      : StratumTransitionPage<void>(
          key: state.pageKey,
          type: type,
          child: child,
        );
}

/// The shell around the shell navigator [child]. Its tab bar sits outside
/// that navigator, so a page inside the shell moves while the tab bar
/// stays where it is (US-10 FR-01 E03).
class _Shell extends StatelessWidget {
  const _Shell({required this.path, required this.child});

  /// The current location, which picks the selected tab.
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('tabBar'),
        selectedIndex: path.startsWith('/b') ? 1 : 0,
        onDestinationSelected: (index) => context.go(index == 0 ? '/a' : '/b'),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.filter_1), label: 'Tab A'),
          NavigationDestination(icon: Icon(Icons.filter_2), label: 'Tab B'),
        ],
      ),
    );
  }
}

/// A tab's first page: the transition picker and the three checks.
class _TabPage extends StatelessWidget {
  const _TabPage({required this.tab, required this.pick});

  final String tab;
  final ValueNotifier<ScreenTransitionType?> pick;

  /// The location of the page inside the shell, with the pick as its
  /// `type` query when one is picked.
  String get _insideLocation {
    final type = pick.value;
    return type == null ? '/$tab/page' : '/$tab/page?type=${type.name}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page transition demo, tab ${tab.toUpperCase()}'),
      ),
      body: ColumnLayout(
        style: const WidgetStyle(padding: EdgeInsets.all(24)),
        scroll: const Scroll(),
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: 16,
        children: [
          const Text("Transition: the theme's, or one of the nineteen."),
          ValueListenableBuilder<ScreenTransitionType?>(
            valueListenable: pick,
            builder: (context, picked, _) => WrapLayout(
              gap: 8,
              runGap: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('pick-theme'),
                  label: const Text("Theme's transition"),
                  selected: picked == null,
                  onSelected: (_) => pick.value = null,
                ),
                for (final type in ScreenTransitionType.values)
                  ChoiceChip(
                    key: ValueKey('pick-${type.name}'),
                    label: Text(type.name),
                    selected: picked == type,
                    onSelected: (_) => pick.value = type,
                  ),
              ],
            ),
          ),
          const Text(checkInside),
          FilledButton(
            key: const ValueKey('openInside'),
            onPressed: () => context.push(_insideLocation),
            child: const Text('Open inside'),
          ),
          const Text(checkFullScreen),
          FilledButton(
            key: const ValueKey('openFullScreen'),
            onPressed: () => context.push('/full'),
            child: const Text('Open full screen'),
          ),
          const Text(checkBack),
        ],
      ),
    );
  }
}

/// A page the demo opens, inside the shell or above it.
class _OpenedPage extends StatelessWidget {
  const _OpenedPage({super.key, required this.title, this.fullScreen = false});

  final String title;

  /// Whether the page offers "Open full screen", as the page inside the
  /// shell does (US-10 Scenario 3).
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ColumnLayout(
        style: const WidgetStyle(padding: EdgeInsets.all(24)),
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: 16,
        children: [
          if (fullScreen)
            FilledButton(
              key: const ValueKey('openFullScreenFromInside'),
              onPressed: () => context.push('/full'),
              child: const Text('Open full screen'),
            ),
          FilledButton(
            key: const ValueKey('back'),
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
