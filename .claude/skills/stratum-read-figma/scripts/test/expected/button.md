---
name: Button
figma:
  fileKey: "SYNTHETIC_FILE_KEY"
  nodeId: "55483:24307"
  componentKey: "7687e83a1ce129a5ae07141a00699e2d0484a42c"
dart:
  class: StratumButton
  base: StratumStatefulWidget
  path: lib/src/components/control/button/button.dart
---

# Button

```dart
/// The primary interactive element for committing actions in a flow — submitting a form, confirming a decision, or
/// initiating a new process. **The label is the action, not the object**: it tells users exactly what will happen
/// when they tap.
///
/// ## Use when
///
/// - The action has a clear, nameable outcome ("Save", "Continue", "Delete")
/// - There is a hierarchy of importance among actions on the screen — style variants express that hierarchy
///
/// ## Don't use when
///
/// - The only content is an icon with no text label — use `IconButton` instead
/// - The action belongs to a social sign-in flow — use `SocialButton` instead
/// - The action connects a Web3 wallet — use `ConnectWalletButton` instead
/// - There is a primary action with related secondary options in a dropdown — use `SplitButton`
///
/// ## Related
///
/// - Use `IconButton` when there is no text label
/// - Use `VerticalButton` when icon + label needs a stacked vertical layout
/// - Use `SplitButton` when a primary action has related secondary options
/// - Use `SocialButton` for OAuth sign-in, `ConnectWalletButton` for Web3 wallet connection
```

Content guidelines, kept for `stratum-create-flutter-widget` to place:

- **Use sentence case** ("Add to cart", not "ADD TO CART")
- **Keep labels to 1–3 words**; longer labels should be rewritten, not truncated
- Avoid generic labels like "OK" or "Yes" — use the specific action as the label

## Properties

| Figma | Dart field | Type | Default |
|---|---|---|---|
| `💬 label` | `label` | `String` | required |
| `🕶️ style` | `style` | `StratumButtonStyle` | `StratumButtonStyle.filledBrand` |
| `📐 size` (HUGE, LARGE, MEDIUM, SMALL) | `size` (base) | `WidgetSize?` | `null` (theme default) |
| `✏️ leftIcon` + `👁️ showLeftIcon` | `leftIcon` | `Widget?` | `null` |
| `✏️ rightIcon` + `👁️ showRightIcon` | `rightIcon` | `Widget?` | `null` |
| nested `Badge` + `👁️ showBadge` | `badge` | `StratumBadge?` | `null` |
| `🚦 state` (NORMAL, HOVERED, PRESSED) | `state` (base) | `FullWidgetState` | `FullWidgetState.normal` |
| `🚦 state` (DISABLED) | `disabled` (base) | `bool` | `false` |
| `🚦 state` (PROGRESS, LOADING) | `loading` (base) | `bool` | `false` |
| `🚦 state` (PROGRESS) | `progress` | `double?` | `null` |
| — | `onPressed` | `VoidCallback?` | `null` |
| — | `customStyle` (base) | `WidgetStyle?` | `null` |

```dart
const StratumButton({
  required this.label,
  this.style = StratumButtonStyle.filledBrand,
  super.size,
  this.leftIcon,
  this.rightIcon,
  this.badge,
  super.state,
  super.disabled,
  super.loading,
  this.progress,
  this.onPressed,
  super.customStyle,
});
```

## Enums

### `StratumButtonStyle` (new)

| Figma value | Dart value | Doc |
|---|---|---|
| `FILLED_BRAND` | `filledBrand` |  |
| `OUTLINE` | `outline` |  |
| `GHOST` | `ghost` |  |
| `SHADED` | `shaded` |  |
| `FILLED` | `filled` |  |
| `DESTRUCTIVE` | `destructive` |  |

## States

| Figma value | Dart |
|---|---|
| `NORMAL` | `state: FullWidgetState.normal` |
| `HOVERED` | `state: FullWidgetState.hovered` |
| `PRESSED` | `state: FullWidgetState.pressed` |
| `PROGRESS` | `loading: true` plus `progress: double?` |
| `LOADING` | `loading: true` |
| `DISABLED` | `disabled: true` |

## Slots

| Slot | Size | Width | Height | Sizing (H × V) | Wrapper |
|---|---|---|---|---|---|
| `leftIcon` | `huge` | 24 | 24 | FIXED × FIXED | SizedBox |
| `leftIcon` | `large` | 24 | 24 | FIXED × FIXED | SizedBox |
| `leftIcon` | `medium` | 20 | 20 | FIXED × FIXED | SizedBox |
| `leftIcon` | `small` | 16 | 16 | FIXED × FIXED | SizedBox |
| `rightIcon` | `huge` | 24 | 24 | FIXED × FIXED | SizedBox |
| `rightIcon` | `large` | 24 | 24 | FIXED × FIXED | SizedBox |
| `rightIcon` | `medium` | 20 | 20 | FIXED × FIXED | SizedBox |
| `rightIcon` | `small` | 16 | 16 | FIXED × FIXED | SizedBox |

## Visual tokens

