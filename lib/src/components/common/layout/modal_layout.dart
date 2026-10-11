import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/src.dart';

/// How a [ModalLayout] sits on the screen (US-20 FR-03), the Figma `type`
/// values `BOTTOM_SHEET`, `FLOATING`, and `MODAL`.
enum ModalLayoutType {
  /// Rises from the bottom edge across the window, with a drag handle.
  bottomSheet,

  /// A sheet 8 px in from the screen edges, with corners concentric with
  /// the screen's.
  floating,

  /// A centered card.
  modal,
}

/// The content width of a [ModalLayout] (US-20 FR-03), the Figma `size`
/// values `MEDIUM`, `LARGE`, `EXTRA_LARGE`, and `FILL_WIDTH`.
///
/// Below [WindowSize.tablet] a sheet takes the full window width and
/// ignores the size.
enum ModalLayoutSize {
  /// 400 px, the Figma default.
  medium,

  /// 800 px.
  large,

  /// 1000 px.
  extraLarge,

  /// The window width less the theme's `lg` space token on each side.
  fillWidth,
}

/// One [WidgetStyle] per part of a [ModalLayout], each merged field by
/// field over the theme defaults (NFR-E02).
///
/// Register one app-wide through `StratumThemeApplication(
/// componentPartDefaults: (theme) => {ModalLayout: ModalLayoutStyle(...)})`;
/// it has value equality, so an equal map from a new builder call rebuilds
/// no modal layout (FO-03 US-06 FR-01).
@immutable
class ModalLayoutStyle {
  const new({
    this.surface,
    this.top,
    this.tab,
    this.body,
    this.handle,
    this.close,
  });

  /// The card or sheet that holds the slots: fill, shadow, corners, width,
  /// and padding.
  final WidgetStyle? surface;

  /// The box around [ModalLayout.top].
  final WidgetStyle? top;

  /// The box around [ModalLayout.tab].
  final WidgetStyle? tab;

  /// The box around [ModalLayout.body], which scrolls inside it.
  final WidgetStyle? body;

  /// The drag handle pill of a bottom sheet.
  final WidgetStyle? handle;

  /// The box around the close icon.
  final WidgetStyle? close;

  /// Returns a copy where each part merges [other]'s part over this one
  /// through [WidgetStyle.merge].
  ModalLayoutStyle merge(ModalLayoutStyle? other) {
    if (other == null) return this;
    return ModalLayoutStyle(
      surface: _mergePart(surface, other.surface),
      top: _mergePart(top, other.top),
      tab: _mergePart(tab, other.tab),
      body: _mergePart(body, other.body),
      handle: _mergePart(handle, other.handle),
      close: _mergePart(close, other.close),
    );
  }

  static WidgetStyle? _mergePart(WidgetStyle? base, WidgetStyle? other) =>
      base?.merge(other) ?? other;

  @override
  bool operator ==(Object other) =>
      other is ModalLayoutStyle &&
      other.surface == surface &&
      other.top == top &&
      other.tab == tab &&
      other.body == body &&
      other.handle == handle &&
      other.close == close;

  @override
  int get hashCode => Object.hash(surface, top, tab, body, handle, close);
}

/// The [ModalLayoutType] shown for [type] in a [window]: [type] when set,
/// else a bottom sheet below [WindowSize.tablet] and a modal at tablet and
/// above (US-20 FR-03; layout s03 inv. 71).
///
/// Internal: `layout.dart` hides it; `showModalLayout` imports this file.
ModalLayoutType resolveModalLayoutType(
  ModalLayoutType? type,
  WindowSize window,
) =>
    type ??
    (window < WindowSize.tablet
        ? ModalLayoutType.bottomSheet
        : ModalLayoutType.modal);

/// The content width of a modal layout of [type] and [size] in a window
/// [windowWidth] wide (US-20 FR-03; layout s03 inv. 71).
///
/// Below [WindowSize.tablet] a bottom sheet takes [windowWidth] and a
/// floating sheet [windowWidth] less its 8 px edge margin on each side,
/// both ignoring [size]. Otherwise [size] sets the width, clamped to
/// [windowWidth] less [edgeMargin] on each side, never below 0.
///
/// Internal: `layout.dart` hides it.
double modalContentWidth({
  required ModalLayoutType type,
  required ModalLayoutSize size,
  required WindowSize window,
  required double windowWidth,
  required double edgeMargin,
}) {
  if (type != ModalLayoutType.modal && window < WindowSize.tablet) {
    return switch (type) {
      ModalLayoutType.floating => math.max(
        0,
        windowWidth - 2 * _floatingMargin,
      ),
      _ => windowWidth,
    };
  }
  final limit = math.max(0.0, windowWidth - 2 * edgeMargin);
  final width = switch (size) {
    ModalLayoutSize.medium => 400.0,
    ModalLayoutSize.large => 800.0,
    ModalLayoutSize.extraLarge => 1000.0,
    ModalLayoutSize.fillWidth => limit,
  };
  return math.min(width, limit);
}

