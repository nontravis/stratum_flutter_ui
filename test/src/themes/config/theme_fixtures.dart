import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

/// The `$schema` line every theme file starts with.
const schemaLine = r'$schema: stratum-theme/v1.0.0';

/// A layer file: [body] below the `$schema` line, so the first line of
/// [body] is line 2 of the file.
String layer(String body) => '$schemaLine\n$body';

/// The small package default most config tests parse over. Line 2 is
/// `name: base`.
const baseYaml = r'''
$schema: stratum-theme/v1.0.0
name: base
assets:
  splash-screen:
  loading:
space:
  md: 16
  lg: 20
  gutter: { mobile: 16, desktop: 32 }
radius:
  sm: 8
layouts:
  max-width-read: 720
palette:
  brand:
    500: "#3B82F6"
    600: "#2563EB"
    700: "#1D4ED8"
  gray:
    950: "#030712"
  app: {}
color:
  light:
    brand:
      normal: "{palette.brand.500}"
      hover: "{palette.brand.600}"
    button:
      primary:
        normal: "{color.light.brand.normal}"
    background:
      control:
        input-disabled: "{transparent.black.3}"
    transparent:
      0: "{transparent.white.0}"
    app: {}
  dark:
    brand:
      normal: "{palette.brand.600}"
      hover: "{palette.brand.700}"
    button:
      primary:
        normal: "{color.dark.brand.normal}"
    background:
      control:
        input-disabled: "{transparent.white.3}"
    transparent:
      0: "{transparent.black.0}"
    app: {}
  highContrastLight: {}
  highContrastDark: {}
typography:
  fonts:
    inter: { family: Inter }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: inter
      table: inter
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
extensions: {}
animation:
  duration:
    default: fast
    micro: 30
    veryFast: 75
    fast: 125
    normal: 200
    slow: 300
    verySlow: 400
  reverseDuration: 64%
  transition:
    watch: platform
    mobile: platform
    tablet: platform
    desktop: platform
    bigDesktop: platform
  curve:
    standard: easeInOutSine
    enter: easeOut
    exit: easeIn
opacity:
  disabled: 0.5
border:
  sm: 0.5
  md: 1
  lg: 1.5
shadow:
  "1":
    - {x: 0, y: 1, blur: 2, spread: 0, color: "{color.brand.hover}"}
    - {x: 0, y: 0, blur: 1, spread: 0, color: "#00000026"}
  "2": []
  "3": []
  "4": []
  "5": []
  "6": []
blur:
  "1": 4
  "2": 8
  "3": 16
  "4": 24
  "5": 40
  "6": 80
''';

/// The folder of the package default in [sources].
const baseFolder = 'packages/stratum_ui/assets/themes/default';

/// [base] as the source `base`, then each of [layers] as `layer1`,
/// `layer2`, and so on, each in the folder `themes/<id>`.
List<StratumThemeSource> sources(
  List<String> layers, {
  String base = baseYaml,
}) => [
  StratumThemeSource(id: 'base', folder: baseFolder, yaml: base),
  for (final (index, yaml) in layers.indexed)
    StratumThemeSource(
      id: 'layer${index + 1}',
      folder: 'themes/layer${index + 1}',
      yaml: yaml,
    ),
];

/// A [ThemeErrors] for [sources].
ThemeErrors errorsFor(List<StratumThemeSource> sources) =>
    ThemeErrors([for (final source in sources) source.id]);

/// Each error as `<source> <path>: <message> [<key>]`, in the order of
/// spec section 7.4; the root path shows as `(root)`.
List<String> problems(ThemeErrors errors) => [
  for (final error in errors.sorted) _describe(error),
];

String _describe(StratumThemeFormatError error) {
  final path = error.path.isEmpty ? '(root)' : error.path;
  return '${error.source} $path: ${error.message} [${error.code.key}]';
}