| Style | State | Background | Foreground | Border | Radius | Padding (T R B L) | Gap | Text |
|---|---|---|---|---|---|---|---|---|
| `FILLED_BRAND` | `NORMAL` | `button.primary.normal` | `text.default.primary-on-color` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `FILLED_BRAND` | `HOVERED` | `button.primary.normal` | `text.default.primary-on-color` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `FILLED_BRAND` | `PRESSED` | `button.primary.normal` | `text.default.primary-on-color` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `FILLED_BRAND` | `PROGRESS` | `background.subtle.gray` | — | `border.control.solid` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `FILLED_BRAND` | `LOADING` | `background.subtle.gray` | — | `border.control.solid` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `FILLED_BRAND` | `DISABLED` | `button.primary.normal` | `text.default.primary-on-color` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `OUTLINE` | `NORMAL` | `background.control.input` | `text.default.primary` | `border.default.normal` | by size | by size | 0 (hard-coded) | by size |
| `OUTLINE` | `HOVERED` | `background.control.input` | `text.default.primary` | `border.default.normal` | by size | by size | 0 (hard-coded) | by size |
| `OUTLINE` | `PRESSED` | `background.control.input` | `text.default.primary` | `border.default.normal` | by size | by size | 0 (hard-coded) | by size |
| `OUTLINE` | `PROGRESS` | `background.control.input` | — | `border.default.normal` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `OUTLINE` | `LOADING` | `background.control.input` | — | `border.default.normal` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `OUTLINE` | `DISABLED` | `background.control.input` | `text.default.primary` | `border.default.normal` | by size | by size | 0 (hard-coded) | by size |
| `GHOST` | `NORMAL` | — | `text.default.primary` | — | by size | by size | 0 (hard-coded) | by size |
| `GHOST` | `HOVERED` | `state.hover-light` | `text.default.primary` | — | by size | by size | 0 (hard-coded) | by size |
| `GHOST` | `PRESSED` | `state.press-light` | `text.default.primary` | — | by size | by size | 0 (hard-coded) | by size |
| `GHOST` | `PROGRESS` | — | — | — | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `GHOST` | `LOADING` | — | — | — | by size | by size | 10 (hard-coded), `space.2xs`, `space.3xs` | — |
| `GHOST` | `DISABLED` | — | `text.default.primary` | — | by size | by size | 0 (hard-coded) | by size |
| `SHADED` | `NORMAL` | `button.shaded.normal` | `text.default.primary` | `border.control.shaded` | by size | by size | 0 (hard-coded) | by size |
| `SHADED` | `HOVERED` | `button.shaded.normal` | `text.default.primary` | `border.control.shaded` | by size | by size | 0 (hard-coded) | by size |
| `SHADED` | `PRESSED` | `button.shaded.normal` | `text.default.primary` | `border.control.shaded` | by size | by size | 0 (hard-coded) | by size |
| `SHADED` | `PROGRESS` | `background.subtle.gray` | — | `border.control.shaded` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `SHADED` | `LOADING` | `background.subtle.gray` | — | `border.control.shaded` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `SHADED` | `DISABLED` | `button.shaded.normal` | `text.default.primary` | `border.control.shaded` | by size | by size | 0 (hard-coded) | by size |
| `FILLED` | `NORMAL` | `button.filled.normal` | `text.default.primary-inverse` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `FILLED` | `HOVERED` | `button.filled.normal` | `text.default.primary-inverse` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `FILLED` | `PRESSED` | `button.filled.normal` | `text.default.primary-inverse` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `FILLED` | `PROGRESS` | `background.subtle.gray` | — | `border.control.solid` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `FILLED` | `LOADING` | `background.subtle.gray` | — | `border.control.solid` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `FILLED` | `DISABLED` | `button.filled.normal` | `text.default.primary-inverse` | `border.control.solid` | by size | by size | 0 (hard-coded) | by size |
| `DESTRUCTIVE` | `NORMAL` | `button.destructive.normal` | `text.color.negative-on-color` | `border.control.destructive` | by size | by size | 0 (hard-coded) | by size |
| `DESTRUCTIVE` | `HOVERED` | `button.destructive.normal` | `text.color.negative-on-color` | `border.control.destructive` | by size | by size | 0 (hard-coded) | by size |
| `DESTRUCTIVE` | `PRESSED` | `button.destructive.normal` | `text.color.negative-on-color` | `border.control.destructive` | by size | by size | 0 (hard-coded) | by size |
| `DESTRUCTIVE` | `PROGRESS` | `background.subtle.negative` | — | `border.control.destructive` | by size | by size | `space.xs`, 8 (hard-coded), `space.3xs` | — |
| `DESTRUCTIVE` | `LOADING` | `background.subtle.negative` | — | `border.control.destructive` | by size | by size | `space.xs`, `space.2xs`, `space.3xs` | — |
| `DESTRUCTIVE` | `DISABLED` | `button.destructive.normal` | `text.color.negative-on-color` | `border.control.destructive` | by size | by size | 0 (hard-coded) | by size |

| Size | Radius | Padding (T R B L) | Text |
|---|---|---|---|
| `huge` | `radius.md` | 14 (hard-coded) `space.lg` 14 (hard-coded) `space.lg` | `body-huge/18-semi-bold` → `FontType.body`, `FontSize.s18`, `FontWeight.w600` |
| `large` | `radius.md` | `space.sm` `space.md` `space.sm` `space.md` | `body-large/16-semi-bold` → `FontType.body`, `FontSize.s16`, `FontWeight.w600` |
| `medium` | `radius.md` | `space.2xs` `space.sm` `space.2xs` `space.sm` | `body/14-semi-bold` → `FontType.body`, `FontSize.s14`, `FontWeight.w600` |
| `small` | `radius.sm` | `space.2xs` `space.xs` `space.2xs` `space.xs` | `body-small/12-semi-bold` → `FontType.body`, `FontSize.s12`, `FontWeight.w600` |

## Nested

| Figma component | Layer | Dart class | Field | Exposed properties |
|---|---|---|---|---|
| `FocusBorder` | `FocusBorder` | — | none (helper) | `style`, `state` |
| `Badge` | `Badge` | `StratumBadge` | `badge` | `removable`, `showIcon`, `icon`, `label`, `style`, `color`, `size` |
| `SpinnerIndeterminate` | `SpinnerIndeterminate` | unresolved | none (internal) | — |

## Open questions

None.
