# Accessibility

## Built-in labels

- **Thai labels** — Stratum's own labels hold English and Thai, and read English for any other language. The menu
  action a screen reader offers on a tap surface with `onSecondaryTap` takes the app's material localizations'
  tooltip first when present, so with the global material delegates a Japanese app hears the Japanese material
  tooltip, not Stratum's English fallback; otherwise it reads Stratum's built-in label, Thai for a Thai locale. List
  `Locale('th')` in the app's `supportedLocales` to show them in Thai. Stratum's built-in labels need no delegate of
  their own: an app that lists `Locale('th')` in `supportedLocales` still adds Flutter's
  `GlobalMaterialLocalizations.delegates`, as any Thai Flutter app does, for its own material widgets; Stratum reads
  the resulting locale without registering a delegate of its own. Above `MaterialApp` the platform locale picks the
  language. A component's label prop, such as `StratumInkWell.secondaryTapSemanticsLabel`, replaces its built-in
  label.
