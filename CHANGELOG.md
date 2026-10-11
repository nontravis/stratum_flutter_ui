# Changelog

## Unreleased

- Breaking: `AppBorder`, `AppShadow`, and `AppFilter` are removed, with no `@Deprecated` step, since no release has
  shipped them. Border widths, shadows, and blurs now come from the theme file: read
  `StratumTheme.of(context).border` (`StratumBorderTokens`: `sm`, `md`, `lg` as `double` widths, no longer `Border`
  objects), `.shadow` (`StratumShadowTokens`, `level1` to `level6`, each a `List<BoxShadow>`), and `.blur`
  (`StratumBlurTokens`, `level1` to `level6`, each an `ImageBlurFilter`). A blur's sigma is half its Figma radius, so
  each blur is half as strong as the `AppFilter` step of the same number.
- Breaking: `StratumThemeData.filter` and the `StratumTheme.filter` getter are renamed `blur`, and `StratumThemeData`
  now takes `border`, `shadow`, and `blur` as required parameters with no built-in default, and `StratumThemeConfig`
  takes `border`, `shadow`, and `blur` as required parameters, so a hand-built one passes them.
- Breaking: `StratumThemeData.screenBorderRadius`, its constructor and `copyWith` parameters, and the
  `StratumTheme.screenBorderRadius` getter are removed; nothing read it. Read the screen corner radius from
  `context.deviceWindow.radius`.
- Breaking: the theme format `stratum-theme/v1.2.0` adds the `border`, `shadow`, and `blur` groups, and the package
  default reads `v1.2.0`. This package reads every `v1.0`, `v1.1`, and `v1.2` theme; a package build that reads only
  up to `v1.1` refuses a `v1.2` theme as `unsupported_schema`. A theme that leaves the three groups out takes the
  package default's Figma values. The new problem code `expected_shadow` reports a `shadow` level that is not a list
  of layers of exactly `x`, `y`, `blur`, `spread`, and `color`.
- Breaking: the theme format `stratum-theme/v1.3.0` adds `opacity.scrim`, a modal layout's background scrim, to the
  already-closed `opacity` group, and the package default reads `v1.3.0`. This package reads every `v1.0` to `v1.3`
  theme; a package build that reads only up to `v1.2` refuses a `v1.3` theme as `unsupported_schema`. A theme that
  leaves `scrim` out takes the package default's 0.5. `StratumOpacityTokens` gains `scrim`, and
  `StratumOpacityTokens.fromMap` throws an `ArgumentError` for a map with no `scrim` key, so a hand-built map, or a
  hand-built `StratumThemeConfig` opacity map, passes one.
- Breaking: a theme file's lengths and shadow layers are bounded. Every `space`, `radius`, and `layouts` number (each
  window-size entry included), the `N` of a `layouts` `"N%"`, and a shadow layer's `x`, `y`, and `spread` must be a
  finite number from -10000 to 10000, and every `border` width, `blur` radius, and layer `blur` one from 0 to 10000;
  anything else is `expected_dimension`, where `space`, `radius`, and `layouts` used to take an infinite, NaN, or huge
  number. A `shadow` level holds at most 8 layers, else `expected_shadow`. The messages of `border`, `blur`, and the
  layer numbers now name the range (`expected a number from 0 to 10000, got <value>`). A downloaded theme can no
  longer ask for an unbounded stack of blurred shadows or hand the renderer an infinite size.
