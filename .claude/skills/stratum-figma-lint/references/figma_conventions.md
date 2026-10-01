# Stratum Figma conventions: tables and rationale

`../scripts/conventions.js` is the single source of truth. The tables below are generated from it; the rest of this
file is hand-written rationale with one before/after example per rule.

## Convention tables

<!-- generated:start -->

_Generated from `scripts/conventions.js` by `node scripts/gen_conventions_md.js`. Edit the data, then rerun it._

### Rules

The report takes each message from this table (results carry rule ids only) and appends a row's note, which holds only detail the message cannot say.

| Rule | Severity | Message |
| --- | --- | --- |
| L01 | blocking | typo: close to a known spelling (see suggestion) |
| L02 | blocking | two properties normalize to the same name |
| L03 | blocking | name has no letters after normalization |
| L04 | blocking | Dart reserved word or built-in identifier |
| L05 | convention | emoji missing or not matching the role template |
| L06 | convention | name or value format |
| L07 | convention | value not UPPER_SNAKE, or emoji outside feedback and direction values |
| L08 | convention | boolean variant values are False/True |
| L09 | convention | feedback values are 🔵 INFO, 🔴 NEGATIVE, 🟡 WARNING, 🟢 POSITIVE |
| L10 | convention | value outside the state, size, or color vocabulary |
| L11 | convention | visual variants belong in `style`, not `type` |
| L12 | convention | hard-coded color, not bound to a variable |
| L13 | advisory | `ACTIVE` is ambiguous |
| L14 | advisory | variant has a single value |
| L15 | advisory | mixed axis: interaction value outside `state` or `status`, or slot value in `position` or `type` without a ❖ slot of the same name |
| L16 | advisory | legacy name for a canonical name |
| L17 | — | retired 2026-10-01: `LOADING` and `PROGRESS` inside `state` are allowed |
| L18 | info | variant matrix incomplete (existing/product) |
| L19 | info | no description (Figma can read it empty; re-publish the library) |
| L20 | convention | numbered list toggles not named `👁️ show<Item><N>` |

### Emoji by role

First matching row wins.

| Role | Emoji | Property type | Match |
| --- | --- | --- | --- |
| show | 👁️ | BOOLEAN | name starts with `show` |
| show | 👁️ | VARIANT | name starts with `show` |
| graphicToggle | 👁️ | BOOLEAN | `icon`, `logo`, renamed `show<Name>` |
| loading | ⏳ | BOOLEAN | `loading` |
| checked | ✅ | BOOLEAN, VARIANT | `checked`, `selected` |
| expanded | ↕️ | VARIANT | `expanded` |
| filled | ✍️ | VARIANT | `filled` |
| theme | 🌗 | VARIANT | `theme`, `darkMode` |
| flag | 🔘 | BOOLEAN | any name |
| flag | 🔘 | VARIANT | options `False`/`True` |
| text | 💬 | TEXT | any name |
| slot | ❖ | SLOT | any name |
| slot | ❖ | INSTANCE_SWAP | swapped component name contains `Slot` or starts with `❖` |
| slot | ❖ | INSTANCE_SWAP | any default, name `top`, `body`, `bottom`, `left`, `right`, `tab`, `content`, `snackbar`, `slot` |
| icon | ✏️ | INSTANCE_SWAP | any name |
| style | 🕶️ | VARIANT | `style` |
| type | 🔖 | VARIANT | `type` |
| size | 📐 | VARIANT | `size` |
| state | 🚦 | VARIANT | `state`, `status` |
| color | 🌈 | VARIANT | `color` |
| accent | 💡 | VARIANT | `accent` |
| position | 📍 | VARIANT | `position`, `align` |
| direction | ➡️ | VARIANT | `direction`, `arrow` |
| layout | ⬒ | VARIANT | `layout` |
| platform | 🖥️ | VARIANT | `platform`, `os`, `browser` |
| count | 🔢 | VARIANT | `items`, `tabs`, `steps`, `section`, `page`, `attachments`, `rating`, `avatars`, `frame` |
| graphic | 🏞️ | VARIANT | `graphic`, `image`, `emotion` |
| variant | 🔖 | VARIANT | any name |

### Canonical property names