/// The floating sheet's edge margin (US-20 FR-04).
const double _floatingMargin = 8;

/// The corners of a modal layout of [type], concentric with the [screen]
/// corners where it sits on or near them (US-20 FR-04; layout s03 inv. 70).
///
/// A bottom sheet's top corners take [sheetTop], or at [fullHeight] the
/// screen radius, else [sheetTop]; its bottom corners take the screen
/// radius, else 0. A floating sheet's four corners take the screen radius
/// less its 8 px edge margin, else 38. A modal's four take [cardLarge].
/// A null [screen] means the radius is unknown.
///
/// Internal: `layout.dart` hides it.
BorderRadius modalCorners({
  required ModalLayoutType type,
  required BorderRadius? screen,
  required double sheetTop,
  required double cardLarge,
  bool fullHeight = false,
}) {
  Radius inset(Radius? corner, double fallback) => corner == null
      ? Radius.circular(fallback)
      : Radius.circular(math.max(0, corner.x - _floatingMargin));
  final top = Radius.circular(sheetTop);
  return switch (type) {
    ModalLayoutType.bottomSheet => BorderRadius.only(
      topLeft: fullHeight ? screen?.topLeft ?? top : top,
      topRight: fullHeight ? screen?.topRight ?? top : top,
      bottomLeft: screen?.bottomLeft ?? Radius.zero,
      bottomRight: screen?.bottomRight ?? Radius.zero,
    ),
    ModalLayoutType.floating => BorderRadius.only(
      topLeft: inset(screen?.topLeft, 38),
      topRight: inset(screen?.topRight, 38),
      bottomLeft: inset(screen?.bottomLeft, 38),
      bottomRight: inset(screen?.bottomRight, 38),
    ),
    ModalLayoutType.modal => BorderRadius.all(Radius.circular(cardLarge)),
  };
}

/// The state a modal route hands the [ModalLayout] it shows (US-20 FR-02
/// to FR-06): a [ModalLayout] reads each value where its own field is
/// null.
///
/// Internal: `layout.dart` hides it; `showModalLayout` publishes it.
class ModalLayoutScope extends InheritedWidget {
  const new({
    super.key,
    required this.type,
    required this.onDismiss,
    this.showBackground = true,
    this.fullHeight = false,
    required super.child,
  });

  /// The type the route resolved and shows.
  final ModalLayoutType type;

  /// Dismisses the route with no value; the close button and the handle
  /// call it when [ModalLayout.onClose] is null.
  final VoidCallback onDismiss;

  /// Whether a scrim draws behind the route; without one the surface also
  /// draws its outline (NFR-U08).
  final bool showBackground;

  /// Whether the sheet is dragged to full height (US-20 FR-04 E03,
  /// FR-05 E02).
  final bool fullHeight;

  /// The nearest scope above [context], else null for an inline modal
  /// layout.
  static ModalLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModalLayoutScope>();

  @override
  bool updateShouldNotify(ModalLayoutScope oldWidget) =>
      type != oldWidget.type ||
      onDismiss != oldWidget.onDismiss ||
      showBackground != oldWidget.showBackground ||
      fullHeight != oldWidget.fullHeight;
}