- Breaking: a theme file's `typography` lengths are bounded too. Every `adjustSize`, `scaleByWindowSize` entry
  (theme-wide or a type's own), `spaceHeight`, and `letterSpacing` must be a number, or a `"N%"` whose `N` is one,
  that is finite and from -10000 to 10000, negatives included; anything else is `expected_dimension` at its path
  (`expected a number or "N%" from -10000 to 10000, got <value>`), where these four used to take an infinite, NaN, or
  huge value. A `typography` that draws some text at a font size or a line box of 0 px or less at text scale 1, at
  any size `s10` to `s56`, with no window size or at any one, in any font a tag gives the type, is refused too:
  `expected_dimension` once per path, at the `adjustSize`, the `scaleByWindowSize` entry, or the `spaceHeight` to
  blame, such as `expected an adjustSize that keeps s10 above 0 px, got -12 (s10 draws at -2 px)`, in the app and in
  the `stratum_theme` CLI alike. `StratumTextStyle.size` now asserts a finite custom size above 0 in a debug build; a
  release build draws any other custom size at `s16`.
- New `StratumComponentDefaults.parts`, built by the new `StratumThemeApplication(componentPartDefaults:)` and
  `.controlled(componentPartDefaults:)`, lets an app restyle every part of a multi-part component type, such as a
  page layout, a modal layout, or a notice, from one place: `componentPartDefaults: (theme) => {ModalLayout:
  ModalLayoutStyle(...)}`. Read a part style with `StratumComponentDefaults.partsOf<S>(context, type)`: null when
  none is registered for `type`, or a thrown `FlutterError` naming both `type` and `S` when the registered value is
  not an `S`. `StratumThemeApplication.wrap` copies `componentPartDefaults` the same way it copies
  `componentDefaults`.
- New `HoverBuilder` and `FocusBuilder` build a look, or run a listener, from whether a pointer is over a widget or
  focus sits anywhere inside it. They add no Tab stop, focus ring, tap handling, cursor, or size, read false inside a
  disabled component, and take an optional `semantics` that labels the wrapped group for screen readers.
  `ContainerLayout(builder: (context, state) => ...)` builds its content from the new `InteractionState` of its tap
  surface (`hovered`, `pressed`, `focused`, `disabled`), in place of `child`.
- `StratumInkWell`, and so every box layout with an `interaction`, now calls `onHover(false)` once when it turns
  disabled under the pointer, by its own `disabled` or a disabled component around it, and `onHover(true)` once when it
  turns enabled again under the pointer; before, a disabled flip left `onHover` without its `false`.
- Renamed under one naming rule: screen-building blocks carry no `Stratum` prefix, while design-drawn components and
  theme or app-setup types keep it. `StratumInteraction` is now `Interaction`, `StratumScroll` is `Scroll`,
  `StratumTapTargetSize` is `TapTargetSize`, `StratumFocusGroup` is `FocusGroup`, `StratumReorderableItemsController`
  is `ReorderableItemsController`, `StratumShow` is `Show`, `StratumShowTransition` is `ShowTransition`,
  `StratumShowSlideDirection` is `ShowSlideDirection`, `Slot` is `StratumSlot`, and `HighContrastMode` is
  `StratumHighContrastMode`. Each old name stays one minor version as a `@Deprecated` alias, so existing code compiles
  with a deprecation hint.
- The empty `assets/fonts/` asset declaration is removed from `pubspec.yaml`; the package ships no font from it.
- Breaking: the theme animation scale gains a sixth duration level, `micro`, first and shortest: 30 ms forward and
  19.2 ms back in the package default (its 64% `reverseDuration`), read as `StratumTheme.of(context).animation.micro`
  and `StratumMotionLevel.micro`, and valid as `animation.duration.default`. `StratumMotionLevels` and
  `StratumAnimation` now take a required `micro`, so a hand-built one passes it, and an exhaustive `switch` over
  `StratumMotionLevel` needs a `micro` case. A theme file that sets no `micro` reads the package default's 30 ms, and
  the `animation.duration.default` problem message now lists `micro` first.
- Breaking: the package default `veryFast` duration level slows by 25 ms, from 50 ms to 75 ms forward and from 32 ms
  to 48 ms back. No `@Deprecated` step: no release has shipped the 50 ms value.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now inflate and check every zip entry, those
  the install never reads included (`__MACOSX/` entries, a `.DS_Store`, a loose file beside the theme folder): an
  entry whose data does not inflate to exactly its declared size, or fails its CRC-32 check, is `invalid_archive`
  (`unsafe_entry_path` for a folder entry), and every entry counts toward `maxBytes`. An entry typed as a folder on a
  name that does not end in `/` is `unsafe_entry_path`. A folder entry may hold any deflate stream that inflates to
  nothing, so Java's level-0 folder entries now install.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now inflate every zip entry with the
  package's own strict inflate, which refuses as `invalid_archive` (`unsafe_entry_path` for a folder entry) a deflate
  stream malformed anywhere, as zlib-based tools refuse it: a stored block whose NLEN is not the complement of its
  LEN, a block of the reserved type, a malformed dynamic block header, an over-subscribed or incomplete Huffman code,
  a symbol or distance out of range, a stream with no final block, or a byte after it.
- Breaking: `StratumNamedCurve.byName` moved to `StratumCurveConvert.byName`, on the Flutter side of the theme models,
  so the curve model compiles in the Dart VM; `stratumCurve.curve` reads as before. No `@Deprecated` step: Dart has no
  static extension members, and no release tag exists yet.
- Breaking: `StratumThemeConfig`, `StratumColorSets`, `StratumAnimationConfig`, `StratumTypeStyle`,
  `StratumTypography`, and `StratumFamilySet` are now `abstract class` with a `const factory`, generated by `freezed`.
  A subclass of any of them (`class X extends StratumThemeConfig { ... }`) no longer compiles, because the class has
  no generative constructor.
- Breaking: every map getter on a theme model (for example `StratumColorSets.light`) now returns an unmodifiable view
  over the map its factory was given. Mutating it, `config.light['k'] = c`, now throws `UnsupportedError`; read the
  map and copy it with `Map.of` instead.
- Breaking: an FO-01 problem message, `StratumThemeFormatError.toString`, and the `FormatException` thrown by
  `StratumDimension.parse` now escape non-ASCII text taken from the zip or the yaml. A test asserting on one of these
  messages with raw non-ASCII characters needs the escaped form instead.
- `copyWith` is now generated on all fifteen theme models, and `StratumNamedCurve.names` lists every curve name.
- Fixed: a theme yaml with a malformed tag %-escape now reports a yaml syntax error instead of throwing.
- Breaking: `google_fonts` is now pinned to exactly the version the `stratum_theme` CLI's family list was generated
  from (`>=9.0.0 <=9.0.0`); an app whose own `google_fonts` constraint excludes that version must widen it to allow
  it.
- Breaking: an escaped text past 200 characters, in an FO-01 problem message, a remote theme message, or a
  `stratum_theme` output line, now ends with `\[cut N chars, id H]` in place of `...`: N is the text's length in
  UTF-16 code units and H the first 32 hex digits of its SHA-256, so two long texts that differ only past the cut
  print differently. A test or a log parser that matched the old `...` needs the new form.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now refuse a zip entry name holding any
  character outside printable ASCII, U+0020 to U+007E, whatever the zip's UTF-8 flag says — a control character, an
  accented letter, a Thai letter, or a byte another zip tool would decode another way, is `unsafe_entry_path` — as
  is a `/`-ending entry that holds bytes; `pack` refuses such a file or folder name before it writes anything. A zip
  an app already keeps that breaks this rule, or any rule of this release, now fails at preload, which skips it and
  calls `onRemoteThemeError` with its id and the error.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now refuse as `invalid_archive` a zip that
  another zip tool could read differently: a byte before the central directory that belongs to no entry, or to two;
  a local header whose flags, method, CRC-32, sizes, or name differ from the central directory, the zeros a data
  descriptor stands for aside; an extra field that is not whole records (a later bullet allowlists its record ids);
  a data descriptor on a stored entry, or of another length or value; and a byte after the end record's comment.
  Zips from Finder, Info-ZIP `zip`, and Java's `ZipOutputStream` install as before.
- Breaking: every theme yaml file, bundled, the app's own, or in a remote zip, now fails as `yaml_syntax` at the
  offending character, before the yaml package reads it, when it holds a YAML anchor, alias, or tag (`&a`, `*a`, `!x`,
  `!!x`), uses a collection or an explicit `?` key as a mapping key (`[a]: x`, `{a: 1}: x`, `? a`), nests more than 64
  collections, block or flow, or is longer than 1 MiB (1,048,576 UTF-16 code units). Write each value out, or refer to
  a token with a quoted `"{group.path}"` alias, and write each key as a plain or quoted value. A malformed tag now
  reports `no anchor, alias, or tag; refer to a token with "{path}" instead` at its `!`, in place of `invalid percent
  escape in a tag`. It also now fails when a byte-order mark (U+FEFF) stands anywhere but the text's first
  character, package:yaml's own leading-mark rule included for any later line: move the mark to the very start of
  the text or remove it.
- Breaking: `stratum_theme` now exits 66 with `cannot read "pubspec.yaml": text longer than 1 MiB` when the app
  project's `pubspec.yaml` is longer than 1 MiB (1,048,576 bytes), refused after reading at most 1,048,577 bytes off
  one handle; exits 66 with `not valid UTF-8 text` when the bytes under that cap do not decode as UTF-8; and exits 66
  when the yaml check refuses the file, as it refuses a theme file: an anchor, alias, or tag, a collection or an
  explicit `?` key as a mapping key, or nesting past 64.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now refuse a zip entry whose extra field
  holds a record of any id but 0x000a (NTFS times), 0x5455 and 0x5855 (timestamps), 0x7875 (Unix owner ids), and
  0xcafe (the jar marker), the ones Finder, Info-ZIP, Java, and `tar` write, as `invalid_archive`, and an entry that
  carries the MS-DOS folder attribute on a name that does not end in `/` as `unsafe_entry_path`.
- Breaking: a theme yaml file, bundled, the app's own, or in a remote zip, now fails as `yaml_syntax` with `more than
  256 keys in one mapping, or more than 2,048 in the text` at the first key past either cap, before the yaml package
  reads it; past a construct the check does not model, from where it counts every `:`, `,`, and `{` as a key, the
  message reads `a key cap under the locked count, which began at line <line>, column <column>`, naming that
  construct; `stratum_theme` exits 66 on such a `pubspec.yaml`. Split a larger mapping into nested groups.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now read an entry's host byte and attribute
  bits from an allowlist of what Finder, Info-ZIP, `tar`, Python, Java, 7-Zip, and Windows tools write, and refuse as
  `unsafe_entry_path` an entry made on a host other than 0 (MS-DOS and Windows) or 3 (Unix and macOS), one that
  carries the setuid, setgid, or sticky bit, and one with any MS-DOS attribute bit but read-only, archive, the
  0x4000 and 0x8000 markers, and the folder bit on a name ending in `/`, such as the volume-label bit for which
  UnZip skips the entry.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now refuse as `invalid_archive`
  (`unsafe_entry_path` for a folder entry) a zip whose deflate entries together start more Huffman blocks, dynamic or
  fixed, than 16, plus one per deflate entry, plus one per 512 bytes of their output, which no zip from a common zip
  tool does, so a hostile zip costs time in proportion to its entries and output rather than its size; long Huffman
  codes now decode through zlib's two-level tables.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now refuse as `unsafe_entry_path` an entry
  name Windows would not create unchanged: a name part ending in a dot or a space, a part of dots only, any of `:`,
  `<`, `>`, `"`, `|`, `?`, and `*` anywhere in the name, a part whose text before its first dot, trailing spaces
  trimmed, is a reserved device name in any letter case — `CON`, `PRN`, `AUX`, `NUL`, `CONIN$`, `CONOUT$`, `COM1` to
  `COM9`, or `LPT1` to `LPT9`, such as `con`, `Con.txt`, `CON .txt`, or `images/NUL.svg` — or a part holding `~`
  before an ASCII digit, the 8.3 short-name marker, such as `THEME~1.YAM`; `pack` refuses such a file or folder name
  under the theme folder before it writes anything.
- Breaking: a remote theme install, and `stratum_theme pack` and `check`, now refuse as `invalid_archive` a zip entry
  whose allowed extra-field record fits neither its id's local nor its central layout, read on either side: a
  0x000a record other than 4 reserved bytes and one tag-0x0001 attribute of 24 bytes; a 0x5455 record with no flags
  byte, a flag past bit 2, or a size other than 4 bytes for each flag bit 0 to 2 set or 4 bytes only for bit 0; a
  0x5855 record other than 8 or 12 bytes; a 0x7875 record other than version 1 with its user and group ids filling
  it exactly; and a 0xcafe record that is not empty. The zips Finder, Info-ZIP, Java, `jar`, `tar`, and 7-Zip write
  still install, and so do a Python `zipfile` or Java `ZipOutputStream` repack that copies one header's 0x5455 or
  0x5855 body into the other unchanged.
- The tap surface's menu action label, `StratumInkWell`'s last fallback when neither `secondaryTapSemanticsLabel` nor
  the app's material localizations name it, now reads Stratum's built-in labels: Thai under a Thai locale, English
  under any other. The package now depends on `flutter_localizations` (SDK) and `intl` (`any`); an app whose own
  `intl` constraint excludes the version `flutter_localizations` requires must widen it to allow it.
- The Flutter floor is now `>=3.47.0`, the floor `google_fonts` 9.0.0, `badges` 4.0.1, and
  `webview_flutter_wkwebview` 3.27.0 already required; no app below Flutter 3.47 could resolve the package before.
- New `context.themeData([ThemeMode? mode])`, `context.defaultWidgetSize([ThemeMode? mode])`, and `context.windowSize`
  read the theme data, the default widget size, and the window size at a context in one line each, each registering
  only the dependency of the lookup it wraps.
- `StratumWidgetProps.resolveDefaultSize(context)` is the hook a component now calls for its default size: `size`
  when set, else `resolveTheme(context).defaultWidgetSize`, so a subclass that overrides `resolveTheme` sets its own
  default size, matching `resolveColor`. `resolveSize` stays one minor version as a `@Deprecated` member that calls
  `resolveDefaultSize`, with no release tag yet, so NFR-M04's major-version rule does not apply.
- `context.deviceWindow.radius` now reads the screen's corner radii: on Android API 31+ through Flutter's own value,
  and on iOS 26+ and macOS 27+ through the package's own native plugin under a `StratumThemeApplication`; every
  other platform and version reads null, and the caller supplies its own fallback.
- New `StratumRadiusTokens.sheet` reads the theme's `radius.sheet` token, 40 in the package default, a bottom
  sheet's top corners.
- New `ModalLayout`, a slot widget of an optional `top`, an optional `tab`, and a required `body`, with a drag
  handle on the bottom sheet type and a close button under `showClose`; its `type` (`ModalLayoutType.bottomSheet`,
  `.floating`, `.modal`) and `size` (`ModalLayoutSize.medium`, `.large`, `.extraLarge`, `.fillWidth`) pick its
  corners, width, and padding, concentric with the screen's own corners; `borderRadius`, `safeArea`, and
  `scrollBody` (default `true`, wraps `body` in a bounded scroll view; `false` hands it that height unwrapped for a
  body that scrolls itself) complete its fields; a `ModalLayoutStyle customStyle` restyles each slot and the
  surface, over an app-wide parts style registered through `StratumComponentDefaults.partsOf<ModalLayoutStyle>`. It
  works inline, with no scrim and no route, as well as inside the route `showModalLayout` opens.
- New `showModalLayout<T>(context, type:, builder:, useRootNavigator: true, showBackground: true,
  semanticsLabel:)` opens a `ModalLayout` above the current page and returns a `Future<T?>` that completes with the
  value it closes with, or null on a dismissal. It blocks the page behind for taps and for screen readers, keeps
  keyboard focus inside the modal layout, and returns focus to the opener on close; Esc, a tap outside, back, a
  drag down on a sheet, and the close button dismiss it. The package depends on `smooth_sheets` (`^1.3.0`) for the
  sheet types' drag and snap behavior.