| Canonical | Type | Replaces |
| --- | --- | --- |
| `helperText` | TEXT | `helper` |
| `showHelperText` | BOOLEAN | `showHelper` |
| `errorText` | TEXT | `error` |
| `showErrorText` | BOOLEAN | `showError` |
| `warningText` | TEXT | `warning` |
| `showWarningText` | BOOLEAN | `showWarning` |
| `successText` | TEXT | `success` |
| `showSuccessText` | BOOLEAN | `showSuccess` |
| `groupHelperText` | TEXT | `groupHelper` |
| `showGroupHelperText` | BOOLEAN | `showGroupHelper` |
| `groupErrorText` | TEXT | `groupError` |
| `showGroupErrorText` | BOOLEAN | `showGroupError` |
| `label` | any | `labelText` |
| `stepNumber` | any | `step` |
| `showLine` | BOOLEAN | `line` |

### Numbered list toggles

One BOOLEAN per list item, named `👁️ show<Item><N>`. L20 reports these forms once per component; `L01`, `L03`, `L05`, `L06` stay silent on them.

| Legacy form | Examples |
| --- | --- |
| `<N>. <Item>` | `1. Checkbox`, `2. Checkbox` |
| `<Item> <N>` | `Menu item 1`, `Menu item 2` |
| `<Item> <N> (first\|last)` | `Accordion 1 (first)`, `Accordion 2 (last)` |
| `<other emoji> show<Item><N>` | `🔘 showTag1`, `🔘 showTag2` |

### Value vocabularies

#### `state` (`FullWidgetState`)

Roles: `state`. Figma only (allowed, not in the enum): `PROGRESS`. Dart only: `INITIAL`, `SCROLLED_UNDER`, `SUCCESS`, `CANCEL`, `WARNING`, `FAIL`. Any value may end in a part suffix: `_LEFT`, `_RIGHT`.

| Value | Replaces |
| --- | --- |
| `NORMAL` |  |
| `HOVERED` | `HOVER` |
| `PRESSED` | `PRESS` |
| `FOCUSED` | `FOCUS` |
| `DRAGGED` | `DRAG` |
| `SELECTED` |  |
| `DISABLED` |  |
| `LOADING` |  |
| `EMPTY` |  |

#### `feedback` (`FeedbackState`)

Roles: `state`, `color`. Figma only (allowed, not in the enum): `⚫️ NORMAL`.

| Value | Replaces |
| --- | --- |
| `🔵 INFO` | `INFO` |
| `🔴 NEGATIVE` | `NEGATIVE`, `ERROR` |
| `🟡 WARNING` | `WARNING` |
| `🟢 POSITIVE` | `POSITIVE`, `SUCCESS` |

#### `size` (`WidgetSize`)

Roles: `size`. Figma only (allowed, not in the enum): `FILL_WIDTH`, `EXTRA_TINY`.

| Value | Replaces |
| --- | --- |
| `TINY` |  |
| `EXTRA_SMALL` |  |
| `SMALL` |  |
| `MEDIUM` |  |
| `LARGE` |  |
| `EXTRA_LARGE` |  |
| `HUGE` |  |

#### `color` (`ColorEnum`)

Roles: `color`. Figma only (allowed, not in the enum): `NONE`, `BLACK`, `GHOST`, `CUSTOM`, `LOADING`.

| Value | Replaces |
| --- | --- |
| `BRAND` |  |
| `RED` |  |
| `PINK` |  |
| `ROSE` |  |
| `VIOLET` |  |
| `PURPLE` |  |
| `INDIGO` |  |
| `BLUE` |  |
| `CYAN` |  |
| `TEAL` |  |
| `EMERALD` |  |
| `GREEN` |  |
| `MOSS` |  |
| `LIME` |  |
| `YELLOW` |  |
| `AMBER` |  |
| `ORANGE` |  |
| `BROWN` |  |
| `BLUE_GRAY` |  |
| `GRAY` |  |

#### `fontSize` (`FontSize`)

Dart only: `CUSTOM`.

| Value | Replaces |
| --- | --- |
| `10` |  |
| `12` |  |
| `14` |  |
| `16` |  |
| `18` |  |
| `20` |  |
| `24` |  |
| `36` |  |
| `48` |  |
| `56` |  |

#### `windowSize` (`WindowSize`)

Roles: `platform`.

| Value | Replaces |
| --- | --- |
| `WATCH` |  |
| `MOBILE` |  |
| `TABLET` |  |
| `DESKTOP` |  |
| `BIG_DESKTOP` |  |

### ACTIVE suggestions

| Components | Suggestion |
| --- | --- |
| TextInput, Combobox, Dropdown, DateInput, TimeInput, NumberInput, TextArea, TextEditor, Stepper, InlineEditableText, ChatMessageInput | `FOCUSED` |
| TextDropdown, IconDropdown | `↕️ expanded: True` |
| SideNavigationMenu, PageDot, ChartBar | `SELECTED` |
| BottomNavigationMenu | `PRESSED` |
| RatingElement, RatingEmoji | `✅ selected: False/True; keep NORMAL/HOVERED` |
| any other | a precise value: FOCUSED, SELECTED, PRESSED, or ↕️ expanded: True |