/// The slot widget of a sheet or a modal (US-20 FR-01): an optional [top],
/// an optional [tab], and a required [body], in that order, on a surface
/// drawn from theme tokens.
///
/// A bottom sheet shows a drag handle above the slots, and [showClose]
/// shows a close button at the surface's top end corner. Place it inline
/// in a page, where it draws no scrim and no route, or show it through
/// `showModalLayout`, whose route state it reads where its own fields are
/// null. Inline with no [onClose], nothing closes: no close button shows
/// and the handle is decoration that screen readers and Tab skip (US-20
/// FR-01 E06). With a bounded height the [body] takes the height left under the
/// other slots and, unless [scrollBody] is false, scrolls inside it.
///
/// Each part's style layers the theme defaults, then the app-wide
/// [ModalLayoutStyle] the application registers for [ModalLayout], then
/// [borderRadius], then [customStyle] (FO-08 US-06 FR-01).
///
/// Tab visits [top], [tab], and [body], then the handle and the close
/// button, whatever their place on screen (NFR-U02).
class ModalLayout extends StatelessWidget {
  const new({
    super.key,
    this.top,
    this.tab,
    required this.body,
    this.type,
    this.size = ModalLayoutSize.medium,
    this.showClose = true,
    this.onClose,
    this.borderRadius,
    this.safeArea,
    this.fullHeight,
    this.scrollBody = true,
    this.customStyle,
  });

  /// The first slot; null shows none.
  final Widget? top;

  /// The slot below [top]; null shows none.
  final Widget? tab;

  /// The slot below [tab].
  final Widget body;

  /// The type shown; null takes the route's, else a bottom sheet below
  /// [WindowSize.tablet] and a modal at tablet and above (US-20 FR-03).
  final ModalLayoutType? type;

  /// The content width (US-20 FR-03).
  final ModalLayoutSize size;

  /// Whether the close button shows, when it has an action: [onClose] or
  /// the route's dismissal.
  final bool showClose;

  /// Called by the close button and the handle. Null dismisses the route
  /// that shows this layout; inline, with no route, it shows no close
  /// button and leaves the handle as decoration (US-20 FR-01 E06).
  final VoidCallback? onClose;

  /// The surface's corners, winning over the concentric-corner rule of
  /// US-20 FR-04; [customStyle]'s surface radius wins over it.
  final BorderRadiusGeometry? borderRadius;

  /// Whether the content keeps clear of the system insets: the home
  /// indicator for a sheet, and the status bar once [fullHeight]; every
  /// inset for a modal. Null is true for a sheet and false for a modal
  /// (US-20 FR-05).
  final bool? safeArea;

  /// Whether a bottom sheet is dragged to full height, so its top corners
  /// take the screen radius (US-20 FR-04 E03). Null takes the route's,
  /// else false.
  final bool? fullHeight;

  /// Whether a scroll view wraps [body], so a body taller than the height
  /// left scrolls, as at large text. Pass false for a body that scrolls
  /// itself, such as a list view: it then gets that height unwrapped
  /// (US-20 FR-01 E05). The wrapper takes the route's primary scroll
  /// controller under `showModalLayout`, and never inline, where it would
  /// take the host page's.
  final bool scrollBody;

  /// The per-instance part styles, the highest layer (NFR-E02).
  final ModalLayoutStyle? customStyle;

  /// The handle pill's size, from the Figma bottom sheet.
  static const Size _handleSize = Size(36, 4);

  /// The gap between the slots, from the Figma modal layout frame.
  static const double _slotGap = 1;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final window = context.deviceWindow;
    final scope = ModalLayoutScope.maybeOf(context);
    final type =
        this.type ??
        scope?.type ??
        resolveModalLayoutType(null, window.windowSize);
    final fullHeight = this.fullHeight ?? scope?.fullHeight ?? false;
    final onClose = this.onClose ?? scope?.onDismiss;
    final labels = builtInLabelsOf(context);
    final style = _themeStyle(context, theme, type, fullHeight, scope)
        .merge(
          StratumComponentDefaults.partsOf<ModalLayoutStyle>(
            context,
            ModalLayout,
          ),
        )
        .merge(
          ModalLayoutStyle(surface: WidgetStyle(borderRadius: borderRadius)),
        )
        .merge(customStyle);
    final surface = style.surface ?? const WidgetStyle();
    final insets = _insets(window.safeArea, type, fullHeight);

