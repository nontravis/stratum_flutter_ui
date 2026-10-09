import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'stratum_labels_en.dart';
import 'stratum_labels_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of StratumLabels
/// returned by `StratumLabels.of(context)`.
///
/// Applications need to include `StratumLabels.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/stratum_labels.dart';
///
/// return MaterialApp(
///   localizationsDelegates: StratumLabels.localizationsDelegates,
///   supportedLocales: StratumLabels.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the StratumLabels.supportedLocales
/// property.
abstract class StratumLabels {
  StratumLabels(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static StratumLabels? of(BuildContext context) {
    return Localizations.of<StratumLabels>(context, StratumLabels);
  }

  static const LocalizationsDelegate<StratumLabels> delegate =
      _StratumLabelsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// Close button label.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButtonLabel;

  /// Announced when a section expands.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get expanded;

  /// Announced when a section collapses.
  ///
  /// In en, this message translates to:
  /// **'Collapsed'**
  String get collapsed;

  /// Remove tag label.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTagLabel;

  /// Loading label.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// Required marker.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredMarker;

  /// Show menu label: the last fallback of the tap surface's menu action label.
  ///
  /// In en, this message translates to:
  /// **'Show menu'**
  String get showMenuLabel;

  /// Retry label.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// Failure message.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get failureMessage;

  /// Placeholder page title.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get placeholderPageTitle;

  /// Force update title.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get forceUpdateTitle;

  /// Force update message.
  ///
  /// In en, this message translates to:
  /// **'Please update to the latest version to continue.'**
  String get forceUpdateMessage;

  /// Maintenance title.
  ///
  /// In en, this message translates to:
  /// **'Under maintenance'**
  String get maintenanceTitle;

  /// Maintenance message.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be back soon. Please try again later.'**
  String get maintenanceMessage;

  /// Soft update title.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get softUpdateTitle;

  /// Soft update message.
  ///
  /// In en, this message translates to:
  /// **'A new version is ready. Update now for the latest improvements.'**
  String get softUpdateMessage;

  /// Update label.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateLabel;

  /// Later label.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get laterLabel;
}

class _StratumLabelsDelegate extends LocalizationsDelegate<StratumLabels> {
  const _StratumLabelsDelegate();

  @override
  Future<StratumLabels> load(Locale locale) {
    return SynchronousFuture<StratumLabels>(lookupStratumLabels(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_StratumLabelsDelegate old) => false;
}

StratumLabels lookupStratumLabels(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return StratumLabelsEn();
    case 'th':
      return StratumLabelsTh();
  }

  throw FlutterError(
    'StratumLabels.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