### Known words

| Kind | Words |
| --- | --- |
| name | `accent`, `action`, `addon`, `align`, `arrow`, `artist`, `attachments`, `avatars` |
| name | `badge`, `bank`, `body`, `body2`, `body3`, `bottom`, `brandName`, `browser` |
| name | `captionBottom`, `captionRight`, `center`, `char`, `checked`, `code`, `color`, `colored`, `condition`, `content`, `contentText`, `count`, `counter` |
| name | `country` |
| name | `dark`, `darkMode`, `date`, `description`, `detail`, `direction`, `domain`, `dotPosition`, `dropdown` |
| name | `emoji`, `emotion`, `errorIcon`, `errorMessage`, `esc`, `example`, `expand`, `expandable`, `expanded` |
| name | `feature`, `fileFilled`, `fileName`, `filled`, `focused`, `format`, `frame`, `fullWidth` |
| name | `graphic`, `groupLabel`, `groupName` |
| name | `hasFilter`, `header`, `helperRight`, `horizontal`, `hour` |
| name | `icon`, `iconFilled`, `illustration`, `image`, `infoGlyph`, `infoIcon`, `input`, `inputText`, `items` |
| name | `key` |
| name | `layout`, `left`, `leftIcon`, `length`, `level`, `loading`, `logo` |
| name | `macOS`, `maxValue`, `method`, `minMaxPosition`, `minute`, `minValue` |
| name | `name`, `number` |
| name | `option`, `os`, `outgoing` |
| name | `page`, `passed`, `path`, `percent`, `placeholder`, `platform`, `portrait`, `position`, `positiveIcon`, `primaryButton` |
| name | `range`, `rating`, `ratio`, `removable`, `resizable`, `reverse`, `right`, `rightIcon` |
| name | `safeArea`, `safeIndicator`, `safeStatusBar`, `secondaryButton`, `section`, `secure`, `select`, `selected`, `selectedIcon` |
| name | `separator`, `showAction`, `showActions`, `showAmPm`, `showArrow`, `showArrowLeft`, `showArrowRight`, `showAvatar`, `showBack` |
| name | `showBackground`, `showBackNext`, `showBadge`, `showBaseLine`, `showBlur`, `showBody`, `showBody2`, `showBody3`, `showBottom` |
| name | `showBottomButtons`, `showBottomDateRange`, `showBrandLogo`, `showButton`, `showButtons`, `showCamera`, `showCaptionBottom` |
| name | `showCaptionRight`, `showCenter`, `showClearButton`, `showClose`, `showCloseable`, `showCloseButton`, `showCommand` |
| name | `showContent`, `showControl`, `showCounter`, `showCover`, `showDescription`, `showDiff`, `showDislikeButton`, `showDivider` |
| name | `showDropdown`, `showEmojiButton`, `showEstimateLine`, `showExpandable`, `showExternal` |
| name | `showFileAttachment`, `showFileButton`, `showFilterButton`, `showFullLoading`, `showGmt` |
| name | `showHeader`, `showHelperRight`, `showIcon`, `showImage`, `showIndicator` |
| name | `showInfo`, `showInfoButton`, `showKeyboard`, `showLabel`, `showLeft`, `showLeftIcon`, `showLeftItems`, `showLikeButton` |
| name | `showLineNumber`, `showLink`, `showLoading`, `showMaxValue`, `showMediaButton`, `showMetaData` |
| name | `showMinimizeButton`, `showMinValue`, `showMore`, `showMoreButton`, `showMoreMediaAttachment`, `showName` |
| name | `showNegativeButton`, `showNextAndBack`, `showNotification`, `showNumber`, `showOption`, `showOverflow`, `showPagination` |
| name | `showPath`, `showPopover`, `showPrimaryButton`, `showReplyButton`, `showRequired`, `showRight`, `showRightIcon` |
| name | `showRightItems`, `showScrollbar`, `showSearchButton`, `showSecondaryButton`, `showShift`, `showShortcut`, `showSideButtons` |
| name | `showSnackbar`, `showSortButton`, `showSplit`, `showStatusBar`, `showStatusDot`, `showStatusRing`, `showSubMenu`, `showSubmenu` |
| name | `showSubtitle`, `showSuggestionBar`, `showTab`, `showTertiaryButton`, `showText` |
| name | `showTickMark`, `showTitle`, `showTooltip`, `showTop`, `showTopDateRange`, `showTutorial`, `showTwoMonths`, `showUpload` |
| name | `showVolume`, `simple`, `size`, `slot`, `slot2`, `slotItem`, `snackbar`, `sorting`, `stacked`, `state`, `status` |
| name | `steps`, `store`, `style`, `subtitle`, `successMessage` |
| name | `tab`, `tabName`, `tabs`, `text`, `theme`, `title`, `titleText`, `toggle`, `top`, `track`, `transparent`, `type` |
| name | `underlined` |
| name | `value` |
| name | `warningIcon`, `weight`, `wide` |
| value | `ACCENT`, `ACTION`, `ACTION_DESTRUCTIVE`, `ACTIVE`, `AIFF`, `ALT`, `ANDROID`, `ANGRY`, `ANIMATION`, `ANOTHER_MONTH`, `APPGALLERY`, `APPLE` |
| value | `APPSTORE`, `ARCHIVE`, `ARROW`, `ASCENDING`, `AUTHENTICATING`, `AUTO`, `AVATAR`, `AVI` |
| value | `BAD_GATEWAY`, `BASE`, `BITMAP`, `BLACK`, `BLUE`, `BOLD`, `BORDER`, `BOTTOM`, `BOTTOM_CENTER`, `BOTTOM_INDICATOR`, `BOTTOM_LEFT` |
| value | `BOTTOM_RIGHT`, `BOTTOM_SHEET`, `BRAND`, `BREADCRUMBS`, `BROWN`, `BUTTON`, `BUTTON_CENTER`, `BUTTON_HORIZONTAL`, `BUTTON_LEFT` |
| value | `BUTTON_VERTICAL`, `BUTTONS` |
| value | `CENTER`, `CHAR`, `CHECKBOX`, `CHECKED`, `CHROME`, `CMD`, `CODE`, `COINBASE_WALLET`, `COLLAPSED`, `COME_BACK_LATER`, `COMING_SOON` |
| value | `COMPACT`, `COMPLETED`, `CONDITION`, `CONFIRMED`, `CONTENT`, `CONTROL`, `CSS`, `CSV`, `CURRENT`, `CUSTOM` |
| value | `DARK`, `DAY_OF_THE_WEEK`, `DEFAULT`, `DELETE`, `DELETE_CONFIRMATION`, `DELIVERY`, `DESCENDING`, `DESKTOP`, `DESTRUCTIVE`, `DIVIDER` |
| value | `DOCS`, `DOCX`, `DOING`, `DONE`, `DOT`, `DOTS`, `DOWNLOADING`, `DRAGGED`, `DROPDOWN` |
| value | `EMOJI`, `EMPTY`, `EPS`, `ERROR`, `EXPANDED`, `EXTRA_LARGE`, `EXTRA_SMALL`, `EXTRA_TINY` |
| value | `FACEBOOK`, `FADED`, `FAILED`, `FALLING`, `FATAL_ERROR`, `FEATURE`, `FILL`, `FILL_WIDTH`, `FILLED`, `FILLED_BRAND`, `FIRST`, `FLOAT`, `FLOATING` |
| value | `FOCUSED`, `FOUR_FIFTHS`, `FROWNING`, `FULL` |
| value | `GALAXY_STORE`, `GESTURE`, `GET`, `GHOST`, `GITHUB`, `GOLDEN`, `GOOGLE`, `GOOGLE_PLAY`, `GRAY`, `GREEN`, `GRINNING`, `GROUP_HEADER` |
| value | `GROUP_HEADING` |
| value | `HALF`, `HEART`, `HEIC`, `HORIZONTAL`, `HOVERED`, `HTML`, `HUGE` |
| value | `ICON`, `ICONS`, `ILLUSTRATION`, `IMAGE`, `IMAGE_VIDEO`, `IN_REVIEW`, `INACTIVE`, `INCOMPLETE`, `INDETERMINATE`, `INFO` |
| value | `INPUT`, `INPUT_BUTTON_HORIZONTAL`, `INPUT_BUTTON_VERTICAL`, `INSIDE`, `IOS` |
| value | `JPG`, `JS`, `JSON` |
| value | `LARGE`, `LEDGER`, `LEFT`, `LEFT_BOTTOM`, `LEFT_RIGHT`, `LEFT_TOP`, `LETTER`, `LIGHT`, `LINE`, `LIST_IS_EMPTY`, `LOADING`, `LOGGED_OUT` |
| value | `LOTTIE` |
| value | `M4A`, `MAC_APPSTORE`, `MAC_OS`, `MEDIUM`, `MESSAGE_SENT`, `METAMASK`, `MICROSOFT`, `MIDDLE`, `MIXED`, `MIXER`, `MOBILE`, `MODAL`, `MOV`, `MP3` |
| value | `MP4`, `MUSIC` |
| value | `NEGATIVE`, `NEUTRAL`, `NEW_UPDATED`, `NO_COMMENTS`, `NO_CONNECT`, `NO_CONTROL`, `NO_MESSAGE`, `NODE`, `NONE`, `NORMAL`, `NUMBER` |
| value | `NUMBERS` |
| value | `OFF`, `ON`, `ONE_FIFTH`, `ORDER_COMPLETED`, `OTHER`, `OUTLINE`, `OUTSIDE`, `OVERFLOW` |
| value | `PAGE`, `PAGE_NOT_FOUND`, `PAGE_UNDER_CONSTRUCTION`, `PATCH`, `PAYMENT_PROCESSED`, `PDF`, `PNG`, `POSITIVE`, `POST`, `PPTX`, `PREFIX` |
| value | `PRESSED`, `PROFILE`, `PROGRESS`, `PROGRESS_FILLED`, `PURPLE`, `PUT` |
| value | `RADIO`, `RANGE_END`, `RANGE_MIDDLE`, `RANGE_START`, `RAR`, `RECTANGLE`, `RED`, `REGULAR`, `RESPONSIVE`, `RETRY`, `RIGHT`, `RIGHT_BOTTOM` |
| value | `RIGHT_DRAWER`, `RIGHT_SIDE`, `RIGHT_TOP`, `RISING`, `ROUND` |
| value | `SAFARI`, `SEARCH`, `SEARCHING`, `SECOND`, `SECTION`, `SELECTED`, `SENDING`, `SENT`, `SHADED`, `SHIFT`, `SIGN_IN`, `SIGN_UP`, `SIMPLE`, `SLASH`, `SMALL` |
| value | `SMILING` |
| value | `SPREAD_SHEET`, `SQUARE`, `STAR`, `START`, `STRONG`, `SUBTLE`, `SUCCESS`, `SUFFIX`, `SVG`, `SWATCHES` |
| value | `TABLET`, `TEAL`, `TEXT`, `TEXT_BOTTOM`, `TEXT_CENTER`, `TEXT_FIELD`, `TEXT_LEFT`, `TEXT_RIGHT`, `TEXT_TOP`, `THIRD`, `THREE_FIFTHS`, `TIFF`, `TINY` |
| value | `TITLE`, `TODAY`, `TOGGLE`, `TOP`, `TOP_CENTER`, `TOP_LEFT`, `TOP_RIGHT`, `TOP_STATUS_BAR`, `TRIANGLE`, `TWITTER`, `TWO_FIFTHS`, `TXT`, `TYPING` |
| value | `UNDERLINE`, `UNSUBSCRIBED`, `UPGRADE`, `UPLOADING`, `URGENT` |
| value | `VECTOR`, `VERTICAL`, `VIDEO`, `VIOLET` |
| value | `WAITING`, `WALLETCONNECT`, `WARNING`, `WAV`, `WEBP`, `WELCOME`, `WINDOWS` |
| value | `XLSX` |
| value | `YELLOW` |
| value | `ZIP` |