    final close = showClose && onClose != null
        ? FocusTraversalOrder(
            order: const NumericFocusOrder(5),
            child: ContainerLayout(
              style: style.close ?? const WidgetStyle(),
              interaction: Interaction(onTap: onClose),
              semantics: SemanticsProperties(label: labels.closeButtonLabel),
              child: const Icon(Icons.close),
            ),
          )
        : null;
    final handle = type == ModalLayoutType.bottomSheet
        ? FocusTraversalOrder(
            order: const NumericFocusOrder(4),
            child: ContainerLayout(
              style: const WidgetStyle(alignment: Alignment.center),
              child: ContainerLayout(
                style: style.handle ?? const WidgetStyle(),
                interaction: onClose == null
                    ? null
                    : Interaction(onTap: onClose),
                semantics: onClose == null
                    ? null
                    : SemanticsProperties(label: labels.dismissLabel),
              ),
            ),
          )
        : null;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ContainerLayout(
        style: surface.copyWith(
          padding: (surface.padding ?? EdgeInsets.zero).add(insets),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.color.text.defaults.primary),
          child: IconTheme.merge(
            data: IconThemeData(color: theme.color.icon.defaults.primary),
            child: StackLayout(
              alignment: AlignmentDirectional.topEnd,
              clipBehavior: Clip.none,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => _slots(
                    style,
                    handle: handle,
                    bounded: constraints.hasBoundedHeight,
                    inRoute: scope != null,
                  ),
                ),
                ?close,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The theme layer of every part (NFR-E01).
  ModalLayoutStyle _themeStyle(
    BuildContext context,
    StratumTheme theme,
    ModalLayoutType type,
    bool fullHeight,
    ModalLayoutScope? scope,
  ) {
    final window = context.deviceWindow;
    final space = theme.space;
    return ModalLayoutStyle(
      surface: WidgetStyle(
        width: modalContentWidth(
          type: type,
          size: size,
          window: window.windowSize,
          windowWidth: window.width,
          edgeMargin: space.lg,
        ),
        margin: type == ModalLayoutType.floating
            ? const EdgeInsets.all(_floatingMargin)
            : null,
        padding: switch ((type, size)) {
          (ModalLayoutType.modal, ModalLayoutSize.medium) =>
            EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xl4),
          (ModalLayoutType.modal, _) => EdgeInsets.all(space.xl4),
          _ => EdgeInsets.zero,
        },
        backgroundColor: theme.color.background.defaults.normal,
        border: scope?.showBackground ?? true
            ? null
            : Border.all(
                color: theme.color.border.defaults.normal,
                width: theme.border.sm,
              ),
        borderRadius: modalCorners(
          type: type,
          screen: window.radius,
          sheetTop: theme.radius.sheet,
          cardLarge: theme.radius.cardLarge,
          fullHeight: fullHeight,
        ),
        dropShadow: theme.shadow.level4,
      ),
      top: const WidgetStyle(),
      tab: const WidgetStyle(),
      body: const WidgetStyle(),
      handle: WidgetStyle(
        width: _handleSize.width,
        height: _handleSize.height,
        borderRadius: BorderRadius.circular(theme.radius.full),
        backgroundColor: theme.color.icon.defaults.primary,
      ),
      close: WidgetStyle(backgroundBlur: theme.blur.level3),
    );
  }

  /// The system insets the content keeps clear of (US-20 FR-05).
  EdgeInsets _insets(EdgeInsets system, ModalLayoutType type, bool fullHeight) {
    final isModal = type == ModalLayoutType.modal;
    if (!(safeArea ?? !isModal)) return EdgeInsets.zero;
    if (isModal) return system;
    return EdgeInsets.only(
      top: fullHeight ? system.top : 0,
      bottom: system.bottom,
    );
  }

  /// The handle and the slots, top to bottom. When [bounded], the body
  /// takes the height left and, under [scrollBody], scrolls on the route's
  /// primary scroll controller when [inRoute] and on its own otherwise;
  /// unbounded, it sizes to its content.
  Widget _slots(
    ModalLayoutStyle style, {
    required Widget? handle,
    required bool bounded,
    required bool inRoute,
  }) {
    final top = this.top;
    final tab = this.tab;
    final bodyBox = FocusTraversalOrder(
      order: const NumericFocusOrder(3),
      child: ContainerLayout(
        style: style.body ?? const WidgetStyle(),
        scroll: bounded && scrollBody ? Scroll(primary: inRoute) : null,
        child: body,
      ),
    );
    return ColumnLayout(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: _slotGap,
      children: [
        ?handle,
        if (top != null)
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: ContainerLayout(
              style: style.top ?? const WidgetStyle(),
              child: top,
            ),
          ),
        if (tab != null)
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: ContainerLayout(
              style: style.tab ?? const WidgetStyle(),
              child: tab,
            ),
          ),
        if (bounded) Flexible(child: bodyBox) else bodyBox,
      ],
    );
  }
}
