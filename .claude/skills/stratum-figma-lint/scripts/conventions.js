// Stratum Figma conventions: the single source of truth, data only. Each table is an array of row objects,
// one object per row. references/figma_conventions.md renders these tables (node scripts/gen_conventions_md.js).
const CONVENTIONS = {
  // message: the text a report shows for the rule; a finding's own message holds only what this cannot say.
  rules: [
    { id: 'L01', severity: 'blocking', message: 'typo: close to a known spelling (see suggestion)' },
    { id: 'L02', severity: 'blocking', message: 'two properties normalize to the same name' },
    { id: 'L03', severity: 'blocking', message: 'name has no letters after normalization' },
    { id: 'L04', severity: 'blocking', message: 'Dart reserved word or built-in identifier' },
    { id: 'L05', severity: 'convention', message: 'emoji missing or not matching the role template' },
    { id: 'L06', severity: 'convention', message: 'name or value format' },
    { id: 'L07', severity: 'convention',
      message: 'value not UPPER_SNAKE, or emoji outside feedback and direction values' },
    { id: 'L08', severity: 'convention', message: 'boolean variant values are False/True' },
    { id: 'L09', severity: 'convention',
      message: 'feedback values are 🔵 INFO, 🔴 NEGATIVE, 🟡 WARNING, 🟢 POSITIVE' },
    { id: 'L10', severity: 'convention', message: 'value outside the state, size, or color vocabulary' },
    { id: 'L11', severity: 'convention', message: 'visual variants belong in `style`, not `type`' },
    { id: 'L12', severity: 'convention', message: 'hard-coded color, not bound to a variable' },
    { id: 'L13', severity: 'advisory', message: '`ACTIVE` is ambiguous' },
    { id: 'L14', severity: 'advisory', message: 'variant has a single value' },
    { id: 'L15', severity: 'advisory', message: 'mixed axis: interaction value outside `state` or `status`, or slot ' +
      'value in `position` or `type` without a ❖ slot of the same name' },
    { id: 'L16', severity: 'advisory', message: 'legacy name for a canonical name' },
    { id: 'L17', severity: '—', message: 'retired 2026-10-01: `LOADING` and `PROGRESS` inside `state` are allowed' },
    { id: 'L18', severity: 'info', message: 'variant matrix incomplete (existing/product)' },
    { id: 'L19', severity: 'info', message: 'no description (Figma can read it empty; re-publish the library)' },
    { id: 'L20', severity: 'convention', message: 'numbered list toggles not named `👁️ show<Item><N>`' },
  ],
  // A rule whose severity is not in severityOrder is retired: its row keeps the id, and the sandbox never gets it.
  severityOrder: ['blocking', 'convention', 'advisory', 'info'],
  // One problem per value: the first rule in this list wins (a value's non-ASCII space, L06, yields only to a typo).
  valueRuleOrder: ['L01', 'L06', 'L09', 'L08', 'L10', 'L07', 'L13'],
  // Name rules silenced on a property whose name normalizes to empty (L03).
  emptyNameSilences: ['L01', 'L04', 'L05', 'L06'],

  // Numbered list toggles (L20): one BOOLEAN per list item, canonical `<emoji> <prefix><Item><N>`. The legacy forms
  // are reported once per component; `silences` are the rules L20 owns on those properties. A `show<Item><N>` form
  // counts only beside a sibling of the same item (a lone `showBody2` is an ordinary toggle).
  listToggles: {
    canonical: '👁️ show<Item><N>',
    emoji: '👁️',
    prefix: 'show',
    silences: ['L01', 'L03', 'L05', 'L06'],
    legacy: [
      { form: '<N>. <Item>', examples: ['1. Checkbox', '2. Checkbox'] },
      { form: '<Item> <N>', examples: ['Menu item 1', 'Menu item 2'] },
      { form: '<Item> <N> (first|last)', examples: ['Accordion 1 (first)', 'Accordion 2 (last)'] },
      { form: '<other emoji> show<Item><N>', examples: ['🔘 showTag1', '🔘 showTag2'] },
    ],
  },

  // match: exact name, name prefix, or contains. wholeFileOnly: a page the user names (scope 2) is still linted.
  // Variant components are always read through their set (code, not data).
  skip: [
    { target: 'page', match: 'prefix', value: '.' },
    { target: 'page', match: 'prefix', value: '─' },
    { target: 'page', match: 'prefix', value: '-' },
    { target: 'page', match: 'prefix', value: '☀', wholeFileOnly: true },
    { target: 'page', match: 'contains', value: 'Example', wholeFileOnly: true },
    { target: 'frame', match: 'exact', value: 'Doc' },
    { target: 'frame', match: 'exact', value: 'Examples' },
    { target: 'component', match: 'prefix', value: '_' },
  ],

  // Emoji template: the first role whose types, prefix, names, booleanOptions, and swapName all match wins.
  // A name matches `names` when it equals the key or ends with the capitalized key (iconSize -> size).
  // swapName matches the INSTANCE_SWAP default component's name. A layout-region name is a slot whatever its default
  // (CardLayout `top` defaults to TopNavigation). An old slot emoji gets L05 like any other mismatch.
  // rename: L05 also fires when the emoji fits and suggests `<rename><Name>` (a logo toggle follows the icon toggle).
  // theme sits above the VARIANT flag, so `darkMode` keeps 🌗 with False/True options.
  emojiRoles: [
    { key: 'show', emoji: '👁️', types: ['BOOLEAN'], prefix: 'show' },
    { key: 'show', emoji: '👁️', types: ['VARIANT'], prefix: 'show', booleanOptions: true },
    { key: 'graphicToggle', emoji: '👁️', types: ['BOOLEAN'], names: ['icon', 'logo'], rename: 'show' },
    { key: 'loading', emoji: '⏳', types: ['BOOLEAN'], names: ['loading'] },
    { key: 'checked', emoji: '✅', types: ['BOOLEAN', 'VARIANT'], names: ['checked', 'selected'] },
    { key: 'expanded', emoji: '↕️', types: ['VARIANT'], names: ['expanded'] },
    { key: 'filled', emoji: '✍️', types: ['VARIANT'], names: ['filled'] },
    { key: 'theme', emoji: '🌗', types: ['VARIANT'], names: ['theme', 'darkMode'] },
    { key: 'flag', emoji: '🔘', types: ['BOOLEAN'] },
    { key: 'flag', emoji: '🔘', types: ['VARIANT'], booleanOptions: true },
    { key: 'text', emoji: '💬', types: ['TEXT'] },
    { key: 'slot', emoji: '❖', types: ['SLOT'] },
    { key: 'slot', emoji: '❖', types: ['INSTANCE_SWAP'], swapName: { contains: 'Slot', prefix: '❖' } },
    { key: 'slot', emoji: '❖', types: ['INSTANCE_SWAP'],
      names: ['top', 'body', 'bottom', 'left', 'right', 'tab', 'content', 'snackbar', 'slot'] },
    { key: 'icon', emoji: '✏️', types: ['INSTANCE_SWAP'] },
    { key: 'style', emoji: '🕶️', types: ['VARIANT'], names: ['style'] },
    { key: 'type', emoji: '🔖', types: ['VARIANT'], names: ['type'] },
    { key: 'size', emoji: '📐', types: ['VARIANT'], names: ['size'] },
    { key: 'state', emoji: '🚦', types: ['VARIANT'], names: ['state', 'status'] },
    { key: 'color', emoji: '🌈', types: ['VARIANT'], names: ['color'] },
    { key: 'accent', emoji: '💡', types: ['VARIANT'], names: ['accent'] },
    { key: 'position', emoji: '📍', types: ['VARIANT'], names: ['position', 'align'] },
    { key: 'direction', emoji: '➡️', types: ['VARIANT'], names: ['direction', 'arrow'] },
    { key: 'layout', emoji: '⬒', types: ['VARIANT'], names: ['layout'] },
    { key: 'platform', emoji: '🖥️', types: ['VARIANT'], names: ['platform', 'os', 'browser'] },
    { key: 'count', emoji: '🔢', types: ['VARIANT'],
      names: ['items', 'tabs', 'steps', 'section', 'page', 'attachments', 'rating', 'avatars', 'count', 'frame'] },
    { key: 'graphic', emoji: '🏞️', types: ['VARIANT'], names: ['graphic', 'image', 'emotion'] },
    { key: 'variant', emoji: '🔖', types: ['VARIANT'] },
  ],

  // Canonical property names and the legacy names L16 replaces; `type` limits a row to one property type.
  canonicalNames: [
    { name: 'helperText', type: 'TEXT', legacy: ['helper'] },
    { name: 'showHelperText', type: 'BOOLEAN', legacy: ['showHelper'] },
    { name: 'errorText', type: 'TEXT', legacy: ['error'] },
    { name: 'showErrorText', type: 'BOOLEAN', legacy: ['showError'] },
    { name: 'warningText', type: 'TEXT', legacy: ['warning'] },
    { name: 'showWarningText', type: 'BOOLEAN', legacy: ['showWarning'] },
    { name: 'successText', type: 'TEXT', legacy: ['success'] },
    { name: 'showSuccessText', type: 'BOOLEAN', legacy: ['showSuccess'] },
    { name: 'groupHelperText', type: 'TEXT', legacy: ['groupHelper'] },
    { name: 'showGroupHelperText', type: 'BOOLEAN', legacy: ['showGroupHelper'] },
    { name: 'groupErrorText', type: 'TEXT', legacy: ['groupError'] },
    { name: 'showGroupErrorText', type: 'BOOLEAN', legacy: ['showGroupError'] },
    { name: 'label', legacy: ['labelText'] },
    { name: 'stepNumber', legacy: ['step'] },
    { name: 'showLine', type: 'BOOLEAN', legacy: ['line'] },
  ],

  booleanValues: { canonical: ['False', 'True'], falsy: ['false', 'off', 'no'], truthy: ['true', 'on', 'yes'] },

  // Each vocabulary mirrors a Dart enum in `values`. roles: the property roles that use it (L01 reference; L10 for
  // vocabularyRoles). designOnly: values Figma may use that the enum lacks; codeOnly: enum members Figma never uses;
  // the drift test allows both gaps. legacy: values a row replaces. partSuffixes: a part suffix any value of the
  // vocabulary may carry (SplitButton HOVERED_LEFT).
  // A property named `status` (ChatStatus, UploadedFile, Steps) has no vocabulary: no role lists it.
  vocabularies: {
    state: {
      dartEnum: 'FullWidgetState',
      roles: ['state'],
      designOnly: ['PROGRESS'],
      codeOnly: ['INITIAL', 'SCROLLED_UNDER', 'SUCCESS', 'CANCEL', 'WARNING', 'FAIL'],
      partSuffixes: ['_LEFT', '_RIGHT'],
      values: [
        { value: 'NORMAL' },
        { value: 'HOVERED', legacy: ['HOVER'] },
        { value: 'PRESSED', legacy: ['PRESS'] },
        { value: 'FOCUSED', legacy: ['FOCUS'] },
        { value: 'DRAGGED', legacy: ['DRAG'] },
        { value: 'SELECTED' },
        { value: 'DISABLED' },
        { value: 'LOADING' },
        { value: 'EMPTY' },
      ],
    },
    feedback: {
      dartEnum: 'FeedbackState',
      roles: ['state', 'color'],
      designOnly: ['⚫️ NORMAL'],
      values: [
        { value: '🔵 INFO', legacy: ['INFO'] },
        { value: '🔴 NEGATIVE', legacy: ['NEGATIVE', 'ERROR'] },
        { value: '🟡 WARNING', legacy: ['WARNING'] },
        { value: '🟢 POSITIVE', legacy: ['POSITIVE', 'SUCCESS'] },
      ],
    },
    size: {
      dartEnum: 'WidgetSize',
      roles: ['size'],
      designOnly: ['FILL_WIDTH', 'EXTRA_TINY'],
      values: [{ value: 'TINY' }, { value: 'EXTRA_SMALL' }, { value: 'SMALL' }, { value: 'MEDIUM' }, { value: 'LARGE' },
        { value: 'EXTRA_LARGE' }, { value: 'HUGE' }],
    },
    color: {
      dartEnum: 'ColorEnum',
      roles: ['color'],
      designOnly: ['NONE', 'BLACK', 'GHOST', 'CUSTOM', 'LOADING'],
      values: [{ value: 'BRAND' }, { value: 'RED' }, { value: 'PINK' }, { value: 'ROSE' }, { value: 'VIOLET' },
        { value: 'PURPLE' }, { value: 'INDIGO' }, { value: 'BLUE' }, { value: 'CYAN' }, { value: 'TEAL' },
        { value: 'EMERALD' }, { value: 'GREEN' }, { value: 'MOSS' }, { value: 'LIME' }, { value: 'YELLOW' },
        { value: 'AMBER' }, { value: 'ORANGE' }, { value: 'BROWN' }, { value: 'BLUE_GRAY' }, { value: 'GRAY' }],
    },
    fontSize: {
      dartEnum: 'FontSize',
      roles: [],
      codeOnly: ['CUSTOM'],
      values: [{ value: '10' }, { value: '12' }, { value: '14' }, { value: '16' }, { value: '18' }, { value: '20' },
        { value: '24' }, { value: '36' }, { value: '48' }, { value: '56' }],
    },
    windowSize: {
      dartEnum: 'WindowSize',
      roles: ['platform'],
      values: [{ value: 'WATCH' }, { value: 'MOBILE' }, { value: 'TABLET' }, { value: 'DESKTOP' }, { value: 'BIG_DESKTOP' }],
    },
  },
  freeSize: 'Free',
  vocabularyRoles: ['state', 'size', 'color'],
  directionArrows: [
    { arrow: '←', word: 'LEFT' }, { arrow: '→', word: 'RIGHT' }, { arrow: '↑', word: 'UP' }, { arrow: '↓', word: 'DOWN' },
    { arrow: '↖', word: 'UP_LEFT' }, { arrow: '↗', word: 'UP_RIGHT' }, { arrow: '↘', word: 'DOWN_RIGHT' },
    { arrow: '↙', word: 'DOWN_LEFT' },
  ],

  ambiguousValue: 'ACTIVE',
  ambiguousPartner: 'INACTIVE',
  activeSuggestions: [
    { components: ['TextInput', 'Combobox', 'Dropdown', 'DateInput', 'TimeInput', 'NumberInput', 'TextArea', 'TextEditor',
      'Stepper', 'InlineEditableText', 'ChatMessageInput'], suggestion: 'FOCUSED' },
    { components: ['TextDropdown', 'IconDropdown'], suggestion: '↕️ expanded: True' },
    { components: ['SideNavigationMenu', 'PageDot', 'ChartBar'], suggestion: 'SELECTED' },
    { components: ['BottomNavigationMenu'], suggestion: 'PRESSED' },
    { components: ['RatingElement', 'RatingEmoji'], suggestion: '✅ selected: False/True; keep NORMAL/HOVERED' },
  ],
  activeDefault: 'a precise value: FOCUSED, SELECTED, PRESSED, or ↕️ expanded: True',

  visualStyles: ['GHOST', 'OUTLINE', 'FILLED', 'SHADED', 'SUBTLE'],
  // L15: interaction values outside `state` or `status`. LOADING and feedback values may sit in any variant.
  stateLike: { exact: ['DISABLED', 'PRESSED'], prefixes: ['HOVER'] },
  // L15: a slot value in a slotAxes variant, unless the set has a ❖ slot of the same name (CONTENT with ❖ content).
  slotValues: ['CONTENT', 'SLOT'],
  slotAxes: ['position', 'type'],
  // Role keys whose values name pictures (🏞️ image: SUCCESS), so L09 and L15 skip them.
  pictureRoles: ['graphic'],
  // Role keys whose values keep digits (counts, numeric sizes); L07 suggests no other value that starts with one.
  digitRoles: ['count', 'size'],

  // Curated spellings used in the file; L01 compares every name and value against them in every scope.
  // Names are normalized camelCase; values are UPPER_SNAKE without emoji (a value's emoji prefix is ignored).
  // Each string is one pipe-joined group (keeps the use_figma code small). Vocabulary values and canonical names
  // count as known without being listed. Seed: owner-approved curation of the 2026-09-30 audit; typos and legacy
  // state values stay out on purpose (test/known_words.test.js). Refresh per the reference "Refreshing knownWords".
  knownWords: {
    names: [
      'accent|action|addon|align|arrow|artist|attachments|avatars',
      'badge|bank|body|body2|body3|bottom|brandName|browser',
      'captionBottom|captionRight|center|char|checked|code|color|colored|condition|content|contentText|count|counter',
      'country',
      'dark|darkMode|date|description|detail|direction|domain|dotPosition|dropdown',
      'emoji|emotion|errorIcon|errorMessage|esc|example|expand|expandable|expanded',
      'feature|fileFilled|fileName|filled|focused|format|frame|fullWidth',
      'graphic|groupLabel|groupName',
      'hasFilter|header|helperRight|horizontal|hour',
      'icon|iconFilled|illustration|image|infoGlyph|infoIcon|input|inputText|items',
      'key',
      'layout|left|leftIcon|length|level|loading|logo',
      'macOS|maxValue|method|minMaxPosition|minute|minValue',
      'name|number',
      'option|os|outgoing',
      'page|passed|path|percent|placeholder|platform|portrait|position|positiveIcon|primaryButton',
      'range|rating|ratio|removable|resizable|reverse|right|rightIcon',
      'safeArea|safeIndicator|safeStatusBar|secondaryButton|section|secure|select|selected|selectedIcon',
      'separator|showAction|showActions|showAmPm|showArrow|showArrowLeft|showArrowRight|showAvatar|showBack',
      'showBackground|showBackNext|showBadge|showBaseLine|showBlur|showBody|showBody2|showBody3|showBottom',
      'showBottomButtons|showBottomDateRange|showBrandLogo|showButton|showButtons|showCamera|showCaptionBottom',
      'showCaptionRight|showCenter|showClearButton|showClose|showCloseable|showCloseButton|showCommand',
      'showContent|showControl|showCounter|showCover|showDescription|showDiff|showDislikeButton|showDivider',
      'showDropdown|showEmojiButton|showEstimateLine|showExpandable|showExternal',
      'showFileAttachment|showFileButton|showFilterButton|showFullLoading|showGmt',
      'showHeader|showHelperRight|showIcon|showImage|showIndicator',
      'showInfo|showInfoButton|showKeyboard|showLabel|showLeft|showLeftIcon|showLeftItems|showLikeButton',
      'showLineNumber|showLink|showLoading|showMaxValue|showMediaButton|showMetaData',
      'showMinimizeButton|showMinValue|showMore|showMoreButton|showMoreMediaAttachment|showName',
      'showNegativeButton|showNextAndBack|showNotification|showNumber|showOption|showOverflow|showPagination',
      'showPath|showPopover|showPrimaryButton|showProp|showReplyButton|showRequired|showRight|showRightIcon',
      'showRightItems|showScrollbar|showSearchButton|showSecondaryButton|showShift|showShortcut|showSideButtons',
      'showSnackbar|showSortButton|showSplit|showStatusBar|showStatusDot|showStatusRing|showSubMenu|showSubmenu',
      'showSubtitle|showSuggestionBar|showTab|showTertiaryButton|showText',
      'showTickMark|showTitle|showTooltip|showTop|showTopDateRange|showTutorial|showTwoMonths|showUpload',
      'showVolume|simple|size|slot|slot2|slotItem|snackbar|sorting|stacked|state|status',
      'steps|store|style|subtitle|successMessage',
      'tab|tabName|tabs|text|theme|title|titleText|toggle|top|track|transparent|type',
      'underlined',
      'value',
      'warningIcon|weight|wide',
    ],
    values: [
      'ACCENT|ACTION|ACTION_DESTRUCTIVE|ACTIVE|AIFF|ALT|ANDROID|ANGRY|ANIMATION|ANOTHER_MONTH|APPGALLERY|APPLE',
      'APPSTORE|ARCHIVE|ARROW|ASCENDING|AUTHENTICATING|AUTO|AVATAR|AVI',
      'BAD_GATEWAY|BASE|BITMAP|BLACK|BLUE|BOLD|BORDER|BOTTOM|BOTTOM_CENTER|BOTTOM_INDICATOR|BOTTOM_LEFT',
      'BOTTOM_RIGHT|BOTTOM_SHEET|BRAND|BREADCRUMBS|BROWN|BUTTON|BUTTON_CENTER|BUTTON_HORIZONTAL|BUTTON_LEFT',
      'BUTTON_VERTICAL|BUTTONS',
      'CENTER|CHAR|CHECKBOX|CHECKED|CHROME|CMD|CODE|COINBASE_WALLET|COLLAPSED|COME_BACK_LATER|COMING_SOON',
      'COMPACT|COMPLETED|CONDITION|CONFIRMED|CONTENT|CONTROL|CSS|CSV|CURRENT|CUSTOM',
      'DARK|DAY_OF_THE_WEEK|DEFAULT|DELETE|DELETE_CONFIRMATION|DELIVERY|DESCENDING|DESKTOP|DESTRUCTIVE|DIVIDER',
      'DOCS|DOCX|DOING|DONE|DOT|DOTS|DOWNLOADING|DRAGGED|DROPDOWN',
      'EMOJI|EMPTY|EPS|ERROR|EXPANDED|EXTRA_LARGE|EXTRA_SMALL|EXTRA_TINY',
      'FACEBOOK|FADED|FAILED|FALLING|FATAL_ERROR|FEATURE|FILL|FILL_WIDTH|FILLED|FILLED_BRAND|FIRST|FLOAT|FLOATING',
      'FOCUSED|FOUR_FIFTHS|FROWNING|FULL',
      'GALAXY_STORE|GESTURE|GET|GHOST|GITHUB|GOLDEN|GOOGLE|GOOGLE_PLAY|GRAY|GREEN|GRINNING|GROUP_HEADER',
      'GROUP_HEADING',
      'HALF|HEART|HEIC|HORIZONTAL|HOVERED|HTML|HUGE',
      'ICON|ICONS|ILLUSTRATION|IMAGE|IMAGE_VIDEO|IN_REVIEW|INACTIVE|INCOMPLETE|INDETERMINATE|INFO',
      'INPUT|INPUT_BUTTON_HORIZONTAL|INPUT_BUTTON_VERTICAL|INSIDE|IOS',
      'JPG|JS|JSON',
      'LARGE|LEDGER|LEFT|LEFT_BOTTOM|LEFT_RIGHT|LEFT_TOP|LETTER|LIGHT|LINE|LIST_IS_EMPTY|LOADING|LOGGED_OUT',
      'LOTTIE',
      'M4A|MAC_APPSTORE|MAC_OS|MEDIUM|MESSAGE_SENT|METAMASK|MICROSOFT|MIDDLE|MIXED|MIXER|MOBILE|MODAL|MOV|MP3',
      'MP4|MUSIC',
      'NEGATIVE|NEUTRAL|NEW_UPDATED|NO_COMMENTS|NO_CONNECT|NO_CONTROL|NO_MESSAGE|NODE|NONE|NORMAL|NUMBER',
      'NUMBERS',
      'OFF|ON|ONE_FIFTH|ORDER_COMPLETED|OTHER|OUTLINE|OUTSIDE|OVERFLOW',
      'PAGE|PAGE_NOT_FOUND|PAGE_UNDER_CONSTRUCTION|PATCH|PAYMENT_PROCESSED|PDF|PNG|POSITIVE|POST|PPTX|PREFIX',
      'PRESSED|PROFILE|PROGRESS|PROGRESS_FILLED|PURPLE|PUT',
      'RADIO|RANGE_END|RANGE_MIDDLE|RANGE_START|RAR|RECTANGLE|RED|REGULAR|RESPONSIVE|RETRY|RIGHT|RIGHT_BOTTOM',
      'RIGHT_DRAWER|RIGHT_SIDE|RIGHT_TOP|RISING|ROUND',
      'SAFARI|SEARCH|SEARCHING|SECOND|SECTION|SELECTED|SENDING|SENT|SHADED|SHIFT|SIGN_IN|SIGN_UP|SIMPLE|SLASH|SMALL',
      'SMILING',
      'SPREAD_SHEET|SQUARE|STAR|START|STRONG|SUBTLE|SUCCESS|SUFFIX|SVG|SWATCHES',
      'TABLET|TEAL|TEXT|TEXT_BOTTOM|TEXT_CENTER|TEXT_FIELD|TEXT_LEFT|TEXT_RIGHT|TEXT_TOP|THIRD|THREE_FIFTHS|TIFF|TINY',
      'TITLE|TODAY|TOGGLE|TOP|TOP_CENTER|TOP_LEFT|TOP_RIGHT|TOP_STATUS_BAR|TRIANGLE|TWITTER|TWO_FIFTHS|TXT|TYPING',
      'UNDERLINE|UNSUBSCRIBED|UPGRADE|UPLOADING|URGENT',
      'VECTOR|VERTICAL|VIDEO|VIOLET',
      'WAITING|WALLETCONNECT|WARNING|WAV|WEBP|WELCOME|WINDOWS',
      'XLSX',
      'YELLOW',
      'ZIP',
    ],
  },

  typo: { minValueLength: 4, minNameLength: 5, shortLength: 4, shortDistance: 1, maxDistance: 2 },

  dartReserved: ['assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum',
    'extends', 'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
    'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
    'abstract', 'as', 'covariant', 'deferred', 'dynamic', 'export', 'extension', 'external', 'factory', 'Function',
    'get', 'implements', 'import', 'interface', 'late', 'library', 'mixin', 'operator', 'part', 'required', 'set',
    'static', 'typedef'],
};

if (typeof module !== 'undefined') module.exports = { CONVENTIONS };