### Skip rules

Scope 1 lints the whole file, scope 2 the pages the user names, scope 3 one node.

| Target | Match | Value | Scopes |
| --- | --- | --- | --- |
| page | prefix | `.` | 1, 2 |
| page | prefix | `─` | 1, 2 |
| page | prefix | `-` | 1, 2 |
| page | prefix | `☀` | 1 |
| page | contains | `Example` | 1 |
| frame | exact | `Doc` | 1, 2, 3 |
| frame | exact | `Examples` | 1, 2, 3 |
| component | prefix | `_` | 1, 2, 3 |

<!-- generated:end -->

## Why names and values matter

`stratum-read-figma` turns each component property into a Dart constructor field and each variant value into an enum
member. The normalized name (strip the `#<id>` suffix, emoji, and symbols, then camelCase) is the field name, and the
value in `UPPER_SNAKE` maps to a Dart enum member in camelCase. Anything that breaks that mapping, or maps two things to
one identifier, breaks the generated code.

## Emoji roles

The emoji tells a reader what kind of field a property becomes before they read its name. The role comes from the
property type plus its name, so a new `show*` toggle or a new `iconSize` variant needs no dictionary entry: a name
matches a role key when it equals the key or ends with it in camelCase (`iconSize` takes the `size` role). The first
matching row of `emojiRoles` wins, so the named flag roles (`show*`, `loading`, `checked`, `expanded`, `filled`) come
before the generic flag, and a VARIANT with `False/True` options is a flag even when its name says otherwise
(`🌈 color` with `False/True` becomes `🔘`). The `theme` row is the exception: it sits above the VARIANT flag, so
`🌗 darkMode: False|True` keeps its theme emoji. A BOOLEAN that shows or hides a graphic (`icon`, `logo`, or a name ending
in `Icon` or `Logo`) is a `show*` toggle under another name, so its row renames it: `💼 logo` → `👁️ showLogo`,
`🔍 Icon` → `👁️ showIcon`. A logo follows the icon rule; an INSTANCE_SWAP `logo` stays `✏️`.

An INSTANCE_SWAP takes its role from the component it swaps in by default: a default whose name contains `Slot` or
starts with `❖` makes the property a `❖` slot (PageLayout `❖ top`), and any other default makes it an `✏️` swap. A
property named after a layout region (the third slot row of Emoji by role) is a `❖` slot whatever its default,
because a layout fills that region with a real component: CardLayout `❖ top` defaults to `TopNavigation`, and Sidebar
`❖ top`, `❖ body`, and `❖ bottom` default to `SideNavigationMenu`. An older slot emoji gets L05 with the `❖`
suggestion (MenuItem `↻ right` → `❖ right`). The entry script resolves each default id once in Figma (the main
component for an instance, the set for a variant) and stores the name as `defaultName` on the property, so
`--mode raw` fixtures carry it.

## Severity and de-duplication

🔴 blocking breaks code generation; `stratum-read-figma` stops on it. 🟠 convention yields working but inconsistent
Dart. 🟡 advisory is a design smell. ℹ️ info is a fact to confirm.

Each problem is reported once. For one value, the first rule in `valueRuleOrder` wins: `HOVERD` is L01, never also
L10 or L07, and a value whose only fault is a non-ASCII space is L06, never also L09 or L07. `ACTIVE` (and `INACTIVE`
next to it) belongs to L13 only. A name that normalizes to empty (L03) silences the other name rules on that
property, and L20 silences L01, L03, L05, and L06 on the properties of a numbered list-toggle series. Rules about a
different problem on the same value still fire: `HOVER` in a `size` variant (CalendarItem) is both L10 (outside
`WidgetSize`) and L15 (wrong axis).

## Rules

### L01 typo 🔴

A misspelled name or value becomes a misspelled Dart identifier that every caller then copies. L01 compares a value
with its role vocabulary (state, size, color, and the platform role against `WindowSize`), then with `knownWords`,
then with values of the same property name used by more components in the batch. It compares a name with
`knownWords` plus the canonical and legacy names, then with more frequent names of the same type. `knownWords` works
in every scope, so the single-set gate of `stratum-read-figma` catches `MXIED` although `MIXED` lives on another page.
A word in `knownWords` or a vocabulary is never a typo. L01 also never fires on:

- a legacy value (`HOVER`, `PRESS`, `FOCUS`, `DRAG`): it is an old convention, so L10 reports it with the table's
  suggestion. Misspellings such as `HOVERD`, `HOVERDED`, and `DRAGED` are not legacy values and stay L01;
- a compound whose words all appear in known names or values (`LEFT_RIGHT` = `LEFT` + `RIGHT`, `showLeftItems` =
  `show` + `Left` + `Items`);
- a known word with a numeric suffix (`LOADING_1`, `slot2`), which marks an animation frame or a numbered item;
- a numbered list toggle, which L20 owns.

`knownWords` values carry no emoji, so L01 compares the word after a feedback dot or direction arrow. Boolean and
feedback words go to L08 and L09 instead. Words of 4 characters allow distance 1, longer words distance 2. Plural and
digit-only differences never count, and two spellings used side by side in one property or component are distinct.
When two names sit at the same distance, a canonical name wins over a `knownWords` entry, then the name used by more
components in the batch wins: `💬 lebel` suggests the canonical `label` over the known word `level`. Before
`🚦 state: HOVERD`, after `🚦 state: HOVERED`.

### L02 collision 🔴

Two properties that normalize to one name produce two constructor fields with the same identifier.
Before `👁️ showSuccessText` (BOOLEAN) plus `💬 showSuccessText` (TEXT), after `💬 successText`.

### L03 empty name 🔴

A name built only from symbols has no identifier at all. Before `⌘`, after `🔘 command`.

### L04 reserved word 🔴

A Dart reserved word or built-in identifier cannot serve as a field name. Before `📈 dynamic`, after `🔘 isDynamic`.

### L05 emoji template 🟠

A wrong or missing emoji hides the property's role from readers. L05 also fires on a graphic toggle whose emoji already
fits, because its row renames it. Before `💨 showClearButton`, after `👁️ showClearButton`; before `👁️ leftIcon`
(BOOLEAN), after `👁️ showLeftIcon`.

### L06 name format 🟠

Leading or trailing spaces and colons, a missing or doubled space, and non-camelCase words each make the Figma name
drift from the Dart name. A non-ASCII space (no-break U+00A0, U+2000 to U+200A, U+202F, U+205F, ideographic U+3000)
looks like a space, so the name or value reads right in Figma while another tool sees a different string. L06 reports
it in a name or a value; for a value, the suggestion is the same value with plain spaces, and only a typo (L01)
outranks it. Before `✏️ Label text:`, after `💬 labelText`; before `🚦<U+00A0>status`, after `🚦 status`.

### L07 value case 🟠

`UPPER_SNAKE` maps one-to-one onto a camelCase enum member. Emoji in a value is kept only where it carries meaning:
feedback dots and direction arrows followed by a word. A Dart enum value cannot start with a digit, so when the
`UPPER_SNAKE` form would, L07 leaves the suggestion empty and its note asks for a word (TextSkeleton `length: 1/5`,
for example `ONE_FIFTH`). Roles in `digitRoles` (🔢 counts, numeric sizes) keep their digits. Before
`🏋️ weight: Regular`, after `REGULAR`; before `↑`, after `↑ UP`.

### L08 boolean variant 🟠

`False/True` maps to a Dart `bool`; `FALSE/TRUE` or `Off/On` would generate a two-member enum instead.
Before `☑️ Selected: Off|On`, after `✅ selected: False|True`.

### L09 feedback vocabulary 🟠

Feedback values mirror `FeedbackState`, so every component shares one mapping. The legacy column of the feedback
vocabulary supplies the suggestion. Roles in `pictureRoles` (🏞️ `graphic`, `image`, `emotion`) name pictures, so
L09 skips them: Illustration `🏞️ image: SUCCESS` names the success picture. Before `🔴 ERROR`, after
`🔴 NEGATIVE`; before `NEGATIVE`, after `🔴 NEGATIVE`.

### L10 vocabulary 🟠

`state`, `size`, and `color` values map to shared Dart enums (`FullWidgetState`, `WidgetSize`, `ColorEnum`); a value
outside them has no member to map to. A legacy value gets its canonical value as the suggestion. Interaction states
end in "ED" to match `FullWidgetState` and Flutter `WidgetState`. Numeric sizes and `Free` map to `FontSize` or
pixels, so they are info. Before `🚦 state: HOVER`, after `HOVERED`.

The owner allowed some values outside the enums on 2026-10-01; each vocabulary's "Figma only" note lists them
(`size` `FILL_WIDTH` and `EXTRA_TINY`; `color` `BLACK`, `GHOST`, and `CUSTOM`, where the caller sets the color). A
split control names each part's state with a part suffix (SplitButton `HOVERED_LEFT`, `PRESSED_RIGHT`), so a `state`
value may end in `_LEFT` or `_RIGHT`. A property named `status` (ChatStatus `SENDING/SENT/FAILED`, UploadedFile
`UPLOADING`, Steps) shares the 🚦 emoji with `state` but names progress or delivery, so no vocabulary checks it.

### L11 style named type 🟠

`type` names what a component is; `style` names how it looks. Visual variants in `type` split one concept across two
field names. Before `🔖 type: OUTLINE|GHOST`, after `🕶️ style: OUTLINE|GHOST`.

### L12 hard-coded color 🟠

A hex fill has no design token behind it, so a theme change misses it. A paint bound to a variable or to a color
style counts as bound. Nested instances are
skipped because their colors belong to their own main component, and the set's own purple outline is skipped.
Before fill `#E5E7EB`, after fill bound to a color variable.

### L13 ambiguous ACTIVE 🟡

`ACTIVE` means focused in an input, expanded in a dropdown, and selected in navigation, so it has no single Dart
member. The suggestion depends on the component (see ACTIVE suggestions). Rating
components get `✅ selected` because `filled` already means the input holds a value. Before `TextInput 🚦 state: ACTIVE`, after
`FOCUSED`.

### L14 single-value variant 🟡

A variant with one value generates a field that can never change. Before `🚦 state: NORMAL` alone, after the property
removed or its other states added.

### L15 mixed axis 🟡

An interaction value (`HOVER*`, `PRESSED`, `DISABLED`) in a property other than `state` or `status`, or a slot value
in `position` or `type`, puts two concepts on one axis, so the Dart API cannot express both at once. `LOADING` and
feedback values may sit in any variant (Toggle `checked`, Spinner `type`, BarCell `color`): each is one drawn look,
and `stratum-read-figma` maps them to `loading: true` and `FeedbackState`. A slot value stays when the set has a `❖`
slot property of the same name, because the value selects the layout that shows that slot (BottomActions `CONTENT`
with `❖ content`, StateActions `SLOT` with `❖ slot`). `pictureRoles` variants are skipped, as in L09. Before
`📐 size: DISABLED`, after `🚦 state: DISABLED`.

### L16 one concept, two names 🟡

The same concept under different names gives the same widget parameter different names across widgets. The canonical
names table maps each legacy name to its replacement: message text uses the `*Text` family with a matching `show*Text`
toggle, and `label` stays `label`. A row with a type pairs only properties of that type: `line` → `showLine` renames
a BOOLEAN, so a TEXT `💬 line` (MultiLineCodeSnippet line numbers) is not reported. Before `💬 helper`, after
`💬 helperText`.

### L17 retired

Retired on 2026-10-01; the id stays reserved. `LOADING` and `PROGRESS` stay inside `state`: `stratum-read-figma` maps
them to `loading: true`, and `loading: true` plus `progress: double?`, and splitting a `⏳ loading` axis would
restructure about 25 sets for combinations nobody draws.

### L18 incomplete matrix ℹ️

Missing variants may be intentional (a disabled state without hover) or forgotten; code generation needs to know
which. Before 96 of 135 variants, after the gaps added or confirmed.

### L19 missing description ℹ️

The description becomes the widget's doc comment. Figma sometimes returns an empty `descriptionMarkdown` for a set
that has one; re-publishing the library fixes it. Before no description, after a one-line purpose.

### L20 numbered list toggles 🟠

A list with one BOOLEAN per item (`1. Checkbox` to `8. Checkbox`) is one concept: `stratum-read-figma` maps the
series to `List<Widget>`, so its names share one shape, `👁️ show<Item><N>`. L20 detects the legacy forms in the
Numbered list toggles table, plus `show<Item><N>` under another emoji when a sibling of the same item exists (a lone
`showBody2` is an ordinary toggle). It reports one finding per component that lists the properties and suggests the
number range, and it silences L01, L03, L05, and L06 on them, so a series costs one row instead of an L05 and an L06
row per toggle. Before `1. Toggle` to `8. Toggle`, after `👁️ showToggle1` to `👁️ showToggle8`.

## Refreshing knownWords

Run this when the Figma file gains new words, or when L01 flags a correctly spelled word. Commands run from the skill
folder `.claude/skills/stratum-figma-lint/`.

1. Get the file URL from the user and list its pages (SKILL.md workflow step 2).
2. For each batch of up to 10 pages, build the code with `node scripts/assemble.js --pages <ids> --mode vocab` and
   run it with `use_figma`. Each result maps every normalized property name and every value to the number of
   components that use it.
3. If a result carries `droppedSingles` or `truncated`, split that batch in half and rerun until neither flag is set.
4. Merge the batches: sum the counts of each name and each value.
5. Exclude every token within distance 2 of a more frequent token unless a vocabulary already names it (`HOVERED`
   stays; `HOVERD` goes). Exclude legacy state values and every canonical or legacy name; the tables already hold
   them, and a test fails on a listed one. Bare feedback words (`ERROR`, `WARNING`) stay: they catch typos outside
   feedback properties.
6. The owner reviews both lists: the kept tokens, and the excluded tokens with the word each was near. A correctly
   spelled excluded token goes back in.
7. Write the kept tokens into `knownWords` (names and values, pipe-joined groups), run
   `node scripts/gen_conventions_md.js`, and rerun `node --test scripts/test/`.

## Known limits

- L01 cannot catch misspelled proper nouns (country or bank names on icon variants) with no nearby vocabulary entry.
- A correctly spelled word missing from `knownWords` can still draw L01 when it sits within distance 2 of a known
  word; refresh `knownWords` to clear it.
- A typo whose words are all known words passes L01 as a compound (`TEXT_LIGHT` meant as `TEXT_RIGHT`).
- L12 reads solid paints only; mixed text fills and gradients are not checked.
- The region-name rule also matches a camelCase suffix whatever the default, so `iconRight` takes `❖`; the Stratum
  form `rightIcon` stays `✏️`. A swap whose default is not in the file and whose name is no region word takes `✏️`.
