import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_et.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('es'),
    Locale('et'),
    Locale('fi'),
    Locale('sv'),
  ];

  /// fi: Chromecast / Google TV / Android TV
  ///
  /// In en, this message translates to:
  /// **'Chromecast / Google TV / Android TV'**
  String get s186cc1d7b9;

  /// fi: Chromecast, Google TV, Android TV:t (Sony, Philips, TCL, Xiaomi…) ja Nest-kaiuttimet Cast-yhteydellä: tila, äänenvoimakk
  ///
  /// In en, this message translates to:
  /// **'Chromecast, Google TV, Android TVs (Sony, Philips, TCL, Xiaomi…) and Nest speakers over Cast: status, volume, pause and stop.'**
  String get s9da55e3993;

  /// fi: Löytyy yleensä itse. Muuten: Google Home -sovellus → laite → Asetukset → Laitteen tiedot → IP-osoite.
  ///
  /// In en, this message translates to:
  /// **'Usually found automatically. Otherwise: Google Home app → device → Settings → Device information → IP address.'**
  String get sb3a497d14b;

  /// fi: Samsung Smart TV (Tizen)
  ///
  /// In en, this message translates to:
  /// **'Samsung Smart TV (Tizen)'**
  String get s02bafb3752;

  /// fi: Samsung-televisiot 2016→: virta, äänenvoimakkuus, mykistys ja toisto suoraan kotiverkossa.
  ///
  /// In en, this message translates to:
  /// **'Samsung TVs 2016→: power, volume, mute and playback straight over the home network.'**
  String get s709ac4cf0e;

  /// fi: TV: Asetukset → Yleiset → Verkko → Verkon tila → IP-asetukset. Käynnistystä varten: Yleiset → Verkko → Asiantuntija-aset
  ///
  /// In en, this message translates to:
  /// **'TV: Settings → General → Network → Network Status → IP Settings. For power on: General → Network → Expert Settings → \"Power On with Mobile\" on.'**
  String get s19a8179b98;

  /// fi: Televisioon tulee kysymys "Salli Molaplan?" – valitse kaukosäätimellä Salli.
  ///
  /// In en, this message translates to:
  /// **'The TV asks \"Allow Molaplan?\" – choose Allow with the remote.'**
  String get s0f80ea94c0;

  /// fi: LG Smart TV (webOS)
  ///
  /// In en, this message translates to:
  /// **'LG Smart TV (webOS)'**
  String get s830956d10f;

  /// fi: LG-televisiot (webOS): virta, äänenvoimakkuus, mykistys, toisto ja avoin sovellus kotiverkossa.
  ///
  /// In en, this message translates to:
  /// **'LG TVs (webOS): power, volume, mute, playback and the open app over the home network.'**
  String get s6f7121cc67;

  /// fi: TV: Asetukset → Yleiset → Verkko → Wi-Fi/langallinen → Lisäasetukset. Käynnistystä varten: Yleiset → Laitteet → "Käynnis
  ///
  /// In en, this message translates to:
  /// **'TV: Settings → General → Network → Wi-Fi/wired → Advanced. For power on: General → Devices → \"Turn on via Wi-Fi\" on.'**
  String get scf3ccada17;

  /// fi: Televisioon tulee yhteyspyyntö – hyväksy se kaukosäätimellä (Hyväksy / Accept).
  ///
  /// In en, this message translates to:
  /// **'The TV shows a connection request – accept it with the remote.'**
  String get s898762ead6;

  /// fi: Philips TV (JointSPACE)
  ///
  /// In en, this message translates to:
  /// **'Philips TV (JointSPACE)'**
  String get s378548d3cd;

  /// fi: Philips-televisiot: virta (Android-mallit), äänenvoimakkuus, mykistys ja näppäimet. Android-mallit paritetaan TV:n näytt
  ///
  /// In en, this message translates to:
  /// **'Philips TVs: power (Android models), volume, mute and keys. Android models pair with a PIN shown on the TV.'**
  String get s9a2645043b;

  /// fi: TV: Asetukset → Langaton ja verkot → Langallinen tai Wi-Fi → Näytä verkkoasetukset.
  ///
  /// In en, this message translates to:
  /// **'TV: Settings → Wireless and networks → Wired or Wi-Fi → View network settings.'**
  String get s2fb79a3487;

  /// fi: Kirjoita televisioon ilmestynyt nelinumeroinen PIN-koodi.
  ///
  /// In en, this message translates to:
  /// **'Type the four-digit PIN shown on the TV.'**
  String get s12f47341ce;

  /// fi: Näkyy television ruudulla noin minuutin.
  ///
  /// In en, this message translates to:
  /// **'Shown on the TV screen for about a minute.'**
  String get s0ec3e3e11d;

  /// fi: Android TV / Google TV (kaukosäädin)
  ///
  /// In en, this message translates to:
  /// **'Android TV / Google TV (remote)'**
  String get s11d9226341;

  /// fi: Sony, Philips, TCL, Xiaomi, Chromecast with Google TV…: virta, äänenvoimakkuus, mykistys, kanavat, nuolinäppäimet ja avo
  ///
  /// In en, this message translates to:
  /// **'Sony, Philips, TCL, Xiaomi, Chromecast with Google TV…: power, volume, mute, channels, arrow keys and the open app. Pairs with a code shown on the TV.'**
  String get s0992ee68bf;

  /// fi: TV: Asetukset → Verkko ja Internet → (verkko) → IP-osoite. Tai Google Home -sovellus → laite → Laitteen tiedot.
  ///
  /// In en, this message translates to:
  /// **'TV: Settings → Network & Internet → (network) → IP address. Or Google Home app → device → Device information.'**
  String get s8a14ae9518;

  /// fi: Televisioon ilmestyy kuusimerkkinen koodi (numerot ja kirjaimet A–F) – kirjoita se tähän.
  ///
  /// In en, this message translates to:
  /// **'The TV shows a six-character code (digits and letters A–F) – type it here.'**
  String get s714e6f6143;

  /// fi: Näkyy television ruudulla parituksen ajan.
  ///
  /// In en, this message translates to:
  /// **'Shown on the TV screen during pairing.'**
  String get sd92171df4d;

  /// fi: Sonos
  ///
  /// In en, this message translates to:
  /// **'Sonos'**
  String get s6db078dbe3;

  /// fi: Sonos-kaiuttimet ja -soundbarit: äänenvoimakkuus, mykistys, toisto/tauko, seuraava ja mitä soi. Suoraan kotiverkossa, ei
  ///
  /// In en, this message translates to:
  /// **'Sonos speakers and soundbars: volume, mute, play/pause, next and now playing. Straight over the home network, no account.'**
  String get s8f7a93b1ea;

  /// fi: Sonos-sovellus → Asetukset → Järjestelmä → Tietoja järjestelmästäni → IP-osoite.
  ///
  /// In en, this message translates to:
  /// **'Sonos app → Settings → System → About My System → IP address.'**
  String get s1cf843ef3e;

  /// fi: Roku
  ///
  /// In en, this message translates to:
  /// **'Roku'**
  String get s01d549ef4d;

  /// fi: Roku-soittimet ja Roku TV:t: näppäimet, ääni +/−, mykistys, toisto/tauko, avoin sovellus; Roku TV:ssä myös virta ja kana
  ///
  /// In en, this message translates to:
  /// **'Roku players and Roku TVs: keys, volume +/−, mute, play/pause, the open app; on Roku TVs also power and channels.'**
  String get s406bfe2259;

  /// fi: Roku: Asetukset → Verkko → Tietoja → IP-osoite. Salli ohjaus: Asetukset → Järjestelmä → Järjestelmän lisäasetukset → Ohj
  ///
  /// In en, this message translates to:
  /// **'Roku: Settings → Network → About → IP address. Allow control: Settings → System → Advanced system settings → Control by mobile apps → Enabled.'**
  String get sb4f88e9b1b;

  /// fi: TV ja Chromecast
  ///
  /// In en, this message translates to:
  /// **'TV and Chromecast'**
  String get sd3b85fadc0;

  /// fi: Samsung, LG, Philips, Android TV / Google TV, Chromecast, Sonos ja Roku: virta, ääni, kanavat ja toisto.
  ///
  /// In en, this message translates to:
  /// **'Samsung, LG, Philips, Android TV / Google TV, Chromecast, Sonos and Roku: power, volume, channels and playback.'**
  String get sebd2ee78b0;

  /// fi: RenderingControl
  ///
  /// In en, this message translates to:
  /// **'/MediaRenderer/RenderingControl/Control'**
  String get s50eb745165;

  /// fi: AVTransport
  ///
  /// In en, this message translates to:
  /// **'/MediaRenderer/AVTransport/Control'**
  String get s9e4f134628;

  /// fi: ZoneGroupTopology
  ///
  /// In en, this message translates to:
  /// **'/ZoneGroupTopology/Control'**
  String get s77251a38d3;

  /// fi: epäonnistui
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get s7594076cbd;

  /// fi: Sonokseen ei saatu yhteyttä
  ///
  /// In en, this message translates to:
  /// **'Sonos not reachable'**
  String get s01c48d363e;

  /// fi: ei Sonos-laite
  ///
  /// In en, this message translates to:
  /// **'not a Sonos device'**
  String get sc49795d7d1;

  /// fi: Linjasisääntulo
  ///
  /// In en, this message translates to:
  /// **'Line-in'**
  String get s89541675fe;

  /// fi: Sonoksessa ei ole kanavia
  ///
  /// In en, this message translates to:
  /// **'Sonos has no channels'**
  String get sdd6a5ac9b8;

  /// fi: Chromecastia ei voi käynnistää etänä
  ///
  /// In en, this message translates to:
  /// **'A Chromecast cannot be switched on remotely'**
  String get sbd92a41506;

  /// fi: Mitään ei toisteta
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get sd8167370bc;

  /// fi: paritus tarvitaan
  ///
  /// In en, this message translates to:
  /// **'pairing needed'**
  String get s0249d39100;

  /// fi: televisioon ei saatu yhteyttä
  ///
  /// In en, this message translates to:
  /// **'TV not reachable'**
  String get se5b2692112;

  /// fi: Väärä koodi
  ///
  /// In en, this message translates to:
  /// **'Wrong code'**
  String get s536792efd0;

  /// fi: paritus ei alkanut
  ///
  /// In en, this message translates to:
  /// **'pairing did not start'**
  String get s4a67144434;

  /// fi: Koodissa on 6 merkkiä (0–9, A–F)
  ///
  /// In en, this message translates to:
  /// **'The code has 6 characters (0–9, A–F)'**
  String get s3f514c9aa2;

  /// fi: Android TV pitää parittaa (koodi televisiosta)
  ///
  /// In en, this message translates to:
  /// **'Pair the Android TV first (code on the TV)'**
  String get sb3712c846c;

  /// fi: Android TV ei hyväksynyt yhteyttä – paritus tarvitaan
  ///
  /// In en, this message translates to:
  /// **'The Android TV refused – pairing needed'**
  String get sc7cbbc343d;

  /// fi: Televisio ei kerro äänenvoimakkuutta
  ///
  /// In en, this message translates to:
  /// **'The TV does not report volume'**
  String get s85bb00e885;

  /// fi: Televisio hylkäsi yhteyden – salli Molaplan TV:n kehotteesta
  ///
  /// In en, this message translates to:
  /// **'The TV refused – allow Molaplan in the prompt on the TV'**
  String get sd42552b5c1;

  /// fi: Hyväksy yhteys televisiosta (Salli) ja yritä uudelleen
  ///
  /// In en, this message translates to:
  /// **'Accept the connection on the TV (Allow) and try again'**
  String get sb7b15dd59e;

  /// fi: ei Samsung-televisio
  ///
  /// In en, this message translates to:
  /// **'not a Samsung TV'**
  String get s19ae80a1a6;

  /// fi: Käynnistys vaatii MAC-osoitteen
  ///
  /// In en, this message translates to:
  /// **'Turning on needs the MAC address'**
  String get s7e1bbea60b;

  /// fi: Televisio ei hyväksynyt äänenvoimakkuutta
  ///
  /// In en, this message translates to:
  /// **'The TV did not accept the volume'**
  String get se7feba6088;

  /// fi: Chromecast / Google TV / Android TV (Cast)
  ///
  /// In en, this message translates to:
  /// **'Chromecast / Google TV / Android TV (Cast)'**
  String get s97c684e038;

  /// fi: Televisio / Chromecast (oma integraatio)
  ///
  /// In en, this message translates to:
  /// **'TV / Chromecast (built-in integration)'**
  String get s66c82f9d98;

  /// fi: Merkki
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get s1c9df5579f;

  /// fi: Android TV:t ja Google TV:t: Cast (tila, ääni, toisto) tai kaukosäädin-yhteys (näppäimet, kanavat, virta; paritus koodil
  ///
  /// In en, this message translates to:
  /// **'Android TVs and Google TVs: Cast (status, volume, playback) or the remote protocol (keys, channels, power; pairing code).'**
  String get s22e7286858;

  /// fi: IP-osoite
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get s178e07f06b;

  /// fi: Laitteen IP-osoite (reitittimen laitelistasta). Anna reitittimessä kiinteä osoite.
  ///
  /// In en, this message translates to:
  /// **'The device IP address (router device list). Reserve a fixed address in the router.'**
  String get s678a1d0824;

  /// fi: MAC-osoite (käynnistys)
  ///
  /// In en, this message translates to:
  /// **'MAC address (power on)'**
  String get sc9db95d473;

  /// fi: Wake-on-LAN-käynnistykseen. Täyttyy yleensä itse; TV:n asetuksissa "Käynnistä verkon kautta" päälle.
  ///
  /// In en, this message translates to:
  /// **'For Wake-on-LAN power on. Usually filled in automatically; enable \"Turn on via network\" on the TV.'**
  String get s179f2d4764;

  /// fi: JointSPACE-versio (Philips)
  ///
  /// In en, this message translates to:
  /// **'JointSPACE version (Philips)'**
  String get s8480eec244;

  /// fi: Tunnistetaan itse: 6 = Android-TV:t (https 1926), 1 = vanhat (http 1925).
  ///
  /// In en, this message translates to:
  /// **'Detected automatically: 6 = Android TVs (https 1926), 1 = older sets (http 1925).'**
  String get sa592a45cc0;

  /// fi: Paritustunnus (Philips)
  ///
  /// In en, this message translates to:
  /// **'Pairing id (Philips)'**
  String get s0f34d752b2;

  /// fi: Syntyy parituksessa (PIN-koodi televisiosta).
  ///
  /// In en, this message translates to:
  /// **'Created during pairing (PIN code from the TV).'**
  String get s55e83ab0e3;

  /// fi: Paritusavain (Philips)
  ///
  /// In en, this message translates to:
  /// **'Pairing key (Philips)'**
  String get s090082b8ce;

  /// fi: Syntyy parituksessa. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'Created during pairing. Stored on this device only.'**
  String get s74b0fa8af8;

  /// fi: Yhteystunnus (Samsung)
  ///
  /// In en, this message translates to:
  /// **'Access token (Samsung)'**
  String get sf6035d1731;

  /// fi: Samsung antaa tunnuksen, kun hyväksyt yhteyden televisiosta. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'Samsung returns it when you allow the connection on the TV. Stored on this device only.'**
  String get scee449b738;

  /// fi: Asiakasavain (LG)
  ///
  /// In en, this message translates to:
  /// **'Client key (LG)'**
  String get s565b6ac234;

  /// fi: LG antaa avaimen, kun hyväksyt yhteyden televisiosta. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'LG returns it when you accept the connection on the TV. Stored on this device only.'**
  String get s8b34eb0ec5;

  /// fi: Asiakasvarmenne (Android TV)
  ///
  /// In en, this message translates to:
  /// **'Client certificate (Android TV)'**
  String get sa14b4d0a62;

  /// fi: Molaplanin oma varmenne, jonka televisio hyväksyi parituksessa. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'Molaplan\'\'s own certificate that the TV accepted during pairing. Stored on this device only.'**
  String get sb6b8ce62e4;

  /// fi: Asiakasavain (Android TV)
  ///
  /// In en, this message translates to:
  /// **'Client key (Android TV)'**
  String get s55c0154762;

  /// fi: Varmenteen yksityinen avain. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'The certificate\'\'s private key. Stored on this device only.'**
  String get s49678d6bba;

  /// fi: Lukema
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get sbdf670977b;

  /// fi: Chromecast ei kerro virtatilaa; "Päällä" on silloin aina 0.
  ///
  /// In en, this message translates to:
  /// **'A Chromecast has no power state; \"On\" is then always 0.'**
  String get s4cd6848cf8;

  /// fi: Tila (teksti)
  ///
  /// In en, this message translates to:
  /// **'Status (text)'**
  String get sb545795f0a;

  /// fi: Päällä (1/0)
  ///
  /// In en, this message translates to:
  /// **'On (1/0)'**
  String get s7c7098854f;

  /// fi: Äänenvoimakkuus (%)
  ///
  /// In en, this message translates to:
  /// **'Volume (%)'**
  String get s1d28a837cb;

  /// fi: Mykistetty (1/0)
  ///
  /// In en, this message translates to:
  /// **'Muted (1/0)'**
  String get sa13c4f1248;

  /// fi: Sovellus
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get sef1842c9c5;

  /// fi: Toistettava
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get sc5c36c50e6;

  /// fi: Toistaa (1/0)
  ///
  /// In en, this message translates to:
  /// **'Playing (1/0)'**
  String get saded6a492a;

  /// fi: Komento
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get s5bed8bff00;

  /// fi: Arvo tulee kytkimestä tai liukusäätimestä.
  ///
  /// In en, this message translates to:
  /// **'The value comes from the toggle or slider.'**
  String get s56ada71b4a;

  /// fi: Virta päälle/pois (arvo 1/0)
  ///
  /// In en, this message translates to:
  /// **'Power on/off (value 1/0)'**
  String get s5d41165c1a;

  /// fi: Äänenvoimakkuus (arvo 0–100)
  ///
  /// In en, this message translates to:
  /// **'Volume (value 0–100)'**
  String get s7df609092d;

  /// fi: Mykistys (arvo 1/0)
  ///
  /// In en, this message translates to:
  /// **'Mute (value 1/0)'**
  String get s7ce360cc79;

  /// fi: Näppäin
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get sdce14191c7;

  /// fi: Kanava (arvo = numero)
  ///
  /// In en, this message translates to:
  /// **'Channel (value = number)'**
  String get sbefd940b7e;

  /// fi: Avaa sovellus (Android TV, arvo = linkki)
  ///
  /// In en, this message translates to:
  /// **'Open app (Android TV, value = link)'**
  String get s8028880bf9;

  /// fi: Vain komennolle "Näppäin".
  ///
  /// In en, this message translates to:
  /// **'Only for the \"Key\" command.'**
  String get sc91823aedb;

  /// fi: Seuraava
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get s6c3e76828b;

  /// fi: Edellinen
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get sd61993184d;

  /// fi: Mykistys päälle/pois
  ///
  /// In en, this message translates to:
  /// **'Mute on/off'**
  String get sd46979cb3c;

  /// fi: Kanava +
  ///
  /// In en, this message translates to:
  /// **'Channel +'**
  String get s9c350b0f5e;

  /// fi: Kanava −
  ///
  /// In en, this message translates to:
  /// **'Channel −'**
  String get s66136ee35f;

  /// fi: Ylös
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get sf936d0b01d;

  /// fi: Alas
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get s09e8d49ceb;

  /// fi: Vasemmalle
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get s34e61d8a2f;

  /// fi: Oikealle
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get s365a1e8626;

  /// fi: OK
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get s183ed60009;

  /// fi: Virtanäppäin
  ///
  /// In en, this message translates to:
  /// **'Power key'**
  String get s8cbc3f33aa;

  /// fi: Toista / tauko
  ///
  /// In en, this message translates to:
  /// **'Play / pause'**
  String get sdac8f8b638;

  /// fi: Toista
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get seab0493fde;

  /// fi: Tauko
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get sef0810bb79;

  /// fi: Pysäytä
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get s6fe2320f3d;

  /// fi: Ääni kovemmalle
  ///
  /// In en, this message translates to:
  /// **'Volume up'**
  String get s476a29a514;

  /// fi: Ääni hiljemmalle
  ///
  /// In en, this message translates to:
  /// **'Volume down'**
  String get s1cafda29fd;

  /// fi: Kotinäkymä
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get s9d9c84b3a8;

  /// fi: Takaisin
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get scf7e14661c;

  /// fi: Äänenvoimakkuus puuttuu
  ///
  /// In en, this message translates to:
  /// **'Volume missing'**
  String get s94e14089d6;

  /// fi: Sovelluksen avaus toimii vain Android TV -yhteydellä
  ///
  /// In en, this message translates to:
  /// **'Open app needs the Android TV remote connection'**
  String get s483f02b584;

  /// fi: ääni
  ///
  /// In en, this message translates to:
  /// **'volume'**
  String get s5d5363db20;

  /// fi: tila
  ///
  /// In en, this message translates to:
  /// **'status'**
  String get s14252e6c3a;

  /// fi: virta
  ///
  /// In en, this message translates to:
  /// **'power'**
  String get s58332642fb;

  /// fi: äänenvoimakkuus
  ///
  /// In en, this message translates to:
  /// **'volume'**
  String get s449ab0a31f;

  /// fi: mykistys
  ///
  /// In en, this message translates to:
  /// **'mute'**
  String get s3a12232f33;

  /// fi: Televisio hylkäsi yhteyden
  ///
  /// In en, this message translates to:
  /// **'The TV refused the connection'**
  String get s46a1321d85;

  /// fi: Hyväksy yhteys televisiosta ja yritä uudelleen
  ///
  /// In en, this message translates to:
  /// **'Accept the connection on the TV and try again'**
  String get sbfbb3d52b3;

  /// fi: Rokuun ei saatu yhteyttä
  ///
  /// In en, this message translates to:
  /// **'Roku not reachable'**
  String get s9df7f078c6;

  /// fi: Roku estää ohjauksen: Asetukset → Järjestelmä → Järjestelmän lisäasetukset → Ohjaus mobiilisovelluksilla → Käytössä
  ///
  /// In en, this message translates to:
  /// **'Roku blocks control: Settings → System → Advanced system settings → Control by mobile apps → Enabled'**
  String get s0dc1e158bc;

  /// fi: ei Roku-laite
  ///
  /// In en, this message translates to:
  /// **'not a Roku device'**
  String get s58d9f3b1b1;

  /// fi: Roku ei tue äänenvoimakkuuden asettamista – käytä ääni +/− -painikkeita
  ///
  /// In en, this message translates to:
  /// **'Roku has no absolute volume – use volume +/−'**
  String get sd44e043ccc;

  /// fi: Televisio vaatii parituksen
  ///
  /// In en, this message translates to:
  /// **'The TV needs pairing'**
  String get sf2993f0346;

  /// fi: ei vastaa
  ///
  /// In en, this message translates to:
  /// **'does not answer'**
  String get s43720a9032;

  /// fi: ei JointSPACE-televisio
  ///
  /// In en, this message translates to:
  /// **'is not a JointSPACE TV'**
  String get s3a275af4f7;

  /// fi: paritus ei ole käynnissä
  ///
  /// In en, this message translates to:
  /// **'no pairing in progress'**
  String get s3d91340835;

  /// fi: Väärä PIN-koodi tai paritus vanhentui
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN or the pairing expired'**
  String get secb14ea9df;

  /// fi: {p0}
  ///
  /// In en, this message translates to:
  /// **''**
  String s404f230c13(String p0);

  /// fi: Pois päältä
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scc0cccf89d;

  /// fi: Päällä
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get s4cbe24240f;

  /// fi: Valmiina
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get s4e1ea0bc65;

  /// fi: Kanavan numero puuttuu
  ///
  /// In en, this message translates to:
  /// **'Channel number missing'**
  String get sbeb26f2b64;

  /// fi: Halpa / keski / kallis
  ///
  /// In en, this message translates to:
  /// **'Cheap / mid / expensive'**
  String get sb1d6e8bb4c;

  /// fi: Halpa / keski / kallis / erittäin kallis
  ///
  /// In en, this message translates to:
  /// **'Cheap / mid / expensive / very expensive'**
  String get sebcf59cf80;

  /// fi: Negatiivinen / halpa / kallis
  ///
  /// In en, this message translates to:
  /// **'Negative / cheap / expensive'**
  String get s0260895da8;

  /// fi: Huonelämpö
  ///
  /// In en, this message translates to:
  /// **'Room temperature'**
  String get s051944392f;

  /// fi: Ulkolämpö
  ///
  /// In en, this message translates to:
  /// **'Outdoor temperature'**
  String get s9df0743fd6;

  /// fi: Kosteus %
  ///
  /// In en, this message translates to:
  /// **'Humidity %'**
  String get sf5bd3b7950;

  /// fi: CO₂
  ///
  /// In en, this message translates to:
  /// **'CO₂'**
  String get s5538433078;

  /// fi: Matala / keski / korkea
  ///
  /// In en, this message translates to:
  /// **'Low / mid / high'**
  String get sfad2bc2059;

  /// fi: {p0} ruutua lisätty
  ///
  /// In en, this message translates to:
  /// **'{p0} tiles added'**
  String s095ca83913(String p0);

  /// fi: Airthings-mittarit
  ///
  /// In en, this message translates to:
  /// **'Airthings monitors'**
  String get sd53b0c4edc;

  /// fi: Lisää {p0} ruutua
  ///
  /// In en, this message translates to:
  /// **'Add {p0} tiles'**
  String sc401e05b53(String p0);

  /// fi: Laitteita ei saatu
  ///
  /// In en, this message translates to:
  /// **'Could not list the devices'**
  String get s212e35a61b;

  /// fi: Tililläsi ei ole mittareita. Lisää mittari ensin Airthings-sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'There are no monitors in your account. Add one in the Airthings app first.'**
  String get s039683f4a5;

  /// fi: Hubin kautta
  ///
  /// In en, this message translates to:
  /// **'via the Hub'**
  String get sdfff64e4c3;

  /// fi: Tietohaut
  ///
  /// In en, this message translates to:
  /// **'Data fetches'**
  String get s6f1dc5d97e;

  /// fi: Onnistuneet tietohaut merkitään tänne. Ilmoitus tulee vain, jos haku epäonnistuu toistuvasti.
  ///
  /// In en, this message translates to:
  /// **'Successful data fetches are listed here. A notification is sent only if a fetch keeps failing.'**
  String get s472700f0f5;

  /// fi: Onnistui
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get sdfa5b44030;

  /// fi: Epäonnistui
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get s8b8e9ac677;

  /// fi: Uusi näkymä
  ///
  /// In en, this message translates to:
  /// **'New dashboard'**
  String get scb28b11e70;

  /// fi: esim. Mökki
  ///
  /// In en, this message translates to:
  /// **'e.g. Cottage'**
  String get s1f9799af4e;

  /// fi: Nimeä näkymä
  ///
  /// In en, this message translates to:
  /// **'Rename dashboard'**
  String get s3a13f9d077;

  /// fi: Poistetaanko näkymä?
  ///
  /// In en, this message translates to:
  /// **'Delete dashboard?'**
  String get sa5bf37213b;

  /// fi: "{p0}" ja sen {p1} ruutua poistetaan.
  ///
  /// In en, this message translates to:
  /// **'\"{p0}\" and its {p1} tiles will be deleted.'**
  String s10671afc00(String p0, String p1);

  /// fi: Poista
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sc1845eb440;

  /// fi: Näkymä "{p0}" poistettu
  ///
  /// In en, this message translates to:
  /// **'Dashboard \"{p0}\" deleted'**
  String s897761b5f4(String p0);

  /// fi: Valitse ruudun tyyppi
  ///
  /// In en, this message translates to:
  /// **'Choose tile type'**
  String get scc5cf9957d;

  /// fi: Uusi laite valmiilla ruuduilla
  ///
  /// In en, this message translates to:
  /// **'New device with ready tiles'**
  String get s7cf6340503;

  /// fi: Helpoin tapa: Shelly, ESP32-CAM, Home Assistant, IV-kone…
  ///
  /// In en, this message translates to:
  /// **'Easiest: Shelly, ESP32-CAM, Home Assistant…'**
  String get se6ca707cf3;

  /// fi: NÄKYMÄT
  ///
  /// In en, this message translates to:
  /// **'DASHBOARDS'**
  String get s0789f5f14f;

  /// fi: Kaikki
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sedb7b77645;

  /// fi: Yhteydet
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get s78d94155f1;

  /// fi: Automaatiot
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get se9ca7cb470;

  /// fi: Älykäs lämmitys
  ///
  /// In en, this message translates to:
  /// **'Smart heating'**
  String get s798f7b2876;

  /// fi: pois
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get s356d822497;

  /// fi: Ilmoitukset ja muistutukset
  ///
  /// In en, this message translates to:
  /// **'Notifications and reminders'**
  String get s41bb837a83;

  /// fi: Energia
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get s49de879696;

  /// fi: Asetukset
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get s1da81fd6c3;

  /// fi: Nimeä
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get s59622d792b;

  /// fi: Poista näkymä
  ///
  /// In en, this message translates to:
  /// **'Delete dashboard'**
  String get sfb3e3c456c;

  /// fi: Valmis
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get s2acab0eccd;

  /// fi: Muokkaa
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get s187d328bb1;

  /// fi: Tyhjä näkymä
  ///
  /// In en, this message translates to:
  /// **'Empty dashboard'**
  String get s71af34b8e9;

  /// fi: Täällä näkyvät laitteidesi ruudut: lämpötilat, kytkimet, kamerat ja pikakomennot. Aloita lisäämällä laite.
  ///
  /// In en, this message translates to:
  /// **'Your device tiles appear here: temperatures, switches, cameras and shortcuts. Start by adding a device.'**
  String get s6a210970eb;

  /// fi: Lisää ensimmäinen laite
  ///
  /// In en, this message translates to:
  /// **'Add your first device'**
  String get s4229fb4103;

  /// fi: Lisää laite
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get s41c3cebc48;

  /// fi: Lisää ruutu
  ///
  /// In en, this message translates to:
  /// **'Add a tile'**
  String get s147f47be4c;

  /// fi: Poistetaanko ruutu?
  ///
  /// In en, this message translates to:
  /// **'Delete tile?'**
  String get sf67e0d5752;

  /// fi: Ruutu "{p0}" poistettu
  ///
  /// In en, this message translates to:
  /// **'Tile \"{p0}\" deleted'**
  String s97f46743e0(String p0);

  /// fi: Siirrä
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get sbeef9a7f21;

  /// fi: Siirrä vasemmalle
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get sdb0cb19db6;

  /// fi: Siirrä oikealle
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get s5570ed5144;

  /// fi: Oma väri
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get sc3abd09cd9;

  /// fi: Sävy
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get s10e7cef8c1;

  /// fi: Kylläisyys
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get s59b65e3322;

  /// fi: Vaaleus
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get s750ed8d878;

  /// fi: Peruuta
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get s809d0eb368;

  /// fi: Valitse
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get sa39e78050c;

  /// fi: Mitä lisätään?
  ///
  /// In en, this message translates to:
  /// **'What do you want to add?'**
  String get sc51b1e0dc0;

  /// fi: Laite
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get s67584c9abf;

  /// fi: Shelly, Sonoff, Hue, kamera, lämpöpumppu… Etsii kotiverkosta automaattisesti.
  ///
  /// In en, this message translates to:
  /// **'Shelly, Sonoff, Hue, camera, heat pump… Searches your home network automatically.'**
  String get s38f5b2ef26;

  /// fi: Ruutu
  ///
  /// In en, this message translates to:
  /// **'Tile'**
  String get s3b56b2cb8d;

  /// fi: Sähkön hinta, sää, kamera, mittari, ilmoitus tai komento – ei vaadi uutta laitetta.
  ///
  /// In en, this message translates to:
  /// **'Electricity price, weather, camera, gauge, notification or command – no new device needed.'**
  String get sfc846c4cc5;

  /// fi: Luo automaatio
  ///
  /// In en, this message translates to:
  /// **'Create automation'**
  String get s1b359d69e2;

  /// fi: Kun… jos… tee: valot auringonlaskussa, ilmoitus vuodosta, halvimmat tunnit, skriptit ja tilannekuvat.
  ///
  /// In en, this message translates to:
  /// **'When… if… do: lights at sunset, a leak alert, the cheapest hours, scripts and scenes.'**
  String get sf00aa23cf6;

  /// fi: Mittari
  ///
  /// In en, this message translates to:
  /// **'Gauge'**
  String get s3c98732a8c;

  /// fi: Lisää
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get s5a40f12b6a;

  /// fi: Hälytykset
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get s58f6602375;

  /// fi: Hälytykset soivat kovalla hälytysäänellä hälytysäänenvoimakkuudella, myös äänettömällä ja Älä häiritse -tilassa. Muut il
  ///
  /// In en, this message translates to:
  /// **'Alarms ring with a loud alarm sound at alarm volume, also in silent and Do Not Disturb mode. Other notifications stay quieter.'**
  String get sc2f4353c5c;

  /// fi: Hälytysääni hälytyksille
  ///
  /// In en, this message translates to:
  /// **'Alarm sound for alarms'**
  String get sbdecec718c;

  /// fi: Hälytysääni
  ///
  /// In en, this message translates to:
  /// **'Alarm sound'**
  String get s3bb454c8b4;

  /// fi: Laitteen oletushälytysääni
  ///
  /// In en, this message translates to:
  /// **'The device\'\'s default alarm sound'**
  String get s225139ca2c;

  /// fi: Äänenvoimakkuus on laitteen hälytysäänenvoimakkuus (Asetukset → Äänet → Hälytykset).
  ///
  /// In en, this message translates to:
  /// **'The volume is the device\'\'s alarm volume (Settings → Sounds → Alarms).'**
  String get s1574170d6e;

  /// fi: Soi, kunnes ilmoitus avataan
  ///
  /// In en, this message translates to:
  /// **'Ring until the notification is opened'**
  String get s8eee4c47dc;

  /// fi: Testaa hälytysääni
  ///
  /// In en, this message translates to:
  /// **'Test the alarm sound'**
  String get scf0b386f09;

  /// fi: Testihälytys
  ///
  /// In en, this message translates to:
  /// **'Test alarm'**
  String get sfa9c350c71;

  /// fi: Näin hälytys kuuluu tällä laitteella.
  ///
  /// In en, this message translates to:
  /// **'This is how an alarm sounds on this device.'**
  String get s250f45b1af;

  /// fi: Hälytysääni on käytössä Android-sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'The alarm sound is available in the Android app.'**
  String get s49450df596;

  /// fi: Hälytysääntä ei voitu toistaa. Valitse toinen hälytysääni.
  ///
  /// In en, this message translates to:
  /// **'The alarm sound could not be played. Choose another alarm sound.'**
  String get s0224b6a444;

  /// fi: Hälytysäänenvoimakkuus on nollassa, joten hälytys ei kuulu. Nosta hälytysten äänenvoimakkuutta.
  ///
  /// In en, this message translates to:
  /// **'The alarm volume is at zero, so the alarm cannot be heard. Turn up the alarm volume.'**
  String get s4fa67b1e2e;

  /// fi: Ääni soi, mutta Android ei näytä hälytysilmoitusta. Salli ilmoitukset.
  ///
  /// In en, this message translates to:
  /// **'The sound plays, but Android does not show the alarm notification. Allow notifications.'**
  String get sc407fb7084;

  /// fi: Hiljennä hälytysääni
  ///
  /// In en, this message translates to:
  /// **'Silence the alarm sound'**
  String get safeb2973b1;

  /// fi: Tarvittavat luvat
  ///
  /// In en, this message translates to:
  /// **'Required permissions'**
  String get sb616800ea4;

  /// fi: Ilmoitukset sallittu
  ///
  /// In en, this message translates to:
  /// **'Notifications allowed'**
  String get s0ff5878e24;

  /// fi: Ilman tätä mikään ilmoitus ei näy.
  ///
  /// In en, this message translates to:
  /// **'Without this no notification is shown.'**
  String get s182f268e52;

  /// fi: Hälytysäänenvoimakkuus {p0}/{p1}
  ///
  /// In en, this message translates to:
  /// **'Alarm volume {p0}/{p1}'**
  String sfe51b35785(String p0, String p1);

  /// fi: Hälytysäänenvoimakkuus
  ///
  /// In en, this message translates to:
  /// **'Alarm volume'**
  String get sfb18f97ad0;

  /// fi: Nollassa hälytys ei kuulu.
  ///
  /// In en, this message translates to:
  /// **'At zero the alarm cannot be heard.'**
  String get sb6da6f30eb;

  /// fi: Hälytykset-kanava päällä (ääni ja ponnahdus)
  ///
  /// In en, this message translates to:
  /// **'Alarms channel on (sound and pop-up)'**
  String get s85a9b79024;

  /// fi: Androidin asetuksissa kanava "Hälytykset".
  ///
  /// In en, this message translates to:
  /// **'The \"Alarms\" channel in Android settings.'**
  String get s8b8bd8d1fc;

  /// fi: Ohita Älä häiritse
  ///
  /// In en, this message translates to:
  /// **'Override Do Not Disturb'**
  String get se6188f85c8;

  /// fi: Salli Molaplanille "Älä häiritse -käyttöoikeus".
  ///
  /// In en, this message translates to:
  /// **'Allow Molaplan \"Do Not Disturb access\".'**
  String get sdc5ec1d7c5;

  /// fi: Koko näytön hälytys
  ///
  /// In en, this message translates to:
  /// **'Full-screen alarm'**
  String get s23b6916646;

  /// fi: Hälytys avautuu lukitulle näytölle.
  ///
  /// In en, this message translates to:
  /// **'The alarm opens on the lock screen.'**
  String get sff377917cb;

  /// fi: Ei akun optimointia
  ///
  /// In en, this message translates to:
  /// **'No battery optimisation'**
  String get s2646a90987;

  /// fi: Muuten Android voi pysäyttää kuuntelun.
  ///
  /// In en, this message translates to:
  /// **'Otherwise Android may stop listening.'**
  String get s3817641568;

  /// fi: Lisäasetukset: mikä on hälytys
  ///
  /// In en, this message translates to:
  /// **'Advanced: what is an alarm'**
  String get sa21239a35e;

  /// fi: Kiireelliset (5) ovat aina hälytyksiä
  ///
  /// In en, this message translates to:
  /// **'Urgent (5) is always an alarm'**
  String get s9a3142f8bb;

  /// fi: Hälytyssanat otsikossa
  ///
  /// In en, this message translates to:
  /// **'Alarm words in the title'**
  String get s7cf3a8e68d;

  /// fi: Ei hälytys, jos otsikossa
  ///
  /// In en, this message translates to:
  /// **'Not an alarm if the title has'**
  String get s9d82c5d4ea;

  /// fi: Hälytystunnisteet (ntfy-tagit)
  ///
  /// In en, this message translates to:
  /// **'Alarm tags (ntfy tags)'**
  String get sf2a45478e3;

  /// fi: Sääntöjen mukaan
  ///
  /// In en, this message translates to:
  /// **'By the rules'**
  String get s72f6fb3f29;

  /// fi: Aina hälytys
  ///
  /// In en, this message translates to:
  /// **'Always alarm'**
  String get s3c6f35a28c;

  /// fi: Ei koskaan
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get se03fb0114e;

  /// fi: Palauta oletukset
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get s0c362450c7;

  /// fi: Salli
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get sc8ef04815c;

  /// fi: Pilkulla erotettuna
  ///
  /// In en, this message translates to:
  /// **'Separated by commas'**
  String get s2e554f3c5c;

  /// fi: Tailscale (helppo VPN)
  ///
  /// In en, this message translates to:
  /// **'Tailscale (easy VPN)'**
  String get sd5cb601286;

  /// fi: Ilmainen henkilökäyttöön. Puhelin ja koti ovat kuin samassa verkossa – Molaplan toimii samoilla osoitteilla kuin kotona.
  ///
  /// In en, this message translates to:
  /// **'Free for personal use. Your phone and home act like one network – Molaplan works with the same addresses as at home.'**
  String get s0aa851cfb4;

  /// fi: Sopii, jos sinulla on kotona aina päällä PC, Raspberry Pi tai Home Assistant.
  ///
  /// In en, this message translates to:
  /// **'Good if you have an always-on PC, Raspberry Pi or Home Assistant at home.'**
  String get s444ca5d58f;

  /// fi: Tee Tailscale-tili osoitteessa tailscale.com (Google-, Microsoft- tai Apple-tunnuksella).
  ///
  /// In en, this message translates to:
  /// **'Create a Tailscale account at tailscale.com (Google, Microsoft or Apple sign-in).'**
  String get sec7b4d1d7a;

  /// fi: Asenna Tailscale kotona aina päällä olevaan laitteeseen. Home Assistantissa: Asetukset → Lisäosat → Tailscale.
  ///
  /// In en, this message translates to:
  /// **'Install Tailscale on the always-on device at home. In Home Assistant: Settings → Add-ons → Tailscale.'**
  String get s178c57446d;

  /// fi: Ota siinä käyttöön "subnet router" ja kerro kotiverkkosi, esim. 192.168.1.0/24. Silloin kaikki kodin laitteet näkyvät.
  ///
  /// In en, this message translates to:
  /// **'Turn on \"subnet router\" there and enter your home network, e.g. 192.168.1.0/24. Then all your home devices are reachable.'**
  String get s4faf83aa13;

  /// fi: Hyväksy reitti Tailscalen hallintasivulla (Machines → laite → Edit route settings).
  ///
  /// In en, this message translates to:
  /// **'Approve the route in the Tailscale admin console (Machines → device → Edit route settings).'**
  String get s721719c0e1;

  /// fi: Asenna Tailscale-sovellus puhelimeen ja kirjaudu samalla tilillä. Laita VPN päälle.
  ///
  /// In en, this message translates to:
  /// **'Install the Tailscale app on your phone and sign in with the same account. Switch the VPN on.'**
  String get s921f981bda;

  /// fi: Valmis! Molaplan käyttää samoja osoitteita kuin kotona. Etäyhteyttä ei tarvitse muuttaa.
  ///
  /// In en, this message translates to:
  /// **'Done! Molaplan uses the same addresses as at home. Nothing else to change.'**
  String get s8ae7e7b2a4;

  /// fi: tailscale.com/download
  ///
  /// In en, this message translates to:
  /// **'https://tailscale.com/download'**
  String get se92301ff0a;

  /// fi: Subnet router -ohje / guide
  ///
  /// In en, this message translates to:
  /// **'https://tailscale.com/kb/1019/subnets'**
  String get sf6270ae66c;

  /// fi: WireGuard (reitittimen VPN)
  ///
  /// In en, this message translates to:
  /// **'WireGuard (router VPN)'**
  String get s57f0b61334;

  /// fi: Jos reitittimesi tukee WireGuardia (esim. ASUS, FRITZ!Box, UniFi, OpenWrt), puhelin liittyy kotiverkkoon suoraan.
  ///
  /// In en, this message translates to:
  /// **'If your router supports WireGuard (e.g. ASUS, FRITZ!Box, UniFi, OpenWrt), your phone joins the home network directly.'**
  String get sb9bb49ab92;

  /// fi: Sopii, jos reitittimessä on WireGuard ja liittymässä julkinen IP-osoite.
  ///
  /// In en, this message translates to:
  /// **'Good if the router has WireGuard and your connection has a public IP address.'**
  String get s986d264604;

  /// fi: Avaa reitittimen asetukset ja etsi "VPN-palvelin" → "WireGuard".
  ///
  /// In en, this message translates to:
  /// **'Open the router settings and look for \"VPN server\" → \"WireGuard\".'**
  String get sf24b16dc12;

  /// fi: Ota palvelin käyttöön ja lisää uusi laite (peer) puhelimelle.
  ///
  /// In en, this message translates to:
  /// **'Enable the server and add a new device (peer) for the phone.'**
  String get s1e5d1eb832;

  /// fi: Reititin näyttää QR-koodin. Asenna puhelimeen WireGuard-sovellus ja skannaa koodi.
  ///
  /// In en, this message translates to:
  /// **'The router shows a QR code. Install the WireGuard app on the phone and scan it.'**
  String get s8e0252a2b4;

  /// fi: Tarkista että "Allowed IPs" sisältää kotiverkon (esim. 192.168.1.0/24).
  ///
  /// In en, this message translates to:
  /// **'Check that \"Allowed IPs\" includes the home network (e.g. 192.168.1.0/24).'**
  String get s4b3740b727;

  /// fi: Laita VPN päälle puhelimessa – Molaplan toimii kuten kotona.
  ///
  /// In en, this message translates to:
  /// **'Switch the VPN on in the phone – Molaplan works as at home.'**
  String get sd2e8523b28;

  /// fi: wireguard.com/install
  ///
  /// In en, this message translates to:
  /// **'https://www.wireguard.com/install/'**
  String get saa17c5a456;

  /// fi: Monissa mobiililaajakaistoissa (4G/5G-kotinetti) ei ole julkista IP-osoitetta (CGNAT), eikä WireGuard silloin toimi ulko
  ///
  /// In en, this message translates to:
  /// **'Many mobile broadband (4G/5G home internet) connections have no public IP (CGNAT) and WireGuard then cannot be reached from outside. Use Molaplan remote access or Tailscale instead.'**
  String get se5960424ea;

  /// fi: Home Assistant Cloud (Nabu Casa)
  ///
  /// In en, this message translates to:
  /// **'Home Assistant Cloud (Nabu Casa)'**
  String get sab2dfe387b;

  /// fi: Maksullinen kuukausitilaus Home Assistantin tekijöiltä. Antaa turvallisen etäosoitteen Home Assistantiin.
  ///
  /// In en, this message translates to:
  /// **'A paid monthly subscription from the makers of Home Assistant. Gives a secure remote address to Home Assistant.'**
  String get s2e0586b37e;

  /// fi: Sopii, jos laitteesi ovat jo Home Assistantissa.
  ///
  /// In en, this message translates to:
  /// **'Good if your devices are already in Home Assistant.'**
  String get s534e7ec95e;

  /// fi: Home Assistantissa: Asetukset → Home Assistant Cloud → aloita kokeilu tai kirjaudu.
  ///
  /// In en, this message translates to:
  /// **'In Home Assistant: Settings → Home Assistant Cloud → start the trial or sign in.'**
  String get s0f7533967d;

  /// fi: Ota "Remote control / Etäohjaus" päälle.
  ///
  /// In en, this message translates to:
  /// **'Turn \"Remote control\" on.'**
  String get s2e60dd8178;

  /// fi: Kopioi etäosoite, joka näyttää tältä: https://abcd1234.ui.nabu.casa
  ///
  /// In en, this message translates to:
  /// **'Copy the remote address, which looks like: https://abcd1234.ui.nabu.casa'**
  String get s7a73024451;

  /// fi: Molaplanissa: Yhteydet → Home Assistant → vaihda osoitteeksi tuo etäosoite. Token pysyy samana.
  ///
  /// In en, this message translates to:
  /// **'In Molaplan: Connections → Home Assistant → change the address to the remote address. The token stays the same.'**
  String get sd4873612f7;

  /// fi: Valmis! Home Assistant -ruudut toimivat nyt kaikkialla.
  ///
  /// In en, this message translates to:
  /// **'Done! Home Assistant tiles now work everywhere.'**
  String get s15223b0e32;

  /// fi: nabucasa.com
  ///
  /// In en, this message translates to:
  /// **'https://www.nabucasa.com/'**
  String get s9b3201b1fa;

  /// fi: Tämä koskee vain Home Assistantin kautta ohjattavia laitteita. Muille (Modbus, kamerat suoraan) käytä Molaplan-etäyhteyt
  ///
  /// In en, this message translates to:
  /// **'This only covers devices controlled through Home Assistant. For others (Modbus, cameras directly) use Molaplan remote access or a VPN.'**
  String get s60e7067815;

  /// fi: Pilvi-MQTT (esim. HiveMQ Cloud)
  ///
  /// In en, this message translates to:
  /// **'Cloud MQTT (e.g. HiveMQ Cloud)'**
  String get s8e0d0a2d4e;

  /// fi: Laitteet ja Molaplan puhuvat saman pilvipalvelimen kautta. HiveMQ Cloudissa on ilmainen taso, joka riittää kotikäyttöön.
  ///
  /// In en, this message translates to:
  /// **'Devices and Molaplan talk through the same cloud server. HiveMQ Cloud has a free tier that is enough for home use.'**
  String get sd0fff65292;

  /// fi: Sopii MQTT-laitteille: Tasmota, ESPHome, Shelly, Zigbee2MQTT, omat ESP-laitteet.
  ///
  /// In en, this message translates to:
  /// **'Good for MQTT devices: Tasmota, ESPHome, Shelly, Zigbee2MQTT, your own ESP boards.'**
  String get s7350b9f98b;

  /// fi: Tee ilmainen tili osoitteessa console.hivemq.cloud ja luo ilmainen klusteri (Free/Serverless).
  ///
  /// In en, this message translates to:
  /// **'Create a free account at console.hivemq.cloud and create a free cluster (Free/Serverless).'**
  String get s59b3c7d246;

  /// fi: Kohdassa "Access Management" luo käyttäjätunnus ja salasana.
  ///
  /// In en, this message translates to:
  /// **'Under \"Access Management\" create a username and password.'**
  String get s04fe436d1e;

  /// fi: Kopioi palvelimen osoite (esim. abcd.s1.eu.hivemq.cloud). Portti on 8883 ja TLS on päällä.
  ///
  /// In en, this message translates to:
  /// **'Copy the server address (e.g. abcd.s1.eu.hivemq.cloud). The port is 8883 with TLS on.'**
  String get sdf0075eab5;

  /// fi: Vaihda laitteidesi MQTT-asetuksiin tämä palvelin, tunnus ja salasana (TLS päälle).
  ///
  /// In en, this message translates to:
  /// **'Put this server, username and password in your devices\'\' MQTT settings (TLS on).'**
  String get s9e9be6fc33;

  /// fi: Molaplanissa: Yhteydet → MQTT → osoite, portti 8883, TLS päälle, tunnus ja salasana. Valmis – toimii kaikkialla.
  ///
  /// In en, this message translates to:
  /// **'In Molaplan: Connections → MQTT → address, port 8883, TLS on, username and password. Done – works everywhere.'**
  String get s90f1cb151b;

  /// fi: console.hivemq.cloud
  ///
  /// In en, this message translates to:
  /// **'https://console.hivemq.cloud/'**
  String get s77bf29f2f5;

  /// fi: Valitse vahva salasana: kuka tahansa salasanan tietävä voi ohjata laitteitasi.
  ///
  /// In en, this message translates to:
  /// **'Pick a strong password: anyone who knows it can control your devices.'**
  String get safd2cd2b7b;

  /// fi: Etäkäytön ohjeet
  ///
  /// In en, this message translates to:
  /// **'Remote access guides'**
  String get s9557c0ef28;

  /// fi: Helpoin: Molaplan-etäyhteys
  ///
  /// In en, this message translates to:
  /// **'Easiest: Molaplan remote access'**
  String get sf4d7957b78;

  /// fi: Ei tilejä, ei reititinasetuksia. Tarvitset vain kotona aina päällä olevan tabletin tai PC:n.
  ///
  /// In en, this message translates to:
  /// **'No accounts, no router settings. You only need a tablet or PC that stays on at home.'**
  String get s8032085166;

  /// fi: Muut tavat
  ///
  /// In en, this message translates to:
  /// **'Other ways'**
  String get sd9b48e01fc;

  /// fi: Laiteohjeet
  ///
  /// In en, this message translates to:
  /// **'Device guides'**
  String get sfe551fd431;

  /// fi: Ilmalämpöpumppu (huoltoliitäntä/ESPHome)
  ///
  /// In en, this message translates to:
  /// **'Heat pump (service port/ESPHome)'**
  String get sbd2f94e7a4;

  /// fi: Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Molaplan löytää lämpöpumpun itse.
  ///
  /// In en, this message translates to:
  /// **'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Found automatically.'**
  String get sa35e37b4b4;

  /// fi: Sähkönkulutus
  ///
  /// In en, this message translates to:
  /// **'Electricity use'**
  String get sb8934a5835;

  /// fi: Ei mukana
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get s5409dc748f;

  /// fi: Koko kohde
  ///
  /// In en, this message translates to:
  /// **'Whole site'**
  String get sf0bbcc217b;

  /// fi: Laitteen mittaus
  ///
  /// In en, this message translates to:
  /// **'Device meter'**
  String get s0ad1897b28;

  /// fi: Koko kohde = pääsähkömittari. Laitteen mittaus = yksi laite (näytetään osana kokonaisuutta, ei lasketa kahteen kertaan).
  ///
  /// In en, this message translates to:
  /// **'Whole site = main meter. Device meter = one device (shown as part of the total, never counted twice).'**
  String get s99268b5a6c;

  /// fi: Osa mittaria (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Part of meter (optional)'**
  String get se1174af557;

  /// fi: Ei mitään
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get se12fc46923;

  /// fi: Energia ja kustannukset
  ///
  /// In en, this message translates to:
  /// **'Energy and costs'**
  String get s9773c92c92;

  /// fi: Sähkösopimus
  ///
  /// In en, this message translates to:
  /// **'Electricity contract'**
  String get s43dead6994;

  /// fi: Päivä
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get sef4d24cdd4;

  /// fi: Kuukausi
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get sa62dd794ce;

  /// fi: Valitse ensin mittarit
  ///
  /// In en, this message translates to:
  /// **'Pick your meters first'**
  String get s6b2ebe5aca;

  /// fi: Merkitse alta, mikä mittari mittaa koko kohdetta ja mitkä yksittäisiä laitteita.
  ///
  /// In en, this message translates to:
  /// **'Mark below which meter measures the whole site and which ones single devices.'**
  String get sde41f2fac9;

  /// fi: sis. ALV
  ///
  /// In en, this message translates to:
  /// **'incl. VAT'**
  String get s4ad000d885;

  /// fi: ilman ALV
  ///
  /// In en, this message translates to:
  /// **'excl. VAT'**
  String get s9e214b6e88;

  /// fi: Mitatut laitteet yhteensä
  ///
  /// In en, this message translates to:
  /// **'Measured devices total'**
  String get s73771d252c;

  /// fi: Muu kulutus
  ///
  /// In en, this message translates to:
  /// **'Other use'**
  String get s22d03356a9;

  /// fi: Perusmaksut (energia + siirto)
  ///
  /// In en, this message translates to:
  /// **'Monthly fees (energy + transfer)'**
  String get s48b08c5f5a;

  /// fi: Yhteensä
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get s286e1cfb54;

  /// fi: Osalle kulutuksesta ei ollut hintaa (pörssihinta puuttui).
  ///
  /// In en, this message translates to:
  /// **'Part of the use had no price (the spot price was missing).'**
  String get s2e8700e0cf;

  /// fi: Kulutus kirjataan, kun sovellus on auki (esimerkiksi kotisillalla jatkuvasti).
  ///
  /// In en, this message translates to:
  /// **'Use is recorded while the app is open (for example continuously on the home bridge).'**
  String get sf14a153dac;

  /// fi: Mittarit
  ///
  /// In en, this message translates to:
  /// **'Meters'**
  String get s64382718ff;

  /// fi: Ei teho- tai energiaruutuja (W, kW, Wh, kWh). Lisää esim. Shelly-mittari.
  ///
  /// In en, this message translates to:
  /// **'No power or energy tiles (W, kW, Wh, kWh). Add e.g. a Shelly meter.'**
  String get s9a3a0d414e;

  /// fi: Tallennettu
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sdb0484d728;

  /// fi: Katso hinnat sähkölaskusta. Voit kirjoittaa ne verollisina tai verottomina – kustannukset näytetään molempina.
  ///
  /// In en, this message translates to:
  /// **'Copy the prices from your bill. Type them with or without VAT – costs are shown both ways.'**
  String get se80021e22a;

  /// fi: Hinta-alue
  ///
  /// In en, this message translates to:
  /// **'Price area'**
  String get sfb62156afe;

  /// fi: Sähköenergia
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get s1762fb70a7;

  /// fi: Pörssisähkö
  ///
  /// In en, this message translates to:
  /// **'Spot price'**
  String get s2ed3e3cf28;

  /// fi: Kiinteä
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get s5d1dd0f675;

  /// fi: Yö/päivä
  ///
  /// In en, this message translates to:
  /// **'Night/day'**
  String get sedb38796fb;

  /// fi: Marginaali
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get s0774cea15a;

  /// fi: Energian hinta
  ///
  /// In en, this message translates to:
  /// **'Energy price'**
  String get s63370fe61a;

  /// fi: Päiväenergia
  ///
  /// In en, this message translates to:
  /// **'Day energy'**
  String get s50a7dd89c6;

  /// fi: Yöenergia
  ///
  /// In en, this message translates to:
  /// **'Night energy'**
  String get sdeaa5ad900;

  /// fi: Perusmaksu (energia)
  ///
  /// In en, this message translates to:
  /// **'Monthly fee (energy)'**
  String get se93c7bcd86;

  /// fi: Siirto
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get sb7937e4b91;

  /// fi: Yleissiirto
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get s0f89840226;

  /// fi: Siirtohinta
  ///
  /// In en, this message translates to:
  /// **'Transfer price'**
  String get sa768f1b352;

  /// fi: Päiväsiirto
  ///
  /// In en, this message translates to:
  /// **'Day transfer'**
  String get s9e5dde22cb;

  /// fi: Yösiirto
  ///
  /// In en, this message translates to:
  /// **'Night transfer'**
  String get sdf7a4fd2e3;

  /// fi: Perusmaksu (siirto)
  ///
  /// In en, this message translates to:
  /// **'Monthly fee (transfer)'**
  String get s4df0aee067;

  /// fi: Yö alkaa
  ///
  /// In en, this message translates to:
  /// **'Night starts'**
  String get s4c59c90975;

  /// fi: Yö päättyy
  ///
  /// In en, this message translates to:
  /// **'Night ends'**
  String get s84decd042b;

  /// fi: Verot
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get s90c26f1e37;

  /// fi: Sähkövero
  ///
  /// In en, this message translates to:
  /// **'Electricity tax'**
  String get s222cb348a0;

  /// fi: ALV
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get sbe412dcaa6;

  /// fi: Tallenna
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get s162a85c6ef;

  /// fi: Haku ei onnistunut. Tarkista verkkoyhteys.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Check the connection.'**
  String get s43b55c13c5;

  /// fi: Kodin sijainti
  ///
  /// In en, this message translates to:
  /// **'Home location'**
  String get s171834ca33;

  /// fi: Sääennuste (Open-Meteo) auttaa lämmittämään etukäteen ennen pakkasta. Paikkakunta riittää.
  ///
  /// In en, this message translates to:
  /// **'The weather forecast (Open-Meteo) helps pre-heat before cold weather. The town is enough.'**
  String get s6f6c2fe37a;

  /// fi: Poista
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get s9593939a4c;

  /// fi: Paikkakunta
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get s5f663978d6;

  /// fi: esim. Tampere
  ///
  /// In en, this message translates to:
  /// **'e.g. Tampere'**
  String get s7be6460c54;

  /// fi: Sähkönkulutus, kustannukset, sopimus ja sää.
  ///
  /// In en, this message translates to:
  /// **'Electricity use, costs, contract and weather.'**
  String get s1576b70590;

  /// fi: Sijainti
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get sa6212aaeb4;

  /// fi: Laattaa ei löytynyt tästä selaimesta. Kirjaudu sisään samalla tilillä, jolla laatta tehtiin.
  ///
  /// In en, this message translates to:
  /// **'Tile not found in this browser. Sign in with the account the tile was made with.'**
  String get s1af2f8cc38;

  /// fi: Avaa Molaplan
  ///
  /// In en, this message translates to:
  /// **'Open Molaplan'**
  String get sb9b069da26;

  /// fi: Avaa koko Molaplan
  ///
  /// In en, this message translates to:
  /// **'Open full Molaplan'**
  String get s6659f500d5;

  /// fi: Kaikki
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get s3ac2079668;

  /// fi: Ei mitään
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get sc45a6d2e30;

  /// fi: Vain valvonta ja hälytykset
  ///
  /// In en, this message translates to:
  /// **'Only arming and alarms'**
  String get s08541d02f1;

  /// fi: Automaattinen (suositus)
  ///
  /// In en, this message translates to:
  /// **'Automatic (recommended)'**
  String get s92f67aa475;

  /// fi: Lisäasetukset: mistä tulee ilmoitus
  ///
  /// In en, this message translates to:
  /// **'Advanced: what notifies'**
  String get sd506bb5c34;

  /// fi: Molaplan lukee kaikki viestit (tila, syke, viiveet, vastaukset), mutta ilmoittaa oletuksena vain valvonnan kytkemisestä
  ///
  /// In en, this message translates to:
  /// **'Molaplan reads every message (status, heartbeat, delays, replies) but by default only notifies when monitoring is armed or disarmed, about alarms and about other devices\'\' ordinary messages. The same choice applies to the iPhone ntfy app when the server supports it (ntfy.molaplan.com).'**
  String get s57cfeb1fe7;

  /// fi: Ei kuunneltavia aiheita
  ///
  /// In en, this message translates to:
  /// **'No topics to listen to'**
  String get sa7251b3fca;

  /// fi: Molaplanin omat ilmoitukset
  ///
  /// In en, this message translates to:
  /// **'Molaplan\'\'s own notifications'**
  String get s6f3a092e07;

  /// fi: Laitteen vastaukset
  ///
  /// In en, this message translates to:
  /// **'Device replies'**
  String get sba0a4fbaba;

  /// fi: Tallennettu, myös palvelimelle (iPhone)
  ///
  /// In en, this message translates to:
  /// **'Saved, also on the server (iPhone)'**
  String get sdf08a348ba;

  /// fi: Tallennettu tähän sovellukseen
  ///
  /// In en, this message translates to:
  /// **'Saved in this app'**
  String get s6b8c0469dc;

  /// fi: Ilmoita myös onnistuneista tietohauista
  ///
  /// In en, this message translates to:
  /// **'Also notify when a data fetch succeeds'**
  String get scafc63f250;

  /// fi: Oletuksena onnistuneet haut merkitään vain lokiin (Lokit ja trendit → Tietohaut). Ilmoitus tulee, jos haku epäonnistuu t
  ///
  /// In en, this message translates to:
  /// **'By default, successful fetches are written only to the log (Logs and trends → Data fetches). A notification is sent if a fetch keeps failing.'**
  String get sc871df3444;

  /// fi: Kopioitu
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get sd9762f0556;

  /// fi: Linkki kopioitu
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get s703e5ec00e;

  /// fi: Kopioi
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get sd6f41faa1d;

  /// fi: Avaa
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get s3bfcb448ea;

  /// fi: Pikakomento ja kotinäyttö
  ///
  /// In en, this message translates to:
  /// **'Shortcut and home screen'**
  String get s5794ae95b6;

  /// fi: Tee laatasta "{p0}" linkki, oma kotinäytön kuvake tai iPhonen widget. Linkit ja skriptit eivät koskaan sisällä PIN-koodi
  ///
  /// In en, this message translates to:
  /// **'Turn the tile \"{p0}\" into a link, its own home-screen icon or an iPhone widget. Links and scripts never contain a PIN or password – commands ask for confirmation and the PIN every time.'**
  String sd0ebbc7196(String p0);

  /// fi: Linkit
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get s0e8a27d980;

  /// fi: Avaa laatta
  ///
  /// In en, this message translates to:
  /// **'Open the tile'**
  String get sf032c99d57;

  /// fi: Avaa molaplan.comin suoraan tähän laattaan.
  ///
  /// In en, this message translates to:
  /// **'Opens molaplan.com directly on this tile.'**
  String get se0c5314ff7;

  /// fi: Suorita komento
  ///
  /// In en, this message translates to:
  /// **'Run the command'**
  String get sfec7615e33;

  /// fi: Avaa Molaplanin ja suorittaa laatan komennon vahvistuksen (ja tarvittaessa PIN-koodin) jälkeen.
  ///
  /// In en, this message translates to:
  /// **'Opens Molaplan and runs the tile\'\'s command after confirmation (and the PIN, if needed).'**
  String get s793336a278;

  /// fi: Oma kotinäytön kuvake
  ///
  /// In en, this message translates to:
  /// **'Own home-screen icon'**
  String get s4ada3d547a;

  /// fi: Sähkön hinta -näkymä (ei kirjautumista)
  ///
  /// In en, this message translates to:
  /// **'Electricity price view (no sign-in)'**
  String get se5b7d50d32;

  /// fi: Hinta nyt ja tämän päivän ja huomisen pylväät. Toimii kenellä tahansa ilman tiliä: linkissä on vain hinta-alue, ALV, mar
  ///
  /// In en, this message translates to:
  /// **'The price now and today\'\'s and tomorrow\'\'s bars. Works for anyone without an account: the link holds only the price area, VAT, margin and transfer.'**
  String get s433d095042;

  /// fi: Laatta koko näytöllä
  ///
  /// In en, this message translates to:
  /// **'Tile full screen'**
  String get s418e567059;

  /// fi: Pelkkä tämä laatta, päivittyy itsestään. Vaatii kirjautumisen samalla tilillä.
  ///
  /// In en, this message translates to:
  /// **'Only this tile, updates by itself. Needs sign-in with the same account.'**
  String get s854b37962a;

  /// fi: iPhone: avaa linkki Safarissa → Jaa → Lisää Koti-valikkoon. Android: Chrome → ⋮ → Lisää aloitusnäytölle. PC: Chrome tai
  ///
  /// In en, this message translates to:
  /// **'iPhone: open the link in Safari → Share → Add to Home Screen. Android: Chrome → ⋮ → Add to home screen. PC: Chrome or Edge → Install app. A home-screen app has its own storage: sign in there once.'**
  String get sb377843191;

  /// fi: iPhonen widget
  ///
  /// In en, this message translates to:
  /// **'iPhone widget'**
  String get s8e05e68318;

  /// fi: iPhonen widgetit vaativat sovelluksen. Molaplanilla ei ole App Store -sovellusta, joten widget tehdään ilmaisella Script
  ///
  /// In en, this message translates to:
  /// **'iPhone widgets need an app. Molaplan has no App Store app, so the widget uses the free Scriptable app: install Scriptable, tap +, paste the script and name it. Add a Scriptable widget to the home screen, long-press it → Edit Widget → Script: pick the script.'**
  String get s5da072d585;

  /// fi: Sähkön hinta -widget (Scriptable)
  ///
  /// In en, this message translates to:
  /// **'Electricity price widget (Scriptable)'**
  String get s37a2c08789;

  /// fi: Hakee hinnat suoraan Molaplanin hintapalvelusta – ei tarvitse tiliä eikä päällä olevaa laitetta.
  ///
  /// In en, this message translates to:
  /// **'Fetches prices straight from Molaplan\'\'s price service – no account or device left on needed.'**
  String get s6345f88fa0;

  /// fi: Tilasyöte widgetille
  ///
  /// In en, this message translates to:
  /// **'Status feed for the widget'**
  String get s4de0571af7;

  /// fi: Molaplan julkaisee laatan tilan (teksti, väri) satunnaiseen, vain lukemiseen tarkoitettuun osoitteeseen. Syötettä päivit
  ///
  /// In en, this message translates to:
  /// **'Molaplan publishes the tile\'\'s state (text, colour) to a random, read-only address. The feed is updated by a device where the tile is shown (e.g. the home bridge). Anyone with the address can see the state but cannot control anything.'**
  String get s0d66c9fdf7;

  /// fi: Laatan widget (Scriptable)
  ///
  /// In en, this message translates to:
  /// **'Tile widget (Scriptable)'**
  String get s694ea6d8d2;

  /// fi: Uusi osoite (vanha lakkaa toimimasta)
  ///
  /// In en, this message translates to:
  /// **'New address (the old one stops working)'**
  String get sd6c9e55bce;

  /// fi: Pikakomennot ja Siri (iPhone)
  ///
  /// In en, this message translates to:
  /// **'Shortcuts and Siri (iPhone)'**
  String get s32d2c87e84;

  /// fi: Pikakomento: suorita komento
  ///
  /// In en, this message translates to:
  /// **'Shortcut: run the command'**
  String get sd3e8aa895f;

  /// fi: Pikakomento: avaa laatta
  ///
  /// In en, this message translates to:
  /// **'Shortcut: open the tile'**
  String get sa82dd6fac4;

  /// fi: Pikakomento: lue arvo ääneen
  ///
  /// In en, this message translates to:
  /// **'Shortcut: read the value aloud'**
  String get s980a75a37b;

  /// fi: Mikä on natiivia, mikä kiertotie
  ///
  /// In en, this message translates to:
  /// **'What is native, what is a workaround'**
  String get s5f8107014a;

  /// fi: Android: oikeat kotinäytön widgetit ja pikakuvakkeet Molaplan-sovelluksesta (Lisää aloitusnäytölle). iPhone: kotinäytön
  ///
  /// In en, this message translates to:
  /// **'Android: real home-screen widgets and shortcuts from the Molaplan app (Add to home screen). iPhone: the home-screen icon is a web app (Safari), the widget runs through the Scriptable app and Siri through Shortcuts. Commands always open Molaplan, which asks for confirmation and the PIN.'**
  String get sbf5c8473b2;

  /// fi: Vain sovelluksessa
  ///
  /// In en, this message translates to:
  /// **'App only'**
  String get s463074e5cc;

  /// fi: Toimii vain sovelluksessa tai kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'Works only in the app or via a home bridge'**
  String get seb8b8d2adf;

  /// fi: Ei yhteyttä
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get s3a5c21004e;

  /// fi: Hintoja ei saatu – yritetään uudelleen
  ///
  /// In en, this message translates to:
  /// **'Could not get prices – retrying'**
  String get sbc7a87e591;

  /// fi: Säätietoja ei saatu – yritetään uudelleen
  ///
  /// In en, this message translates to:
  /// **'Could not get the weather – retrying'**
  String get s3f0837ec84;

  /// fi: ntfy-viestiraja täynnä
  ///
  /// In en, this message translates to:
  /// **'ntfy message limit reached'**
  String get sedeaf26f8a;

  /// fi: Ei vastausta laitteelta
  ///
  /// In en, this message translates to:
  /// **'No reply from the device'**
  String get s349ca716f2;

  /// fi: Päivällä ei ohjata
  ///
  /// In en, this message translates to:
  /// **'Not controlled during the day'**
  String get sd2b99f6417;

  /// fi: Kirjautuminen vanhentunut
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired'**
  String get s68cbe596f8;

  /// fi: Ei nettiyhteyttä
  ///
  /// In en, this message translates to:
  /// **'No internet'**
  String get s599357f47b;

  /// fi: Modbus ei päällä
  ///
  /// In en, this message translates to:
  /// **'Modbus is off'**
  String get s74fa2d56aa;

  /// fi: Laite ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Device not responding'**
  String get s156aa7eeb3;

  /// fi: Väärä unit id?
  ///
  /// In en, this message translates to:
  /// **'Wrong unit id?'**
  String get sbf2cfbb102;

  /// fi: Estotila
  ///
  /// In en, this message translates to:
  /// **'Lockout'**
  String get s9be06479ff;

  /// fi: Osoite puuttuu
  ///
  /// In en, this message translates to:
  /// **'No address'**
  String get s613938b0b3;

  /// fi: Varattu (HA?)
  ///
  /// In en, this message translates to:
  /// **'Busy (HA?)'**
  String get s252d8628c7;

  /// fi: Palvelu ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Service not answering'**
  String get s0e3a6bafbf;

  /// fi: Palvelinta ei löydy
  ///
  /// In en, this message translates to:
  /// **'Server not found'**
  String get s7abcbf1107;

  /// fi: Kotisilta ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Home bridge not responding'**
  String get sca533b6f25;

  /// fi: Tietoa ei löydy laitteesta
  ///
  /// In en, this message translates to:
  /// **'Value not found on device'**
  String get s96ad0dc252;

  /// fi: Asetus puuttuu
  ///
  /// In en, this message translates to:
  /// **'Setting missing'**
  String get s61cdd7287b;

  /// fi: Suojausvirhe
  ///
  /// In en, this message translates to:
  /// **'Security error'**
  String get s57d0940253;

  /// fi: Laite ei ole verkossa
  ///
  /// In en, this message translates to:
  /// **'Device is offline'**
  String get sfec025279e;

  /// fi: Tarkista nyt
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get s1ea16fc636;

  /// fi: Ei verkkoyhteyttä
  ///
  /// In en, this message translates to:
  /// **'No network'**
  String get sbaf1a2b35e;

  /// fi: Laite ei ole Wi-Fissä, eikä mobiilidata toimi. Ruuduissa näkyvät viimeksi saadut arvot.
  ///
  /// In en, this message translates to:
  /// **'This device is not on Wi-Fi and mobile data does not work. Tiles show the last values received.'**
  String get s3f750ce1d4;

  /// fi: Wi-Fissä ei ole nettiä
  ///
  /// In en, this message translates to:
  /// **'The Wi-Fi has no internet'**
  String get s542a3e9332;

  /// fi: Kotiverkon laitteet toimivat, pilvipalvelut ja etäyhteys eivät.
  ///
  /// In en, this message translates to:
  /// **'Devices on this Wi-Fi work; cloud services and remote access do not.'**
  String get sba13ded915;

  /// fi: Etäpalvelin ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Remote server not answering'**
  String get se24bfd1257;

  /// fi: Netti toimii, mutta Molaplanin etäpalvelin ei vastaa. Kotona kaikki toimii; etäkäyttö palaa itsestään.
  ///
  /// In en, this message translates to:
  /// **'The internet works, but Molaplan\'\'s remote server does not answer. At home everything works; remote access comes back by itself.'**
  String get s8584be9da3;

  /// fi: Yhteys kunnossa
  ///
  /// In en, this message translates to:
  /// **'Connection OK'**
  String get s1e03ade992;

  /// fi: Tarkistetaan itsestään 15 s välein, kunnes yhteys toimii. Ilmoitus poistuu silloin itsestään.
  ///
  /// In en, this message translates to:
  /// **'Re-checked every 15 s until it works; this notice then disappears by itself.'**
  String get s0fc5f4d788;

  /// fi: Edistyneet
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sf4caddf894;

  /// fi: Wi-Fi/Ethernet-osoitteet
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi/Ethernet addresses'**
  String get s3e05e0efab;

  /// fi: ei yhtään
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get s6b59e217ba;

  /// fi: Tarkistettu
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get s3b7c55c4fc;

  /// fi: Olet poissa kotoa, eikä kotisilta vastaa. Kotiverkon laitteita ei voi nyt ohjata.
  ///
  /// In en, this message translates to:
  /// **'You are away and the home bridge is not answering. Home network devices cannot be controlled now.'**
  String get sc26c52235c;

  /// fi: Olet poissa kotoa. Kotiverkon laitteet toimivat etänä vain kotisillan kautta.
  ///
  /// In en, this message translates to:
  /// **'You are away. Home network devices work remotely only through a home bridge.'**
  String get s0fc1c9f296;

  /// fi: Etäkäyttö
  ///
  /// In en, this message translates to:
  /// **'Remote access'**
  String get se50ed56454;

  /// fi: Täytä avain ja palvelin.
  ///
  /// In en, this message translates to:
  /// **'Fill in the key and the server.'**
  String get sc5f54cf3c8;

  /// fi: Pilvessä ei ole laitteita tällä avaimella.
  ///
  /// In en, this message translates to:
  /// **'No devices in the cloud with this key.'**
  String get sb26dad8f73;

  /// fi: {p0} toimii nyt Shelly Cloudin kautta.
  ///
  /// In en, this message translates to:
  /// **'{p0} now works through Shelly Cloud.'**
  String s2c6ce95ec2(String p0);

  /// fi: Ohjaa {p0} kodin ulkopuolelta
  ///
  /// In en, this message translates to:
  /// **'Control {p0} away from home'**
  String s5629901cc4(String p0);

  /// fi: Laite vaihdetaan käyttämään Shelly Cloudia. Kaikki sen kanavat, nimet ja ruudut säilyvät. Avain: Shelly-sovellus → oma p
  ///
  /// In en, this message translates to:
  /// **'The device is switched to Shelly Cloud. All its channels, names and tiles stay. Key: Shelly app → your profile → User settings → Authorization cloud key.'**
  String get s064abc90af;

  /// fi: Pilviavain
  ///
  /// In en, this message translates to:
  /// **'Cloud key'**
  String get s61a2d946a4;

  /// fi: Palvelin (Server URI)
  ///
  /// In en, this message translates to:
  /// **'Server (Server URI)'**
  String get sf16961256b;

  /// fi: Mikä näistä on {p0}?
  ///
  /// In en, this message translates to:
  /// **'Which of these is {p0}?'**
  String s28e10c6870(String p0);

  /// fi: Vaihda Shelly Cloudiin
  ///
  /// In en, this message translates to:
  /// **'Switch to Shelly Cloud'**
  String get s09f5da65e0;

  /// fi: Pois käytöstä
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get sf5768a876d;

  /// fi: Käsiohjaus
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get s8724f302ef;

  /// fi: Käsiohjaus {p0}
  ///
  /// In en, this message translates to:
  /// **'Manual {p0}'**
  String s76bce4b6c2(String p0);

  /// fi: Takka-tila
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode'**
  String get s221a4ab646;

  /// fi: Lomatila
  ///
  /// In en, this message translates to:
  /// **'Holiday mode'**
  String get s5da1e65941;

  /// fi: Lämpötilaohjaus
  ///
  /// In en, this message translates to:
  /// **'Temperature control'**
  String get se50792831f;

  /// fi: Halvimmat tunnit
  ///
  /// In en, this message translates to:
  /// **'Cheapest hours'**
  String get sd408a5dbe9;

  /// fi: Kalleimpien ohitus
  ///
  /// In en, this message translates to:
  /// **'Skip expensive'**
  String get s5c33c7b488;

  /// fi: Sään mukaan
  ///
  /// In en, this message translates to:
  /// **'By the weather'**
  String get seaa748138e;

  /// fi: Älykäs lämmitys: ota käyttöön
  ///
  /// In en, this message translates to:
  /// **'Smart heating: set it up'**
  String get saf3ce7f717;

  /// fi: Älykäs lämmitys: lisää laite
  ///
  /// In en, this message translates to:
  /// **'Smart heating: add a device'**
  String get scde8147260;

  /// fi: Lämmityslaite poistettu
  ///
  /// In en, this message translates to:
  /// **'Heating device removed'**
  String get sea2ac9b443;

  /// fi: Ei kotisiltaa: lämmitys ei ohjaudu vielä. Ota etäyhteys käyttöön kotona olevalla laitteella.
  ///
  /// In en, this message translates to:
  /// **'No home bridge: heating is not controlled yet. Set up remote access on a device at home.'**
  String get s27e0af845d;

  /// fi: Nyt {p0} · tavoite {p1}
  ///
  /// In en, this message translates to:
  /// **'Now {p0} · setpoint {p1}'**
  String s04fcb24bc5(String p0, String p1);

  /// fi: Lämpötila {p0}
  ///
  /// In en, this message translates to:
  /// **'Temperature {p0}'**
  String s3c3d6b5485(String p0);

  /// fi: {p0} c/kWh
  ///
  /// In en, this message translates to:
  /// **'{p0} c/kWh'**
  String s670a6ed937(String p0);

  /// fi: {p0} c/kWh · raja {p1} c
  ///
  /// In en, this message translates to:
  /// **'{p0} c/kWh · limit {p1} c'**
  String s8272e84b1c(String p0, String p1);

  /// fi: Anturi ei vastaa – {p0}
  ///
  /// In en, this message translates to:
  /// **'Sensor not answering – {p0}'**
  String s8235ae91c4(String p0);

  /// fi: Arvio hinnoista – ei kotisiltaa
  ///
  /// In en, this message translates to:
  /// **'Estimate from prices – no home bridge'**
  String get s0be7b030a0;

  /// fi: Arvio – kotisilta ei vastaa vielä
  ///
  /// In en, this message translates to:
  /// **'Estimate – the home bridge has not answered yet'**
  String get s9c543b2106;

  /// fi: pidetään päällä
  ///
  /// In en, this message translates to:
  /// **'kept on'**
  String get see998ca830;

  /// fi: pidetään pois
  ///
  /// In en, this message translates to:
  /// **'kept off'**
  String get s9eb36d05e1;

  /// fi: hintaohjaus
  ///
  /// In en, this message translates to:
  /// **'price schedule'**
  String get s871e341710;

  /// fi: Tilannekuva
  ///
  /// In en, this message translates to:
  /// **'Situation'**
  String get s579f396ae5;

  /// fi: Lämpötila
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get s8653f173b6;

  /// fi: Hinta nyt
  ///
  /// In en, this message translates to:
  /// **'Price now'**
  String get sb730159a01;

  /// fi: Seuraava muutos
  ///
  /// In en, this message translates to:
  /// **'Next change'**
  String get s7dfe0e7977;

  /// fi: Tekniset tiedot
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get sf77125583f;

  /// fi: Tämä on arvio hinnoista ja asetuksista: kotisilta ei ole vielä vastannut, joten laitteen todellista tilaa ei tiedetä.
  ///
  /// In en, this message translates to:
  /// **'This is an estimate from prices and settings: the home bridge has not answered yet, so the real state of the device is unknown.'**
  String get s5555a716bb;

  /// fi: Lopeta käsiohjaus
  ///
  /// In en, this message translates to:
  /// **'End manual override'**
  String get sbe50b10e9e;

  /// fi: Käsiohjaus…
  ///
  /// In en, this message translates to:
  /// **'Manual override…'**
  String get s728ddd7778;

  /// fi: ei anturia
  ///
  /// In en, this message translates to:
  /// **'no sensor'**
  String get sd661031615;

  /// fi: anturi ei vastaa
  ///
  /// In en, this message translates to:
  /// **'sensor not answering'**
  String get scfb407cd2d;

  /// fi: tavoite {p0} ± {p1}
  ///
  /// In en, this message translates to:
  /// **'setpoint {p0} ± {p1}'**
  String s1284293e15(String p0, String p1);

  /// fi: yläraja {p0}
  ///
  /// In en, this message translates to:
  /// **'upper limit {p0}'**
  String s07a15cf1d3(String p0);

  /// fi: min {p0}
  ///
  /// In en, this message translates to:
  /// **'min {p0}'**
  String s4e43228e07(String p0);

  /// fi: jäätymissuoja {p0}
  ///
  /// In en, this message translates to:
  /// **'frost {p0}'**
  String sd4db0fbbb5(String p0);

  /// fi: ei hintatietoa
  ///
  /// In en, this message translates to:
  /// **'no price data'**
  String get s63c3e9c766;

  /// fi: {p0} (ohitetaan, kun ≥ {p1} c)
  ///
  /// In en, this message translates to:
  /// **'{p0} (skipped at ≥ {p1} c)'**
  String s8c60756474(String p0, String p1);

  /// fi: {p0} (päällä, kun ≤ {p1} c)
  ///
  /// In en, this message translates to:
  /// **'{p0} (on at ≤ {p1} c)'**
  String sff29b84ddc(String p0, String p1);

  /// fi: Miksi näin? Säännöt ja niiden tila
  ///
  /// In en, this message translates to:
  /// **'Why? The rules and their state'**
  String get s750dcb984f;

  /// fi: ratkaisee nyt
  ///
  /// In en, this message translates to:
  /// **'decides now'**
  String get s39d300e3ea;

  /// fi: Seuraavat 24 h: hinta ja suunnitellut lämmitystunnit
  ///
  /// In en, this message translates to:
  /// **'Next 24 h: price and planned heating hours'**
  String get s55153c17b8;

  /// fi: Hintatietoa ei ole vielä.
  ///
  /// In en, this message translates to:
  /// **'No price data yet.'**
  String get sfb5a3f7da0;

  /// fi: Oranssi = lämmitys suunnitellusti päällä. Korkeampi pylväs = kalliimpi tunti ({p0}–{p1} c/kWh).
  ///
  /// In en, this message translates to:
  /// **'Orange = heating planned on. A taller bar = a more expensive hour ({p0}–{p1} c/kWh).'**
  String sba9d60d97c(String p0, String p1);

  /// fi: Korkeampi pylväs = kalliimpi tunti ({p0}–{p1} c/kWh). Suunnitelma näkyy, kun kotisilta on vastannut.
  ///
  /// In en, this message translates to:
  /// **'A taller bar = a more expensive hour ({p0}–{p1} c/kWh). The plan shows when the home bridge has answered.'**
  String s3030d2947a(String p0, String p1);

  /// fi: Käsiohjaus
  ///
  /// In en, this message translates to:
  /// **'Manual override'**
  String get s3d99bc591b;

  /// fi: Tavoitelämpötilaa nostetaan tai lasketaan valituksi ajaksi, sitten automaattinen ohjaus jatkuu.
  ///
  /// In en, this message translates to:
  /// **'The target temperature is raised or lowered for the chosen time, then automatic control continues.'**
  String get sb65a9ab4a9;

  /// fi: Lämmitys pakotetaan päälle tai pois valituksi ajaksi, sitten automaattinen ohjaus jatkuu.
  ///
  /// In en, this message translates to:
  /// **'Heating is forced on or off for the chosen time, then automatic control continues.'**
  String get sb1c3627dc7;

  /// fi: Tehostus
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get seeaa40c11e;

  /// fi: Päälle
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get s4cd3d92d4c;

  /// fi: Säästö
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get sdb7d34e8e1;

  /// fi: Pois
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get s33831dd49f;

  /// fi: Turvarajat (jäätymissuoja ja vähimmäislämpötila) ovat silti voimassa.
  ///
  /// In en, this message translates to:
  /// **'The safety limits (frost protection and minimum temperature) still apply.'**
  String get s3ef843cf90;

  /// fi: Ota käyttöön
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get s3077b295d1;

  /// fi: Ei lämpötilaa
  ///
  /// In en, this message translates to:
  /// **'No reading'**
  String get s7926a59e29;

  /// fi: Nyt
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get s29fd8d5b5e;

  /// fi: Tavoite {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Setpoint {p0} °C'**
  String s961397a99b(String p0);

  /// fi: Tavoite {p0} °C (hinta: {p1} °C tällä tunnilla)
  ///
  /// In en, this message translates to:
  /// **'Setpoint {p0} °C (price: {p1} °C this hour)'**
  String sc47170dbe0(String p0, String p1);

  /// fi: Kotisillan kautta: valot, pistorasiat, Home Assistant, Shelly, Tasmota, ESPHome, Modbus, kamerakuvat
  ///
  /// In en, this message translates to:
  /// **'Through your home bridge: lights, plugs, Home Assistant, Shelly, Tasmota, ESPHome, Modbus, camera stills'**
  String get s6b536de0c8;

  /// fi: Suoraan netistä: ntfy-komennot, sähkön hinta, sää
  ///
  /// In en, this message translates to:
  /// **'Straight over the internet: ntfy commands, electricity price, weather'**
  String get s082c8c6278;

  /// fi: Samat näkymät ja ruudut kuin tilisi muilla laitteilla
  ///
  /// In en, this message translates to:
  /// **'The same views and tiles as your account\'\'s other devices'**
  String get s5a419e551c;

  /// fi: Ilman kotisiltaa kotiverkon laitteita ei voi ohjata selaimesta
  ///
  /// In en, this message translates to:
  /// **'Without a home bridge the browser cannot control home-network devices'**
  String get sa8f5c5c719;

  /// fi: Vain sovelluksessa: laitteiden haku, Bluetooth, RTSP-video, kotisiltana toimiminen
  ///
  /// In en, this message translates to:
  /// **'App only: device search, Bluetooth, RTSP video, acting as the home bridge'**
  String get sb1c4acea71;

  /// fi: Selainversio on etäohjain
  ///
  /// In en, this message translates to:
  /// **'The browser version is a remote control'**
  String get s2842696c47;

  /// fi: Täällä ohjaat vain laitteita, jotka ovat etäkäytettävissä: kotisillan (Molaplan PC:llä, Android-laitteella tai Molaplan
  ///
  /// In en, this message translates to:
  /// **'Here you control only devices that can be reached remotely: through a home bridge (Molaplan on a PC, an Android device or a Molaplan Bridge), ntfy or a cloud service. For full local control you need the Molaplan app.'**
  String get s1cbac3d12d;

  /// fi: Sovellukset ovat tulossa sovelluskauppoihin (Google Play, Microsoft Store). Jo nyt: jos sinulla on vanha Android-laite,
  ///
  /// In en, this message translates to:
  /// **'The apps are coming to the app stores (Google Play, Microsoft Store). Already now: if you have an old Android device, we can install Molaplan on it as a service, or we will send the install file (APK) for you to install yourself if you are comfortable doing that.'**
  String get scc4366802a;

  /// fi: Tilaa PC-sovellus tai valmis Android-laite
  ///
  /// In en, this message translates to:
  /// **'Order the PC app or a ready Android device'**
  String get saffec3d1c7;

  /// fi: Pyydä asennus palveluna
  ///
  /// In en, this message translates to:
  /// **'Request installation as a service'**
  String get sb2b9982ba7;

  /// fi: Lataa asennustiedosto
  ///
  /// In en, this message translates to:
  /// **'Download the install file'**
  String get s02179b814a;

  /// fi: Lataa uusin Android-asennustiedosto (APK). Avaa tiedosto puhelimessa tai tabletissa. Jos Android kysyy, salli asennus tu
  ///
  /// In en, this message translates to:
  /// **'Download the latest Android install file (APK). Open the file on the phone or tablet. If Android asks, allow installation from unknown sources (Settings → security).'**
  String get see46457ffd;

  /// fi: Lataa
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get s167c125f07;

  /// fi: Tähän laitteeseen ei saada yhteyttä selaimesta. Se toimii Molaplan-sovelluksessa, tai täältä, kun kotisilta on päällä.
  ///
  /// In en, this message translates to:
  /// **'This device cannot be reached from the browser. It works in the Molaplan app, or from here when a home bridge is on.'**
  String get s2bf22ca429;

  /// fi: Sulje
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get s1e593aeca2;

  /// fi: Selainversio: ohjaat etäkäytettäviä laitteita. Täysi ohjaus sovelluksella – lisätietoja ›
  ///
  /// In en, this message translates to:
  /// **'Browser version: you control remotely reachable devices. Full control with the app – more ›'**
  String get sc6e6f17ad4;

  /// fi: Piilota
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get s2b463f47ba;

  /// fi: Kodin laitteet ja tila yhdessä näkymässä
  ///
  /// In en, this message translates to:
  /// **'Your home\'\'s devices and status in one view'**
  String get sbed5ab99f6;

  /// fi: Ohjaa valoja, pistorasioita, lämpöpumppua ja hälytintä isoilla ruuduilla
  ///
  /// In en, this message translates to:
  /// **'Control lights, plugs, heat pump and alarm with big tiles'**
  String get s1ffc6e9e18;

  /// fi: Sama näkymä PC:llä, tabletilla, puhelimella ja selaimessa
  ///
  /// In en, this message translates to:
  /// **'The same view on a PC, tablet, phone and in the browser'**
  String get sb18bf27c69;

  /// fi: Laitteiden salasanat salataan – vain sinun laitteesi avaavat ne
  ///
  /// In en, this message translates to:
  /// **'Device passwords are encrypted – only your devices can open them'**
  String get sdc86a6f82c;

  /// fi: Käytä ilman tiliä
  ///
  /// In en, this message translates to:
  /// **'Use without an account'**
  String get s3865b9c032;

  /// fi: Asetukset jäävät tähän selaimeen. Voit myöhemmin luoda tilin ja siirtää ne sinne.
  ///
  /// In en, this message translates to:
  /// **'Setup stays in this browser. You can create an account later and move it there.'**
  String get sdf7bb58964;

  /// fi: Kirjaudu sisään
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get se697487621;

  /// fi: Luo tili sähköpostikoodilla
  ///
  /// In en, this message translates to:
  /// **'Create an account with an email code'**
  String get sb2703f9ad3;

  /// fi: Nimi tulee espanjan ilmauksesta "me mola el plan" – "kuulostaa hyvältä".
  ///
  /// In en, this message translates to:
  /// **'The name comes from the Spanish \"me mola el plan\" – \"sounds good\".'**
  String get s326d86a618;

  /// fi: Poistetaanko selaimen tiedot?
  ///
  /// In en, this message translates to:
  /// **'Delete this browser\'\'s data?'**
  String get s1812df3cb5;

  /// fi: Kaikki tässä selaimessa olevat Molaplan-asetukset, laitteet, yhteydet ja ruudut poistetaan. Tätä ei voi perua.
  ///
  /// In en, this message translates to:
  /// **'All Molaplan settings, devices, connections and tiles in this browser will be deleted. This cannot be undone.'**
  String get sbab6f0fd9d;

  /// fi: Poista selaimen tiedot
  ///
  /// In en, this message translates to:
  /// **'Delete browser data'**
  String get s38a0f7939b;

  /// fi: Kumoa
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get s4226eb046f;

  /// fi: Siltaa ei löytynyt. Onko puhelin liitetty sillan Wi-Fiin "Molaplan-XXXX"? Jos verkkoa ei näy, pidä sillan nappia painett
  ///
  /// In en, this message translates to:
  /// **'Bridge not found. Is the phone on the bridge\'\'s Wi-Fi \"Molaplan-XXXX\"? If the network is missing, hold the bridge button for 3 s (setup opens for 15 minutes).'**
  String get saa4df8e877;

  /// fi: Silta ei ole asetustilassa. Pidä sen nappia painettuna 3 s ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The bridge is not in setup mode. Hold its button for 3 s and try again.'**
  String get sf5293b1989;

  /// fi: Tämä ei ole tarran / QR-koodin silta (avain ei täsmää). Mitään ei lähetetty.
  ///
  /// In en, this message translates to:
  /// **'This is not the bridge on the label / QR code (key mismatch). Nothing was sent.'**
  String get s839deeab41;

  /// fi: Sillan vastaus ei kelpaa (salaus ei täsmää). Mitään ei tallennettu.
  ///
  /// In en, this message translates to:
  /// **'The bridge\'\'s reply is not valid (encryption mismatch). Nothing was saved.'**
  String get s3694ce006b;

  /// fi: Silta hylkäsi asetukset: {p0}
  ///
  /// In en, this message translates to:
  /// **'The bridge rejected the setup: {p0}'**
  String s61aea0b713(String p0);

  /// fi: Koti
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get s5b44cbe9c0;

  /// fi: Lisää kotisilta
  ///
  /// In en, this message translates to:
  /// **'Add home bridge'**
  String get s63551081b0;

  /// fi: Molaplan Bridge -laite
  ///
  /// In en, this message translates to:
  /// **'Molaplan Bridge device'**
  String get s592edd94e7;

  /// fi: Pieni, aina päällä oleva laite (esim. Athom IR/RF -ohjain), joka välittää etäkomennot kodin laitteille ja ohjaa ilmalämp
  ///
  /// In en, this message translates to:
  /// **'A small always-on device (e.g. the Athom IR/RF controller) that passes remote commands to your devices and controls the heat pump by infrared.'**
  String get sa329968355;

  /// fi: Kytke silta virtaan. Uusi silta avaa asetustilan itse (valo vilkkuu hitaasti, kerran sekunnissa).
  ///
  /// In en, this message translates to:
  /// **'Power the bridge. A new bridge opens setup by itself (slow blink, once a second).'**
  String get sd8790684a6;

  /// fi: Avaa puhelimen Wi-Fi-asetukset ja liity verkkoon "Molaplan-XXXX" (ei salasanaa).
  ///
  /// In en, this message translates to:
  /// **'Open the phone\'\'s Wi-Fi settings and join \"Molaplan-XXXX\" (no password).'**
  String get s087004d26c;

  /// fi: Palaa tähän ja paina "Etsi silta".
  ///
  /// In en, this message translates to:
  /// **'Come back here and press \"Find bridge\".'**
  String get sf85e449cd8;

  /// fi: Etsi silta
  ///
  /// In en, this message translates to:
  /// **'Find bridge'**
  String get s57466387fc;

  /// fi: Silta löytyi
  ///
  /// In en, this message translates to:
  /// **'Bridge found'**
  String get sd166e3cf6f;

  /// fi: Ohjelmisto
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get s6b841de5dd;

  /// fi: Kodin Wi-Fi
  ///
  /// In en, this message translates to:
  /// **'Home Wi-Fi'**
  String get s88fa323548;

  /// fi: Verkon nimi
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get sf48dd63b0a;

  /// fi: Wi-Fi-salasana
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi password'**
  String get s9f9c574cf9;

  /// fi: Kodin nimi
  ///
  /// In en, this message translates to:
  /// **'Home name'**
  String get sc58a7d7121;

  /// fi: Laitemalli
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get sc452460b0f;

  /// fi: testaamaton
  ///
  /// In en, this message translates to:
  /// **'untested'**
  String get s4bdd633042;

  /// fi: Tiedot lähetetään sillalle salattuina – sillan Wi-Fi on avoin, mutta salasanaa ei voi lukea siitä.
  ///
  /// In en, this message translates to:
  /// **'The details are sent encrypted – the bridge Wi-Fi is open, but the password cannot be read from it.'**
  String get sbe6a859b63;

  /// fi: Yhdistä silta kotiin
  ///
  /// In en, this message translates to:
  /// **'Connect the bridge'**
  String get s77af0820de;

  /// fi: Silta yhdistetty!
  ///
  /// In en, this message translates to:
  /// **'Bridge connected!'**
  String get s1ec01d8473;

  /// fi: Silta liittyy nyt kodin Wi-Fiin (valo palaa ja välähtää pois 3 s välein, kun yhteys on kunnossa). Vaihda puhelin takaisi
  ///
  /// In en, this message translates to:
  /// **'The bridge is now joining the home Wi-Fi (light on with a short dip every 3 s when connected). Switch the phone back to the home Wi-Fi or mobile data – Remote access shows the bridge status.'**
  String get s88bc217a1b;

  /// fi: Lisää laite
  ///
  /// In en, this message translates to:
  /// **'Add a device'**
  String get s876c7230a2;

  /// fi: Käytä
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get s3d00dee1a9;

  /// fi: Valitse laitteesi merkki. Molaplan etsii sen ja tekee ruudut valmiiksi.
  ///
  /// In en, this message translates to:
  /// **'Pick your device brand. Molaplan finds it and creates the tiles.'**
  String get sa252f06bff;

  /// fi: Hae merkkiä tai laitetta (esim. Shelly, Hue, IKEA)
  ///
  /// In en, this message translates to:
  /// **'Search brand or device (e.g. Shelly, Hue, IKEA)'**
  String get s5b3b5e5a24;

  /// fi: Löydä ja yhdistä automaattisesti
  ///
  /// In en, this message translates to:
  /// **'Find and connect automatically'**
  String get sa427be10c9;

  /// fi: Tulossa – näin käytät nyt
  ///
  /// In en, this message translates to:
  /// **'Coming – how to use it today'**
  String get s6f4cc0844f;

  /// fi: Muut laitteet
  ///
  /// In en, this message translates to:
  /// **'Other devices'**
  String get s846ee3bc67;

  /// fi: Termostaatti lämmitys jäähdytys
  ///
  /// In en, this message translates to:
  /// **'Thermostat heating cooling'**
  String get sdeadd78d47;

  /// fi: Termostaatti
  ///
  /// In en, this message translates to:
  /// **'Thermostat'**
  String get s48264cfe32;

  /// fi: Pitää lämmön halutussa: ohjaa releitä tai lämpöpumppua lämpömittarin mukaan. Voi säästää pörssisähköllä.
  ///
  /// In en, this message translates to:
  /// **'Keeps the temperature you want: controls relays or a heat pump from a thermometer. Can save with spot prices.'**
  String get s641a848754;

  /// fi: Sääennuste sää lämpötila sade tuuli
  ///
  /// In en, this message translates to:
  /// **'Weather forecast temperature rain wind'**
  String get s94493d01ca;

  /// fi: Sääennuste
  ///
  /// In en, this message translates to:
  /// **'Weather forecast'**
  String get s262f9527aa;

  /// fi: Sää nyt ja tunneittain: lämpötila, sade ja tuuli kotisi sijainnista. Ei vaadi laitetta.
  ///
  /// In en, this message translates to:
  /// **'Weather now and hourly: temperature, rain and wind at your home. No device needed.'**
  String get scb3570338f;

  /// fi: Etkö löydä merkkiäsi?
  ///
  /// In en, this message translates to:
  /// **'Can\'\'t find your brand?'**
  String get s2a9b6fedd9;

  /// fi: Husqvarna, Zigbee, Tuya, Netatmo, lämpöpumput… katso miten ne toimivat jo nyt.
  ///
  /// In en, this message translates to:
  /// **'Husqvarna, Zigbee, Tuya, heat pumps… see how to use them today.'**
  String get scfc7244d06;

  /// fi: Muu laite (oma asetus)
  ///
  /// In en, this message translates to:
  /// **'Other (manual setup)'**
  String get sf7b77783e5;

  /// fi: Muu laite (edistynyt)
  ///
  /// In en, this message translates to:
  /// **'Other device (advanced)'**
  String get sc168355ee6;

  /// fi: Kaikki yhteystyypit: HTTP, MQTT, Modbus, WebSocket, TCP, UDP.
  ///
  /// In en, this message translates to:
  /// **'All connection types.'**
  String get s3022f72ece;

  /// fi: Teknisille käyttäjille. Vaatii edistyneet asetukset.
  ///
  /// In en, this message translates to:
  /// **'For technical users.'**
  String get s2d1d488d6d;

  /// fi: Sisältää esimerkkiasetuksia
  ///
  /// In en, this message translates to:
  /// **'Contains example settings'**
  String get s6f1c11270c;

  /// fi: Laitteessa on {p0} relettä
  ///
  /// In en, this message translates to:
  /// **'The device has {p0} relays'**
  String s4f55f417b1(String p0);

  /// fi: Laitteessa on 1 rele
  ///
  /// In en, this message translates to:
  /// **'The device has 1 relay'**
  String get sab3ebba17a;

  /// fi: energiamittaus
  ///
  /// In en, this message translates to:
  /// **'energy metering'**
  String get sfa48c40832;

  /// fi: Ruudun nimi
  ///
  /// In en, this message translates to:
  /// **'Tile name'**
  String get sc8d1abbd21;

  /// fi: Osoite: {p0}
  ///
  /// In en, this message translates to:
  /// **'Address: {p0}'**
  String s1ea8fe913b(String p0);

  /// fi: Home Assistant käyttää itse allekirjoitettua varmennetta. Se hyväksyttiin, koska osoite on kotiverkossa.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant uses a self-signed certificate. It was accepted because the address is on the home network.'**
  String get s16dc13070c;

  /// fi: Home Assistantia ei löytynyt automaattisesti. Kirjoita osoite, jolla avaat sen selaimessa (esim. http://192.168.1.20:812
  ///
  /// In en, this message translates to:
  /// **'Home Assistant was not found automatically. Type the address you open it with (e.g. http://192.168.1.20:8123 or the Nabu Casa address).'**
  String get sd531eb2fc2;

  /// fi: Löydetyt Home Assistantit:
  ///
  /// In en, this message translates to:
  /// **'Found Home Assistants:'**
  String get s7def041e83;

  /// fi: Löytyi: {p0} – {p1}
  ///
  /// In en, this message translates to:
  /// **'Found: {p0} – {p1}'**
  String s2967a37e01(String p0, String p1);

  /// fi: Täytä ensin
  ///
  /// In en, this message translates to:
  /// **'Fill in first'**
  String get s43370d968c;

  /// fi: Laitteita ei löytynyt automaattisesti. Kirjoita osoite itse – sen löydät reitittimen laitelistasta tai laitteen omasta s
  ///
  /// In en, this message translates to:
  /// **'No devices found automatically. Type the address yourself – find it in your router or the device app.'**
  String get s8f4c0baf1a;

  /// fi: Löydetyt laitteet – valitse omasi:
  ///
  /// In en, this message translates to:
  /// **'Found devices – pick yours:'**
  String get s104238f11e;

  /// fi: Haku ei ole käytettävissä tässä verkossa.
  ///
  /// In en, this message translates to:
  /// **'Search is not available on this network.'**
  String get sd5f9dce947;

  /// fi: Opetetaanko kaukosäätimen napit?
  ///
  /// In en, this message translates to:
  /// **'Teach remote buttons?'**
  String get s26abc57d91;

  /// fi: Perusohjaus (virta, lämpö, tila) toimii jo. Voit lisäksi opettaa kaukosäätimen muita nappeja, esim. "Turbo" tai "Hiljain
  ///
  /// In en, this message translates to:
  /// **'Basic control works already. You can also teach other remote buttons, e.g. \"Turbo\".'**
  String get sc709f38633;

  /// fi: Ei nyt
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get s6cac83dd5e;

  /// fi: Opeta nyt
  ///
  /// In en, this message translates to:
  /// **'Teach now'**
  String get s97ea2eeb11;

  /// fi: Laite lisätty
  ///
  /// In en, this message translates to:
  /// **'Device added'**
  String get s09cfb7b2a1;

  /// fi: Laite ja {p0} ruutua lisätty
  ///
  /// In en, this message translates to:
  /// **'Device and {p0} tiles added'**
  String sda9574390f(String p0);

  /// fi: Valmiit asetukset ovat esimerkkejä. Tarkista ne laitteesi ohjeesta ennen kuin luotat arvoihin.
  ///
  /// In en, this message translates to:
  /// **'Preset settings are examples. Check them against your device manual before relying on them.'**
  String get sd51ee1ec8d;

  /// fi: IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan lähettää aina koko tilan (virta, t
  ///
  /// In en, this message translates to:
  /// **'IR is one-way: the heat pump does not confirm. Molaplan always sends the whole state and shows what it sent. Teach other remote buttons later: Connections → blaster → \"Teach a new command\".'**
  String get s2e99b59497;

  /// fi: Ohje ja automaattinen haku
  ///
  /// In en, this message translates to:
  /// **'Guide and automatic search'**
  String get s0dd21e026c;

  /// fi: Skannaa Modbus
  ///
  /// In en, this message translates to:
  /// **'Scan Modbus'**
  String get se3ef5a5658;

  /// fi: Tuo Home Assistantin modbus.yaml
  ///
  /// In en, this message translates to:
  /// **'Import a Home Assistant modbus.yaml'**
  String get s810014ca02;

  /// fi: Etsitään…
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get s695a011cc1;

  /// fi: Etsi verkosta
  ///
  /// In en, this message translates to:
  /// **'Search network'**
  String get s47d409fddd;

  /// fi: Tunnista releet
  ///
  /// In en, this message translates to:
  /// **'Detect relays'**
  String get sa62eebe6bd;

  /// fi: ⚠ Tässä koneessa ei ole Modbus TCP:tä – tarvitset RS485 → Modbus TCP -muuntimen.
  ///
  /// In en, this message translates to:
  /// **'⚠ No native Modbus TCP – an RS485 → TCP gateway is needed.'**
  String get s7196b72140;

  /// fi: Lähde
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get s2e8ba44677;

  /// fi: Testaa yhteys
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get sceb8e47d07;

  /// fi: Toimii!
  ///
  /// In en, this message translates to:
  /// **'Works!'**
  String get s02ce5f4a01;

  /// fi: Nämä ruudut luodaan
  ///
  /// In en, this message translates to:
  /// **'These tiles will be created'**
  String get sb9e9e55164;

  /// fi: Täytä tähdellä (*) merkityt kentät, niin näet ruudut.
  ///
  /// In en, this message translates to:
  /// **'Fill in the fields marked with * to see the tiles.'**
  String get s1cb2891ef2;

  /// fi: Ei valmiita ruutuja – voit lisätä ne myöhemmin kynä-painikkeesta.
  ///
  /// In en, this message translates to:
  /// **'No ready tiles – you can add them later with the pencil button.'**
  String get s504861ee78;

  /// fi: Näyttää arvon
  ///
  /// In en, this message translates to:
  /// **'Shows a value'**
  String get s1094266d4c;

  /// fi: Kytkin päälle/pois
  ///
  /// In en, this message translates to:
  /// **'On/off switch'**
  String get sf6ae3f3323;

  /// fi: Painike
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get s20dad69675;

  /// fi: Säädin
  ///
  /// In en, this message translates to:
  /// **'Slider'**
  String get s0e9f94df05;

  /// fi: Kamerakuva
  ///
  /// In en, this message translates to:
  /// **'Camera view'**
  String get s109b454866;

  /// fi: Edistyneet asetukset
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get s37153e0e80;

  /// fi: Muu laite liitetään teknisillä asetuksilla (HTTP, MQTT, Modbus…). Jos laitteesi merkki löytyy listasta, käytä sitä – se
  ///
  /// In en, this message translates to:
  /// **'Other devices use technical settings (HTTP, MQTT, Modbus…). If your brand is listed, use it instead.\n\nTurn on advanced settings? You can turn them off in Settings.'**
  String get s0ca55a9cae;

  /// fi: Ota käyttöön
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get s9630135746;

  /// fi: Mikä kamera sinulla on?
  ///
  /// In en, this message translates to:
  /// **'Which camera do you have?'**
  String get sbcdff8f72a;

  /// fi: Muu kamera (ONVIF)
  ///
  /// In en, this message translates to:
  /// **'Other camera (ONVIF)'**
  String get s67bf18fb6f;

  /// fi: Mikä lämpöpumppu sinulla on?
  ///
  /// In en, this message translates to:
  /// **'Which heat pump do you have?'**
  String get sdbbc24198f;

  /// fi: Tarkista asetukset – ei valmistajan virallista dokumenttia.
  ///
  /// In en, this message translates to:
  /// **'Verify – no official vendor document.'**
  String get sdfd0407af6;

  /// fi: Ei wifiä – IR-ohjain (mikä tahansa merkki)
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi – IR blaster (any brand)'**
  String get s5562a66892;

  /// fi: Tasmota- tai ESPHome-IR-lähetin (esim. Athom IR & RF) lähettää koko tilan kuten kaukosäädin. Voit myös opettaa omia kome
  ///
  /// In en, this message translates to:
  /// **'A Tasmota or ESPHome IR blaster (e.g. Athom IR & RF) sends the full state like the remote. You can also teach your own commands.'**
  String get sc6411a9010;

  /// fi: Huoltoliitäntä (ESPHome)
  ///
  /// In en, this message translates to:
  /// **'Service port (ESPHome)'**
  String get s6cce12c7e3;

  /// fi: ESP sisäyksikön liittimeen, kaksisuuntainen.
  ///
  /// In en, this message translates to:
  /// **'An ESP on the indoor unit connector, two-way.'**
  String get s0d3bc6d125;

  /// fi: Home Assistantin kautta
  ///
  /// In en, this message translates to:
  /// **'Via Home Assistant'**
  String get s8275426406;

  /// fi: Jos sinulla on jo Home Assistant.
  ///
  /// In en, this message translates to:
  /// **'If you already have Home Assistant.'**
  String get s5b10465c5b;

  /// fi: Muut merkit – miksi ei vielä
  ///
  /// In en, this message translates to:
  /// **'Other brands – why not yet'**
  String get s417228f48f;

  /// fi: Laitteita ohjataan kotiverkossa ilman pilveä. Ensimmäisellä kerralla tarvitaan laitteiden paikalliset avaimet, jotka hae
  ///
  /// In en, this message translates to:
  /// **'The devices are controlled on your home network without the cloud. The first time, their local keys are fetched with your own free Tuya developer account (about 10 minutes, only once).'**
  String get se50e28a0e4;

  /// fi: Hae avaimet omalla Tuya-tunnuksella (suositus)
  ///
  /// In en, this message translates to:
  /// **'Fetch the keys with my own Tuya account (recommended)'**
  String get sb35b23dbdd;

  /// fi: Kaikki sovelluksen wifi-laitteet kerralla.
  ///
  /// In en, this message translates to:
  /// **'All Wi-Fi devices of the app at once.'**
  String get sbc29869e30;

  /// fi: Minulla on jo paikallinen avain
  ///
  /// In en, this message translates to:
  /// **'I already have the local key'**
  String get s2f57241369;

  /// fi: Yksi laite: osoite, tunnus ja avain.
  ///
  /// In en, this message translates to:
  /// **'One device: address, ID and key.'**
  String get sf4a309c04a;

  /// fi: Tarkista lukemat – ei valmistajan virallista dokumenttia.
  ///
  /// In en, this message translates to:
  /// **'Verify the readings – no official vendor document.'**
  String get sd551537404;

  /// fi: Paikallinen – suositus
  ///
  /// In en, this message translates to:
  /// **'Local – recommended'**
  String get sa1a45de0f2;

  /// fi: Pilvi – valinnainen
  ///
  /// In en, this message translates to:
  /// **'Cloud – optional'**
  String get se8b35fb9e9;

  /// fi: Muut – miksi ei vielä
  ///
  /// In en, this message translates to:
  /// **'Others – why not yet'**
  String get s95216a7a5e;

  /// fi: Mikä invertteri sinulla on?
  ///
  /// In en, this message translates to:
  /// **'Which inverter do you have?'**
  String get sc52321f275;

  /// fi: Tuotanto, verkosta osto/myynti ja akun varaus ruutuihin ja automaatioihin. Paikallinen yhteys päivittyy sekunneissa eikä
  ///
  /// In en, this message translates to:
  /// **'Production, grid import/export and battery charge as tiles and for automations. A local connection updates in seconds and needs no cloud.'**
  String get s862002ac64;

  /// fi: Mikä laturi sinulla on?
  ///
  /// In en, this message translates to:
  /// **'Which charger do you have?'**
  String get sa5f3da9152;

  /// fi: Tila, lataus päälle/pois, teho ja virtaraja. Automaatiot: lataa aurinkosähkön ylijäämällä tai halvimpina tunteina.
  ///
  /// In en, this message translates to:
  /// **'Status, charging on/off, power and current limit. Automations: charge on solar surplus or in the cheapest hours.'**
  String get sdeb1f4332e;

  /// fi: Mikä televisio tai laite?
  ///
  /// In en, this message translates to:
  /// **'Which TV or device?'**
  String get se5084a149d;

  /// fi: Tila, virta, äänenvoimakkuus, mykistys, kanavat ja toisto ruutuihin ja automaatioihin – suoraan kotiverkossa, ilman pilv
  ///
  /// In en, this message translates to:
  /// **'Status, power, volume, mute, channels and playback as tiles and for automations – straight over the home network, no cloud and no Home Assistant. Android TV and Google TV: Chromecast (status and volume) or the remote (keys, channels, power).'**
  String get s512db00a17;

  /// fi: Sähkön hinta
  ///
  /// In en, this message translates to:
  /// **'Electricity price'**
  String get sca7e088857;

  /// fi: Poikkeuksellisen kallis sähkö
  ///
  /// In en, this message translates to:
  /// **'Exceptionally expensive electricity'**
  String get s83f816fbe3;

  /// fi: Anturin arvo
  ///
  /// In en, this message translates to:
  /// **'Sensor value'**
  String get sfc404aec8b;

  /// fi: Laitteen tila
  ///
  /// In en, this message translates to:
  /// **'Device state'**
  String get s58d2896c42;

  /// fi: Aika tai päivä
  ///
  /// In en, this message translates to:
  /// **'Time or date'**
  String get s7def336f41;

  /// fi: Saapuminen (esilämmitys)
  ///
  /// In en, this message translates to:
  /// **'Arrival (pre-heating)'**
  String get sf80835a318;

  /// fi: huomenna
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get s9a37dbb58a;

  /// fi: tänään
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get s1fe084d61b;

  /// fi: kallein
  ///
  /// In en, this message translates to:
  /// **'highest'**
  String get safd8f4dddf;

  /// fi: halvin
  ///
  /// In en, this message translates to:
  /// **'lowest'**
  String get s484731d968;

  /// fi: keskihinta
  ///
  /// In en, this message translates to:
  /// **'average'**
  String get s77f9bfc303;

  /// fi: (valitse laite)
  ///
  /// In en, this message translates to:
  /// **'(pick a device)'**
  String get sc017c085e4;

  /// fi: {p0}: keskihinta ≥ {p1} c tai kallein ≥ {p2} c tai {p3}× edellinen päivä
  ///
  /// In en, this message translates to:
  /// **'{p0}: average ≥ {p1} c or peak ≥ {p2} c or {p3}× the day before'**
  String s3f09da81b6(String p0, String p1, String p2, String p3);

  /// fi: {p0} {p1} {p2} {p3} °C
  ///
  /// In en, this message translates to:
  /// **'{p0}  {p2} {p3} °C'**
  String s900c886f50(String p0, String p1, String p2, String p3);

  /// fi: {p0} ei vastaa {p1} min
  ///
  /// In en, this message translates to:
  /// **'{p0} not answering {p1} min'**
  String s81c88dabf7(String p0, String p1);

  /// fi: {p0} menee pois päältä
  ///
  /// In en, this message translates to:
  /// **'{p0} turns off'**
  String s5414e9e5fd(String p0);

  /// fi: {p0} menee päälle
  ///
  /// In en, this message translates to:
  /// **'{p0} turns on'**
  String s09a43fc401(String p0);

  /// fi: saapuminen {p0} · muistutus {p1} h ennen · {p2} °C
  ///
  /// In en, this message translates to:
  /// **'arrival {p0} · reminder {p1} h before · {p2} °C'**
  String s56ef33ee50(String p0, String p1, String p2);

  /// fi: Oma ilmoitus
  ///
  /// In en, this message translates to:
  /// **'My notification'**
  String get sdeb38e3907;

  /// fi: Oma ilmoitus
  ///
  /// In en, this message translates to:
  /// **'My own notification'**
  String get s5e9a552fe6;

  /// fi: Mikä tahansa ehto ja oma viesti.
  ///
  /// In en, this message translates to:
  /// **'Any condition and your own message.'**
  String get se2e6db5acc;

  /// fi: Toimii tällä kotisillalla, myös kun sovellus on kiinni.
  ///
  /// In en, this message translates to:
  /// **'Runs on this home bridge, also with the app closed.'**
  String get sc6bec5e6cb;

  /// fi: Kotisilta on vanhempi kuin 0.11.0: muistutukset toimivat nyt vain, kun tämä sovellus on auki. Päivitä silta (Etäkäyttö →
  ///
  /// In en, this message translates to:
  /// **'The home bridge is older than 0.11.0: reminders work only while this app is open. Update the bridge (Remote access → My home bridges).'**
  String get se17e32a5c9;

  /// fi: Toimii kotisillalla, myös kun sovellus on kiinni.
  ///
  /// In en, this message translates to:
  /// **'Runs on the home bridge, also with the app closed.'**
  String get s5fd9e146bf;

  /// fi: Ei kotisiltaa: muistutukset toimivat, kun sovellus on auki. Kotisilta pitää ne käynnissä aina.
  ///
  /// In en, this message translates to:
  /// **'No home bridge: reminders work while the app is open. A home bridge keeps them running all the time.'**
  String get s563ba24005;

  /// fi: Lisää muistutus
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get sf378d832a1;

  /// fi: Saat ilmoituksen, kun jokin ehto täyttyy: sähkön hinta (myös huominen), sääennuste, anturin arvo, laitteen tila tai aika
  ///
  /// In en, this message translates to:
  /// **'Get a notification when a condition is met: electricity price (tomorrow too), weather forecast, a sensor value, a device state or a time.'**
  String get s034093c675;

  /// fi: Valitse valmis malli
  ///
  /// In en, this message translates to:
  /// **'Pick a ready template'**
  String get s49a26ce1f2;

  /// fi: Viimeisimmät ilmoitukset
  ///
  /// In en, this message translates to:
  /// **'Latest notifications'**
  String get sc0597b9029;

  /// fi: Ei vielä ilmoituksia.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get sac8af0108d;

  /// fi: Puhelinilmoitukset (ntfy), hiljaiset tunnit, mykistys
  ///
  /// In en, this message translates to:
  /// **'Phone notifications (ntfy), quiet hours, mute'**
  String get sbb2b4bdfc8;

  /// fi: Valitse laite.
  ///
  /// In en, this message translates to:
  /// **'Pick a device.'**
  String get s13d942a5a9;

  /// fi: Kokeiluilmoitus lähetetty.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent.'**
  String get sac782d209c;

  /// fi: Tänään
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get s140acccb81;

  /// fi: Huomenna
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get s0de6e75a52;

  /// fi: Keskihinta
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get sbbf8b7a598;

  /// fi: Kallein
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get s43b4c610f8;

  /// fi: Halvin
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get s9dd0f70be6;

  /// fi: Raja
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get scd65d31d4c;

  /// fi: Keskihinta vähintään
  ///
  /// In en, this message translates to:
  /// **'Average at least'**
  String get s543838d91f;

  /// fi: tai kallein vähintään
  ///
  /// In en, this message translates to:
  /// **'or peak at least'**
  String get s087a7e1b24;

  /// fi: tai × edellisen päivän keskihinta
  ///
  /// In en, this message translates to:
  /// **'or × the previous day\'\'s average'**
  String get s8463e08e0b;

  /// fi: Alin
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get sd8332d82ec;

  /// fi: Ylin
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get s109b35551a;

  /// fi: Keski
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get sf2c65c5aeb;

  /// fi: Aseta kodin sijainti (Energia → Asetukset), jotta sääennuste on käytössä.
  ///
  /// In en, this message translates to:
  /// **'Set the home location (Energy → Settings) for the forecast.'**
  String get s68b942c864;

  /// fi: Arvo
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get s38ac222392;

  /// fi: Ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get sa8e43f2b0e;

  /// fi: Kun ei vastaa
  ///
  /// In en, this message translates to:
  /// **'When offline for'**
  String get s65f512f499;

  /// fi: Kello
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sa224d2f5f9;

  /// fi: Joka päivä (valitse päivä kerran)
  ///
  /// In en, this message translates to:
  /// **'Every day (pick a date for once)'**
  String get s96b7e2c62c;

  /// fi: Saapuminen
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get s593004184e;

  /// fi: Muistuta ennen
  ///
  /// In en, this message translates to:
  /// **'Remind before'**
  String get sa9faf47356;

  /// fi: Tavoitelämpö
  ///
  /// In en, this message translates to:
  /// **'Target temperature'**
  String get sf527ec4275;

  /// fi: Uusi muistutus
  ///
  /// In en, this message translates to:
  /// **'New reminder'**
  String get s009a96409a;

  /// fi: Muistutus
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get sb346b2b647;

  /// fi: Nimi
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sb1924acbe7;

  /// fi: Kun
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get s5506524eac;

  /// fi: Viesti
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get s86c5d7fa73;

  /// fi: Voit käyttää: {avg} {max} {min} {hour} {temp} {value} {tile} {target} {arrival} {date}
  ///
  /// In en, this message translates to:
  /// **'\'You can use: {avg} {max} {min} {hour} {temp} {value} {tile} {target} {arrival} {date}\''**
  String get s8dda7ee75e;

  /// fi: Myös puhelimeen (ntfy)
  ///
  /// In en, this message translates to:
  /// **'Also to phones (ntfy)'**
  String get sec1bdb2451;

  /// fi: Näkyy aina myös sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'Always shown in the app too.'**
  String get se2de73b535;

  /// fi: Tärkeys
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sd84d87d156;

  /// fi: 5 (myös hiljaisina tunteina)
  ///
  /// In en, this message translates to:
  /// **'5 (also in quiet hours)'**
  String get s7a09198c53;

  /// fi: Ei uudelleen ennen
  ///
  /// In en, this message translates to:
  /// **'Not again within'**
  String get se8e58d6206;

  /// fi: Ei ennen kello
  ///
  /// In en, this message translates to:
  /// **'Not before'**
  String get s7d773a4dc9;

  /// fi: Kokeile
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get sb86dc1b7bf;

  /// fi: Kieli
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get s2ad22696ca;

  /// fi: Laitteen kieli
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get s7efc5653d2;

  /// fi: Salasana ei täsmää. Kirjoita tilin salasana (sama jolla kirjauduit ensimmäisen kerran).
  ///
  /// In en, this message translates to:
  /// **'The password does not match. Type your account password.'**
  String get sf1b5d0ffa6;

  /// fi: Yhteys ei onnistunut: {p0}
  ///
  /// In en, this message translates to:
  /// **'The connection did not work: {p0}'**
  String sd0219ce512(String p0);

  /// fi: Tilipalveluun ei saatu yhteyttä. Tarkista wifi tai mobiilidata ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the account service. Check Wi-Fi or mobile data and try again.'**
  String get sfad8715d97;

  /// fi: Netti toimii, mutta suojattu yhteys tilipalveluun epäonnistui. Tarkista laitteen päivämäärä ja kellonaika.
  ///
  /// In en, this message translates to:
  /// **'The internet works, but the secure connection to the account service failed. Check the device date and time.'**
  String get sa052abd601;

  /// fi: Sähköposti tai salasana on väärin. Tarkista kirjoitusasu, tai paina "Unohdin salasanan".
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Check them, or tap \"Forgot password\".'**
  String get s9ba7e7a8e6;

  /// fi: Sähköpostia ei ole vielä vahvistettu. Katso sähköpostistasi koodi.
  ///
  /// In en, this message translates to:
  /// **'The email is not confirmed yet. Look for the code in your email.'**
  String get se899b438b5;

  /// fi: Tällä sähköpostilla on jo tili. Paina "Minulla on jo tili" ja kirjaudu.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Sign in instead.'**
  String get s3fb651ebf3;

  /// fi: Salasanan pitää olla vähintään 8 merkkiä.
  ///
  /// In en, this message translates to:
  /// **'The password must be at least 8 characters.'**
  String get s1eddf46047;

  /// fi: Sähköpostiosoite ei näytä oikealta (esim. nimi@esimerkki.fi).
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email address.'**
  String get sca19a10c02;

  /// fi: Koodi on väärä tai vanhentunut. Tarkista koodi tai pyydä uusi.
  ///
  /// In en, this message translates to:
  /// **'The code is wrong or expired. Check it or ask for a new one.'**
  String get s736463f0d2;

  /// fi: Liian monta yritystä. Odota hetki (noin minuutti) ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get s4800010fa4;

  /// fi: Kirjautuminen on vanhentunut. Kirjaudu uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in expired. Please sign in again.'**
  String get sf1a6e42ab0;

  /// fi: Toinen laite muutti asetuksia samaan aikaan. Yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Another device changed the setup at the same time. Try again.'**
  String get sf597621fdd;

  /// fi: Tilipalvelu ei vastannut oikein. Yritä hetken päästä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The account service did not answer properly. Try again shortly.'**
  String get se16eef219e;

  /// fi: Tililläsi on jo kotinäkymä
  ///
  /// In en, this message translates to:
  /// **'Your account already has a setup'**
  String get s2ab0ff38c1;

  /// fi: Tallennetaanko tämän laitteen kotinäkymä tiliisi?
  ///
  /// In en, this message translates to:
  /// **'Save this device\'\'s setup to your account?'**
  String get s3ce644ca86;

  /// fi: Myös tällä laitteella on omia laitteita ja ruutuja. Valitse, kummat pidetään, tai yhdistä molemmat. Tilin asetuksia ei k
  ///
  /// In en, this message translates to:
  /// **'This device has its own devices and tiles too. Choose which to keep, or combine both. The account setup is not silently overwritten.'**
  String get sa80b1060fe;

  /// fi: Silloin samat kodit, laitteet ja ruudut näkyvät kaikilla laitteillasi, joilla kirjaudut tälle tilille.
  ///
  /// In en, this message translates to:
  /// **'Then the same homes, devices and tiles appear on every device signed in to this account.'**
  String get sd8a380a86d;

  /// fi: Yhdistä molemmat (suositus)
  ///
  /// In en, this message translates to:
  /// **'Combine both (recommended)'**
  String get sf498dceefb;

  /// fi: Käytä tilin asetuksia
  ///
  /// In en, this message translates to:
  /// **'Use the account\'\'s setup'**
  String get sb7a13da58b;

  /// fi: Käytä tämän laitteen asetuksia (korvaa tilin)
  ///
  /// In en, this message translates to:
  /// **'Use this device\'\'s setup (replaces the account\'\'s)'**
  String get s8c0329f792;

  /// fi: Tallenna tiliin
  ///
  /// In en, this message translates to:
  /// **'Save to account'**
  String get s9542718c6f;

  /// fi: Peru ja kirjaudu ulos
  ///
  /// In en, this message translates to:
  /// **'Cancel and sign out'**
  String get sec25d10ff5;

  /// fi: Kirjoita sähköpostiosoitteesi (esim. nimi@esimerkki.fi).
  ///
  /// In en, this message translates to:
  /// **'Type your email address.'**
  String get sa711c4833e;

  /// fi: Salasanan pitää olla vähintään 8 merkkiä.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get s933dc9caef;

  /// fi: Molaplan-tili
  ///
  /// In en, this message translates to:
  /// **'Molaplan account'**
  String get sb3cec3f199;

  /// fi: Sähköposti
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get sb24f053a48;

  /// fi: Salasana
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get s976a9f2980;

  /// fi: Näytä salasana
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get sc0f9642fb2;

  /// fi: Koodi sähköpostista
  ///
  /// In en, this message translates to:
  /// **'Code from the email'**
  String get s4d212254bc;

  /// fi: Koodi tulee muutamassa minuutissa. Katso myös roskapostikansio.
  ///
  /// In en, this message translates to:
  /// **'The code arrives in a few minutes. Check the spam folder too.'**
  String get s3b86a618be;

  /// fi: Tilin avulla kotisi, laitteesi ja ruudut ovat samat kaikilla laitteillasi – PC:llä, tabletilla ja puhelimella. Kotiyhtey
  ///
  /// In en, this message translates to:
  /// **'With an account your homes, devices and tiles are the same on all your devices – PC, tablet and phone. The home connection moves to a new device without a QR code.\n\nThe account is optional: without one Molaplan works as before and the setup stays on this device.'**
  String get sb35c5ba0fc;

  /// fi: Minulla ei ole tiliä – luo uusi
  ///
  /// In en, this message translates to:
  /// **'I don\'\'t have an account – create one'**
  String get sec4d25a98e;

  /// fi: Kirjaudu sähköpostiin tulevalla koodilla
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code sent by email'**
  String get s860d0269e0;

  /// fi: Unohdin salasanan
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get s755639049e;

  /// fi: Luo Molaplan-tili
  ///
  /// In en, this message translates to:
  /// **'Create a Molaplan account'**
  String get s4a1671a2cc;

  /// fi: Keksi salasana (vähintään 8 merkkiä)
  ///
  /// In en, this message translates to:
  /// **'Choose a password (8+ characters)'**
  String get s75c960f1e5;

  /// fi: Salasana myös suojaa laitteidesi salasanat ja pilviavaimet: ne salataan tällä laitteella ennen tallennusta. Pidä salasan
  ///
  /// In en, this message translates to:
  /// **'The password also protects your device passwords and cloud keys: they are encrypted on this device before saving. Keep it safe.'**
  String get sea446a95e5;

  /// fi: Luo tili
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get s4508b6c2e0;

  /// fi: Lähetimme koodin osoitteeseen {p0}. Kirjoita se alle.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {p0}. Type it below.'**
  String s0ca1377846(String p0);

  /// fi: Minulla on jo tili – kirjaudu
  ///
  /// In en, this message translates to:
  /// **'I already have an account – sign in'**
  String get s07e981c940;

  /// fi: Vahvista sähköposti
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get s2e793f899b;

  /// fi: Vahvista
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get s87b6699e12;

  /// fi: Uusi koodi lähetetty.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent.'**
  String get s824a7408ab;

  /// fi: Koodi ei tullut – lähetä uusi
  ///
  /// In en, this message translates to:
  /// **'No code – send a new one'**
  String get s317ad443fb;

  /// fi: Luo tili tai kirjaudu
  ///
  /// In en, this message translates to:
  /// **'Create an account or sign in'**
  String get s7d43ee2d5a;

  /// fi: Kirjaudu koodilla
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get s22c960ff4f;

  /// fi: Kirjoita sähköpostiosoitteesi, niin lähetämme koodin. Salasanaa ei tarvita. Jos tiliä ei vielä ole, se luodaan, ja tämän
  ///
  /// In en, this message translates to:
  /// **'Type your email and we send you a code. No password needed. If you have no account yet, one is created and this device\'\'s setup moves into it.'**
  String get scb167ce8b1;

  /// fi: Lähetämme sähköpostiisi koodin. Salasanaa ei tarvita kirjautumiseen.
  ///
  /// In en, this message translates to:
  /// **'We email you a code. No password needed to sign in.'**
  String get s7d29d1dfbd;

  /// fi: Lähetä koodi
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sc350da6f19;

  /// fi: Koodi lähetetty osoitteeseen {p0}.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {p0}.'**
  String s23cda12342(String p0);

  /// fi: Kirjaudu
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get s14d85b9e32;

  /// fi: Lähetä uusi koodi
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get saa1e3d1f13;

  /// fi: Kirjaudu salasanalla
  ///
  /// In en, this message translates to:
  /// **'Sign in with a password'**
  String get se1be2ec8e5;

  /// fi: Vaihda salasana
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get s8c48f847f6;

  /// fi: Lähetämme sähköpostiisi koodin. Sen jälkeen voit keksiä uuden salasanan.
  ///
  /// In en, this message translates to:
  /// **'We email you a code, then you choose a new password.'**
  String get safd591d9b6;

  /// fi: Uusi salasana (vähintään 8 merkkiä)
  ///
  /// In en, this message translates to:
  /// **'New password (8+ characters)'**
  String get s6807ac704e;

  /// fi: Vaihda salasana ja kirjaudu
  ///
  /// In en, this message translates to:
  /// **'Change password and sign in'**
  String get sa9b5a0b2df;

  /// fi: Synkronoidaan…
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get se10ce6962a;

  /// fi: Ajan tasalla – samat asetukset kaikilla laitteillasi
  ///
  /// In en, this message translates to:
  /// **'Up to date on all your devices'**
  String get s94d5ea139c;

  /// fi: Ei nettiä – muutokset siirtyvät, kun yhteys palaa
  ///
  /// In en, this message translates to:
  /// **'Offline – changes sync when back online'**
  String get sc6f1932436;

  /// fi: Synkronointi epäonnistui – yritetään uudelleen
  ///
  /// In en, this message translates to:
  /// **'Sync failed – will retry'**
  String get s16ab688a9b;

  /// fi: Ei synkronoitu vielä
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get s97d4aa9c1a;

  /// fi: Kirjautunut
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get s40ea946050;

  /// fi: Synkronoi nyt
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get s456721b668;

  /// fi: Laitteiden salasanat ja pilviavaimet ovat tilillä lukittuina. Kirjoita tilin salasana avataksesi ne tällä laitteella.
  ///
  /// In en, this message translates to:
  /// **'Device passwords and cloud keys are locked. Type your account password to open them on this device.'**
  String get sa9df24980f;

  /// fi: Tilin salasana
  ///
  /// In en, this message translates to:
  /// **'Account password'**
  String get sd1723cc065;

  /// fi: Avaa salasanat
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get s9e9a059c2f;

  /// fi: En muista salasanaa – aloita salasanat alusta
  ///
  /// In en, this message translates to:
  /// **'I forgot it – start the passwords over'**
  String get s8b2b8fdc77;

  /// fi: Mitä tilille tallennetaan: kodit, laitteet, ruudut ja niiden järjestys sekä kotiyhteys. Laitteiden salasanat, pilviavaim
  ///
  /// In en, this message translates to:
  /// **'Saved to the account: homes, devices, tiles and their order, and the home connection. Device passwords, cloud keys and home connection keys are encrypted on this device with your account password before upload – the server cannot read them.'**
  String get s5ec8009dfd;

  /// fi: Vaihda salasana
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get s2ea6f9de12;

  /// fi: Kirjaudu ulos?
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get s7ebd89c416;

  /// fi: Tämä selain unohtaa kodit, ruudut ja kotisillan yhteyden. Tiedot säilyvät tililläsi.
  ///
  /// In en, this message translates to:
  /// **'This browser forgets the homes, tiles and home bridge link. Your data stays in your account.'**
  String get sab30063821;

  /// fi: Kodit ja ruudut jäävät tälle laitteelle, mutta muutokset eivät enää siirry muille laitteillesi.
  ///
  /// In en, this message translates to:
  /// **'Homes and tiles stay on this device, but changes no longer reach your other devices.'**
  String get s6c6165d662;

  /// fi: Kirjaudu ulos
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get s643325053b;

  /// fi: Tilin poistaminen
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get sfd6f965e64;

  /// fi: Poistaa tilin ja kaikki palvelimelle tallennetut tiedot pysyvästi. Tämän laitteen kotinäkymä jää laitteelle.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes the account and everything stored on the server. This device keeps its own setup.'**
  String get s37bf90cffe;

  /// fi: Poista tili
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get sc523d0f28e;

  /// fi: Peru
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get s84fda3e17f;

  /// fi: Keksi uusi salasana tilillesi.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password.'**
  String get s02c3403918;

  /// fi: Salasana vaihdettu.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get s04ab058029;

  /// fi: Aloita salasanat alusta
  ///
  /// In en, this message translates to:
  /// **'Start passwords over'**
  String get s7c23534562;

  /// fi: Tilille tallennetut laitteiden salasanat ja pilviavaimet katoavat, ja ne pitää kirjoittaa uudelleen. Kodit ja ruudut säi
  ///
  /// In en, this message translates to:
  /// **'Saved device passwords and cloud keys are lost and must be typed again. Homes and tiles stay. Your sign-in password changes to this new one.'**
  String get s5ea3703a0a;

  /// fi: Poistetaanko tili pysyvästi?
  ///
  /// In en, this message translates to:
  /// **'Delete the account permanently?'**
  String get s321912ef77;

  /// fi: Tili {p0} ja kaikki palvelimelle tallennetut kodit, laitteet, ruudut ja salatut salasanat poistetaan. Tätä ei voi perua.
  ///
  /// In en, this message translates to:
  /// **'The account {p0} and everything stored on the server is deleted. This cannot be undone.\n\nThis device keeps working without an account.'**
  String s3b0ea9bbc7(String p0);

  /// fi: Tili poistettu. Molaplan toimii nyt ilman tiliä.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get s139d2075b8;

  /// fi: Koko leveys
  ///
  /// In en, this message translates to:
  /// **'Full width'**
  String get s2a28790ea2;

  /// fi: Tämä Shelly on energiamittari – vaihdetaanko kytkin {p0} mittausruutuun?
  ///
  /// In en, this message translates to:
  /// **'This Shelly is an energy meter – replace the switch with {p0} metering tiles?'**
  String s3e5741712a(String p0);

  /// fi: Laitteessa on {p0} relettä – lisää loput?
  ///
  /// In en, this message translates to:
  /// **'The device has {p0} relays – add the rest?'**
  String sfe2074ae81(String p0);

  /// fi: Lisää {p0}
  ///
  /// In en, this message translates to:
  /// **'Add {p0}'**
  String sf1319d04d0(String p0);

  /// fi: Korjaa
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get s95f80e9bdf;

  /// fi: Vain kotiverkossa
  ///
  /// In en, this message translates to:
  /// **'Home network only'**
  String get s12c2f8e6e4;

  /// fi: klo {p0}
  ///
  /// In en, this message translates to:
  /// **'at {p0}'**
  String s5f7c464e6d(String p0);

  /// fi: {p0} toimii vain kotiverkossa. Ruutu palaa normaaliksi itsestään, kun olet taas kotona.
  ///
  /// In en, this message translates to:
  /// **'{p0} only works on the home network. The tile returns to normal by itself when you are home again.'**
  String s21b64ae0a7(String p0);

  /// fi: Viimeisin tila
  ///
  /// In en, this message translates to:
  /// **'Last state'**
  String get s6b1a8249de;

  /// fi: Tee etäkäyttöiseksi ›
  ///
  /// In en, this message translates to:
  /// **'Make it work remotely ›'**
  String get s56650a18d5;

  /// fi: Komentoa ei ole määritetty
  ///
  /// In en, this message translates to:
  /// **'No command configured'**
  String get sa0d8c62e5a;

  /// fi: Suoritetaanko komento?
  ///
  /// In en, this message translates to:
  /// **'Run this command?'**
  String get s1e5d696a26;

  /// fi: vaihda PIN-koodi
  ///
  /// In en, this message translates to:
  /// **'change PIN'**
  String get sa5ee6618a3;

  /// fi: syötä PIN-koodi
  ///
  /// In en, this message translates to:
  /// **'enter PIN'**
  String get s66f8ce67ed;

  /// fi: Laite tarvitsee PIN-koodin jokaiseen komentoon ja tilakyselyyn. Syötä se kerran tässä.
  ///
  /// In en, this message translates to:
  /// **'The device needs its PIN for every command and status request. Enter it once here.'**
  String get sb7b0c97cfa;

  /// fi: PIN
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get s1df6e2eaa7;

  /// fi: Selaimessa PIN-koodia ei tallenneta. Se kysytään uudelleen, kun avaat sivun seuraavan kerran.
  ///
  /// In en, this message translates to:
  /// **'The browser never stores the PIN. It is asked again the next time you open the page.'**
  String get sb52d5c0b5b;

  /// fi: Muista tällä laitteella
  ///
  /// In en, this message translates to:
  /// **'Remember on this device'**
  String get secab66c046;

  /// fi: Tallennetaan salattuna vain tähän laitteeseen – ei tilille eikä muille laitteille. Pois päältä = kysytään taas, kun sove
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on this device only – not in the account or on other devices. Off = asked again when the app restarts.'**
  String get s2a15ea2eab;

  /// fi: PIN-koodi
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get sdfc012fb4e;

  /// fi: Tallennetaan suojattuna vain tähän laitteeseen. Oletuksena PIN-koodia ei tallenneta.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on this device only. By default the PIN is not stored.'**
  String get s10bf4eab8e;

  /// fi: Lähetä
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get s912ea5d2ec;

  /// fi: Komentoja ei ole määritetty
  ///
  /// In en, this message translates to:
  /// **'No commands configured'**
  String get s856418521a;

  /// fi: Ajettu klo {p0}
  ///
  /// In en, this message translates to:
  /// **'Ran at {p0}'**
  String sb0ba67e677(String p0);

  /// fi: {p0}: lähetetty
  ///
  /// In en, this message translates to:
  /// **'{p0}: sent'**
  String sdfa66ee201(String p0);

  /// fi: Lähetetty – odotetaan vastausta…
  ///
  /// In en, this message translates to:
  /// **'Sent – waiting for the reply…'**
  String get s12fc3810a5;

  /// fi: Vastaus klo
  ///
  /// In en, this message translates to:
  /// **'Reply at'**
  String get sd1c7d49360;

  /// fi: Hintaohjaus käytössä
  ///
  /// In en, this message translates to:
  /// **'Price control on'**
  String get s29fae6a0e8;

  /// fi: Päivitetty
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get sbfe79d1f5f;

  /// fi: Pikakomento / jaa
  ///
  /// In en, this message translates to:
  /// **'Shortcut / share'**
  String get s71f145905e;

  /// fi: Lisää loki / trendi
  ///
  /// In en, this message translates to:
  /// **'Add log / trend'**
  String get sff8f7a1947;

  /// fi: Loki / trendi
  ///
  /// In en, this message translates to:
  /// **'Log / trend'**
  String get se893c16dba;

  /// fi: Lisää aloitusnäytölle
  ///
  /// In en, this message translates to:
  /// **'Add to home screen'**
  String get s46d0983ce8;

  /// fi: Nimeä uudelleen
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get s59d55f8882;

  /// fi: Vaihda PIN
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get s84ada1ae69;

  /// fi: Tallennettu PIN poistettu
  ///
  /// In en, this message translates to:
  /// **'Saved PIN removed'**
  String get s25580038cb;

  /// fi: Unohda tallennettu PIN
  ///
  /// In en, this message translates to:
  /// **'Forget saved PIN'**
  String get sf50c488b24;

  /// fi: Hintaohjaus
  ///
  /// In en, this message translates to:
  /// **'Price control'**
  String get safe0429a90;

  /// fi: Opettele kaukosäätimen nappi
  ///
  /// In en, this message translates to:
  /// **'Learn a remote button'**
  String get sf3d644dd4c;

  /// fi: Päivitä
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sfb1a18d11f;

  /// fi: Syötä PIN
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get sbb9e9b1229;

  /// fi: Viimeksi
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get se38a9bb2ed;

  /// fi: Lähennä
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get s8e3624e844;

  /// fi: Loitonna
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get s0071c4430f;

  /// fi: Valitse rekisterilista (CSV)
  ///
  /// In en, this message translates to:
  /// **'Choose the register list (CSV)'**
  String get sf1ed8904bb;

  /// fi: Tiedostoa ei tunnistettu NIBEn rekisterilistaksi.
  ///
  /// In en, this message translates to:
  /// **'Not recognised as a NIBE register list.'**
  String get s5bf50963d1;

  /// fi: Listassa ei ollut rekistereitä.
  ///
  /// In en, this message translates to:
  /// **'The list had no registers.'**
  String get s0cba536d9c;

  /// fi: {p0} rekisteriä tuotu, {p1} tunnistettu (ulkolämpö, menovesi, käyttövesi, käyrän siirto…).
  ///
  /// In en, this message translates to:
  /// **'{p0} registers imported, {p1} recognised (outdoor, supply, hot water, curve offset…).'**
  String s80d7fd2d3c(String p0, String p1);

  /// fi: Tiedot vain tässä selaimessa.
  ///
  /// In en, this message translates to:
  /// **'Data is only in this browser. '**
  String get s429f9e257a;

  /// fi: Ei tiliä – asetukset vain tällä laitteella.
  ///
  /// In en, this message translates to:
  /// **'No account – settings only on this device. '**
  String get sda9203de80;

  /// fi: Kirjaudu, niin ne synkronoituvat ›
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync ›'**
  String get sfec58c0c1b;

  /// fi: Luo tili ›
  ///
  /// In en, this message translates to:
  /// **'Create account ›'**
  String get s8b3e63da21;

  /// fi: Laite lisätty! 🎉
  ///
  /// In en, this message translates to:
  /// **'Device added! 🎉'**
  String get s887c293cad;

  /// fi: Luo tili, niin asetukset säilyvät ja siirtyvät muille laitteille. Se käy sähköpostikoodilla, salasanaa ei tarvita.
  ///
  /// In en, this message translates to:
  /// **'Create an account so your settings are kept and move to your other devices. It only takes an email code, no password needed.'**
  String get s84a087a679;

  /// fi: Tervetuloa Molaplaniin
  ///
  /// In en, this message translates to:
  /// **'Welcome to Molaplan'**
  String get s907220900d;

  /// fi: Asetukset kaikilla laitteillasi
  ///
  /// In en, this message translates to:
  /// **'Your setup on all your devices'**
  String get s845ec6276f;

  /// fi: Mitään ei katoa, vaikka puhelin vaihtuu
  ///
  /// In en, this message translates to:
  /// **'Nothing is lost when you change phones'**
  String get s9dfa93453b;

  /// fi: Laitteiden salasanat salataan
  ///
  /// In en, this message translates to:
  /// **'Device passwords are encrypted'**
  String get s6aa51b28a5;

  /// fi: Luo tili / Kirjaudu
  ///
  /// In en, this message translates to:
  /// **'Create account / Sign in'**
  String get sc6f02b69d3;

  /// fi: Sähköpostikoodilla – ei salasanaa.
  ///
  /// In en, this message translates to:
  /// **'With an email code – no password.'**
  String get sc777bde66f;

  /// fi: Jatka ilman tiliä
  ///
  /// In en, this message translates to:
  /// **'Continue without an account'**
  String get se2e5ff2c8a;

  /// fi: Vaatii tilin.
  ///
  /// In en, this message translates to:
  /// **'Requires an account.'**
  String get s82714aa826;

  /// fi: Kirjaudu tai luo tili
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get s9bb545e9b3;

  /// fi: Anna napille nimi, esim. "Turbo".
  ///
  /// In en, this message translates to:
  /// **'Give the button a name.'**
  String get sfb4df77773;

  /// fi: Tallenna ESPHome-koodi Pronto-muodossa: lisää remote_receiver-kohtaan dump: pronto.
  ///
  /// In en, this message translates to:
  /// **'Use Pronto: add dump: pronto to remote_receiver.'**
  String get s986eb41068;

  /// fi: Nappi "{p0}" lisättiin kotinäkymään.
  ///
  /// In en, this message translates to:
  /// **'Button \"{p0}\" added.'**
  String s0d353281af(String p0);

  /// fi: Opeta uusi komento
  ///
  /// In en, this message translates to:
  /// **'Teach a new command'**
  String get sd2a872d1ba;

  /// fi: Tallenna kaukosäätimen nappeja Molaplaniin, esim. "Turbo" tai "Hiljainen". Tarvitset IR-lähettimen, jossa on myös vastaa
  ///
  /// In en, this message translates to:
  /// **'Save remote buttons to Molaplan, e.g. \"Turbo\". The blaster needs an IR receiver.'**
  String get s608a56ad4b;

  /// fi: IR-kaukosäädin
  ///
  /// In en, this message translates to:
  /// **'IR remote'**
  String get sa1aed8855e;

  /// fi: RF433-kaukosäädin
  ///
  /// In en, this message translates to:
  /// **'RF433 remote'**
  String get sded7fb8520;

  /// fi: RF433 = radiokaukosäätimet (esim. pistorasiat, markiisit, autotallin ovet, kattotuulettimet). IR = infrapuna (lämpöpumpu
  ///
  /// In en, this message translates to:
  /// **'RF433 = radio remotes (sockets, awnings, garage doors, fans). IR = infrared (heat pumps, TVs).'**
  String get sc8e312a953;

  /// fi: Paina "Aloita kuuntelu".
  ///
  /// In en, this message translates to:
  /// **'Tap \"Start listening\".'**
  String get s63c57060b6;

  /// fi: Osoita kaukosäätimellä lähetintä alle metrin päästä ja paina haluamaasi nappia kerran.
  ///
  /// In en, this message translates to:
  /// **'Point the remote at the blaster (under 1 m) and press the button once.'**
  String get s439f6f3869;

  /// fi: Anna napille nimi ja paina "Tallenna napiksi".
  ///
  /// In en, this message translates to:
  /// **'Name it and tap \"Save as button\".'**
  String get sd8667596c3;

  /// fi: IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan näyttää vain, mitä se lähetti. Ope
  ///
  /// In en, this message translates to:
  /// **'IR is one-way: the heat pump does not confirm. Molaplan only shows what it sent. Learning works on the home network.'**
  String get sd5f1a45865;

  /// fi: Kuunnellaan… paina kaukosäätimen nappia
  ///
  /// In en, this message translates to:
  /// **'Listening… press the remote button'**
  String get s628dc92a8d;

  /// fi: Aloita kuuntelu
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get s1313eb829d;

  /// fi: Koodi vastaanotettu
  ///
  /// In en, this message translates to:
  /// **'Code received'**
  String get s619fdf8b5c;

  /// fi: Napin nimi
  ///
  /// In en, this message translates to:
  /// **'Button name'**
  String get s6264a40ec6;

  /// fi: Näkyy ruudun otsikkona.
  ///
  /// In en, this message translates to:
  /// **'Shown as the tile title.'**
  String get sc630994fba;

  /// fi: ESPHome ei voi vastaanottaa uusia koodeja verkon yli. Lisää tämä laitteen YAML-asetuksiin, asenna päivitys ESPHomesta ja
  ///
  /// In en, this message translates to:
  /// **'ESPHome cannot take new codes over the network. Add this to the device YAML, install it, then save the button:'**
  String get s09feac6b28;

  /// fi: Tallenna napiksi
  ///
  /// In en, this message translates to:
  /// **'Save as button'**
  String get s0a7c7a151a;

  /// fi: Sisäyksikön piirilevyn CN105-liitin (5-napainen). ESPHome: "esphome-mitsubishiheatpump" (SwiCago-kirjasto). Valmiita ohj
  ///
  /// In en, this message translates to:
  /// **'CN105 connector on the indoor board. ESPHome: esphome-mitsubishiheatpump.'**
  String get s29adc71f1c;

  /// fi: S21 (useimmat seinämallit) tai X50A (uudemmat). Faikin-ohjain kytketään suoraan liittimeen; ESPHome: "esphome-daikin-s21
  ///
  /// In en, this message translates to:
  /// **'S21 (most wall units) or X50A. Faikin plugs straight in; ESPHome: esphome-daikin-s21.'**
  String get s1d17c9fc6e;

  /// fi: CN-CNT-liitin sisäyksikössä (sama kuin Panasonicin oma WLAN-adapteri). ESPHome: "esphome-panasonic-ac".
  ///
  /// In en, this message translates to:
  /// **'CN-CNT connector (where Panasonic\'\'s WLAN adapter goes). ESPHome: esphome-panasonic-ac.'**
  String get s07767f6a03;

  /// fi: Toshiban sisäyksikön huoltoliitin (TCC-Link/AB-väylä). ESPHome: "esphome-toshiba_ac".
  ///
  /// In en, this message translates to:
  /// **'Toshiba indoor service port. ESPHome: esphome-toshiba_ac.'**
  String get s659b742754;

  /// fi: Kirjoita ESPHome-laitteen IP-osoite.
  ///
  /// In en, this message translates to:
  /// **'Type the device IP.'**
  String get s7c3bf9542b;

  /// fi: "{p0}" ja {p1} ruutua lisätty.
  ///
  /// In en, this message translates to:
  /// **'\"{p0}\" added.'**
  String sdfa6aedae8(String p0, String p1);

  /// fi: Paras tapa ohjata ilmalämpöpumppua: pieni ESP32-ohjain kytketään sisäyksikön huoltoliitäntään. Toisin kuin IR, se on kak
  ///
  /// In en, this message translates to:
  /// **'Best way: a small ESP32 on the indoor unit service port. Unlike IR it is two-way – real state and room temperature.'**
  String get s49b479c566;

  /// fi: Turvallisuus: katkaise lämpöpumpun virta pääkytkimestä ennen kuin avaat sisäyksikön. Liitäntä voi vaikuttaa takuuseen. J
  ///
  /// In en, this message translates to:
  /// **'Safety: switch the heat pump off at the mains before opening the indoor unit. It may affect warranty.'**
  String get sc95a59f7c6;

  /// fi: Liitäntä merkeittäin
  ///
  /// In en, this message translates to:
  /// **'Port by brand'**
  String get s7b7121b71e;

  /// fi: Näin otat käyttöön
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get s67c1a8a6a3;

  /// fi: Hanki merkkiisi sopiva ESP32-ohjain ja liitäntäkaapeli (linkit yllä).
  ///
  /// In en, this message translates to:
  /// **'Get an ESP32 controller and cable.'**
  String get s2f9c5f3130;

  /// fi: Asenna siihen ESPHome-asetukset projektin ohjeen mukaan. Lisää mukaan rivi "web_server:" – Molaplan käyttää sitä.
  ///
  /// In en, this message translates to:
  /// **'Flash ESPHome per the project guide. Include \"web_server:\" – Molaplan uses it.'**
  String get s2675e49423;

  /// fi: Kytke ohjain huoltoliitäntään virrat pois päältä ja kiinnitä kansi.
  ///
  /// In en, this message translates to:
  /// **'Connect it with the power off.'**
  String get scd70d27319;

  /// fi: Kirjoita alle ohjaimen IP-osoite ja paina "Etsi lämpöpumput". Molaplan löytää ilmastoinnin itse.
  ///
  /// In en, this message translates to:
  /// **'Type its IP below and tap \"Find heat pumps\".'**
  String get s56b0cb63ea;

  /// fi: ESPHome-ohjaimen IP-osoite
  ///
  /// In en, this message translates to:
  /// **'ESPHome controller IP'**
  String get sdd1cd7bdd5;

  /// fi: Löytyy reitittimen laitelistasta tai ESPHome-hallinnasta.
  ///
  /// In en, this message translates to:
  /// **'From the router device list or ESPHome dashboard.'**
  String get sa1e21d236a;

  /// fi: Etsi lämpöpumput
  ///
  /// In en, this message translates to:
  /// **'Find heat pumps'**
  String get s1bef32afe0;

  /// fi: Laite vastasi, mutta siinä ei ole ilmastointia (climate). Tarkista ESPHome-asetukset.
  ///
  /// In en, this message translates to:
  /// **'Device answered but has no climate entity.'**
  String get s9aa9bc9679;

  /// fi: Et ole kotona? Ota etäyhteys käyttöön
  ///
  /// In en, this message translates to:
  /// **'Not at home? Turn on remote access'**
  String get sd9923cda70;

  /// fi: Tieto {p0} vanha
  ///
  /// In en, this message translates to:
  /// **'State is {p0} old'**
  String s9cf8aec76a(String p0);

  /// fi: Ei yhteyttä
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get s1f8cf57b2c;

  /// fi: Viim. hälytys {p0}
  ///
  /// In en, this message translates to:
  /// **'Last alarm {p0}'**
  String s84819cca05(String p0);

  /// fi: Ilmoitukset
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get s8613961a5a;

  /// fi: Valitse, tuleeko tästä laitteesta push-ilmoitus ja millä tärkeydellä. Oletukset ovat rauhalliset: vain hälytys ja laitte
  ///
  /// In en, this message translates to:
  /// **'Choose whether this device sends a push and at which importance. Defaults stay quiet: only an alarm or a silent device notify you. Notifications go to your ntfy topic and appear in the app.'**
  String get s8814efe188;

  /// fi: Tapahtumien tärkeys
  ///
  /// In en, this message translates to:
  /// **'Event importance'**
  String get s9341ea63c0;

  /// fi: Yleiset oletukset. Laitteen omissa asetuksissa voi poiketa näistä. Automaation omassa ilmoitustoiminnossa prioriteetti v
  ///
  /// In en, this message translates to:
  /// **'General defaults. A device can override these in its own settings. A notify action on an automation takes precedence.'**
  String get s2b4ea7a381;

  /// fi: Laite ilmoitti uuden tilakanavan
  ///
  /// In en, this message translates to:
  /// **'The device reported a new state topic'**
  String get s67917c9a2a;

  /// fi: Käytä tätä
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get s79fc5ea775;

  /// fi: Valon tilaa ei saatu – säätö voi silti toimia.
  ///
  /// In en, this message translates to:
  /// **'Could not read the light – control may still work.'**
  String get s81e0c3084b;

  /// fi: Väri
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get s7400a53ab2;

  /// fi: Valkoinen
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get s09aec1d642;

  /// fi: Värilämpötila
  ///
  /// In en, this message translates to:
  /// **'Colour temperature'**
  String get s16ff3849c9;

  /// fi: Lämmin
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get sf117c88d83;

  /// fi: Kylmä
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get secb1232aad;

  /// fi: Kirkkaus
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get sb2fa876c32;

  /// fi: Suosikit
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get s34cc93ca61;

  /// fi: Pitkä painallus poistaa
  ///
  /// In en, this message translates to:
  /// **'Long-press to remove'**
  String get sdc485831ad;

  /// fi: Kaikki laitteet
  ///
  /// In en, this message translates to:
  /// **'All devices'**
  String get sfe54134176;

  /// fi: laitetta
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get s23baecde5b;

  /// fi: ohjaus + asetukset
  ///
  /// In en, this message translates to:
  /// **'control + settings'**
  String get s776f46ed8d;

  /// fi: ohjaus
  ///
  /// In en, this message translates to:
  /// **'control'**
  String get sa7cfbebc2f;

  /// fi: Perutaanko asentajan pääsy?
  ///
  /// In en, this message translates to:
  /// **'Revoke the installer\'\'s access?'**
  String get seff7e04d91;

  /// fi: {p0} ei enää pääse laitteisiisi. Pääsy loppuu heti, kun kotisilta saa tiedon (yleensä saman tien).
  ///
  /// In en, this message translates to:
  /// **'{p0} can no longer reach your devices. Access ends as soon as the home bridge hears of it (usually at once).'**
  String s633fa022d1(String p0);

  /// fi: Peru pääsy
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get sbdfc0cf419;

  /// fi: Pääsy peruttu
  ///
  /// In en, this message translates to:
  /// **'Access revoked'**
  String get s98b66fc9d8;

  /// fi: Asentaja
  ///
  /// In en, this message translates to:
  /// **'Installer'**
  String get sbd907def5b;

  /// fi: Asentajan pääsy tarvitsee Molaplan-tilin, jotta asentaja tunnistetaan ja salaus toimii.
  ///
  /// In en, this message translates to:
  /// **'Installer access needs a Molaplan account so the installer can be verified and encryption works.'**
  String get sb9c461d827;

  /// fi: Anna asentajalle pääsy laitteisiisi hänen asentajatunnuksellaan (esim. MPL-K7Q-M2X). Molaplan on tarkistanut jokaisen as
  ///
  /// In en, this message translates to:
  /// **'Give an installer access to your devices with their installer ID (e.g. MPL-K7Q-M2X). Molaplan has verified every installer\'\'s name and company. Passwords and addresses never leave home, and you can revoke access at any time.'**
  String get s523c735938;

  /// fi: Anna pääsy
  ///
  /// In en, this message translates to:
  /// **'Give access'**
  String get s03be67bc78;

  /// fi: Asentajat, joilla on pääsy
  ///
  /// In en, this message translates to:
  /// **'Installers with access'**
  String get s65c7781ca3;

  /// fi: Kenelläkään asentajalla ei ole pääsyä.
  ///
  /// In en, this message translates to:
  /// **'No installer has access.'**
  String get sbb7e4c4c3c;

  /// fi: Muuta laitteita tai oikeuksia
  ///
  /// In en, this message translates to:
  /// **'Change devices or rights'**
  String get s84a6d73d1e;

  /// fi: Asiakkaani
  ///
  /// In en, this message translates to:
  /// **'My customers'**
  String get s5fcc7e175d;

  /// fi: Asentajien hallinta
  ///
  /// In en, this message translates to:
  /// **'Manage installers'**
  String get s44dcd38f2b;

  /// fi: Asentajatunnukseni Molaplanissa: {p0} ({p1}). Anna minulle pääsy: Molaplan → Asetukset → Asentaja → Anna pääsy.
  ///
  /// In en, this message translates to:
  /// **'My Molaplan installer ID: {p0} ({p1}). To give me access: Molaplan → Settings → Installer → Give access.'**
  String s2f8dd9569b(String p0, String p1);

  /// fi: Kopioi viesti
  ///
  /// In en, this message translates to:
  /// **'Copy the message'**
  String get s0061cbc425;

  /// fi: Sähköposti
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get sdd0f19c6b8;

  /// fi: Tekstiviesti
  ///
  /// In en, this message translates to:
  /// **'Text message'**
  String get sd57398d989;

  /// fi: Viesti kopioitu
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get s4f09cced25;

  /// fi: Sovellusta ei voitu avata – viesti kopioitiin.
  ///
  /// In en, this message translates to:
  /// **'Could not open the app – the message was copied.'**
  String get s2836191df5;

  /// fi: Asiakas skannaa: Asetukset → Asentaja → Anna pääsy.
  ///
  /// In en, this message translates to:
  /// **'The customer scans it: Settings → Installer → Give access.'**
  String get sd01e57c279;

  /// fi: Olet Molaplan-asentaja
  ///
  /// In en, this message translates to:
  /// **'You are a Molaplan installer'**
  String get se83877749c;

  /// fi: Asentajatunnuksesi
  ///
  /// In en, this message translates to:
  /// **'Your installer ID'**
  String get s014468e53e;

  /// fi: Anna tunnus asiakkaalle. Hän avaa sillä pääsyn laitteisiinsa ja näkee nimesi ja yrityksesi Molaplanin vahvistamina.
  ///
  /// In en, this message translates to:
  /// **'Give the ID to your customer. They open access to their devices with it and see your name and company as verified by Molaplan.'**
  String get s973ddbcd3b;

  /// fi: Tunnus kopioitu
  ///
  /// In en, this message translates to:
  /// **'ID copied'**
  String get s9e0dd2426d;

  /// fi: Jaa
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get s5224946aa1;

  /// fi: QR-koodi
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get s59d0633cbd;

  /// fi: Hae asentajaksi
  ///
  /// In en, this message translates to:
  /// **'Apply to be an installer'**
  String get sacc4275348;

  /// fi: Molaplan tarkistaa nimesi ja yrityksesi ja myöntää asentajatunnuksen. Saat tiedon sovellukseen.
  ///
  /// In en, this message translates to:
  /// **'Molaplan checks your name and company and gives you an installer ID. You will see the result in the app.'**
  String get s29acd8486c;

  /// fi: Nimesi
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get s7aa9c1e208;

  /// fi: Yritys
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get s9f3d2fa73f;

  /// fi: esim. Y-tunnus tai Kevytyrittäjä
  ///
  /// In en, this message translates to:
  /// **'e.g. business ID or sole trader'**
  String get scfe0cd3759;

  /// fi: Viesti (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get s483b3a689d;

  /// fi: Lähetä hakemus
  ///
  /// In en, this message translates to:
  /// **'Send application'**
  String get sb7dbf1a527;

  /// fi: Kirjoita nimesi.
  ///
  /// In en, this message translates to:
  /// **'Type your name.'**
  String get s0b9319b6eb;

  /// fi: Hakemus lähetetty
  ///
  /// In en, this message translates to:
  /// **'Application sent'**
  String get s9929adfbf5;

  /// fi: Oletko asentaja?
  ///
  /// In en, this message translates to:
  /// **'Are you an installer?'**
  String get s2570b96a0b;

  /// fi: Asentajan tilasi ({p0}) on poistettu, eikä asiakkaiden pääsyjä voi käyttää. Kysy lisää Molaplanilta: molaplan1@gmail.com
  ///
  /// In en, this message translates to:
  /// **'Your installer status ({p0}) was removed and customer access cannot be used. Ask Molaplan: molaplan1@gmail.com.'**
  String s63d8fdf8c2(String p0);

  /// fi: Asentajana näet asiakkaidesi laitteet, tilan ja hälytykset sillä laajuudella kuin asiakas sallii. Asentajan tilan myöntä
  ///
  /// In en, this message translates to:
  /// **'As an installer you see your customers\'\' devices, status and alarms as far as each customer allows. Molaplan grants the installer status.'**
  String get s82b8ec7605;

  /// fi: Hakemus lähetetty {p0} – odottaa käsittelyä.
  ///
  /// In en, this message translates to:
  /// **'Application sent {p0} – waiting for review.'**
  String s563801d51b(String p0);

  /// fi: Peru hakemus
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get s1247102567;

  /// fi: Edellistä hakemusta ei hyväksytty.
  ///
  /// In en, this message translates to:
  /// **'The previous application was not approved.'**
  String get s77f0327b09;

  /// fi: Tunnus on muotoa MPL-XXX-XXX.
  ///
  /// In en, this message translates to:
  /// **'The ID looks like MPL-XXX-XXX.'**
  String get s5e130a714c;

  /// fi: Tunnuksella ei löytynyt hyväksyttyä asentajaa. Tarkista tunnus asentajalta.
  ///
  /// In en, this message translates to:
  /// **'No approved installer has this ID. Check the ID with the installer.'**
  String get s16d84ef12f;

  /// fi: Annetaanko pääsy?
  ///
  /// In en, this message translates to:
  /// **'Give access?'**
  String get s7288dc01b6;

  /// fi: Tallennetaanko muutokset?
  ///
  /// In en, this message translates to:
  /// **'Save the changes?'**
  String get s2013b9940c;

  /// fi: Kaikki laitteet (myös myöhemmin lisättävät)
  ///
  /// In en, this message translates to:
  /// **'All devices (also ones added later)'**
  String get sa88745a558;

  /// fi: Saa ohjata ja muuttaa asetuksia
  ///
  /// In en, this message translates to:
  /// **'May control and change settings'**
  String get sd97ead609e;

  /// fi: Saa ohjata, ei muuttaa asetuksia
  ///
  /// In en, this message translates to:
  /// **'May control, not change settings'**
  String get s8be70baa9c;

  /// fi: Voit perua pääsyn milloin vain.
  ///
  /// In en, this message translates to:
  /// **'You can revoke access at any time.'**
  String get sf2581756af;

  /// fi: Pääsy annettu: {p0}
  ///
  /// In en, this message translates to:
  /// **'Access given: {p0}'**
  String s9a6818b304(String p0);

  /// fi: Anna pääsy asentajalle
  ///
  /// In en, this message translates to:
  /// **'Give an installer access'**
  String get s52a64a3307;

  /// fi: Asentajan tunnus
  ///
  /// In en, this message translates to:
  /// **'Installer ID'**
  String get s2113bddc63;

  /// fi: Hae
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get s6d7d0273ad;

  /// fi: Skannaa asentajan QR-koodi
  ///
  /// In en, this message translates to:
  /// **'Scan the installer\'\'s QR code'**
  String get s36418f769d;

  /// fi: Molaplanin vahvistama asentaja
  ///
  /// In en, this message translates to:
  /// **'Installer verified by Molaplan'**
  String get scb4d6b0ddc;

  /// fi: Mihin asentaja pääsee?
  ///
  /// In en, this message translates to:
  /// **'What can the installer reach?'**
  String get s95fd3e8dc3;

  /// fi: Valitut laitteet
  ///
  /// In en, this message translates to:
  /// **'Selected devices'**
  String get s0d395a6edd;

  /// fi: {p0} laitetta nyt, myöhemmin lisättävät tulevat mukaan.
  ///
  /// In en, this message translates to:
  /// **'{p0} devices now; ones added later are included.'**
  String s8affba28ec(String p0);

  /// fi: Saa muuttaa asetuksia
  ///
  /// In en, this message translates to:
  /// **'May change settings'**
  String get sbc76d76351;

  /// fi: Lämpötilat, toimintatilat ja muut asetukset. Pois päältä: asentaja voi ohjata ja katsoa tilaa.
  ///
  /// In en, this message translates to:
  /// **'Temperatures, modes and other settings. Off: the installer can control and see the status.'**
  String get s4fa2d2d66c;

  /// fi: Sinulla ei ole vielä jaettavia laitteita.
  ///
  /// In en, this message translates to:
  /// **'You have no shareable devices yet.'**
  String get s82b62bcb13;

  /// fi: Kotisilta tarkistaa jokaisen pyynnön oikeudet. Laitteiden salasanat ja osoitteet eivät lähde kotoa.
  ///
  /// In en, this message translates to:
  /// **'The home bridge checks the rights of every request. Device passwords and addresses never leave home.'**
  String get s4e60c0286c;

  /// fi: Kirjoita vähintään 3 merkkiä sähköpostista.
  ///
  /// In en, this message translates to:
  /// **'Type at least 3 characters of the e-mail.'**
  String get sd431b45586;

  /// fi: Käyttäjää ei löytynyt.
  ///
  /// In en, this message translates to:
  /// **'No user found.'**
  String get s2162e5cad2;

  /// fi: Asentajan tila
  ///
  /// In en, this message translates to:
  /// **'Installer status'**
  String get s1ec9cc5828;

  /// fi: Vahvistettu nimi
  ///
  /// In en, this message translates to:
  /// **'Verified name'**
  String get s256fb6b50a;

  /// fi: esim. Kevytyrittäjä
  ///
  /// In en, this message translates to:
  /// **'e.g. sole trader'**
  String get sd8a8961db3;

  /// fi: Muistiinpano (vain ylläpito)
  ///
  /// In en, this message translates to:
  /// **'Note (admins only)'**
  String get sb57dfb696c;

  /// fi: Myönnä
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get s8ce95234d7;

  /// fi: Nimi puuttuu.
  ///
  /// In en, this message translates to:
  /// **'The name is missing.'**
  String get s2eca996a49;

  /// fi: Asentaja {p0}: {p1}
  ///
  /// In en, this message translates to:
  /// **'Installer {p0}: {p1}'**
  String s5a4c72db4b(String p0, String p1);

  /// fi: Poistetaanko asentajan tila?
  ///
  /// In en, this message translates to:
  /// **'Remove the installer status?'**
  String get se06acfd38d;

  /// fi: {p0} ({p1}) menettää asentajan tilan, ja kaikki asiakkaiden antamat pääsyt ({p2}) katkeavat heti. Tunnus säilyy, jos til
  ///
  /// In en, this message translates to:
  /// **'{p0} ({p1}) loses the installer status and all customer access ({p2}) ends at once. The ID stays if the status is granted again later.'**
  String sd35135676e(String p0, String p1, String p2);

  /// fi: Poista tila
  ///
  /// In en, this message translates to:
  /// **'Remove status'**
  String get se70c0caad3;

  /// fi: Asentajan tila poistettu
  ///
  /// In en, this message translates to:
  /// **'Installer status removed'**
  String get s2679477d73;

  /// fi: Myönnä asentajan tila vain henkilölle, jonka nimen ja yrityksen olet tarkistanut. Sama hallinta on myös osoitteessa mola
  ///
  /// In en, this message translates to:
  /// **'Grant the installer status only to someone whose name and company you have checked. The same tools are at molaplan.com/tilaa/hallinta (Installers).'**
  String get s5ea6251452;

  /// fi: Hae käyttäjä sähköpostilla
  ///
  /// In en, this message translates to:
  /// **'Find a user by e-mail'**
  String get sa7380f5e5c;

  /// fi: nimi@esimerkki.fi
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get sc023f30da1;

  /// fi: ei ole vielä avannut sovellusta
  ///
  /// In en, this message translates to:
  /// **'has not opened the app yet'**
  String get s9a7d261596;

  /// fi: asentaja
  ///
  /// In en, this message translates to:
  /// **'installer'**
  String get sd4f8f15670;

  /// fi: tila poistettu
  ///
  /// In en, this message translates to:
  /// **'status removed'**
  String get sfee2ce49ea;

  /// fi: Hakemukset
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get s3ecd52ffc6;

  /// fi: Ei avoimia hakemuksia.
  ///
  /// In en, this message translates to:
  /// **'No open applications.'**
  String get se5c4c1e153;

  /// fi: Hyväksy
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get s052118a469;

  /// fi: Hylkää
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get s493a1eaf08;

  /// fi: Asentajat
  ///
  /// In en, this message translates to:
  /// **'Installers'**
  String get sc8ab77f768;

  /// fi: asiakasta
  ///
  /// In en, this message translates to:
  /// **'customers'**
  String get s65f12e7e23;

  /// fi: Myönnä uudelleen
  ///
  /// In en, this message translates to:
  /// **'Grant again'**
  String get sf36e8af07c;

  /// fi: Poista asentajan tila
  ///
  /// In en, this message translates to:
  /// **'Remove installer status'**
  String get s0361487148;

  /// fi: Valitse taustakuva
  ///
  /// In en, this message translates to:
  /// **'Choose a background picture'**
  String get sc1c47d2474;

  /// fi: Enintään {p0} taustakuvaa. Poista jokin ensin.
  ///
  /// In en, this message translates to:
  /// **'At most {p0} background pictures. Remove one first.'**
  String sa8ce5112ee(String p0);

  /// fi: Tiedosto ei ole kuva
  ///
  /// In en, this message translates to:
  /// **'The file is not a picture'**
  String get sceafe9ce2a;

  /// fi: Ulkoasu
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get s12a7d631af;

  /// fi: Koko
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get s0d83798030;

  /// fi: Pieni
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get s64c916e299;

  /// fi: Leveä
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get s5e3097232a;

  /// fi: Iso
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get s8971788287;

  /// fi: Kuvake
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get scf37cbeda8;

  /// fi: Taustakuva (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Background picture (optional)'**
  String get s254a1d8e12;

  /// fi: Valitse kuva
  ///
  /// In en, this message translates to:
  /// **'Choose picture'**
  String get sc48f5f9bcf;

  /// fi: Vaihda kuva
  ///
  /// In en, this message translates to:
  /// **'Change picture'**
  String get sf55eee73b8;

  /// fi: Ota kuva
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get sf6723451b9;

  /// fi: Poista kuva
  ///
  /// In en, this message translates to:
  /// **'Remove picture'**
  String get sdd957ccc1b;

  /// fi: Himmennä kun laite on pois päältä
  ///
  /// In en, this message translates to:
  /// **'Dim when the device is off'**
  String get s7ba9d453ed;

  /// fi: Kuva pienennetään (≤ 200 kt) ja synkronoidaan tiliisi.
  ///
  /// In en, this message translates to:
  /// **'The picture is shrunk (≤ 200 KB) and synced to your account.'**
  String get s016ae7b580;

  /// fi: Kuva pienennetään (≤ 200 kt) ja tallennetaan vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'The picture is shrunk (≤ 200 KB) and kept on this device only.'**
  String get sabb10f8cb2;

  /// fi: Pikakuvake suorittaa komennon suoraan aloitusnäytöltä.
  ///
  /// In en, this message translates to:
  /// **'A shortcut runs the command directly from the home screen.'**
  String get s3cd1e146e8;

  /// fi: Tila (widget)
  ///
  /// In en, this message translates to:
  /// **'Status (widget)'**
  String get s1c2a0377e4;

  /// fi: Widget näyttää laatan tilan aloitusnäytöllä.
  ///
  /// In en, this message translates to:
  /// **'A widget shows the tile status on the home screen.'**
  String get s54512f5660;

  /// fi: Tälle laatalle lisätään tilawidget, joka näyttää arvon aloitusnäytöllä.
  ///
  /// In en, this message translates to:
  /// **'This tile gets a status widget that shows the value on the home screen.'**
  String get s517f5701fd;

  /// fi: Vahvista ennen suoritusta
  ///
  /// In en, this message translates to:
  /// **'Confirm before running'**
  String get sd069985866;

  /// fi: Suositellaan vaarallisille komennoille, kuten hälytyksen pois päältä.
  ///
  /// In en, this message translates to:
  /// **'Recommended for dangerous commands, such as turning an alarm off.'**
  String get s5775841848;

  /// fi: PIN-koodia ei tallenneta pikakuvakkeeseen. Jos laite vaatii PIN-koodin, se kysytään sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'The PIN is not stored in the shortcut. If the device requires a PIN, the app will ask for it.'**
  String get sf8e4a8294a;

  /// fi: Pikakuvake lisätty. Vahvista se aloitusnäytöllä.
  ///
  /// In en, this message translates to:
  /// **'Shortcut added. Confirm it on the home screen.'**
  String get s5eaef9c7e8;

  /// fi: Widget lisätty. Vahvista se aloitusnäytöllä.
  ///
  /// In en, this message translates to:
  /// **'Widget added. Confirm it on the home screen.'**
  String get s526d406d59;

  /// fi: Aloitusnäyttö ei tue tätä, tai lisäys peruutettiin.
  ///
  /// In en, this message translates to:
  /// **'The home screen does not support this, or the add was cancelled.'**
  String get s31c3d63c1e;

  /// fi: Laattaa ei löytynyt
  ///
  /// In en, this message translates to:
  /// **'Tile not found'**
  String get sa37e535e0f;

  /// fi: Esimerkkikamera – lisää oma kamerasi Lisää laite -painikkeella
  ///
  /// In en, this message translates to:
  /// **'Example camera – add your own with Add device'**
  String get sa0bd9ad5b1;

  /// fi: Valitse kamerayhteys
  ///
  /// In en, this message translates to:
  /// **'Choose a camera connection'**
  String get s4529c1010a;

  /// fi: Kameralle ei ole tallennettu videon osoitetta. Poista kamera ja lisää se uudelleen, tai kirjoita RTSP-osoite käsin.
  ///
  /// In en, this message translates to:
  /// **'No video address is stored for this camera. Remove it and add it again, or type the RTSP address by hand.'**
  String get s0ab7f9db7c;

  /// fi: Still-kuvaa ei saatu tehtyä videovirrasta. Kotisillan tietokoneella tarvitaan ffmpeg tai Molaplan-sovellus kotisiltana.
  ///
  /// In en, this message translates to:
  /// **'A still picture could not be made from the video stream. The home bridge computer needs ffmpeg, or use the Molaplan app as the home bridge.'**
  String get sda6d2b0dbe;

  /// fi: Kamera ({p0}) ei vastaa tältä laitteelta. Tarkista, että laite on samassa verkossa kuin kamera ja että kameran RTSP on p
  ///
  /// In en, this message translates to:
  /// **'The camera ({p0}) does not answer from this device. Check that this device is on the same network as the camera and that RTSP is on in the camera.'**
  String sb8cbbd3d99(String p0);

  /// fi: Kamera hylkäsi tunnuksen tai salasanan (RTSP 401). Tarkista ne kameran ONVIF/RTSP-asetuksista.
  ///
  /// In en, this message translates to:
  /// **'The camera refused the username or password (RTSP 401). Check them in the camera\'\'s ONVIF/RTSP settings.'**
  String get s4a6a89a47e;

  /// fi: Kamera ei tunne videon osoitetta (RTSP 404). Lisää kamera uudelleen tai kirjoita RTSP-osoite käsin.
  ///
  /// In en, this message translates to:
  /// **'The camera does not know this video address (RTSP 404). Add the camera again or type the RTSP address by hand.'**
  String get s5f36d79393;

  /// fi: Kamera vastasi, mutta kuvaa ei saatu toistettua{p0}. Yritä uudelleen; jos vika jatkuu, katso tekniset tiedot.
  ///
  /// In en, this message translates to:
  /// **'The camera answered, but the video could not be played{p0}. Try again; if it keeps failing, see the technical details.'**
  String s4c88b1dfe4(String p0);

  /// fi: Kamera vastasi RTSP {p0}, eikä kuvaa saatu. Tarkista tunnus ja salasana ja että RTSP on päällä.
  ///
  /// In en, this message translates to:
  /// **'The camera answered RTSP {p0} and no picture came. Check the username and password and that RTSP is on.'**
  String sedafd495a6(String p0);

  /// fi: Virta päättyi
  ///
  /// In en, this message translates to:
  /// **'Stream ended'**
  String get sc95fb5440b;

  /// fi: Yritä uudelleen
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get s200542b930;

  /// fi: PTZ-ohjaus ei onnistunut ({p0}). Tarkista, että olet kotiverkossa.
  ///
  /// In en, this message translates to:
  /// **'PTZ command failed ({p0}). Check that you are on the home network.'**
  String s359970020b(String p0);

  /// fi: Tila / arvo
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get s1cf33c1fbc;

  /// fi: Kytkin
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get s86029171be;

  /// fi: Painike / pikakomento
  ///
  /// In en, this message translates to:
  /// **'Button / shortcut'**
  String get s4ddce888df;

  /// fi: Liukusäädin / asetusarvo
  ///
  /// In en, this message translates to:
  /// **'Slider / setpoint'**
  String get s357fc9c3fe;

  /// fi: Kamera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get seeb6c38c8e;

  /// fi: Näyttää lukeman, esim. lämpötilan tai tehon.
  ///
  /// In en, this message translates to:
  /// **'Shows a reading, e.g. temperature.'**
  String get s14da6beba5;

  /// fi: Päälle/pois, esim. valo tai hälytys.
  ///
  /// In en, this message translates to:
  /// **'On/off, e.g. a light or alarm.'**
  String get se4b1d203df;

  /// fi: Yksi painallus tekee yhden tai monta asiaa.
  ///
  /// In en, this message translates to:
  /// **'One tap does one or many things.'**
  String get sc2197ab417;

  /// fi: Säädä arvoa, esim. lämpötilaa tai puhallinta.
  ///
  /// In en, this message translates to:
  /// **'Adjust a value, e.g. temperature.'**
  String get sd611704caf;

  /// fi: Näyttää kameran kuvan.
  ///
  /// In en, this message translates to:
  /// **'Shows a camera image.'**
  String get sacfc0c0b41;

  /// fi: Pitää lämpötilan halutussa arvossa.
  ///
  /// In en, this message translates to:
  /// **'Keeps the temperature at the set value.'**
  String get s7172c54c2c;

  /// fi: Korjaa värialueiden rajat ennen tallennusta.
  ///
  /// In en, this message translates to:
  /// **'Fix the colour range limits before saving.'**
  String get s4b9bb0710d;

  /// fi: Luettu arvo
  ///
  /// In en, this message translates to:
  /// **'Value read'**
  String get s76e7a995de;

  /// fi: Skripti
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get sdced476aeb;

  /// fi: Tilanne
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get sdaa7d4de12;

  /// fi: Ohjaa laitetta
  ///
  /// In en, this message translates to:
  /// **'Control a device'**
  String get sae3489a6c9;

  /// fi: Oma komento
  ///
  /// In en, this message translates to:
  /// **'Own command'**
  String get s4e1f25d257;

  /// fi: Mitä nappi tekee?
  ///
  /// In en, this message translates to:
  /// **'What does the button do?'**
  String get sea15760b77;

  /// fi: Valitse skripti, tilanne tai laite. Nappi toimii sovelluksessa ja kodin ulkopuolelta etäkäytön kautta.
  ///
  /// In en, this message translates to:
  /// **'Pick a script, a scene or a device. The button works in the app and, when you are away, through remote access.'**
  String get s630ee9894e;

  /// fi: Skriptejä ei vielä ole. Tee skripti kohdassa Automaatiot.
  ///
  /// In en, this message translates to:
  /// **'No scripts yet. Make one under Automations.'**
  String get s1173c2dbf9;

  /// fi: Tilanteita ei vielä ole. Tallenna tilanne kohdassa Automaatiot.
  ///
  /// In en, this message translates to:
  /// **'No scenes yet. Save one under Automations.'**
  String get s7b42ecba51;

  /// fi: Ohjattavia laitteita ei vielä ole. Lisää ensin kytkin.
  ///
  /// In en, this message translates to:
  /// **'No switchable devices yet. Add a switch first.'**
  String get s589d73245e;

  /// fi: Vaihda
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get s750f16460c;

  /// fi: Uusi ruutu
  ///
  /// In en, this message translates to:
  /// **'New tile'**
  String get sc5edd6d3d1;

  /// fi: Muokkaa ruutua
  ///
  /// In en, this message translates to:
  /// **'Edit tile'**
  String get sa684fd0716;

  /// fi: Mittaus: näyttötapa, trendi, värirajat, hälytykset, desimaalit ja skaalaus.
  ///
  /// In en, this message translates to:
  /// **'Measurement: display, trend, colour limits, alarms, decimals and scaling.'**
  String get sa7b6366b62;

  /// fi: Ohjaus: vahvistus, lukitus / PIN, min / max / askel, käänteinen ja hetkellinen.
  ///
  /// In en, this message translates to:
  /// **'Control: confirmation, lock / PIN, min / max / step, invert and momentary.'**
  String get sae41bebdab;

  /// fi: Otsikko
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get s8a8673aafe;

  /// fi: Huoneen lämpöanturi
  ///
  /// In en, this message translates to:
  /// **'Room temperature sensor'**
  String get sf83143ae23;

  /// fi: Ei valittu
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get s19485c79b2;

  /// fi: Valitse lämpöanturi
  ///
  /// In en, this message translates to:
  /// **'Choose a temperature sensor'**
  String get s0483226428;

  /// fi: Leveys
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get sfeab9bd26f;

  /// fi: Korkeus
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get s58be670598;

  /// fi: Näyttötapa
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get sd7314e8237;

  /// fi: Trendin pituus
  ///
  /// In en, this message translates to:
  /// **'Trend length'**
  String get s1c72b8c56a;

  /// fi: Mittarin minimi
  ///
  /// In en, this message translates to:
  /// **'Gauge minimum'**
  String get s6bb0c0c7e3;

  /// fi: Automaattinen
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get sa444aab286;

  /// fi: Mittarin maksimi
  ///
  /// In en, this message translates to:
  /// **'Gauge maximum'**
  String get sbf29caff87;

  /// fi: Ruudun tekniset asetukset (mistä tila luetaan, mitä komento lähettää) näkyvät, kun otat Asetuksista käyttöön "Edistyneet
  ///
  /// In en, this message translates to:
  /// **'Technical tile settings appear when you turn on \"Advanced\" in Settings.'**
  String get sea30815e6a;

  /// fi: Tilan luku
  ///
  /// In en, this message translates to:
  /// **'State source'**
  String get s382afc832f;

  /// fi: Valinnainen: mistä nykyinen tila luetaan.
  ///
  /// In en, this message translates to:
  /// **'Optional: where the current state is read from.'**
  String get s581aee3e96;

  /// fi: Raaka yhdistelmä (Edistyneet)
  ///
  /// In en, this message translates to:
  /// **'Raw combination (Advanced)'**
  String get s3adc51170c;

  /// fi: ⚠ Kaikki ruututyypit sallitaan kaikille yhteyksille. Väärä yhdistelmä voi näyttää harhaanjohtavaa tietoa, esim. "Päällä"
  ///
  /// In en, this message translates to:
  /// **'⚠ Every tile type is allowed on every connection. A wrong combination can show misleading data, e.g. \"On\" for the electricity price.'**
  String get s5f542e17e2;

  /// fi: Pois: vain yhteyden tukemat ruututyypit.
  ///
  /// In en, this message translates to:
  /// **'Off: only the tile types the connection supports.'**
  String get scb988b1a4a;

  /// fi: Päivitysväli (s, 0 = ei kyselyä)
  ///
  /// In en, this message translates to:
  /// **'Poll interval (s, 0 = none)'**
  String get se6b18b17d9;

  /// fi: MQTT, Home Assistant ja WebSocket päivittyvät reaaliajassa ilman kyselyä.
  ///
  /// In en, this message translates to:
  /// **'MQTT, Home Assistant and WebSocket update live without polling.'**
  String get s01f2b1ee0c;

  /// fi: Testaa luku
  ///
  /// In en, this message translates to:
  /// **'Test read'**
  String get s937448ecf5;

  /// fi: Näyttö
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get s5cbdea7f7e;

  /// fi: Yksikkö
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get se6af4b33df;

  /// fi: Desimaalit
  ///
  /// In en, this message translates to:
  /// **'Decimals'**
  String get sd5498697da;

  /// fi: Arvojen nimet
  ///
  /// In en, this message translates to:
  /// **'Value names'**
  String get s4f7007db78;

  /// fi: 0=Pois;1=Kotona;2=Poissa
  ///
  /// In en, this message translates to:
  /// **'0=Off;1=Home;2=Away'**
  String get s4aae179c52;

  /// fi: Kytkimen komennot
  ///
  /// In en, this message translates to:
  /// **'Toggle commands'**
  String get s0c12fda7ca;

  /// fi: "Päällä"-arvot (pilkuin, tyhjä = automaattinen)
  ///
  /// In en, this message translates to:
  /// **'\"On\" values (comma separated, empty = auto)'**
  String get s3a9d9e16ef;

  /// fi: PÄÄLLE-komento
  ///
  /// In en, this message translates to:
  /// **'ON command'**
  String get s1509c5a2a6;

  /// fi: POIS-komento
  ///
  /// In en, this message translates to:
  /// **'OFF command'**
  String get s2a1e131afd;

  /// fi: Komennossa {{value}} korvataan säätimen arvolla.
  ///
  /// In en, this message translates to:
  /// **'\'{{value}} in the command is replaced by the slider value.\''**
  String get s0201de52c0;

  /// fi: Askel
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get sc30c9a7e51;

  /// fi: Asetuskomento
  ///
  /// In en, this message translates to:
  /// **'Set command'**
  String get s4d6451a63a;

  /// fi: Komennot (suoritetaan järjestyksessä)
  ///
  /// In en, this message translates to:
  /// **'Commands (run in order)'**
  String get sa4082e1a79;

  /// fi: Pikakomento voi ohjata useaa laitetta peräkkäin, viiveillä.
  ///
  /// In en, this message translates to:
  /// **'A shortcut can control several devices in sequence, with delays.'**
  String get s467488e572;

  /// fi: Lisää komento
  ///
  /// In en, this message translates to:
  /// **'Add command'**
  String get sad43973fb3;

  /// fi: Kysy vahvistus ennen komentoa
  ///
  /// In en, this message translates to:
  /// **'Ask for confirmation'**
  String get sdaef43c622;

  /// fi: Kulutus
  ///
  /// In en, this message translates to:
  /// **'Power use'**
  String get s8daad6220b;

  /// fi: Energiavirta- ja energiaseuranta käyttävät tätä, kun laitteella ei ole omaa tehomittausta.
  ///
  /// In en, this message translates to:
  /// **'Used by the energy flow and energy tracking when the device has no power reading of its own.'**
  String get s32f3e14297;

  /// fi: Automaattinen (vakio)
  ///
  /// In en, this message translates to:
  /// **'Automatic (constant)'**
  String get sdb421f416a;

  /// fi: Automaattinen (muuttuva)
  ///
  /// In en, this message translates to:
  /// **'Automatic (variable)'**
  String get s786bfe3da8;

  /// fi: Vakioteho
  ///
  /// In en, this message translates to:
  /// **'Constant power'**
  String get sff135454cc;

  /// fi: Muuttuva teho
  ///
  /// In en, this message translates to:
  /// **'Variable power'**
  String get s3a93ea412d;

  /// fi: Nimellisteho (W)
  ///
  /// In en, this message translates to:
  /// **'Nominal power (W)'**
  String get s7e84a42a54;

  /// fi: esim. 2000
  ///
  /// In en, this message translates to:
  /// **'e.g. 2000'**
  String get s2819df9628;

  /// fi: Kun laite on päällä, sen kulutukseksi arvioidaan tämä teho (esim. lämmitin, sauna, pumppu, valot). Arvio näkyy ≈-merkill
  ///
  /// In en, this message translates to:
  /// **'While the device is on, its use is estimated as this power (e.g. a heater, sauna, pump or lights). The estimate shows with ≈ and is logged as an estimate.'**
  String get s4eda7736bd;

  /// fi: Muuttuvatehoisen laitteen (esim. lämpöpumppu, invertteri, latausasema) kulutusta ei arvioida käsin, koska teho vaihtelee
  ///
  /// In en, this message translates to:
  /// **'A variable-power device (e.g. a heat pump, inverter or charger) is not estimated by hand because its power varies. Use the device\'\'s own power reading or a separate meter.'**
  String get s83db0a9f12;

  /// fi: Yhteys
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get s5210a5ad23;

  /// fi: Uusi yhteys
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get s776d8b06bf;

  /// fi: Komento lähetetty
  ///
  /// In en, this message translates to:
  /// **'Command sent'**
  String get s96705fc3df;

  /// fi: Kokeile
  ///
  /// In en, this message translates to:
  /// **'Try'**
  String get sb41db1e809;

  /// fi: Viive ennen (ms)
  ///
  /// In en, this message translates to:
  /// **'Delay before (ms)'**
  String get s77d2309fd5;

  /// fi: Pylväät
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get sc18ac46162;

  /// fi: Trendi + Nyt-viiva
  ///
  /// In en, this message translates to:
  /// **'Trend + Now line'**
  String get sc0e069225b;

  /// fi: Aikaväli
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get s07647fa07d;

  /// fi: Tarkkuus
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get sbf6aaf9bb8;

  /// fi: Auto
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get sd032c3efec;

  /// fi: 15 min
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get sa6dc2ff399;

  /// fi: 1 h
  ///
  /// In en, this message translates to:
  /// **'1 h'**
  String get s96093c8f41;

  /// fi: Väritys
  ///
  /// In en, this message translates to:
  /// **'Colouring'**
  String get s0a3e006fda;

  /// fi: Suhteellinen (päivän min–max)
  ///
  /// In en, this message translates to:
  /// **'Relative (day min–max)'**
  String get sb6bfec83a2;

  /// fi: Kiinteät rajat
  ///
  /// In en, this message translates to:
  /// **'Absolute thresholds'**
  String get sd13fe2ac25;

  /// fi: Yksi väri
  ///
  /// In en, this message translates to:
  /// **'Fixed colour'**
  String get s717db0e103;

  /// fi: Lisäasetukset
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get sdc398885dc;

  /// fi: Näytä huomenna kun saatavilla
  ///
  /// In en, this message translates to:
  /// **'Show tomorrow when available'**
  String get s8feeef3110;

  /// fi: Huomisen hinnat tulevat näkyviin itsestään, kun ne julkaistaan (n. klo 14).
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'\'s prices appear by themselves once published (around 14:00).'**
  String get sad692e6ae5;

  /// fi: Pylvään leveys
  ///
  /// In en, this message translates to:
  /// **'Bar width'**
  String get s3221d2c8b7;

  /// fi: Ohut
  ///
  /// In en, this message translates to:
  /// **'Thin'**
  String get s2c890951b7;

  /// fi: Keskitaso
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get s0223c26f61;

  /// fi: Pylväiden väli
  ///
  /// In en, this message translates to:
  /// **'Space between bars'**
  String get se6264a30f1;

  /// fi: Ei väliä
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get s93a0675c8f;

  /// fi: Ohut väli
  ///
  /// In en, this message translates to:
  /// **'Thin gap'**
  String get s124beecddd;

  /// fi: Tuntien välissä
  ///
  /// In en, this message translates to:
  /// **'Between hours'**
  String get saca843874b;

  /// fi: Min- ja max-merkinnät
  ///
  /// In en, this message translates to:
  /// **'Min and max markers'**
  String get s4b97930585;

  /// fi: Nyt-viiva
  ///
  /// In en, this message translates to:
  /// **'Now line'**
  String get seef35b192d;

  /// fi: Tilastorivi (nyt, min, ka, max)
  ///
  /// In en, this message translates to:
  /// **'Stats row (now, min, avg, max)'**
  String get s8c6a205222;

  /// fi: Y-asteikko automaattinen
  ///
  /// In en, this message translates to:
  /// **'Automatic y-axis'**
  String get sbeeaa6cf12;

  /// fi: Y-asteikon maksimi (c/kWh)
  ///
  /// In en, this message translates to:
  /// **'Y-axis maximum (c/kWh)'**
  String get s29e7f8092d;

  /// fi: Sisällytä ALV
  ///
  /// In en, this message translates to:
  /// **'Include VAT'**
  String get sd84d7d09c2;

  /// fi: Sisällytä marginaali
  ///
  /// In en, this message translates to:
  /// **'Include margin'**
  String get s6817cff974;

  /// fi: Viivan / kiinteä väri
  ///
  /// In en, this message translates to:
  /// **'Line / fixed colour'**
  String get sd85f1b089e;

  /// fi: Teeman väri
  ///
  /// In en, this message translates to:
  /// **'Theme colour'**
  String get s147f0af2a4;

  /// fi: Värialueet (c/kWh)
  ///
  /// In en, this message translates to:
  /// **'Colour ranges (c/kWh)'**
  String get sdf5278fadb;

  /// fi: Ei omaa väriä (suhteellinen taso)
  ///
  /// In en, this message translates to:
  /// **'No own colour (relative level)'**
  String get s0d88d3856f;

  /// fi: Näytä
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get sb06bee9921;

  /// fi: Apuviivat
  ///
  /// In en, this message translates to:
  /// **'Guide lines'**
  String get s2594346d86;

  /// fi: Ei
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sfdffaffea4;

  /// fi: Vaaka
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get sd6c2de0256;

  /// fi: Ruudukko
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get sb8ef66c33e;

  /// fi: Arvoasteikko
  ///
  /// In en, this message translates to:
  /// **'Value scale'**
  String get s0bee1b8ed3;

  /// fi: Aika-akseli
  ///
  /// In en, this message translates to:
  /// **'Time axis'**
  String get sd4e9b57931;

  /// fi: Datapisteet viivalla
  ///
  /// In en, this message translates to:
  /// **'Data point markers'**
  String get s7abdb12fef;

  /// fi: Auto: akselit ja apuviivat näkyvät, kun ruutu on vähintään 2×2.
  ///
  /// In en, this message translates to:
  /// **'Auto: axes and guide lines show when the tile is at least 2×2.'**
  String get s29135ed75a;

  /// fi: Kuvavirta
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get s638c648b40;

  /// fi: Linssi / kanava {p0}
  ///
  /// In en, this message translates to:
  /// **'Lens / channel {p0}'**
  String s32ef3895b8(String p0);

  /// fi: Värit arvon mukaan
  ///
  /// In en, this message translates to:
  /// **'Colours by value'**
  String get s939603242a;

  /// fi: Omat rajat
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get s45f927bc62;

  /// fi: Liukuva
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get s319dab47d8;

  /// fi: Jyrkkä
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get s613fbec20e;

  /// fi: Omat rajat ja värit: Asetukset → Edistyneet.
  ///
  /// In en, this message translates to:
  /// **'Own limits and colours: Settings → Advanced.'**
  String get s25d9db075e;

  /// fi: Värialueet
  ///
  /// In en, this message translates to:
  /// **'Colour ranges'**
  String get s90b5b7e33f;

  /// fi: Ohita kalleimmat tunnit
  ///
  /// In en, this message translates to:
  /// **'Skip the most expensive hours'**
  String get sa26ae27039;

  /// fi: Sään mukaan ennakoiva
  ///
  /// In en, this message translates to:
  /// **'Weather-based pre-heating'**
  String get scfd1a72ed5;

  /// fi: Lämmittää päivän halvimpina tunteina. Sopii varaavaan lämmitykseen ja lämminvesivaraajaan.
  ///
  /// In en, this message translates to:
  /// **'Heats in the cheapest hours of the day. For storage heating and water heaters.'**
  String get s2bd403874c;

  /// fi: Lämmittää normaalisti, mutta ohittaa päivän kalleimmat tunnit lyhyinä katkoina.
  ///
  /// In en, this message translates to:
  /// **'Heats normally but skips the most expensive hours in short breaks.'**
  String get se759c14061;

  /// fi: Esilämmittää ennen kallista tai kylmää jaksoa ja säästää kalliina tunteina. Tuntimäärä seuraa sääennustetta.
  ///
  /// In en, this message translates to:
  /// **'Pre-heats before expensive or cold spells and saves in expensive hours. The hours follow the forecast.'**
  String get s5cab118d44;

  /// fi: halpa tunti
  ///
  /// In en, this message translates to:
  /// **'cheap hour'**
  String get sa7480a9930;

  /// fi: odottaa halpaa tuntia
  ///
  /// In en, this message translates to:
  /// **'waiting for a cheap hour'**
  String get s50812672e5;

  /// fi: kallis tunti ohitetaan
  ///
  /// In en, this message translates to:
  /// **'skipping an expensive hour'**
  String get seb1c64d9f8;

  /// fi: normaali
  ///
  /// In en, this message translates to:
  /// **'normal'**
  String get s2e52a3d40e;

  /// fi: ei hintoja – normaali lämmitys
  ///
  /// In en, this message translates to:
  /// **'no prices – normal heating'**
  String get sf6d34efdd6;

  /// fi: lomatila
  ///
  /// In en, this message translates to:
  /// **'holiday mode'**
  String get s8c42ad8541;

  /// fi: lämmitetään paluuta varten
  ///
  /// In en, this message translates to:
  /// **'heating for your return'**
  String get sc3d8828060;

  /// fi: takka lämmittää
  ///
  /// In en, this message translates to:
  /// **'the fireplace heats'**
  String get s577b8c3cf1;

  /// fi: tarpeeksi lämmin
  ///
  /// In en, this message translates to:
  /// **'warm enough'**
  String get sbcd02dce0a;

  /// fi: turvaraja: liian kylmä
  ///
  /// In en, this message translates to:
  /// **'safety limit: too cold'**
  String get s22678639dc;

  /// fi: jäätymissuoja
  ///
  /// In en, this message translates to:
  /// **'frost protection'**
  String get s1e3f154a0a;

  /// fi: turvaraja: liian pitkä tauko
  ///
  /// In en, this message translates to:
  /// **'safety limit: off too long'**
  String get s1f2938edec;

  /// fi: esilämmitys
  ///
  /// In en, this message translates to:
  /// **'pre-heating'**
  String get s54fce2a7e8;

  /// fi: säästö kalliina aikana
  ///
  /// In en, this message translates to:
  /// **'saving while expensive'**
  String get s6b35f75e80;

  /// fi: Älykäs lämmitys ohjaa lämmitystä sähkön hinnan ja sään mukaan talosi lämmitystavalle sopivalla tavalla. Vastaa muutamaan
  ///
  /// In en, this message translates to:
  /// **'Smart heating controls heating by electricity price and weather, in a way that suits your heating type. Answer a few questions to get recommended settings.'**
  String get sdde7adcb29;

  /// fi: Aloita kartoitus
  ///
  /// In en, this message translates to:
  /// **'Start the survey'**
  String get s3d29895a40;

  /// fi: Takka-tila päällä
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode on'**
  String get sb0d738492d;

  /// fi: Takka-tila päällä klo {p0} asti
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode on until {p0}'**
  String sd1af5ba10d(String p0);

  /// fi: Lomatila päällä
  ///
  /// In en, this message translates to:
  /// **'Holiday mode on'**
  String get s48a7ba4933;

  /// fi: Älykäs lämmitys on pois päältä
  ///
  /// In en, this message translates to:
  /// **'Smart heating is off'**
  String get s10a95132ce;

  /// fi: Lämmitys toimii hinnan ja sään mukaan
  ///
  /// In en, this message translates to:
  /// **'Heating follows price and weather'**
  String get s035459d8bb;

  /// fi: Tarvitsee kotisillan: ota etäyhteys käyttöön kotona olevalla laitteella (Asetukset → Etäkäyttö).
  ///
  /// In en, this message translates to:
  /// **'Needs a home bridge: set up remote access on a device at home (Settings → Remote access).'**
  String get sbde5e80158;

  /// fi: Päivitä kotisilta (vaatii Molaplan 0.10.0).
  ///
  /// In en, this message translates to:
  /// **'Update the home bridge (needs Molaplan 0.10.0).'**
  String get s830cace8fe;

  /// fi: Toimii kotisillalla myös sovellus suljettuna.
  ///
  /// In en, this message translates to:
  /// **'Runs on the home bridge, also with the app closed.'**
  String get s495c887d23;

  /// fi: Lopeta takka-tila
  ///
  /// In en, this message translates to:
  /// **'Stop fireplace mode'**
  String get s7954d5fca9;

  /// fi: Takka lämmitetty
  ///
  /// In en, this message translates to:
  /// **'Fireplace lit'**
  String get sf44db20422;

  /// fi: Lomatila: muokkaa
  ///
  /// In en, this message translates to:
  /// **'Holiday: edit'**
  String get sd172900c2d;

  /// fi: Lisää ruutu kotinäytölle
  ///
  /// In en, this message translates to:
  /// **'Add a tile to the home screen'**
  String get sdb217dcf7f;

  /// fi: Ruutu lisätty kotinäytölle
  ///
  /// In en, this message translates to:
  /// **'Tile added to the home screen'**
  String get s52d3e04a46;

  /// fi: Lämmityslaitteet
  ///
  /// In en, this message translates to:
  /// **'Heating devices'**
  String get sdca3ad13dd;

  /// fi: Ei laitteita. Lisää ne kartoituksessa.
  ///
  /// In en, this message translates to:
  /// **'No devices. Add them in the survey.'**
  String get sc8c5e37f5d;

  /// fi: Lämmityksen ilmoitukset
  ///
  /// In en, this message translates to:
  /// **'Heating notifications'**
  String get sc6976fa352;

  /// fi: Kotisilta on liian vanha: päivitä se (Molaplan 0.10.0).
  ///
  /// In en, this message translates to:
  /// **'The home bridge is too old: update it (Molaplan 0.10.0).'**
  String get s1abda8b8f3;

  /// fi: Kotisiltaa ei ole yhdistetty.
  ///
  /// In en, this message translates to:
  /// **'No home bridge is paired.'**
  String get s8c3353e896;

  /// fi: Säännöt ja asetukset
  ///
  /// In en, this message translates to:
  /// **'Rules and settings'**
  String get s13a8a207ec;

  /// fi: Älykäs lämmitys käytössä
  ///
  /// In en, this message translates to:
  /// **'Smart heating on'**
  String get s697b47220e;

  /// fi: Muokkaa kartoitusta
  ///
  /// In en, this message translates to:
  /// **'Edit the survey'**
  String get s45cf6423f8;

  /// fi: Turvarajat
  ///
  /// In en, this message translates to:
  /// **'Safety limits'**
  String get sf5dbb363af;

  /// fi: Vähimmäislämpötila
  ///
  /// In en, this message translates to:
  /// **'Minimum temperature'**
  String get sf9cd32fb4f;

  /// fi: Jäätymissuoja
  ///
  /// In en, this message translates to:
  /// **'Frost protection'**
  String get sfb0553315b;

  /// fi: Lämmitys aina päälle alle {p0} °C:ssa.
  ///
  /// In en, this message translates to:
  /// **'Heating always on below {p0} °C.'**
  String s9097fb518a(String p0);

  /// fi: Pisin sallittu tauko (kaikki)
  ///
  /// In en, this message translates to:
  /// **'Longest allowed break (all)'**
  String get s5d37a7088b;

  /// fi: laitteen mukaan
  ///
  /// In en, this message translates to:
  /// **'per device'**
  String get sb0bb55d6e5;

  /// fi: Turvarajat ohittavat hinnan, lomatilan ja takka-tilan. Vähimmäislämpötila ja jäätymissuoja tarvitsevat lämpöanturin.
  ///
  /// In en, this message translates to:
  /// **'Safety limits override price, holiday and fireplace mode. The minimum temperature and frost protection need a temperature sensor.'**
  String get s17bf76025c;

  /// fi: Takka
  ///
  /// In en, this message translates to:
  /// **'Fireplace'**
  String get s109c7fb7a2;

  /// fi: Takka-tilan kesto
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode length'**
  String get s1c15091948;

  /// fi: Termostaattien lasku takka-tilassa
  ///
  /// In en, this message translates to:
  /// **'Thermostats lowered in fireplace mode'**
  String get se150ae5acd;

  /// fi: Takan lähellä oleva lämpöanturi
  ///
  /// In en, this message translates to:
  /// **'Temperature sensor near the fireplace'**
  String get s161f61412e;

  /// fi: Laitteen anturi
  ///
  /// In en, this message translates to:
  /// **'The device sensor'**
  String get s81b30d570b;

  /// fi: Lämmityksen ilmoitukset (ntfy)
  ///
  /// In en, this message translates to:
  /// **'Heating notifications (ntfy)'**
  String get s71e80a04a2;

  /// fi: Sama ilmoituskanava ja hiljaiset ajat kuin automaatioissa.
  ///
  /// In en, this message translates to:
  /// **'The same notification channel and quiet hours as automations.'**
  String get s5ab83c2574;

  /// fi: Poista älykäs lämmitys
  ///
  /// In en, this message translates to:
  /// **'Remove smart heating'**
  String get s32d9d66ffd;

  /// fi: Poistetaanko älykäs lämmitys?
  ///
  /// In en, this message translates to:
  /// **'Remove smart heating?'**
  String get s0f995f3d5d;

  /// fi: Laitteet jäävät siihen tilaan, jossa ne ovat nyt.
  ///
  /// In en, this message translates to:
  /// **'The devices stay in their current state.'**
  String get scc27c1739f;

  /// fi: Sähkölämmitystä vähennetään, koska takka lämmittää. Turvarajat ovat silti voimassa.
  ///
  /// In en, this message translates to:
  /// **'Electric heating is reduced while the fireplace heats. Safety limits still apply.'**
  String get s3bf2d3643c;

  /// fi: Lopeta aiemmin, kun huone alkaa jäähtyä
  ///
  /// In en, this message translates to:
  /// **'End earlier when the room starts to cool'**
  String get s58b2cdb4e2;

  /// fi: Käynnistä
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get s66ce56ca38;

  /// fi: Poissa ollessa huoneet pidetään viileämpinä, ja lämminvesivaraaja lämmitetään vasta paluuta edeltävänä yönä. Turvarajat
  ///
  /// In en, this message translates to:
  /// **'While you are away rooms are kept cooler, and the water heater is heated only the night before you return. Safety limits and frost protection apply.'**
  String get s632723d95f;

  /// fi: Alkaa
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get s2ebf172fad;

  /// fi: Paluupäivä
  ///
  /// In en, this message translates to:
  /// **'Return day'**
  String get s0ba54fbd61;

  /// fi: Lämpötila poissa ollessa
  ///
  /// In en, this message translates to:
  /// **'Temperature while away'**
  String get s025d1c3db1;

  /// fi: Valitse lämpötila-anturi
  ///
  /// In en, this message translates to:
  /// **'Choose the temperature sensor'**
  String get se34a337d6d;

  /// fi: Voit käyttää mitä tahansa lämpötilaa näyttävää ruutua: Shellyn lisäanturi, Zigbee tai Home Assistant, Airthings, Bosch,
  ///
  /// In en, this message translates to:
  /// **'You can use any tile that shows a temperature: a Shelly add-on sensor, Zigbee or Home Assistant, Airthings, Bosch, Tuya…'**
  String get scfa5e7964d;

  /// fi: Lämpötilaruutua ei ole vielä. Lisää ensin laite, jolla on lämpötila-anturi.
  ///
  /// In en, this message translates to:
  /// **'There is no temperature tile yet. Add a device with a temperature sensor first.'**
  String get s20ec3fcfd8;

  /// fi: Lisää uusi laite
  ///
  /// In en, this message translates to:
  /// **'Add a new device'**
  String get sf37075044e;

  /// fi: Ei anturia
  ///
  /// In en, this message translates to:
  /// **'No sensor'**
  String get se68cc54085;

  /// fi: Ohjaustapa
  ///
  /// In en, this message translates to:
  /// **'Control mode'**
  String get s093677b5f1;

  /// fi: Hinnan mukaan
  ///
  /// In en, this message translates to:
  /// **'By price'**
  String get sa6195c2696;

  /// fi: Lämpötilan mukaan
  ///
  /// In en, this message translates to:
  /// **'By temperature'**
  String get s9d6a4787c0;

  /// fi: Lämmitys seuraa mitattua lämpötilaa kuin termostaatti. Hintasäännöt vain siirtävät tavoitetta: halvoilla tunneilla ylös,
  ///
  /// In en, this message translates to:
  /// **'Heating follows the measured temperature like a thermostat. The price rules only move the setpoint: up in cheap hours, down in expensive ones (if set).'**
  String get s84cf10acfd;

  /// fi: Lämmitys noudattaa sähkön hintaa ja säätä. Lämpötila-anturi on valinnainen ja antaa turvarajat.
  ///
  /// In en, this message translates to:
  /// **'Heating follows the electricity price and the weather. A temperature sensor is optional and gives the safety limits.'**
  String get sdf9dc612a6;

  /// fi: Valitse lämpötila-anturi
  ///
  /// In en, this message translates to:
  /// **'Choose a temperature sensor'**
  String get s01c555401a;

  /// fi: Lämpötilaohjaus tarvitsee anturin. Ilman sitä lämmitys noudattaa hintaohjausta.
  ///
  /// In en, this message translates to:
  /// **'Temperature control needs a sensor. Without one, heating follows the price schedule.'**
  String get s249140bfd0;

  /// fi: Hintasäännöt
  ///
  /// In en, this message translates to:
  /// **'Price rules'**
  String get sf9cbe76823;

  /// fi:  (suositus)
  ///
  /// In en, this message translates to:
  /// **' (recommended)'**
  String get s8e6c8ffabb;

  /// fi: Lämmitystunteja päivässä
  ///
  /// In en, this message translates to:
  /// **'Heating hours a day'**
  String get s86c45674db;

  /// fi: Ohitettavia kalleimpia tunteja
  ///
  /// In en, this message translates to:
  /// **'Most expensive hours skipped'**
  String get sbd3dbfd7e9;

  /// fi: Tämän päivän hintaraja: ohitetaan, kun hinta on vähintään {p0} c/kWh.
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s price limit: skipped when the price is {p0} c/kWh or more.'**
  String s1f32a43166(String p0);

  /// fi: Tämän päivän hintaraja: päällä, kun hinta on enintään {p0} c/kWh.
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s price limit: on when the price is {p0} c/kWh or less.'**
  String s3c010a59e8(String p0);

  /// fi: Tavoite alas kalliilla tunneilla
  ///
  /// In en, this message translates to:
  /// **'Setpoint down in expensive hours'**
  String get s68b3688217;

  /// fi: ei käytössä
  ///
  /// In en, this message translates to:
  /// **'not used'**
  String get s108a800ffc;

  /// fi: Tavoite ylös halvoilla tunneilla
  ///
  /// In en, this message translates to:
  /// **'Setpoint up in cheap hours'**
  String get sb35d5f8afd;

  /// fi: Lämpötilarajat
  ///
  /// In en, this message translates to:
  /// **'Temperature limits'**
  String get sd82fb84485;

  /// fi: Tavoitelämpötila
  ///
  /// In en, this message translates to:
  /// **'Setpoint'**
  String get s510de048b8;

  /// fi: Mukavuuslämpötila
  ///
  /// In en, this message translates to:
  /// **'Comfort temperature'**
  String get s017c87df20;

  /// fi: Vähimmäislämpötila (turvaraja)
  ///
  /// In en, this message translates to:
  /// **'Minimum temperature (safety limit)'**
  String get sdb145487c3;

  /// fi: Ei anturia – turvarajat eivät ole käytössä
  ///
  /// In en, this message translates to:
  /// **'No sensor – the safety limits are not active'**
  String get s0c40392b6a;

  /// fi: ei vastaa
  ///
  /// In en, this message translates to:
  /// **'not answering'**
  String get scf2e61da2c;

  /// fi: Viiveet
  ///
  /// In en, this message translates to:
  /// **'Delays'**
  String get s6a37cdb806;

  /// fi: Pisin tauko kerrallaan
  ///
  /// In en, this message translates to:
  /// **'Longest break at a time'**
  String get s1f3d8e19f4;

  /// fi: Vähimmäisajat: ei rajoitusta (Edistyneet).
  ///
  /// In en, this message translates to:
  /// **'Minimum times: no limit (Advanced).'**
  String get s061c02e7ea;

  /// fi: Vähimmäisaika päällä {p0} min, pois {p1} min.
  ///
  /// In en, this message translates to:
  /// **'Minimum on time {p0} min, off {p1} min.'**
  String se7bc20343e(String p0, String p1);

  /// fi: Ohjaus käytössä
  ///
  /// In en, this message translates to:
  /// **'Control on'**
  String get sa35e3e99f4;

  /// fi: Hystereesi (kuollut alue)
  ///
  /// In en, this message translates to:
  /// **'Hysteresis (deadband)'**
  String get sd8084282ca;

  /// fi: Päälle alle {p0} °C, pois yli {p1} °C (hinnan siirtämättä).
  ///
  /// In en, this message translates to:
  /// **'On below {p0} °C, off above {p1} °C (before any price shift).'**
  String s3bded44765(String p0, String p1);

  /// fi: Kun anturi ei vastaa
  ///
  /// In en, this message translates to:
  /// **'When the sensor is not answering'**
  String get s3df29f3fca;

  /// fi: Noudata hintaohjausta
  ///
  /// In en, this message translates to:
  /// **'Follow the price schedule'**
  String get s5f9a56b766;

  /// fi: Pidä päällä
  ///
  /// In en, this message translates to:
  /// **'Keep on'**
  String get scc764046c2;

  /// fi: Pidä pois
  ///
  /// In en, this message translates to:
  /// **'Keep off'**
  String get sd50c0e6c4d;

  /// fi: Vähimmäisaika päällä
  ///
  /// In en, this message translates to:
  /// **'Minimum on time'**
  String get s64540136ff;

  /// fi: ei rajaa
  ///
  /// In en, this message translates to:
  /// **'no limit'**
  String get s5e55e17318;

  /// fi: Vähimmäisaika pois
  ///
  /// In en, this message translates to:
  /// **'Minimum off time'**
  String get s21713a2177;

  /// fi: Vähennä takka-tilassa
  ///
  /// In en, this message translates to:
  /// **'Reduce in fireplace mode'**
  String get s347ce4c3d2;

  /// fi: Termostaatin tavoitelämpö asetetaan tämän mukaan; termostaatin oma lämpötila on mukavuuslämpötila.
  ///
  /// In en, this message translates to:
  /// **'The thermostat target is set by this; the thermostat\'\'s own temperature is the comfort temperature.'**
  String get s6f88da6bab;

  /// fi: Arvio: noin {p0} kWh vuorokaudessa 0 °C:n pakkasella (koko talo).
  ///
  /// In en, this message translates to:
  /// **'Estimate: about {p0} kWh a day at 0 °C (whole house).'**
  String s87cdb30352(String p0);

  /// fi: Millä talo lämpiää? Valitse kaikki.
  ///
  /// In en, this message translates to:
  /// **'How is the house heated? Choose all.'**
  String get sc161d1f9d9;

  /// fi: Eristys
  ///
  /// In en, this message translates to:
  /// **'Insulation'**
  String get saac00e587b;

  /// fi: Heikko
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get s9f103f81c0;

  /// fi: Tavallinen
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get sd51256a0f5;

  /// fi: Hyvä
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get sd5ebaf8a4c;

  /// fi: Lämmitetty pinta-ala
  ///
  /// In en, this message translates to:
  /// **'Heated area'**
  String get sf584870588;

  /// fi: Sallittu lämpötilan vaihtelu
  ///
  /// In en, this message translates to:
  /// **'Allowed temperature swing'**
  String get s97235bfadb;

  /// fi: Mitä enemmän lämpö saa vaihdella, sitä enemmän lämmitystä voidaan siirtää halvoille tunneille.
  ///
  /// In en, this message translates to:
  /// **'The more the temperature may vary, the more heating can move to cheap hours.'**
  String get s6df5f06d38;

  /// fi: Talossa on takka tai varaava uuni
  ///
  /// In en, this message translates to:
  /// **'The house has a fireplace or storing stove'**
  String get s07077e2778;

  /// fi: Valitse, mikä laite ohjaa kutakin lämmitystä: rele tai pistorasia (päälle/pois) tai Molaplanin termostaatti (tavoitelämp
  ///
  /// In en, this message translates to:
  /// **'Choose what controls each heating: a relay or plug (on/off) or a Molaplan thermostat (target temperature).'**
  String get sab28f61fad;

  /// fi: Ei vielä ohjattavia laitteita. Lisää ensin rele tai termostaatti; voit palata kartoitukseen myöhemmin.
  ///
  /// In en, this message translates to:
  /// **'No controllable devices yet. Add a relay or a thermostat first; you can come back to the survey later.'**
  String get s90ae2f4451;

  /// fi: Ohjaava laite
  ///
  /// In en, this message translates to:
  /// **'Controlling device'**
  String get sf7b3494ee1;

  /// fi: Ei ohjata
  ///
  /// In en, this message translates to:
  /// **'Not controlled'**
  String get se7ffc07763;

  /// fi: Termostaatti: {p0}
  ///
  /// In en, this message translates to:
  /// **'Thermostat: {p0}'**
  String s5835dc3308(String p0);

  /// fi: Huoneen lämpöanturi (suositus)
  ///
  /// In en, this message translates to:
  /// **'Room temperature sensor (recommended)'**
  String get s075ddc6f0d;

  /// fi: Suositellut asetukset
  ///
  /// In en, this message translates to:
  /// **'Recommended settings'**
  String get s016c02be08;

  /// fi: Ohitetaan {p0} kalleinta tuntia päivässä, enintään {p1} h kerrallaan.
  ///
  /// In en, this message translates to:
  /// **'Skips the {p0} most expensive hours a day, at most {p1} h at a time.'**
  String s013bbafbec(String p0, String p1);

  /// fi: Noin {p0} lämmitystuntia päivässä 0 °C:ssa.
  ///
  /// In en, this message translates to:
  /// **'About {p0} heating hours a day at 0 °C.'**
  String se67c73d855(String p0);

  /// fi: Ei ohjaavaa laitetta – ei ohjata.
  ///
  /// In en, this message translates to:
  /// **'No controlling device – not controlled.'**
  String get sb7524487f9;

  /// fi: Paina "Takka lämmitetty", kun takka on lämmitetty: sähkölämmitystä vähennetään 12–24 tunniksi tai kunnes anturi näyttää
  ///
  /// In en, this message translates to:
  /// **'Tap \"Fireplace lit\" after lighting it: electric heating is reduced for 12–24 h or until the sensor shows cooling.'**
  String get sad1fbf7d03;

  /// fi: Voit muuttaa ohjaustapaa ja lukuja myöhemmin laitteen sivulla kohdassa Edistyneet.
  ///
  /// In en, this message translates to:
  /// **'You can change the method and numbers later on the device page under Advanced.'**
  String get sfb41f90571;

  /// fi: Lämmitys
  ///
  /// In en, this message translates to:
  /// **'Heating'**
  String get sa3a093e55e;

  /// fi: Talo
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get s1706667040;

  /// fi: Laitteet
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get s84005ad77c;

  /// fi: Suositus
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get s023d14fd87;

  /// fi: Kartoitus {p0}/4: {p1}
  ///
  /// In en, this message translates to:
  /// **'Survey {p0}/4: {p1}'**
  String sfde6663859(String p0, String p1);

  /// fi: Ota käyttöön
  ///
  /// In en, this message translates to:
  /// **'Use these'**
  String get sda588a203b;

  /// fi: ei vielä
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get sba1684ff6c;

  /// fi: Ajohistoria
  ///
  /// In en, this message translates to:
  /// **'Run history'**
  String get sef20071510;

  /// fi: Skriptit
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get s9f1334d4e2;

  /// fi: Tilannekuvat
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get s6b7c1c52da;

  /// fi: Ajetaan tällä kotisillalla, myös kun sovellus on kiinni.
  ///
  /// In en, this message translates to:
  /// **'Running on this home bridge, also when the app is closed.'**
  String get s4f745952b8;

  /// fi: Ajetaan kotisillalla – toimii, vaikka sovellus olisi kiinni.
  ///
  /// In en, this message translates to:
  /// **'Running on the home bridge – works even when the app is closed.'**
  String get s99cbed55fd;

  /// fi: Kotisilta on vanha versio: päivitä se, niin automaatiot toimivat myös sovelluksen ollessa kiinni. Nyt ajetaan tässä sove
  ///
  /// In en, this message translates to:
  /// **'The home bridge is an old version: update it so automations also run while the app is closed. Running in this app for now.'**
  String get s0247948956;

  /// fi: Ajetaan tässä sovelluksessa, kun se on auki. Kotisilta ajaa ne myös sovelluksen ollessa kiinni.
  ///
  /// In en, this message translates to:
  /// **'Running in this app while it is open. A home bridge runs them while the app is closed.'**
  String get s21fae60578;

  /// fi: Automaatiot ovat pois päältä tällä laitteella.
  ///
  /// In en, this message translates to:
  /// **'Automations are off on this device.'**
  String get s66c54e2286;

  /// fi: Mikä on kotisilta?
  ///
  /// In en, this message translates to:
  /// **'What is a home bridge?'**
  String get s57f6ce1c7f;

  /// fi: ma ti ke to pe la su
  ///
  /// In en, this message translates to:
  /// **'Mon Tue Wed Thu Fri Sat Sun'**
  String get s4057f67774;

  /// fi: (laite puuttuu)
  ///
  /// In en, this message translates to:
  /// **'(device missing)'**
  String get s456d234874;

  /// fi: päälle
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get sf3779b50c6;

  /// fi: Klo
  ///
  /// In en, this message translates to:
  /// **'At'**
  String get s7c3e905972;

  /// fi: Auringonnousu
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get s61637a44e4;

  /// fi: Auringonlasku
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sa0d5958b56;

  /// fi: {p0} halvinta tuntia
  ///
  /// In en, this message translates to:
  /// **'{p0} cheapest hours'**
  String s467fd3c653(String p0);

  /// fi: Hinta yli {p0} c/kWh
  ///
  /// In en, this message translates to:
  /// **'Price above {p0} c/kWh'**
  String s65660a4b23(String p0);

  /// fi: Hinta alle {p0} c/kWh
  ///
  /// In en, this message translates to:
  /// **'Price below {p0} c/kWh'**
  String sba8fa4af37(String p0);

  /// fi: Ulkona
  ///
  /// In en, this message translates to:
  /// **'Outdoors'**
  String get s3324b26519;

  /// fi: {p0} ei vastaa {p1} min
  ///
  /// In en, this message translates to:
  /// **'{p0} offline {p1} min'**
  String sf3c2cf0323(String p0, String p1);

  /// fi: Valmiit
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get s835865fd04;

  /// fi: Ei vielä automaatioita. Aloita valmiista: esim. "{p0}" tai "{p1}".
  ///
  /// In en, this message translates to:
  /// **'No automations yet. Start from a template, e.g. \"{p0}\" or \"{p1}\".'**
  String s73d042449b(String p0, String p1);

  /// fi: Nimetön
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get s8039add5ed;

  /// fi: Ei ajoja vielä.
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get sf2d3a43ee8;

  /// fi: Valmiit automaatiot
  ///
  /// In en, this message translates to:
  /// **'Ready-made automations'**
  String get s5c7338ab38;

  /// fi: Valitse verkon teho (+osto / −myynti)
  ///
  /// In en, this message translates to:
  /// **'Choose the grid power (+import / −export)'**
  String get sa50094ffdb;

  /// fi: Valitse laturi (lataus päälle/pois)
  ///
  /// In en, this message translates to:
  /// **'Choose the charger (charging on/off)'**
  String get s3cc31bcfdc;

  /// fi: Valitse laite
  ///
  /// In en, this message translates to:
  /// **'Choose the device'**
  String get s354eb362d8;

  /// fi: Valitse laitteet
  ///
  /// In en, this message translates to:
  /// **'Choose the devices'**
  String get s73a65d7dff;

  /// fi: Ei laitteita vielä.
  ///
  /// In en, this message translates to:
  /// **'No devices yet.'**
  String get s6bc0df13b3;

  /// fi: Uusi automaatio
  ///
  /// In en, this message translates to:
  /// **'New automation'**
  String get s90db0cb9e0;

  /// fi: Muokkaa automaatiota
  ///
  /// In en, this message translates to:
  /// **'Edit automation'**
  String get s3aeb373060;

  /// fi: Poistetaanko automaatio?
  ///
  /// In en, this message translates to:
  /// **'Delete the automation?'**
  String get sac3c555554;

  /// fi: Mikä käynnistää automaation
  ///
  /// In en, this message translates to:
  /// **'What starts the automation'**
  String get s53879bce24;

  /// fi: Jos (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Only if (optional)'**
  String get s179f389617;

  /// fi: Kaikkien ehtojen pitää täyttyä
  ///
  /// In en, this message translates to:
  /// **'All conditions must hold'**
  String get s803ff4f73b;

  /// fi: Lisää ehto
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get sd930bdad70;

  /// fi: Tee
  ///
  /// In en, this message translates to:
  /// **'Do'**
  String get s6f21edea24;

  /// fi: Toiminnot järjestyksessä
  ///
  /// In en, this message translates to:
  /// **'Actions in order'**
  String get scbe17b6bf8;

  /// fi: Lisäasetukset
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get secee53bdd2;

  /// fi: Vähintään minuuttia ajojen välillä
  ///
  /// In en, this message translates to:
  /// **'Minimum minutes between runs'**
  String get scb62f41105;

  /// fi: Estää esim. heiluvaa anturia lähettämästä kymmeniä ilmoituksia.
  ///
  /// In en, this message translates to:
  /// **'Stops e.g. a flapping sensor from sending dozens of notifications.'**
  String get s643b680e89;

  /// fi: Ilmoitus kun tämä automaatio laukeaa
  ///
  /// In en, this message translates to:
  /// **'Notify when this automation runs'**
  String get s0b70275d6c;

  /// fi: Oletus
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get s35e8cce8a9;

  /// fi: Testaa nyt
  ///
  /// In en, this message translates to:
  /// **'Test now'**
  String get s4c4ab28899;

  /// fi: Ajettu: {p0}
  ///
  /// In en, this message translates to:
  /// **'Ran: {p0}'**
  String s7956c29b83(String p0);

  /// fi: (ei laitteita)
  ///
  /// In en, this message translates to:
  /// **'(no devices)'**
  String get s6e85ff5983;

  /// fi: >
  ///
  /// In en, this message translates to:
  /// **'>'**
  String get sa627de5699;

  /// fi: <
  ///
  /// In en, this message translates to:
  /// **'<'**
  String get s24801cdec0;

  /// fi: >=
  ///
  /// In en, this message translates to:
  /// **'≥'**
  String get sef6eef049e;

  /// fi: <=
  ///
  /// In en, this message translates to:
  /// **'≤'**
  String get s5d759b1fd0;

  /// fi: ==
  ///
  /// In en, this message translates to:
  /// **'='**
  String get sc67c2076cc;

  /// fi: !=
  ///
  /// In en, this message translates to:
  /// **'≠'**
  String get sf69ef2bd3e;

  /// fi: Laitteen arvo
  ///
  /// In en, this message translates to:
  /// **'Device value'**
  String get sc300fc12e3;

  /// fi: Laitteen tila (päälle/pois, anturi)
  ///
  /// In en, this message translates to:
  /// **'Device state (on/off, sensor)'**
  String get sbab0e0dc9d;

  /// fi: Kellonaika
  ///
  /// In en, this message translates to:
  /// **'Time of day'**
  String get s76de9025a1;

  /// fi: Auringonnousu / -lasku
  ///
  /// In en, this message translates to:
  /// **'Sunrise / sunset'**
  String get s04c0bcdd51;

  /// fi: Sää (ulkolämpötila)
  ///
  /// In en, this message translates to:
  /// **'Weather (outdoor temperature)'**
  String get s869f0d57af;

  /// fi: Laite ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Device not answering'**
  String get sa4261f6e35;

  /// fi: Tyyppi
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get se0a362c060;

  /// fi: Kun se menee
  ///
  /// In en, this message translates to:
  /// **'When it turns'**
  String get s4f62fd1f09;

  /// fi: päälle / hälyttää
  ///
  /// In en, this message translates to:
  /// **'on / alarm'**
  String get sab64be3b87;

  /// fi: pois / rauhoittuu
  ///
  /// In en, this message translates to:
  /// **'off / calm'**
  String get sbfd08915bd;

  /// fi: Kellonaika (HH:MM)
  ///
  /// In en, this message translates to:
  /// **'Time (HH:MM)'**
  String get s0aaa16b331;

  /// fi: Tapahtuma
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get s9b4b2b3129;

  /// fi: Siirto minuutteina (−60…60)
  ///
  /// In en, this message translates to:
  /// **'Offset in minutes (−60…60)'**
  String get s8c6de5d661;

  /// fi: Milloin
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get s59b3e665bf;

  /// fi: Hinta alle
  ///
  /// In en, this message translates to:
  /// **'Price below'**
  String get s6a23c4a83f;

  /// fi: Hinta yli
  ///
  /// In en, this message translates to:
  /// **'Price above'**
  String get s49083cabf7;

  /// fi: Päivän halvimmat tunnit
  ///
  /// In en, this message translates to:
  /// **'The cheapest hours of the day'**
  String get s411924155f;

  /// fi: Tuntien määrä
  ///
  /// In en, this message translates to:
  /// **'Number of hours'**
  String get s04dc35851a;

  /// fi: Minuuttia
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get s6f22fd8c19;

  /// fi: Ei valintaa = joka päivä
  ///
  /// In en, this message translates to:
  /// **'None selected = every day'**
  String get s32fa6270c8;

  /// fi: Kellonaikaväli
  ///
  /// In en, this message translates to:
  /// **'Time window'**
  String get s966e223f86;

  /// fi: Viikonpäivät
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get s45aae9c551;

  /// fi: Laitteen tila / arvo
  ///
  /// In en, this message translates to:
  /// **'Device state / value'**
  String get sf05bf9c751;

  /// fi: Ulkolämpötila
  ///
  /// In en, this message translates to:
  /// **'Outdoor temperature'**
  String get sb74370fc1e;

  /// fi: Pimeää / valoisaa
  ///
  /// In en, this message translates to:
  /// **'Dark / light'**
  String get s585b4c519f;

  /// fi: Ehto
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get s6019108a01;

  /// fi: Alkaen
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get sc26d444f90;

  /// fi: Asti
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get s796739363a;

  /// fi: Mitä verrataan
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get s39d9f766c6;

  /// fi: Tila päällä/pois
  ///
  /// In en, this message translates to:
  /// **'State on/off'**
  String get sa56aea2cf9;

  /// fi: Lukuarvo
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get sc2521b6b15;

  /// fi: Tila
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get sfffb54daf4;

  /// fi: päällä
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get s609cb4c5f9;

  /// fi: Nyt on
  ///
  /// In en, this message translates to:
  /// **'Now is'**
  String get s3d34e477c2;

  /// fi: halpa tunti
  ///
  /// In en, this message translates to:
  /// **'a cheap hour'**
  String get s099666eafe;

  /// fi: ei halpa tunti
  ///
  /// In en, this message translates to:
  /// **'not a cheap hour'**
  String get s08b96dd0f7;

  /// fi: Halvinta tuntia / vrk
  ///
  /// In en, this message translates to:
  /// **'Cheapest hours / day'**
  String get sd7232b8464;

  /// fi: pimeää
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get se2b3e45118;

  /// fi: valoisaa
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get s709da04ca2;

  /// fi: Lisää toiminto
  ///
  /// In en, this message translates to:
  /// **'Add action'**
  String get s723d015dc1;

  /// fi: Aja tilannekuva
  ///
  /// In en, this message translates to:
  /// **'Run a scene'**
  String get s1f6962ba39;

  /// fi: Aja skripti
  ///
  /// In en, this message translates to:
  /// **'Run a script'**
  String get s02df6d430a;

  /// fi: Lähetä ilmoitus
  ///
  /// In en, this message translates to:
  /// **'Send a notification'**
  String get sed67c16508;

  /// fi: Odota
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get s654489bb29;

  /// fi: Odota kunnes
  ///
  /// In en, this message translates to:
  /// **'Wait until'**
  String get sf216517af2;

  /// fi: Jos / muuten
  ///
  /// In en, this message translates to:
  /// **'If / else'**
  String get sde1657b024;

  /// fi: Toiminto
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get sbc8e165fbf;

  /// fi: Aseta arvo
  ///
  /// In en, this message translates to:
  /// **'Set value'**
  String get s7a544fe304;

  /// fi: Paina
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get s929344a68b;

  /// fi: Tilannekuva
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get s02cfe06e04;

  /// fi: (ei tilannekuvia)
  ///
  /// In en, this message translates to:
  /// **'(no scenes)'**
  String get sdb235c3ced;

  /// fi: (ei skriptejä)
  ///
  /// In en, this message translates to:
  /// **'(no scripts)'**
  String get s4f330bfcfb;

  /// fi: Teksti
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get s34900f9d58;

  /// fi: {summary} = sää, sähkö ja kodin tila
  ///
  /// In en, this message translates to:
  /// **'\'{summary} = weather, price and home state\''**
  String get s3c2ee8fe0d;

  /// fi: 1 – hiljainen
  ///
  /// In en, this message translates to:
  /// **'1 – silent'**
  String get sb55a08c07c;

  /// fi: 2 – matala
  ///
  /// In en, this message translates to:
  /// **'2 – low'**
  String get s423418208e;

  /// fi: 3 – normaali
  ///
  /// In en, this message translates to:
  /// **'3 – normal'**
  String get sbad27a6b89;

  /// fi: 4 – korkea
  ///
  /// In en, this message translates to:
  /// **'4 – high'**
  String get s8c17000b91;

  /// fi: 5 – kiireellinen (myös hiljaisena aikana)
  ///
  /// In en, this message translates to:
  /// **'5 – urgent (also in quiet hours)'**
  String get sa0738def3a;

  /// fi: Napautus avaa
  ///
  /// In en, this message translates to:
  /// **'Tap opens'**
  String get sb33001c92e;

  /// fi: sovelluksen
  ///
  /// In en, this message translates to:
  /// **'the app'**
  String get s07d7410408;

  /// fi: Sekuntia
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get sfb10dd528e;

  /// fi: Enintään sekuntia
  ///
  /// In en, this message translates to:
  /// **'At most seconds'**
  String get sd7ab969914;

  /// fi: Niin
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get sccfe5a0d41;

  /// fi: Muuten
  ///
  /// In en, this message translates to:
  /// **'Else'**
  String get s2d983e951b;

  /// fi: Uusi skripti
  ///
  /// In en, this message translates to:
  /// **'New script'**
  String get s2c7a2bbac1;

  /// fi: Skripti on lista vaiheita: ohjaa laitetta, odota, lähetä ilmoitus, jos/muuten… Aja se napista, automaatiosta tai etänä (
  ///
  /// In en, this message translates to:
  /// **'A script is a list of steps: control a device, wait, notify, if/else… Run it from a button, an automation or remotely (iPhone Shortcut).'**
  String get s5b2dd17cbc;

  /// fi: Aja
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get se9ee46a9c8;

  /// fi: Lisää
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get s45fbc06cdf;

  /// fi: Lisää painike etusivulle
  ///
  /// In en, this message translates to:
  /// **'Add a button to the front page'**
  String get s0557e03436;

  /// fi: Edistynyt
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sfd2d047cb2;

  /// fi: {p0} vaihetta
  ///
  /// In en, this message translates to:
  /// **'{p0} steps'**
  String s766b50721b(String p0);

  /// fi: etäajo
  ///
  /// In en, this message translates to:
  /// **'remote'**
  String get s061d1b874b;

  /// fi: viimeksi
  ///
  /// In en, this message translates to:
  /// **'last'**
  String get s049d71f971;

  /// fi: Painike lisätty näkymään {p0}
  ///
  /// In en, this message translates to:
  /// **'Button added to {p0}'**
  String sdae343a445(String p0);

  /// fi: Muokkaa skriptiä
  ///
  /// In en, this message translates to:
  /// **'Edit script'**
  String get sb886978015;

  /// fi: Ajoloki
  ///
  /// In en, this message translates to:
  /// **'Run log'**
  String get scc2c1e2508;

  /// fi: Poistetaanko skripti?
  ///
  /// In en, this message translates to:
  /// **'Delete the script?'**
  String get sacf2fbc495;

  /// fi: Vaiheet
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get s01de653429;

  /// fi: Koodi
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get s01d3c353e2;

  /// fi: Molaplan-skripti
  ///
  /// In en, this message translates to:
  /// **'Molaplan script'**
  String get s637ae4dbf4;

  /// fi: Funktiot: get set on off toggle wait notify scene price cheapest temp time hour weekday log. Ei tiedosto- eikä verkkoyht
  ///
  /// In en, this message translates to:
  /// **'Functions: get set on off toggle wait notify scene price cheapest temp time hour weekday log. No file or network access; 10 min time limit.'**
  String get sea09cb0d3b;

  /// fi: Ulkoinen käynnistys (PIN) on päällä
  ///
  /// In en, this message translates to:
  /// **'External trigger (PIN) is on'**
  String get s4436dfd836;

  /// fi: Ulkoinen käynnistys, esim. iPhonen Pikakomennot
  ///
  /// In en, this message translates to:
  /// **'External trigger, e.g. iPhone Shortcuts'**
  String get s759ff4cada;

  /// fi: Ulkoinen käynnistys (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'External trigger (optional)'**
  String get s420f3ec828;

  /// fi: Skriptin nappi toimii ilman tätä: se ajaa skriptin sovelluksessa, ja kodin ulkopuolelta automaattisesti etäkäytön kautta
  ///
  /// In en, this message translates to:
  /// **'The script\'\'s button works without this: it runs the script in the app, and through remote access automatically when you are away. You only need this to start the script from outside Molaplan, e.g. iPhone Shortcuts.'**
  String get sb3cef805ee;

  /// fi: Salli käynnistys ulkopuolelta (PIN)
  ///
  /// In en, this message translates to:
  /// **'Allow starting from outside (PIN)'**
  String get sb6e92eacba;

  /// fi: Viesti ntfy-osoitteeseen tai iPhonen Pikakomento käynnistää skriptin PIN-koodilla.
  ///
  /// In en, this message translates to:
  /// **'A message to the ntfy address or an iPhone Shortcut starts the script with the PIN.'**
  String get sa1692aa719;

  /// fi: Etäajon PIN (vähintään 4 merkkiä)
  ///
  /// In en, this message translates to:
  /// **'Remote PIN (at least 4 characters)'**
  String get s0a5410ea4f;

  /// fi: Lähetä viesti "run {p0} <PIN>" osoitteeseen {p1}
  /// iPhonen Pikakomennot: "Hae URL:n sisältö" → {p2}, menetelmä POST, runko
  ///
  /// In en, this message translates to:
  /// **'Send \"run {p0} <PIN>\" to {p1}\niPhone Shortcuts: \"Get Contents of URL\" → {p1}, method POST, body: run {p0} <PIN>'**
  String sceba001122(String p0, String p1, String p2, String p3);

  /// fi: Kopioi URL
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get seff0aac16e;

  /// fi: Ajettu
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sff9b69c6ca;

  /// fi: Painike sovelluksessa
  ///
  /// In en, this message translates to:
  /// **'Button in the app'**
  String get sa32d82e779;

  /// fi: Painikkeella ajat skriptin yhdellä napautuksella. Se toimii kotona ja myös kodin ulkopuolelta kotisillan kautta – Pikako
  ///
  /// In en, this message translates to:
  /// **'The button runs the script with one tap. It works at home and also away from home through the home bridge – no Shortcuts needed.'**
  String get s65fc3dd69a;

  /// fi: Painike näkymässä {p0}
  ///
  /// In en, this message translates to:
  /// **'Button in the view {p0}'**
  String s89638a5b8e(String p0);

  /// fi: Lisää uusi painike
  ///
  /// In en, this message translates to:
  /// **'Add another button'**
  String get s509056a76d;

  /// fi: Painike luodaan, kun tallennat.
  ///
  /// In en, this message translates to:
  /// **'The button is created when you save.'**
  String get s0f8939787f;

  /// fi: Näkymä
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get s5a8c602b42;

  /// fi: Mihin näkymään painike lisätään?
  ///
  /// In en, this message translates to:
  /// **'Which view gets the button?'**
  String get se49d14ff44;

  /// fi: Tallenna nykytila
  ///
  /// In en, this message translates to:
  /// **'Save current state'**
  String get s09f745552a;

  /// fi: Tyhjä
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get s44367fdec5;

  /// fi: Tilannekuva asettaa monta laitetta kerralla, esim. "Elokuvailta" tai "Kaikki pois".
  ///
  /// In en, this message translates to:
  /// **'A scene sets many devices at once, e.g. \"Movie night\" or \"All off\".'**
  String get sc41824585d;

  /// fi: {p0} toimintoa
  ///
  /// In en, this message translates to:
  /// **'{p0} actions'**
  String s7e7b0848fb(String p0);

  /// fi: Mitkä laitteet tilannekuvaan?
  ///
  /// In en, this message translates to:
  /// **'Which devices go in the scene?'**
  String get s7cdee3dc7d;

  /// fi: Tilannekuvan nimi
  ///
  /// In en, this message translates to:
  /// **'Scene name'**
  String get sde0d544a4c;

  /// fi: esim. Elokuvailta
  ///
  /// In en, this message translates to:
  /// **'e.g. Movie night'**
  String get scff2a13871;

  /// fi: Uusi tilannekuva
  ///
  /// In en, this message translates to:
  /// **'New scene'**
  String get se3ba6a13bb;

  /// fi: Muokkaa tilannekuvaa
  ///
  /// In en, this message translates to:
  /// **'Edit scene'**
  String get s020a1af0d8;

  /// fi: Poistetaanko tilannekuva?
  ///
  /// In en, this message translates to:
  /// **'Delete the scene?'**
  String get s4dbd6f62bf;

  /// fi: Nappi näkymään
  ///
  /// In en, this message translates to:
  /// **'Button on dashboard'**
  String get sf1ed05f7de;

  /// fi: Nappi lisätty näkymään {p0}
  ///
  /// In en, this message translates to:
  /// **'Button added to {p0}'**
  String sf1541ca978(String p0);

  /// fi: Push-ilmoitukset
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get se250251ff0;

  /// fi: ntfy-palvelun kautta (ei Google-tiliä)
  ///
  /// In en, this message translates to:
  /// **'Through ntfy (no Google account needed)'**
  String get s91a8948ad7;

  /// fi: Näytä tällä laitteella
  ///
  /// In en, this message translates to:
  /// **'Show on this device'**
  String get sbdd6c9bad2;

  /// fi: Sovellus kuuntelee ilmoituksia, kun se on käynnissä (Windowsissa myös ilmaisinalueella).
  ///
  /// In en, this message translates to:
  /// **'The app listens for notifications while running (on Windows also from the tray).'**
  String get se1e0d398d7;

  /// fi: Aja automaatioita tässä sovelluksessa
  ///
  /// In en, this message translates to:
  /// **'Run automations in this app'**
  String get s6993f32ed2;

  /// fi: Kun kotisiltaa ei ole. Kotisilta ajaa ne aina, myös sovelluksen ollessa kiinni.
  ///
  /// In en, this message translates to:
  /// **'When there is no home bridge. A home bridge always runs them, also while the app is closed.'**
  String get sc0f6ea8ebe;

  /// fi: Sulje ilmaisinalueelle
  ///
  /// In en, this message translates to:
  /// **'Close to the tray'**
  String get sb35519f8e9;

  /// fi: Ikkunan sulkeminen jättää Molaplanin kellon viereen, jotta ilmoitukset tulevat.
  ///
  /// In en, this message translates to:
  /// **'Closing the window keeps Molaplan next to the clock so notifications arrive.'**
  String get s49ca9b6082;

  /// fi: Puhelin, kun Molaplan on kiinni
  ///
  /// In en, this message translates to:
  /// **'Phone, when Molaplan is closed'**
  String get sc6d6d4016e;

  /// fi: Asenna ntfy-sovellus (Android: Google Play / F-Droid, iPhone: App Store) ja tilaa tämä aihe. Ilmoitukset tulevat silloin
  ///
  /// In en, this message translates to:
  /// **'Install the ntfy app (Android: Google Play / F-Droid, iPhone: App Store) and subscribe to this topic. Notifications arrive even when Molaplan is closed.'**
  String get sb460bbf010;

  /// fi: Kopioi tilauslinkki
  ///
  /// In en, this message translates to:
  /// **'Copy subscribe link'**
  String get saa54f34e98;

  /// fi: Kova hälytysääni, testi ja luvat
  ///
  /// In en, this message translates to:
  /// **'Loud alarm sound, test and permissions'**
  String get s5df7b0d00b;

  /// fi: Hiljainen aika
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get s8f19ff1e21;

  /// fi: Vain kiireelliset (5) tulevat läpi.
  ///
  /// In en, this message translates to:
  /// **'Only urgent (5) come through.'**
  String get s1cc7f7a75f;

  /// fi: Alkaen (HH:MM)
  ///
  /// In en, this message translates to:
  /// **'From (HH:MM)'**
  String get s973f30f5e8;

  /// fi: Asti (HH:MM)
  ///
  /// In en, this message translates to:
  /// **'To (HH:MM)'**
  String get sb13eeff3cd;

  /// fi: Mykistä
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get s2f7a5f57b1;

  /// fi: 1 tunti
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get sa81c1da011;

  /// fi: 8 tuntia
  ///
  /// In en, this message translates to:
  /// **'8 hours'**
  String get s0ca30924bd;

  /// fi: Vuorokausi
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get s38bb718aaf;

  /// fi: Poista mykistys ({p0} asti)
  ///
  /// In en, this message translates to:
  /// **'Unmute (until {p0})'**
  String s36ef8a86e1(String p0);

  /// fi: Lähetä testi-ilmoitus
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get s0183ae0a12;

  /// fi: Molaplan-ilmoitukset toimivat
  ///
  /// In en, this message translates to:
  /// **'Molaplan notifications work'**
  String get sd95091858f;

  /// fi: Testi lähetetty
  ///
  /// In en, this message translates to:
  /// **'Test sent'**
  String get s58a8bfdd9f;

  /// fi: Viimeisimmät
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get s5c380d76b6;

  /// fi: Valmis automaatio
  ///
  /// In en, this message translates to:
  /// **'Ready-made automation'**
  String get s9d75942e41;

  /// fi: Valot auringonlaskussa, vesivuoto → hälytys, halvat tunnit…
  ///
  /// In en, this message translates to:
  /// **'Lights at sunset, water leak → alarm, cheap hours…'**
  String get s70860413a1;

  /// fi: Oma automaatio
  ///
  /// In en, this message translates to:
  /// **'Your own automation'**
  String get s8b5be90c1e;

  /// fi: Kun / Jos / Tee
  ///
  /// In en, this message translates to:
  /// **'When / If / Do'**
  String get sa9402c105a;

  /// fi: Tilannekuva nykytilasta
  ///
  /// In en, this message translates to:
  /// **'Scene from the current state'**
  String get s4102c7e085;

  /// fi: Monta laitetta yhdellä napilla
  ///
  /// In en, this message translates to:
  /// **'Many devices with one button'**
  String get s21ee7e78ee;

  /// fi: Vaiheet järjestyksessä, odotukset, jos/muuten
  ///
  /// In en, this message translates to:
  /// **'Steps in order, waits, if/else'**
  String get s5afa6e08f2;

  /// fi: Ryhmä
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get s8070a25da8;

  /// fi: Esim. kaikki olohuoneen valot yhtenä ruutuna
  ///
  /// In en, this message translates to:
  /// **'E.g. all living room lights as one tile'**
  String get sf5f1ae9c9e;

  /// fi: Mitkä laitteet ryhmään?
  ///
  /// In en, this message translates to:
  /// **'Which devices go in the group?'**
  String get s73f89f4de7;

  /// fi: Ryhmän nimi
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get s5b68340d84;

  /// fi: Kaikki: {p0}
  ///
  /// In en, this message translates to:
  /// **'All: {p0}'**
  String s1b087cdbbd(String p0);

  /// fi: Halvimmat tunnit yöllä
  ///
  /// In en, this message translates to:
  /// **'Cheapest hours at night'**
  String get s62cfd94468;

  /// fi: Päällä yön (22–07) halvimpina tunteina. Sopii varaajalle ja sähköauton lataukseen.
  ///
  /// In en, this message translates to:
  /// **'On during the cheapest night hours (22–07). Good for water heaters and EV charging.'**
  String get s7995dff292;

  /// fi: Halvimmat tunnit vuorokaudessa
  ///
  /// In en, this message translates to:
  /// **'Cheapest hours of the day'**
  String get sf92675687a;

  /// fi: Päällä vuorokauden halvimpina tunteina.
  ///
  /// In en, this message translates to:
  /// **'On during the cheapest hours of the day.'**
  String get sf71a753c59;

  /// fi: Pois, kun sähkö on kallis
  ///
  /// In en, this message translates to:
  /// **'Off when electricity is expensive'**
  String get s6c070f7367;

  /// fi: Sammuu, kun hinta ylittää rajan, ja palaa päälle, kun hinta laskee.
  ///
  /// In en, this message translates to:
  /// **'Turns off above the limit and back on when the price drops.'**
  String get s214f034099;

  /// fi: Päälle, kun sähkö on halpa
  ///
  /// In en, this message translates to:
  /// **'On when electricity is cheap'**
  String get s3939cfc37e;

  /// fi: Päällä vain, kun hinta on rajan alla.
  ///
  /// In en, this message translates to:
  /// **'On only when the price is below the limit.'**
  String get scecc366bc4;

  /// fi: Hintaohjaus poistettu
  ///
  /// In en, this message translates to:
  /// **'Price control removed'**
  String get s6e700ae773;

  /// fi: Hintaohjaus tallennettu
  ///
  /// In en, this message translates to:
  /// **'Price control saved'**
  String get s5aa3400a7a;

  /// fi: Sääntö toimii tällä laitteella (kotisilta). Pidä laite kotona päällä ja verkossa.
  ///
  /// In en, this message translates to:
  /// **'The rule runs on this device (home bridge). Keep it on at home.'**
  String get s2f5410429b;

  /// fi: Sääntö toimii kotisillalla{p0} – puhelimen ei tarvitse olla päällä.
  ///
  /// In en, this message translates to:
  /// **'The rule runs on the home bridge – your phone can be off.'**
  String sb86a43361f(String p0);

  /// fi: Kotisiltaa ei ole. Sääntö tallentuu, mutta alkaa toimia vasta kun kotona on aina päällä oleva tabletti tai PC kotisiltan
  ///
  /// In en, this message translates to:
  /// **'No home bridge yet. The rule is saved but runs only once an always-on tablet or PC at home is the bridge (Settings → Remote access).'**
  String get s538517b71b;

  /// fi: Hintaohjaus: {p0}
  ///
  /// In en, this message translates to:
  /// **'Price control: {p0}'**
  String s1a9e9bead3(String p0);

  /// fi: Milloin laite on päällä?
  ///
  /// In en, this message translates to:
  /// **'When should it be on?'**
  String get s6b609c3376;

  /// fi: Ei hintaohjausta
  ///
  /// In en, this message translates to:
  /// **'No price control'**
  String get s93e5435cf4;

  /// fi: Montako tuntia päällä
  ///
  /// In en, this message translates to:
  /// **'How many hours on'**
  String get s55e5c3a177;

  /// fi: Hintaraja
  ///
  /// In en, this message translates to:
  /// **'Price limit'**
  String get s52ef5e0b45;

  /// fi: Tulevat päälläoloajat
  ///
  /// In en, this message translates to:
  /// **'Upcoming on-times'**
  String get s993193d056;

  /// fi: Hintoja ei saatu juuri nyt. Sääntö toimii, kun hinnat saadaan.
  ///
  /// In en, this message translates to:
  /// **'Prices unavailable right now.'**
  String get s2f7c00a89e;

  /// fi: Ei päälläoloa seuraavan vuorokauden aikana.
  ///
  /// In en, this message translates to:
  /// **'No on-times in the next day.'**
  String get s15b42b592c;

  /// fi: Hinta-alue {p0}. Hinnat: pörssisähkö (day-ahead), ALV {p1} %. Vaihda alue ja siirtohinta lisäämällä "Sähkön hinta" -lait
  ///
  /// In en, this message translates to:
  /// **'Price area {p0}. Day-ahead spot prices incl. VAT {p1} %. Add the \"Electricity price\" device to change area and fees.'**
  String sf87d92faf4(String p0, String p1);

  /// fi: Vie asetukset
  ///
  /// In en, this message translates to:
  /// **'Export configuration'**
  String get s4dab2d409b;

  /// fi: Asetukset viety
  ///
  /// In en, this message translates to:
  /// **'Configuration exported'**
  String get s149c1e54d6;

  /// fi: Tuo asetukset
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get s35f445793b;

  /// fi: Korvataanko nykyiset asetukset?
  ///
  /// In en, this message translates to:
  /// **'Replace current configuration?'**
  String get sd55be829e3;

  /// fi: Kaikki nykyiset yhteydet ja näkymät korvataan tiedoston sisällöllä.
  ///
  /// In en, this message translates to:
  /// **'All current connections and dashboards are replaced by the file contents.'**
  String get s852dd1795e;

  /// fi: Tuo
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get s580678cb10;

  /// fi: Asetukset tuotu
  ///
  /// In en, this message translates to:
  /// **'Configuration imported'**
  String get s5f2ec17730;

  /// fi: Tuonti epäonnistui
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get sa87fff54f3;

  /// fi: Tili
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get s2fd2bfedb8;

  /// fi: Samat kodit ja ruudut kaikilla laitteillasi.
  ///
  /// In en, this message translates to:
  /// **'The same homes and tiles on all your devices.'**
  String get s4c0ff416ab;

  /// fi: Kirjaudu, niin kodit, laitteet ja ruudut ovat samat PC:llä, tabletilla ja puhelimella. Vapaaehtoinen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to have the same homes, devices and tiles on PC, tablet and phone. Optional.'**
  String get scc7e418ee3;

  /// fi: Lataukset
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get sb386aff4b7;

  /// fi: PC-sovelluksen lataus kaupan sivulta vaatii tilin (saman kuin tilauksessa).
  ///
  /// In en, this message translates to:
  /// **'Downloading the PC app from the shop requires an account (the same one as on the order).'**
  String get sbb264ce105;

  /// fi: Avaa lataukset
  ///
  /// In en, this message translates to:
  /// **'Open downloads'**
  String get se5ab008127;

  /// fi: Ulkoasu
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get s08d62fd281;

  /// fi: Teema
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get s2b8a2754c6;

  /// fi: Vaalea
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get s79f67deb42;

  /// fi: Tumma
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get s0d6fb52039;

  /// fi: Auringonnousun ja -laskun mukaan
  ///
  /// In en, this message translates to:
  /// **'By sunrise and sunset'**
  String get s70dd7fdd58;

  /// fi: Vaatii kodin sijainnin (Energia › Koti). Siihen asti seurataan laitteen asetusta.
  ///
  /// In en, this message translates to:
  /// **'Needs the home location (Energy › Home). Until then the device setting is followed.'**
  String get s21206b61f7;

  /// fi: Vaalea päivällä, tumma illalla. Pois päältä: seuraa laitteen asetusta.
  ///
  /// In en, this message translates to:
  /// **'Light by day, dark in the evening. Off: follows the device setting.'**
  String get s4e23920823;

  /// fi: Valinta koskee tätä laitetta ja tallentuu tiliisi uusien laitteiden oletukseksi.
  ///
  /// In en, this message translates to:
  /// **'The choice applies to this device and is saved to your account as the default for new devices.'**
  String get s4b847ce63e;

  /// fi: Näytä tuntikeskiarvona
  ///
  /// In en, this message translates to:
  /// **'Show as hourly average'**
  String get s5ebc02022b;

  /// fi: Sähkön hinta, halvimmat tunnit ja hintaohjaukset tunneittain (tuntihinnoiteltu sopimus). Pois: 15 min, kun alueen hinnat
  ///
  /// In en, this message translates to:
  /// **'Price, cheapest hours and price control per hour (hourly-billed contract). Off: 15 min where the area publishes 15-min prices.'**
  String get s68b4d332ca;

  /// fi: Aamukortti: näytä myös kallein tunti
  ///
  /// In en, this message translates to:
  /// **'Morning card: also show the priciest hour'**
  String get saf496a12a3;

  /// fi: Halvin tunti näytetään aina seuraavalta 24 tunnilta hintoineen.
  ///
  /// In en, this message translates to:
  /// **'The cheapest hour of the next 24 h is always shown with its price.'**
  String get sc53b1b78c0;

  /// fi: Laattakoko
  ///
  /// In en, this message translates to:
  /// **'Tile size'**
  String get s0625d54b38;

  /// fi: Normaali
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get s8382da3467;

  /// fi: Piilota etänä toimimattomat
  ///
  /// In en, this message translates to:
  /// **'Hide tiles that don\'\'t work remotely'**
  String get s7c1cd8314e;

  /// fi: Kotiverkon ulkopuolella vain kotiverkossa toimivat ruudut piilotetaan. Oletuksena ne näkyvät harmaina paikallaan.
  ///
  /// In en, this message translates to:
  /// **'Away from home, tiles that only work on the home network are hidden. By default they stay in place, greyed out.'**
  String get sa0cbbafb4e;

  /// fi: Kello ja sää etusivulla
  ///
  /// In en, this message translates to:
  /// **'Clock and weather on the home screen'**
  String get s419166b895;

  /// fi: Kellonaika, päivä, sää ja sähkön hinta näkymän yläreunassa. Koskee vain tätä laitetta.
  ///
  /// In en, this message translates to:
  /// **'Time, date, weather and electricity price at the top of the view. This device only.'**
  String get sec30a8f23e;

  /// fi: Animaatiot
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get sf7205b268f;

  /// fi: Pehmeät siirtymät, kun laite vaihtaa tilaa. Pois päältä = rauhallisempi ja kevyempi vanhalle tabletille. Koskee vain tät
  ///
  /// In en, this message translates to:
  /// **'Soft transitions when a device changes state. Off = calmer and lighter for an older tablet. This device only.'**
  String get s1535c6411d;

  /// fi: Näyttää tekniset asetukset: yhteydet (HTTP, MQTT, Modbus…), viestit, JSON-polut ja ruutujen lähteet. Useimmat eivät tarv
  ///
  /// In en, this message translates to:
  /// **'Shows technical settings: connections (HTTP, MQTT, Modbus…), payloads, JSON paths and tile sources. Most people don\'\'t need these.'**
  String get s21f870dbc2;

  /// fi: Laitteet ja integraatiot
  ///
  /// In en, this message translates to:
  /// **'Devices and integrations'**
  String get sc84689a549;

  /// fi: Lokit ja trendit
  ///
  /// In en, this message translates to:
  /// **'Logs and trends'**
  String get s2b6f77fa62;

  /// fi: Home Assistant: lisää laitteita
  ///
  /// In en, this message translates to:
  /// **'Home Assistant: add devices'**
  String get sca4c8b88b7;

  /// fi: Ohjaa kotia myös kodin ulkopuolelta.
  ///
  /// In en, this message translates to:
  /// **'Control your home from outside too.'**
  String get saec69088a5;

  /// fi: Ota etäkäyttö käyttöön
  ///
  /// In en, this message translates to:
  /// **'Set up remote access'**
  String get s417eb9a875;

  /// fi: Ohjeet: VPN, Nabu Casa, pilvi-MQTT
  ///
  /// In en, this message translates to:
  /// **'Guides: VPN, Nabu Casa, cloud MQTT'**
  String get scc3d01ee5e;

  /// fi: Jakaminen
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get s844e081db8;

  /// fi: Anna toiselle tai asentajalle pääsy valitsemiisi laitteisiin.
  ///
  /// In en, this message translates to:
  /// **'Give someone, or an installer, access to the devices you choose.'**
  String get s535358a517;

  /// fi: Jakaminen – uusi kutsu
  ///
  /// In en, this message translates to:
  /// **'Sharing – new invite'**
  String get s25c286a743;

  /// fi: Ohjeet
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get s90ba544719;

  /// fi: Näytä aloitusopas
  ///
  /// In en, this message translates to:
  /// **'Show the getting-started guide'**
  String get sb915c42792;

  /// fi: Varmuuskopio ja siirto
  ///
  /// In en, this message translates to:
  /// **'Backup and transfer'**
  String get sd337a7ddd5;

  /// fi: Vie asetukset JSON-tiedostoon ja tuo ne toiselle laitteelle (esim. PC → puhelin).
  ///
  /// In en, this message translates to:
  /// **'Export the configuration to a JSON file and import it on another device (e.g. PC → phone).'**
  String get s07c1048b4f;

  /// fi: Sisällytä salasanat ja tokenit
  ///
  /// In en, this message translates to:
  /// **'Include passwords and tokens'**
  String get s2f797098e7;

  /// fi: Tiedosto on silloin salaamaton – säilytä se turvassa.
  ///
  /// In en, this message translates to:
  /// **'The file is then unencrypted – keep it safe.'**
  String get s26f72949e3;

  /// fi: Vie
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get sdb12678e52;

  /// fi: Esimerkki
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get s34686ffb09;

  /// fi: Lisää esimerkkinäkymä (kamera, hälytys, valot, IV-kone). Esimerkkilaitteet eivät ota yhteyttä mihinkään – lisää omat lai
  ///
  /// In en, this message translates to:
  /// **'Add an example dashboard (camera, alarm, lights, ventilation). The example devices never connect anywhere – add your own with Add device.'**
  String get sc8327738b3;

  /// fi: Lisää esimerkkinäkymä
  ///
  /// In en, this message translates to:
  /// **'Add example dashboard'**
  String get sec02c7c071;

  /// fi: selainversio
  ///
  /// In en, this message translates to:
  /// **'browser version'**
  String get s057b871ed2;

  /// fi: Tarkista päivitykset
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get s522d6584c5;

  /// fi: Oma ohjauspääte: HTTP, MQTT, Modbus TCP, Home Assistant, kamerat, WebSocket, TCP ja UDP. Ilman tiliä kaikki asetukset py
  ///
  /// In en, this message translates to:
  /// **'Your own control terminal: HTTP, MQTT, Modbus TCP, Home Assistant, cameras, WebSocket, TCP and UDP. Without an account all settings stay on this device.'**
  String get sd178a1d809;

  /// fi: Mistä Home Assistantista?
  ///
  /// In en, this message translates to:
  /// **'Which Home Assistant?'**
  String get sf5bfc4217c;

  /// fi: Sinulla on useampi Home Assistant -yhteys. Käyttämättömän (ei ruutuja) voi poistaa.
  ///
  /// In en, this message translates to:
  /// **'You have more than one Home Assistant connection. An unused one (no tiles) can be removed.'**
  String get sbc210f9634;

  /// fi: ei ruutuja
  ///
  /// In en, this message translates to:
  /// **'no tiles'**
  String get s4f62c41cb3;

  /// fi: ruutua
  ///
  /// In en, this message translates to:
  /// **'tiles'**
  String get s92c338c3bd;

  /// fi: Poista käyttämätön yhteys
  ///
  /// In en, this message translates to:
  /// **'Remove unused connection'**
  String get sd3089f07cc;

  /// fi: Poistetaanko yhteys?
  ///
  /// In en, this message translates to:
  /// **'Remove the connection?'**
  String get s1333776c9f;

  /// fi: Jäähdytys
  ///
  /// In en, this message translates to:
  /// **'Cooling'**
  String get s8efb99df1d;

  /// fi: Lämmitys ja jäähdytys
  ///
  /// In en, this message translates to:
  /// **'Heat and cool'**
  String get s0b98d62330;

  /// fi: lämmittää
  ///
  /// In en, this message translates to:
  /// **'heating'**
  String get sa61efb9866;

  /// fi: jäähdyttää
  ///
  /// In en, this message translates to:
  /// **'cooling'**
  String get s9a47ee3e3c;

  /// fi: odottaa
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get s156712ac0c;

  /// fi: Termostaatti poistettu
  ///
  /// In en, this message translates to:
  /// **'Thermostat removed'**
  String get s8a1f52a37b;

  /// fi: Lämpötilaa ei saada
  ///
  /// In en, this message translates to:
  /// **'No temperature reading'**
  String get s28dc9bc46a;

  /// fi: Ei kotisiltaa: termostaatti ei ohjaa vielä. Ota etäyhteys käyttöön kotona olevalla laitteella.
  ///
  /// In en, this message translates to:
  /// **'No home bridge: the thermostat is not controlling yet. Set up remote access on a device at home.'**
  String get s31be5697ba;

  /// fi: Rele tai kytkin (päälle/pois)
  ///
  /// In en, this message translates to:
  /// **'Relay or switch (on/off)'**
  String get see9111ba68;

  /// fi: Lämpöpumppu tai ilmastointi (asetusarvo)
  ///
  /// In en, this message translates to:
  /// **'Heat pump or AC (setpoint)'**
  String get seaed91ad78;

  /// fi: Lämmittää
  ///
  /// In en, this message translates to:
  /// **'Heats'**
  String get sb757921c13;

  /// fi: Jäähdyttää
  ///
  /// In en, this message translates to:
  /// **'Cools'**
  String get s7407864734;

  /// fi: Molemmat
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get s272aa3f1da;

  /// fi: Varalämmitin
  ///
  /// In en, this message translates to:
  /// **'Backup heater'**
  String get sdadb6e3501;

  /// fi: Käynnistyy vain, kun lämpö on selvästi alle tavoitteen.
  ///
  /// In en, this message translates to:
  /// **'Starts only when it is clearly below the target.'**
  String get se4e381334d;

  /// fi: Virta päälle/pois (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Power on/off (optional)'**
  String get s17c79c5f4e;

  /// fi: Lämmitystilan painike (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Heat mode button (optional)'**
  String get s92d88612de;

  /// fi: Jäähdytystilan painike (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Cool mode button (optional)'**
  String get s75ac845bab;

  /// fi: Mikä lämmittää tai jäähdyttää?
  ///
  /// In en, this message translates to:
  /// **'What heats or cools?'**
  String get sc590a09db9;

  /// fi: Valitse yksi tai useampi. Esim. lämpöpumppu ja varalämmitin.
  ///
  /// In en, this message translates to:
  /// **'Pick one or more. E.g. a heat pump and a backup heater.'**
  String get sa15ffe53d4;

  /// fi: Ei sopivia laitteita vielä
  ///
  /// In en, this message translates to:
  /// **'No suitable devices yet'**
  String get sd47a7615a7;

  /// fi: Lisää ensin rele (esim. Shelly) tai lämpöpumppu (IR tai huoltoportti) ja palaa sitten tähän.
  ///
  /// In en, this message translates to:
  /// **'First add a relay (e.g. Shelly) or a heat pump (IR or service port), then come back.'**
  String get s3c7649a7f0;

  /// fi: Mistä lämpötila luetaan?
  ///
  /// In en, this message translates to:
  /// **'Where is the temperature read from?'**
  String get see513572ea;

  /// fi: Valitse lämpömittari. Useampi = varalla tai keskiarvo.
  ///
  /// In en, this message translates to:
  /// **'Pick a thermometer. Several = fallback or average.'**
  String get s5155522e83;

  /// fi: Ei pakollinen: lämpöpumppu mittaa itse. Valitse mittari, jos haluat nähdä lämpötilan.
  ///
  /// In en, this message translates to:
  /// **'Optional: the heat pump measures itself. Pick a sensor to see the temperature.'**
  String get s581fa290f3;

  /// fi: Ei lämpömittaria
  ///
  /// In en, this message translates to:
  /// **'No thermometer'**
  String get s7e4d8d60a0;

  /// fi: Lisää ensin laite, joka näyttää lämpötilan.
  ///
  /// In en, this message translates to:
  /// **'First add a device that shows a temperature.'**
  String get s0787d80876;

  /// fi: Ensimmäinen toimiva
  ///
  /// In en, this message translates to:
  /// **'First working'**
  String get s89661203b7;

  /// fi: Keskiarvo
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get s0da3005956;

  /// fi: Nimi ja tila
  ///
  /// In en, this message translates to:
  /// **'Name and mode'**
  String get s0c6a008ffd;

  /// fi: esim. Olohuone
  ///
  /// In en, this message translates to:
  /// **'e.g. Living room'**
  String get s1790a71e85;

  /// fi: Tavoitelämpötila
  ///
  /// In en, this message translates to:
  /// **'Target temperature'**
  String get sd5f46903a1;

  /// fi: Jos lämpötilaa ei saada
  ///
  /// In en, this message translates to:
  /// **'If the temperature is lost'**
  String get s6de95e582f;

  /// fi: Sammuta lämmitys/jäähdytys (turvallisin)
  ///
  /// In en, this message translates to:
  /// **'Switch heating/cooling off (safest)'**
  String get s8ff25225b4;

  /// fi: Pidä ennallaan
  ///
  /// In en, this message translates to:
  /// **'Keep as it is'**
  String get s17cb86f49e;

  /// fi: Hystereesi
  ///
  /// In en, this message translates to:
  /// **'Hysteresis'**
  String get s9624f070ee;

  /// fi: Kuollut alue (lämmitys/jäähdytys)
  ///
  /// In en, this message translates to:
  /// **'Deadband (heat/cool)'**
  String get sf070be2c1e;

  /// fi: Varalämmitin, kun alle tavoitteen
  ///
  /// In en, this message translates to:
  /// **'Backup heater when below target by'**
  String get s8f7c8eb7d0;

  /// fi: Mittari kadonnut, kun ei lukemaa
  ///
  /// In en, this message translates to:
  /// **'Sensor lost after no reading for'**
  String get sf1eb3b2d34;

  /// fi: Uusi termostaatti
  ///
  /// In en, this message translates to:
  /// **'New thermostat'**
  String get s0ab1430151;

  /// fi: Muokkaa termostaattia
  ///
  /// In en, this message translates to:
  /// **'Edit thermostat'**
  String get sbbc98d573d;

  /// fi: Poistetaanko termostaatti?
  ///
  /// In en, this message translates to:
  /// **'Delete the thermostat?'**
  String get s87984716cb;

  /// fi: Tavoite
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get s79786b9f7d;

  /// fi: Termostaatti toimii kotisillalla
  ///
  /// In en, this message translates to:
  /// **'The thermostat runs on the home bridge'**
  String get sdd309c0a63;

  /// fi: Ota etäyhteys käyttöön kotona olevalla laitteella (Asetukset → Etäkäyttö). Siihen asti termostaatti ei ohjaa.
  ///
  /// In en, this message translates to:
  /// **'Set up remote access on a device at home (Settings → Remote access). Until then it does not control anything.'**
  String get sa4701693b6;

  /// fi: Ohjaus toimii tällä laitteella (kotisilta).
  ///
  /// In en, this message translates to:
  /// **'Runs on this device (home bridge).'**
  String get s06cda8c0de;

  /// fi: Ohjaus toimii kotisillalla.
  ///
  /// In en, this message translates to:
  /// **'Runs on the home bridge.'**
  String get s2342536aea;

  /// fi: Lämmittää etukäteen ennen kallista sähköä ja pakkasta, ja antaa lämmön laskea hieman kalliina tunteina.
  ///
  /// In en, this message translates to:
  /// **'Pre-heats before expensive electricity and cold weather, and lets the temperature drop a little in expensive hours.'**
  String get s2c5993c1fd;

  /// fi: Ylilämpö +
  ///
  /// In en, this message translates to:
  /// **'Overheat +'**
  String get s81c4abc1a5;

  /// fi: Alilämpö −
  ///
  /// In en, this message translates to:
  /// **'Underheat −'**
  String get sdea18b2b40;

  /// fi: Viiva = tavoitelämpötila, palkit = sähkön hinta, katkoviiva = ulkolämpötila.
  ///
  /// In en, this message translates to:
  /// **'Line = target temperature, bars = electricity price, dashed = outdoor temperature.'**
  String get s523214c8db;

  /// fi: Lisää kodin sijainti säätä varten
  ///
  /// In en, this message translates to:
  /// **'Add the home location for the weather'**
  String get s94b8f63aa7;

  /// fi: Suunnitelmaa lasketaan…
  ///
  /// In en, this message translates to:
  /// **'Calculating the plan…'**
  String get s941fbb47fe;

  /// fi: Kirjoita luku
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get s969e582f74;

  /// fi: Pitää olla yli {p0}
  ///
  /// In en, this message translates to:
  /// **'Must be above {p0}'**
  String s6c2b7db49f(String p0);

  /// fi: Pitää olla alle {p0}
  ///
  /// In en, this message translates to:
  /// **'Must be below {p0}'**
  String sb2dd9fb046(String p0);

  /// fi: Kaikki arvot
  ///
  /// In en, this message translates to:
  /// **'All values'**
  String get sf53fbf24ad;

  /// fi: alle {p0}{p1}
  ///
  /// In en, this message translates to:
  /// **'below {p0}{p1}'**
  String se9bcd429a9(String p0, String p1);

  /// fi: yli {p0}{p1}
  ///
  /// In en, this message translates to:
  /// **'above {p0}{p1}'**
  String s65758fd482(String p0, String p1);

  /// fi: Ei väriä
  ///
  /// In en, this message translates to:
  /// **'No colour'**
  String get s0a914fa5f8;

  /// fi: Alueet ovat järjestyksessä: alle X, X–Y, yli Y. Rajan muuttaminen siirtää myös viereistä aluetta, joten alueet eivät men
  ///
  /// In en, this message translates to:
  /// **'Ranges are in order: below X, X–Y, above Y. Changing a limit also moves the neighbouring range, so ranges never overlap or leave gaps. A limit value belongs to the upper range.'**
  String get safbc09013c;

  /// fi: Yläraja
  ///
  /// In en, this message translates to:
  /// **'Upper limit'**
  String get s11a3afdbce;

  /// fi: Poista alue
  ///
  /// In en, this message translates to:
  /// **'Remove range'**
  String get sd337d9fc0c;

  /// fi: Lisää alue
  ///
  /// In en, this message translates to:
  /// **'Add range'**
  String get s3f68bf214f;

  /// fi: Kotisilta päällä
  ///
  /// In en, this message translates to:
  /// **'Home bridge on'**
  String get s229f981388;

  /// fi: Kotisilta: ei yhteyttä
  ///
  /// In en, this message translates to:
  /// **'Bridge: offline'**
  String get sfc2dc8fc36;

  /// fi: Kotona
  ///
  /// In en, this message translates to:
  /// **'At home'**
  String get sdedbb30a67;

  /// fi: Etäyhteys
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get s9d64d4c166;

  /// fi: Yhdistetään…
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get sba10f23f03;

  /// fi: Yhdistä tämä laite kotiin
  ///
  /// In en, this message translates to:
  /// **'Connect this device to home'**
  String get s678a751265;

  /// fi: Kotona on jo kotisilta (tabletti tai PC). Skannaa sen QR-koodi tai kirjoita 6 numeroa.
  ///
  /// In en, this message translates to:
  /// **'There is a home bridge (tablet or PC) at home already. Scan its QR code or type the 6 digits.'**
  String get sdae0305965;

  /// fi: Tee tästä laitteesta kotisilta
  ///
  /// In en, this message translates to:
  /// **'Make this device the home bridge'**
  String get s5f8284b98f;

  /// fi: Tämä laite jää kotiin aina päälle (laturiin ja wifiin) ja välittää etänä annetut komennot kodin laitteille.
  ///
  /// In en, this message translates to:
  /// **'This device stays at home, always on (charger + Wi-Fi), and passes remote commands to your devices.'**
  String get s6a95f7843b;

  /// fi: Lisää kotisilta (Molaplan Bridge -laite)
  ///
  /// In en, this message translates to:
  /// **'Add home bridge (Molaplan Bridge device)'**
  String get sa949a952bf;

  /// fi: Pieni aina päällä oleva laite, esim. Athom IR/RF – ohjaa myös ilmalämpöpumppua. Asennus puhelimella parissa minuutissa.
  ///
  /// In en, this message translates to:
  /// **'A small always-on device, e.g. Athom IR/RF – also controls the heat pump. Set up with the phone in a couple of minutes.'**
  String get sb641af74b7;

  /// fi: Muut tavat: VPN, Nabu Casa, pilvi-MQTT
  ///
  /// In en, this message translates to:
  /// **'Other ways: VPN, Nabu Casa, cloud MQTT'**
  String get s2c3ae5833b;

  /// fi: Selkeät ohjeet, jos käytät jo Tailscalea, WireGuardia, Home Assistant Cloudia tai pilvi-MQTT:tä.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step guides if you already use Tailscale, WireGuard, Home Assistant Cloud or cloud MQTT.'**
  String get s807e3a32f3;

  /// fi: Kotisilta vastaa – etäyhteys toimii.
  ///
  /// In en, this message translates to:
  /// **'The home bridge answers – remote access works.'**
  String get sa3e78d5c4e;

  /// fi: Poistetaanko etäyhteys?
  ///
  /// In en, this message translates to:
  /// **'Remove remote access?'**
  String get sfaa5185b74;

  /// fi: Tämä laite ei sen jälkeen saa yhteyttä kotiin kodin ulkopuolelta. Voit yhdistää uudelleen milloin vain.
  ///
  /// In en, this message translates to:
  /// **'This device can then no longer reach home from outside. You can pair again any time.'**
  String get sbc44ce6993;

  /// fi: Ohjaa kotia myös kodin ulkopuolelta
  ///
  /// In en, this message translates to:
  /// **'Control your home from anywhere'**
  String get s0b57661c18;

  /// fi: Kotona Molaplan puhuu laitteille suoraan, muualla salattuna kotisillan kautta. Mitään ei tarvitse säätää reitittimestä.
  ///
  /// In en, this message translates to:
  /// **'At home Molaplan talks to your devices directly, elsewhere encrypted through your home bridge. Nothing to set up on the router.'**
  String get s07dc42dc7a;

  /// fi: Näytä kodin {p0} laitteet täällä
  ///
  /// In en, this message translates to:
  /// **'Show the devices of {p0} here'**
  String sdde4ff19ce(String p0);

  /// fi: Kopioi kotisillan näkymät tähän laitteeseen. Lukemat ja ohjaukset kulkevat sen jälkeen kotisillan kautta.
  ///
  /// In en, this message translates to:
  /// **'Copy the home bridge\'\'s dashboards to this device. Readings and controls then go through the home bridge.'**
  String get sc5328cbb8f;

  /// fi: Kopioi kodin näkymät
  ///
  /// In en, this message translates to:
  /// **'Copy home dashboards'**
  String get s86ad95fa48;

  /// fi: Lisää kotisilta
  ///
  /// In en, this message translates to:
  /// **'Add a home bridge'**
  String get s9b8f1f4a7e;

  /// fi: Aloita näin
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get sa8c35b8bfb;

  /// fi: Kotisilta on mikä tahansa kotona aina päällä oleva Molaplan: PC, vanha tabletti tai puhelin, Molaplan Bridge -laite tai
  ///
  /// In en, this message translates to:
  /// **'A home bridge is any Molaplan that is always on at home: a PC, an old tablet or phone, a Molaplan Bridge device or the separate bridge program. When you are away, commands go through it end-to-end encrypted.'**
  String get s5683f9f7e4;

  /// fi: Kotona = tämä laite on kotisillan omassa verkossa ja puhuu laitteille suoraan. Etäyhteys = kotisillan kautta. Ei yhteytt
  ///
  /// In en, this message translates to:
  /// **'At home = this device is on the home bridge\'\'s own network and talks to devices directly. Remote = through the home bridge. No connection = neither answers.'**
  String get sa75a955933;

  /// fi: Kotisilta on vanha versio eikä kerro verkkoaan, joten yhteys kulkee aina sen kautta. Päivitä kotisilta, niin Kotona-tila
  ///
  /// In en, this message translates to:
  /// **'The home bridge is an old version and does not report its network, so everything goes through it. Update the bridge to detect At home.'**
  String get s90460344ec;

  /// fi: Testaa etäyhteys
  ///
  /// In en, this message translates to:
  /// **'Test remote access'**
  String get s19cec9667e;

  /// fi: Poista etäyhteys
  ///
  /// In en, this message translates to:
  /// **'Remove remote access'**
  String get s3563cb1635;

  /// fi: Tämä laite on kotisilta
  ///
  /// In en, this message translates to:
  /// **'This device is the home bridge'**
  String get s528c4f3a4c;

  /// fi: Kamerakuvan päivitys etänä
  ///
  /// In en, this message translates to:
  /// **'Camera refresh when remote'**
  String get sfd263f3e04;

  /// fi: Etänä kamera näyttää kuvan {p0} s välein (säästää dataa).
  ///
  /// In en, this message translates to:
  /// **'Remotely the camera shows a picture every {p0} s (saves data).'**
  String s99249ddf24(String p0);

  /// fi: Välityspalvelin
  ///
  /// In en, this message translates to:
  /// **'Relay server'**
  String get s451ea613dd;

  /// fi: Kotisilta on jo uusin ({p0}).
  ///
  /// In en, this message translates to:
  /// **'The bridge is up to date ({p0}).'**
  String sc420bf77fa(String p0);

  /// fi: Kotisilta asentaa version {p0} ja käynnistyy uudelleen (noin minuutti).
  ///
  /// In en, this message translates to:
  /// **'The bridge is installing {p0} and restarts (about a minute).'**
  String sb040f9f612(String p0);

  /// fi: Versio {p0} ladattu. Kotisillan laitteessa pitää hyväksyä asennus ilmoituksesta.
  ///
  /// In en, this message translates to:
  /// **'Version {p0} downloaded. Approve the install from the notification on the bridge device.'**
  String s007c4f492d(String p0);

  /// fi: Tämä kotisilta päivitetään käsin (versio {p0}).
  ///
  /// In en, this message translates to:
  /// **'Update this bridge by hand (version {p0}).'**
  String s602d8f4a18(String p0);

  /// fi: Kotisilta ei saanut päivitystietoja nyt. Yritä myöhemmin.
  ///
  /// In en, this message translates to:
  /// **'The bridge could not check for updates now.'**
  String get se8704fa7a4;

  /// fi: Päivitys epäonnistui: {p0}
  ///
  /// In en, this message translates to:
  /// **'Update failed: {p0}'**
  String s2db971daf4(String p0);

  /// fi: Kotisilta
  ///
  /// In en, this message translates to:
  /// **'Home bridge'**
  String get sb38b582dab;

  /// fi:  · päivittyy etänä hiljaisesti
  ///
  /// In en, this message translates to:
  /// **' · updates silently'**
  String get s51fb400921;

  /// fi:  · päivitys hyväksytään laitteella
  ///
  /// In en, this message translates to:
  /// **' · updates need approval on the device'**
  String get s3443bfc674;

  /// fi: Kotisilta: vanhempi versio kuin 0.8.0 (ei versiotietoa). Sitä ei voi päivittää etänä – päivitä se kerran sillan laitteel
  ///
  /// In en, this message translates to:
  /// **'Home bridge: older than 0.8.0 (no version info). It cannot be updated remotely – update it once on the bridge device.'**
  String get s8ae159d87a;

  /// fi: Kotisillan versio: haetaan…
  ///
  /// In en, this message translates to:
  /// **'Home bridge version: checking…'**
  String get s6a02d97944;

  /// fi: Kotisillan versio: ei tiedossa
  ///
  /// In en, this message translates to:
  /// **'Home bridge version: unknown'**
  String get s311c531a8e;

  /// fi: Päivitä silta
  ///
  /// In en, this message translates to:
  /// **'Update bridge'**
  String get s70fe8d5ef3;

  /// fi: {p0}: jo uusin ({p1}).
  ///
  /// In en, this message translates to:
  /// **'{p0}: up to date ({p1}).'**
  String s7897a0f8e0(String p0, String p1);

  /// fi: {p0} asentaa version {p1} ja käynnistyy uudelleen (noin minuutti).
  ///
  /// In en, this message translates to:
  /// **'{p0} is installing {p1} and restarts (about a minute).'**
  String sbcef05dad9(String p0, String p1);

  /// fi: {p0}: versio {p1} ladattu. Asennus pitää hyväksyä sillan laitteella.
  ///
  /// In en, this message translates to:
  /// **'{p0}: version {p1} downloaded. Approve the install on the bridge device.'**
  String s1aee092e31(String p0, String p1);

  /// fi: {p0} päivitetään käsin (versio {p1}).
  ///
  /// In en, this message translates to:
  /// **'{p0} is updated by hand (version {p1}).'**
  String s72774aece1(String p0, String p1);

  /// fi: {p0} on vanhempi kuin 0.8.0 eikä osaa päivittää itseään etänä.
  ///
  /// In en, this message translates to:
  /// **'{p0} is older than 0.8.0 and cannot update itself remotely.'**
  String s238af47c1e(String p0);

  /// fi: {p0} ei saanut päivitystietoja nyt.
  ///
  /// In en, this message translates to:
  /// **'{p0} could not check for updates now.'**
  String sb9bee63c5e(String p0);

  /// fi: Yhdistä kotisiltaan {p0}?
  ///
  /// In en, this message translates to:
  /// **'Connect to the bridge {p0}?'**
  String sd9103f5cee(String p0);

  /// fi: Tämä laite on nyt yhdistetty kotiin {p0}. Se vaihtuu kotisiltaan {p1}. Koodia tai QR:ää ei tarvita, koska molemmat ovat
  ///
  /// In en, this message translates to:
  /// **'This device is now connected to {p0}. It switches to {p1}. No code or QR needed – both are on your account.'**
  String s6046b9ff9c(String p0, String p1);

  /// fi: Koodia tai QR:ää ei tarvita, koska molemmat laitteet ovat omalla tililläsi.
  ///
  /// In en, this message translates to:
  /// **'No code or QR needed – both devices are on your account.'**
  String get s053b2f1211;

  /// fi: Yhdistä
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get sdbdf676485;

  /// fi: Yhdistetty kotiin {p0}.
  ///
  /// In en, this message translates to:
  /// **'Connected to {p0}.'**
  String s948bfb1114(String p0);

  /// fi: haetaan…
  ///
  /// In en, this message translates to:
  /// **'checking…'**
  String get sc4abf59272;

  /// fi: ei tietoa
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get s12b3d49235;

  /// fi: päällä
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get sb9e406274e;

  /// fi: vanha Molaplan (0.8.0-testiversio tai vanhempi)
  ///
  /// In en, this message translates to:
  /// **'old Molaplan (0.8.0 test build or older)'**
  String get sb981e102f1;

  /// fi: päivitä kerran laitteella
  ///
  /// In en, this message translates to:
  /// **'update once on the device'**
  String get s706ee3ad91;

  /// fi:  (ei yhteystietoa tälle laitteelle)
  ///
  /// In en, this message translates to:
  /// **' (no credential on this device)'**
  String get sca90c9c253;

  /// fi: versio ei tiedossa
  ///
  /// In en, this message translates to:
  /// **'version unknown'**
  String get s42b97a989b;

  /// fi: päivittyy hiljaisesti
  ///
  /// In en, this message translates to:
  /// **'updates silently'**
  String get se76155b6bd;

  /// fi: Päivitä {p0} kerran laitteella
  ///
  /// In en, this message translates to:
  /// **'Update {p0} once on the device'**
  String s20889b3dc9(String p0);

  /// fi: Tämä kotisilta käyttää vanhaa Molaplania, joka ei vielä osaa päivittää itseään etänä.
  ///
  /// Kerran tehtävä päivitys: avaa Mol
  ///
  /// In en, this message translates to:
  /// **'This home bridge runs an old Molaplan that cannot update itself remotely yet.\n\nOne-time update: open Molaplan on the bridge device → Settings → Check for updates → Update and approve the install. Or install the latest APK over USB.\n\nAfter that, Update works from this list remotely.'**
  String get secbc1cfea3;

  /// fi: Kotisillat
  ///
  /// In en, this message translates to:
  /// **'Home bridges'**
  String get s356b6d4d13;

  /// fi: Päivitä tiedot
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get s57117babe8;

  /// fi: Avaa = näytä se koti tällä laitteella. Päivitä = asenna kotisillalle uusin Molaplan.
  ///
  /// In en, this message translates to:
  /// **'Open = use that home on this device. Update = install the latest Molaplan on the bridge.'**
  String get s5160bf55ae;

  /// fi: tämä laite
  ///
  /// In en, this message translates to:
  /// **'this device'**
  String get s9b2c8181e4;

  /// fi: Avaa
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get s902eaaff9f;

  /// fi: Päivitä
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get sfbf490ec3f;

  /// fi: Yhteys etäpalveluun: kunnossa
  ///
  /// In en, this message translates to:
  /// **'Remote service: connected'**
  String get s72da730a42;

  /// fi: Yhdistetään etäpalveluun…
  ///
  /// In en, this message translates to:
  /// **'Connecting to the remote service…'**
  String get s421f161f5b;

  /// fi: Ei yhteyttä etäpalveluun – yritetään uudelleen automaattisesti. Tarkista nettiyhteys.
  ///
  /// In en, this message translates to:
  /// **'No connection to the remote service – retrying automatically. Check the internet connection.'**
  String get s88e2b1dad5;

  /// fi: Kotisillalla ei ole näkymiä kopioitavaksi.
  ///
  /// In en, this message translates to:
  /// **'The home bridge has no dashboards to copy.'**
  String get sa1d085d92c;

  /// fi: Kopioitu: {p0} näkymää
  ///
  /// In en, this message translates to:
  /// **'Copied: {p0} dashboards'**
  String sa13ef6f8d9(String p0);

  /// fi: Yhdistetty kotiin "{p0}"!
  ///
  /// In en, this message translates to:
  /// **'Connected to \"{p0}\"!'**
  String sab5e7202f5(String p0);

  /// fi: Nyt voit ohjata kotia myös kodin ulkopuolelta. Haluatko kopioida kotisillan näkymät ja laitteet myös tähän laitteeseen?
  ///
  /// In en, this message translates to:
  /// **'You can now control your home from anywhere. Copy the home bridge\'\'s dashboards and devices to this device too?'**
  String get s30f06b7fb0;

  /// fi: Ei kiitos
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get s641263ce18;

  /// fi: ei Molaplan-koodi
  ///
  /// In en, this message translates to:
  /// **'not a Molaplan code'**
  String get sa7a6c0fc2d;

  /// fi: Yhdistä kotiin
  ///
  /// In en, this message translates to:
  /// **'Connect to home'**
  String get se2ecf1935a;

  /// fi: Näin yhdistät
  ///
  /// In en, this message translates to:
  /// **'How to connect'**
  String get s410655fd47;

  /// fi: Avaa kotona olevalla kotisillalla (tabletti tai PC) Molaplan → Asetukset → Etäkäyttö → Tee tästä laitteesta kotisilta.
  ///
  /// In en, this message translates to:
  /// **'On the home bridge (tablet or PC at home) open Molaplan → Settings → Remote access → Make this device the home bridge.'**
  String get s7c541b8e91;

  /// fi: Paina siellä "Yhdistä puhelin". Näytölle tulee QR-koodi ja 6 numeroa.
  ///
  /// In en, this message translates to:
  /// **'Press \"Pair a phone\" there. A QR code and 6 digits appear.'**
  String get sc7c83b2f58;

  /// fi: Skannaa QR-koodi tai kirjoita numerot alle.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code or type the digits below.'**
  String get s35284509d4;

  /// fi: Skannaa QR-koodi
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code'**
  String get s66bb65d8e8;

  /// fi: tai kirjoita koodi
  ///
  /// In en, this message translates to:
  /// **'or type the code'**
  String get se97cc157ef;

  /// fi: 6 numeroa kotisillan näytöltä
  ///
  /// In en, this message translates to:
  /// **'6 digits from the home bridge screen'**
  String get s3143eb70e1;

  /// fi: Koodilla yhdistettäessä paina vielä kotisillalla "Hyväksy".
  ///
  /// In en, this message translates to:
  /// **'When using the code, press \"Accept\" on the home bridge too.'**
  String get s643434044c;

  /// fi: Paina kotisillan näytöllä "Hyväksy"…
  ///
  /// In en, this message translates to:
  /// **'Press \"Accept\" on the home bridge screen…'**
  String get s9753766742;

  /// fi: Osoita kameralla QR-koodia
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code'**
  String get s50e49dd1df;

  /// fi: Kameraa ei voi käyttää ({p0}). Salli kameran käyttö tai kirjoita koodi käsin.
  ///
  /// In en, this message translates to:
  /// **'Cannot use the camera ({p0}). Allow camera access or type the code.'**
  String s5d717bb2c5(String p0);

  /// fi: Salli toiminta taustalla
  ///
  /// In en, this message translates to:
  /// **'Allow running in the background'**
  String get s12d40eedd5;

  /// fi: Jotta kotisilta toimii näytön ollessa pois päältä, Android pitää sallia ajaa Molaplania taustalla ilman akunsäästörajoit
  ///
  /// In en, this message translates to:
  /// **'For the bridge to work with the screen off, Android must let Molaplan run in the background without battery restrictions. Choose \"Allow\" in the next window.'**
  String get s8e1fcae1fe;

  /// fi: Jatka
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sd62c460e3d;

  /// fi: Laite "{p0}" yhdistetty!
  ///
  /// In en, this message translates to:
  /// **'Device \"{p0}\" connected!'**
  String s7132345f20(String p0);

  /// fi: Kotisilta on kotona aina päällä oleva laite, esimerkiksi vanha tabletti tai PC. Kun olet poissa, puhelimesi komennot kul
  ///
  /// In en, this message translates to:
  /// **'The home bridge is a device that stays on at home, e.g. an old tablet or a PC. When you are away, your phone\'\'s commands go encrypted through it to your devices.'**
  String get se2e2af02ac;

  /// fi: Pidä laite laturissa ja kodin wifissä.
  ///
  /// In en, this message translates to:
  /// **'Keep it on the charger and on the home Wi-Fi.'**
  String get sd64f52490d;

  /// fi: Silta toimii taustalla: näytön voi sammuttaa ja Molaplanin sulkea. Se käynnistyy itsestään laitteen uudelleenkäynnistyks
  ///
  /// In en, this message translates to:
  /// **'The bridge runs in the background: the screen can be off and Molaplan closed. It starts by itself after a restart and reconnects when the network returns.'**
  String get seb25c46911;

  /// fi: Pidä Molaplan auki. Näyttö pysyy päällä, kun silta on käytössä.
  ///
  /// In en, this message translates to:
  /// **'Keep Molaplan open. The screen stays on while the bridge is on.'**
  String get sbb23f25581;

  /// fi: Käytä tätä laitetta kotisiltana
  ///
  /// In en, this message translates to:
  /// **'Use this device as the home bridge'**
  String get sbfed096278;

  /// fi: Akunsäästö voi pysäyttää sillan
  ///
  /// In en, this message translates to:
  /// **'Battery saving may stop the bridge'**
  String get s374a096cb9;

  /// fi: Salli Molaplanin toimia taustalla rajoituksetta.
  ///
  /// In en, this message translates to:
  /// **'Let Molaplan run in the background without restrictions.'**
  String get s9b1298f7c6;

  /// fi: Päivitä automaattisesti
  ///
  /// In en, this message translates to:
  /// **'Update automatically'**
  String get s2fcba19ec3;

  /// fi: Asentaa uuden Molaplan-version itse (tarkistus 6 tunnin välein). Vain Molaplanin allekirjoittamat, tarkistussummaltaan o
  ///
  /// In en, this message translates to:
  /// **'Installs new Molaplan versions by itself (checked every 6 h). Only Molaplan-signed files with a matching checksum.'**
  String get se7a1731ac0;

  /// fi: Yhdistä puhelin
  ///
  /// In en, this message translates to:
  /// **'Pair a phone'**
  String get s13995350ed;

  /// fi: Yhdistetyt laitteet
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get s6a74454a98;

  /// fi: Ei vielä yhtään. Paina "Yhdistä puhelin".
  ///
  /// In en, this message translates to:
  /// **'None yet. Press \"Pair a phone\".'**
  String get s1e4fc2e7fe;

  /// fi: Lisätty
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get s7ea55c5834;

  /// fi: Poistetaanko "{p0}"?
  ///
  /// In en, this message translates to:
  /// **'Remove \"{p0}\"?'**
  String sfd8d693d04(String p0);

  /// fi: Laite ei sen jälkeen pääse kotiin etänä. Sen voi yhdistää uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The device can then no longer connect remotely. It can be paired again.'**
  String get s84572f642e;

  /// fi: Voimassa
  ///
  /// In en, this message translates to:
  /// **'Valid for'**
  String get sf7fa9632f3;

  /// fi: Puhelimessa: Molaplan → Asetukset → Etäkäyttö → Yhdistä tämä laite kotiin
  ///
  /// In en, this message translates to:
  /// **'On the phone: Molaplan → Settings → Remote access → Connect this device to home'**
  String get s4e877aeafe;

  /// fi: Skannaa puhelimella
  ///
  /// In en, this message translates to:
  /// **'Scan with the phone'**
  String get s9715416100;

  /// fi: Hyväksytäänkö laite?
  ///
  /// In en, this message translates to:
  /// **'Accept this device?'**
  String get s5378bb3f05;

  /// fi: "{p0}" haluaa ohjata kotia etänä. Hyväksy vain, jos se on oma tai perheenjäsenen laite, jolla juuri syötit koodin.
  ///
  /// In en, this message translates to:
  /// **'\"{p0}\" wants remote control of your home. Accept only if it is your own or a family member\'\'s device that just entered the code.'**
  String s1d8bb7b0a6(String p0);

  /// fi: Hylkää
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get sa04c218f82;

  /// fi: Hyväksy
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get sdfaf8c242b;

  /// fi: Tämä laite
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sdf66171e91;

  /// fi: ei vielä valittu
  ///
  /// In en, this message translates to:
  /// **'not set up yet'**
  String get sd64229b6d8;

  /// fi: Etäkäyttö ei ole käytössä
  ///
  /// In en, this message translates to:
  /// **'Remote access is off'**
  String get s088e792ee3;

  /// fi: Yhteydessä
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get s85543bf885;

  /// fi: viimeksi nähty
  ///
  /// In en, this message translates to:
  /// **'last seen'**
  String get s3f17564f18;

  /// fi: Mikä on etäkäyttö?
  ///
  /// In en, this message translates to:
  /// **'What is remote access?'**
  String get s9ba8cafced;

  /// fi: On jo näkymässä – lisätäänkö silti?
  ///
  /// In en, this message translates to:
  /// **'Already in the view – add anyway?'**
  String get sa0eeb22daa;

  /// fi: {p0} on jo näkymässä {p1}.
  ///
  /// In en, this message translates to:
  /// **'{p0} is already in the view {p1}.'**
  String s3507210a2a(String p0, String p1);

  /// fi: Lisää silti
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get s0e655a209f;

  /// fi: Valo
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get sa376ec78ec;

  /// fi: Virta
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get s8e574c3313;

  /// fi: Tuuletin
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get sa9360bdda1;

  /// fi: Lämpöpumppu
  ///
  /// In en, this message translates to:
  /// **'Heat pump'**
  String get sc7d02fbe84;

  /// fi: Hälytys
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get s8d06ee5308;

  /// fi: Lukko
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get sfb63e3c23f;

  /// fi: Vesi
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get s2f42d90475;

  /// fi: Kosteus
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get s9cb8820285;

  /// fi: Sähkö / teho
  ///
  /// In en, this message translates to:
  /// **'Electricity / power'**
  String get sf2d10dd213;

  /// fi: Säästö / halvin
  ///
  /// In en, this message translates to:
  /// **'Savings / cheapest'**
  String get s4594c7448e;

  /// fi: Autotalli
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get s291ca127d6;

  /// fi: Ovi
  ///
  /// In en, this message translates to:
  /// **'Door'**
  String get sb543af1c63;

  /// fi: Ikkuna
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get s60b1079d6c;

  /// fi: Anturi
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get se8422f063f;

  /// fi: Ajastin
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get s0ab3a44562;

  /// fi: Verkko
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get s3044a10005;

  /// fi: Sauna / lämmitys
  ///
  /// In en, this message translates to:
  /// **'Sauna / heating'**
  String get s1f67139f55;

  /// fi: Pistorasia
  ///
  /// In en, this message translates to:
  /// **'Outlet'**
  String get sf21fd72396;

  /// fi: Suosikki
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get s7783fe5fca;

  /// fi: Lista
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get se223375393;

  /// fi: Suuntaus
  ///
  /// In en, this message translates to:
  /// **'Swing'**
  String get sfb0b971c01;

  /// fi: Kaukosäädin
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get see42f2d999;

  /// fi: Aurinko
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get s9126bf24a0;

  /// fi: Akku
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get sbb26f2192c;

  /// fi: Liike
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get s66350d8e7a;

  /// fi: Savu
  ///
  /// In en, this message translates to:
  /// **'Smoke'**
  String get s57c2113aee;

  /// fi: Radon
  ///
  /// In en, this message translates to:
  /// **'Radon'**
  String get s11cc92bdc3;

  /// fi: Hiilidioksidi
  ///
  /// In en, this message translates to:
  /// **'CO₂'**
  String get s095db91dfb;

  /// fi: Ilmanlaatu
  ///
  /// In en, this message translates to:
  /// **'Air quality'**
  String get s4b1eda4282;

  /// fi: Aurinkosähkö
  ///
  /// In en, this message translates to:
  /// **'Solar power'**
  String get s981854cf46;

  /// fi: Sähköauton laturi
  ///
  /// In en, this message translates to:
  /// **'EV charger'**
  String get s1a6081db34;

  /// fi: Televisio
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get sf435368c99;

  /// fi: Äänenvoimakkuus
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get s0cea5b1077;

  /// fi: Verho / sälekaihdin
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get s25d92a8625;

  /// fi: Home Assistant lukee jo tätä laitetta
  ///
  /// In en, this message translates to:
  /// **'Home Assistant already reads this device'**
  String get sa846059775;

  /// fi: Laitteella voi olla jo yhteys (esim. Home Assistant) – lue arvot HA:n kautta. Moni laite sallii vain yhden Modbus TCP -y
  ///
  /// In en, this message translates to:
  /// **'The device may already have a connection (e.g. Home Assistant) – read the values through HA. Many devices allow only one Modbus TCP connection.'**
  String get s18a1844439;

  /// fi: {p0} Modbus-arvoa löytyi Home Assistantista. Moni laite sallii vain yhden Modbus TCP -yhteyden, joten HA:n kautta lukemi
  ///
  /// In en, this message translates to:
  /// **'{p0} Modbus values found in Home Assistant. Many devices allow only one Modbus TCP connection, so reading through HA is the safest way.'**
  String sa29df4fc6b(String p0);

  /// fi: Käytä Home Assistantin kautta
  ///
  /// In en, this message translates to:
  /// **'Use via Home Assistant'**
  String get sb8c40d2c20;

  /// fi: Liitä modbus.yaml (tai configuration.yaml:n modbus:-osa). Yhteys ja laatat tehdään samoilla rekistereillä ja ajoituksill
  ///
  /// In en, this message translates to:
  /// **'Paste modbus.yaml (or the modbus: part of configuration.yaml). The connection and tiles use the same registers and timing.'**
  String get sfbf34ee532;

  /// fi: {p0} yhteys, {p1} laattaa
  ///
  /// In en, this message translates to:
  /// **'{p0} connection(s), {p1} tiles'**
  String s2d4fbaade1(String p0, String p1);

  /// fi: Modbus-laite tuotu Home Assistantista
  ///
  /// In en, this message translates to:
  /// **'Modbus device imported from Home Assistant'**
  String get s108e078c0c;

  /// fi: Sinulla on uusin versio ({p0}).
  ///
  /// In en, this message translates to:
  /// **'You have the latest version ({p0}).'**
  String sa0c07ccd04(String p0);

  /// fi: Päivityksiä ei voitu tarkistaa juuri nyt. Tarkista nettiyhteys ja yritä myöhemmin.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates right now. Check the internet connection and try again later.'**
  String get sa118d84538;

  /// fi: Uusi versio {p0} on saatavilla
  ///
  /// In en, this message translates to:
  /// **'Version {p0} is available'**
  String s9f2b092d8c(String p0);

  /// fi: Sinulla on nyt versio {p0}.
  ///
  /// In en, this message translates to:
  /// **'You have version {p0}.'**
  String sa5133b2c4a(String p0);

  /// fi: Mitä uutta:
  ///
  /// In en, this message translates to:
  /// **'What\'\'s new:'**
  String get se099b5797e;

  /// fi: Ohita tämä versio
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get s9315c3df42;

  /// fi: Myöhemmin
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get sdd5c8f0a9d;

  /// fi: Lataus oli viallinen
  ///
  /// In en, this message translates to:
  /// **'The download was corrupted'**
  String get s5a94ef2af1;

  /// fi: Lataus ei onnistunut
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get s81e4325573;

  /// fi: Tiedoston tarkistussumma ei täsmännyt, joten mitään ei asennettu. Yritä hetken päästä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The file checksum did not match, so nothing was installed. Please try again in a moment.'**
  String get s4b1d3df588;

  /// fi: Tarkista nettiyhteys ja yritä uudelleen. Voit myös ladata päivityksen julkaisusivulta.
  ///
  /// In en, this message translates to:
  /// **'Check the internet connection and try again. You can also download the update from the release page.'**
  String get s0c463c7069;

  /// fi: Avaa julkaisusivu
  ///
  /// In en, this message translates to:
  /// **'Open release page'**
  String get s5dd4c9671f;

  /// fi: Asennetaan versio {p0} – sovellus käynnistyy uudelleen hetken kuluttua.
  ///
  /// In en, this message translates to:
  /// **'Installing {p0} – the app restarts in a moment.'**
  String s8f5be45ff1(String p0);

  /// fi: Asennus epäonnistui: {p0}
  ///
  /// In en, this message translates to:
  /// **'Install failed: {p0}'**
  String sf207ef6dc2(String p0);

  /// fi: Päivitys ladattu
  ///
  /// In en, this message translates to:
  /// **'Update downloaded'**
  String get s49ddc3c3b6;

  /// fi: Tiedosto on tarkistettu ja tallennettu:
  /// {p0}
  ///
  /// Näin otat sen käyttöön:
  /// 1. Sulje Molaplan.
  /// 2. Pura zip-tiedosto vanhan Mol
  ///
  /// In en, this message translates to:
  /// **'The file is verified and saved:\n{p0}\n\nTo use it:\n1. Close Molaplan.\n2. Extract the zip over the old Molaplan folder (or into a new folder).\n3. Start molaplan.exe. Your settings are kept.'**
  String s04a05bb8fc(String p0);

  /// fi: Julkaisusivu
  ///
  /// In en, this message translates to:
  /// **'Release page'**
  String get s1dd246ec69;

  /// fi: Avaa zip
  ///
  /// In en, this message translates to:
  /// **'Open zip'**
  String get s0f07b20d45;

  /// fi: Avaa kansio
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get s6e1ebc8baa;

  /// fi: Asennus ei jatkunut
  ///
  /// In en, this message translates to:
  /// **'The install did not continue'**
  String get s6d9de3f94b;

  /// fi: Jos perut asennuksen itse, kaikki on kunnossa. Jos Androidin Asenna-ikkunaa ei näkynyt, paina Yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'If you cancelled it yourself, all is well. If Android\'\'s Install window did not appear, tap Try again.'**
  String get s25a6f00343;

  /// fi: Vahvista asennus Androidin ikkunasta tai ilmoituksesta.
  ///
  /// In en, this message translates to:
  /// **'Confirm the install in the Android window or notification.'**
  String get s29e92898c6;

  /// fi: Vahvista päivitys
  ///
  /// In en, this message translates to:
  /// **'Confirm the update'**
  String get s48093a1369;

  /// fi: Päivitys {p0} odottaa vahvistusta. Paina Avaa asennus (tai napauta ilmoitusta "Molaplan-päivitys valmis").
  ///
  /// In en, this message translates to:
  /// **'Update {p0} is waiting for your confirmation. Tap Open install (or the \"Molaplan-päivitys valmis\" notification).'**
  String s6d50eeae10(String p0);

  /// fi: Avaa asennus
  ///
  /// In en, this message translates to:
  /// **'Open install'**
  String get s1a5c09b6e4;

  /// fi: Asennus ei käynnistynyt
  ///
  /// In en, this message translates to:
  /// **'The install did not start'**
  String get sd1cdbd3630;

  /// fi: Android ei aloittanut päivityksen {p0} asennusta.
  ///
  /// Tarkista, että "Salli tästä lähteestä" on päällä Molaplanille, ja pai
  ///
  /// In en, this message translates to:
  /// **'Android did not start installing {p0}.\n\nCheck that \"Allow from this source\" is on for Molaplan and tap Update again. You can also download the APK from the release page.\n\nDetail: {p1}'**
  String s21972e23c1(String p0, String p1);

  /// fi: Avaa asetukset
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get sa1bd8d2533;

  /// fi: Salli päivitysten asennus
  ///
  /// In en, this message translates to:
  /// **'Allow installing updates'**
  String get sa065e7f650;

  /// fi: Android kysyy kerran luvan, jotta Molaplan saa asentaa omat päivityksensä.
  ///
  /// 1. Paina "Avaa asetukset".
  /// 2. Kytke päälle "
  ///
  /// In en, this message translates to:
  /// **'Android asks once for permission so Molaplan can install its own updates.\n\n1. Tap \"Open settings\".\n2. Turn on \"Allow from this source\".\n3. Come back and tap \"Update\" again.'**
  String get sdc3bf71baf;

  /// fi: Tarkistetaan…
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get s441683b7a8;

  /// fi: Ladataan päivitystä…
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get se83b7fb2ac;

  /// fi: Molaplan {p0} on saatavilla. Silta toimii normaalisti.
  ///
  /// In en, this message translates to:
  /// **'Molaplan {p0} is available. The bridge keeps working.'**
  String s0b68f81d82(String p0);

  /// fi: Tasmota-laite
  ///
  /// In en, this message translates to:
  /// **'Tasmota device'**
  String get s702ca14235;

  /// fi: ESPHome-laite
  ///
  /// In en, this message translates to:
  /// **'ESPHome device'**
  String get se0e5f715ad;

  /// fi: HomeKit-laite
  ///
  /// In en, this message translates to:
  /// **'HomeKit device'**
  String get s63b6e55469;

  /// fi: Tuntematon laite
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get s13e301a66e;

  /// fi: Puhelin
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get sddb2c2cb2b;

  /// fi: Tabletti
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get s16cd267576;

  /// fi: Tietokone
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get sec4679ec39;

  /// fi: Tulostin
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get s798f9a0558;

  /// fi: TV / mediatoistin
  ///
  /// In en, this message translates to:
  /// **'TV / media player'**
  String get s06109b8e5c;

  /// fi: Kaiutin
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get sc4655d321e;

  /// fi: Reititin
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get sa9f2f85b3e;

  /// fi: Verkkolevy
  ///
  /// In en, this message translates to:
  /// **'Network storage'**
  String get sf8360dcd74;

  /// fi: Palvelin
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get s25399cd337;

  /// fi: Älylaite
  ///
  /// In en, this message translates to:
  /// **'Smart device'**
  String get s8e21b6f258;

  /// fi: iPhonen hotspot
  ///
  /// In en, this message translates to:
  /// **'iPhone hotspot'**
  String get s76a76a654e;

  /// fi: Puhelimen hotspot
  ///
  /// In en, this message translates to:
  /// **'Phone hotspot'**
  String get s15d4ca1672;

  /// fi: Reititin / hotspot
  ///
  /// In en, this message translates to:
  /// **'Router / hotspot'**
  String get sd54522fe39;

  /// fi: Valvontapaneeli
  ///
  /// In en, this message translates to:
  /// **'Security panel'**
  String get s3294a9422d;

  /// fi: ESP32-laite
  ///
  /// In en, this message translates to:
  /// **'ESP32 device'**
  String get sb97a2b7ed6;

  /// fi: ei vielä ohjattavissa
  ///
  /// In en, this message translates to:
  /// **'not controllable yet'**
  String get s23f4820db7;

  /// fi: Airthings: lisää pilven tai Bluetoothin kautta
  ///
  /// In en, this message translates to:
  /// **'Airthings: add via the cloud or Bluetooth'**
  String get sdeeabebed9;

  /// fi: kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'via home bridge'**
  String get saae59a3865;

  /// fi: ohjataan ntfy-viesteillä
  ///
  /// In en, this message translates to:
  /// **'controlled with ntfy messages'**
  String get sf226dd023a;

  /// fi: jos tämä on valvontapaneeli, lisää se ntfy-komentolaitteena
  ///
  /// In en, this message translates to:
  /// **'if this is a security panel, add it as an ntfy command device'**
  String get s0e6aa5168c;

  /// fi: Malli
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get sdccd6e7f24;

  /// fi: MAC
  ///
  /// In en, this message translates to:
  /// **'\')\'\'}\''**
  String get s891a4b434e;

  /// fi: Portit
  ///
  /// In en, this message translates to:
  /// **'Ports'**
  String get s43aba09687;

  /// fi: Lähteet
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get scee3511db6;

  /// fi: Nimeä laite
  ///
  /// In en, this message translates to:
  /// **'Name the device'**
  String get sbc46a05125;

  /// fi: Nimi muistetaan tällä laitteella.
  ///
  /// In en, this message translates to:
  /// **'Remembered on this device.'**
  String get s1d5ed84aed;

  /// fi: Lisää komentolaitteena
  ///
  /// In en, this message translates to:
  /// **'Add as command device'**
  String get s3e6dd6ff2d;

  /// fi: Laitehaku toimii selaimessa vain kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'In the browser, device search works only through a home bridge'**
  String get sb616303f5b;

  /// fi: Voit silti lisätä pilvi- ja ntfy-laitteita alta.
  ///
  /// In en, this message translates to:
  /// **'You can still add cloud and ntfy devices below.'**
  String get sef469cadc3;

  /// fi: kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'via the home bridge'**
  String get sa0fccfbcab;

  /// fi: Etsi laitteet
  ///
  /// In en, this message translates to:
  /// **'Find devices'**
  String get s1169d2d093;

  /// fi: Etsitään kotiverkosta…
  ///
  /// In en, this message translates to:
  /// **'Searching your home network…'**
  String get s55b85f29a6;

  /// fi: Molaplan etsii kotiverkosta laitteet, jotka se tunnistaa.
  ///
  /// In en, this message translates to:
  /// **'Molaplan looks for devices it recognises on your home network.'**
  String get se9c923ff0b;

  /// fi: Tunnettuja laitteita ei löytynyt. Valitse merkki alta.
  ///
  /// In en, this message translates to:
  /// **'No known devices found. Pick the brand below.'**
  String get s3ff2220816;

  /// fi: Löytyi {p0}. Lisää napauttamalla.
  ///
  /// In en, this message translates to:
  /// **'Found {p0}. Tap to add.'**
  String s2a9142dc3e(String p0);

  /// fi: Etsi uudelleen
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get s2fc39b0bd7;

  /// fi: Etsi
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get s0a9acb5af1;

  /// fi: Et ole kotona: kotisilta etsi laitteet kotiverkosta.
  ///
  /// In en, this message translates to:
  /// **'You are away: the home bridge searched your home network.'**
  String get s9a018b8166;

  /// fi: Tämä verkko
  ///
  /// In en, this message translates to:
  /// **'This network'**
  String get s55d0b95fd2;

  /// fi: Nämä ovat tämän laitteen omassa verkossa, eivät kodissa {p0}. Niitä ei lisätä siihen kotiin.
  ///
  /// In en, this message translates to:
  /// **'These are on this device\'\'s own network, not at {p0}. They are not added to that home.'**
  String s955b44aaa4(String p0);

  /// fi: Muut laitteet verkossa ({p0})
  ///
  /// In en, this message translates to:
  /// **'Other devices on the network ({p0})'**
  String sf16a25c313(String p0);

  /// fi: Näitä Molaplan ei ohjaa. iPhonet näkyvät nimellä vain hereillä ollessaan.
  ///
  /// In en, this message translates to:
  /// **'Molaplan does not control these. iPhones show their name only while awake.'**
  String get s9e8430c37b;

  /// fi: Lämmittää
  ///
  /// In en, this message translates to:
  /// **'Heating'**
  String get s7f308d40c8;

  /// fi: Jäähdyttää
  ///
  /// In en, this message translates to:
  /// **'Cooling'**
  String get s41de361b3e;

  /// fi: Kuivaa
  ///
  /// In en, this message translates to:
  /// **'Drying'**
  String get s4f7ccb7138;

  /// fi: Puhaltaa
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get s9b2398228e;

  /// fi: Odottaa
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get s533177c689;

  /// fi: Lämmitys
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get sa3e8beed42;

  /// fi: Jäähdytys
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get s6c9668fbd9;

  /// fi: Kuivaus
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get s9db8aefc43;

  /// fi: Puhallus
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get s0117dea8bc;

  /// fi: Hiljainen
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get sb680eb3021;

  /// fi: Pieni
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get s4299eb9d18;

  /// fi: Pieni–keski
  ///
  /// In en, this message translates to:
  /// **'Medium-low'**
  String get s90ba0c57d4;

  /// fi: Keski
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get s0cb68026a7;

  /// fi: Keski–suuri
  ///
  /// In en, this message translates to:
  /// **'Medium-high'**
  String get s9c5e4ed5cb;

  /// fi: Suuri
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get s688b92a62f;

  /// fi: Turbo
  ///
  /// In en, this message translates to:
  /// **'Turbo'**
  String get sb1ef6ab439;

  /// fi: Ulkona
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get s339446ffe7;

  /// fi: Puhallin
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get s018d2e08f4;

  /// fi: Ei lukemaa
  ///
  /// In en, this message translates to:
  /// **'No reading'**
  String get s11a7c24b38;

  /// fi: käyrä
  ///
  /// In en, this message translates to:
  /// **'curve'**
  String get s79bbbe6195;

  /// fi: asetus
  ///
  /// In en, this message translates to:
  /// **'set'**
  String get s28b7c227f0;

  /// fi: Ei hintoja
  ///
  /// In en, this message translates to:
  /// **'No prices'**
  String get s306729fe62;

  /// fi: c/t
  ///
  /// In en, this message translates to:
  /// **'c/h'**
  String get s80c4ecec94;

  /// fi: Kulutus (kWh)
  ///
  /// In en, this message translates to:
  /// **'Usage (kWh)'**
  String get sb68e905fc4;

  /// fi: Kustannus
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get s5fc5085143;

  /// fi: Vanha tieto
  ///
  /// In en, this message translates to:
  /// **'Old data'**
  String get s2b2118a93b;

  /// fi: Halvin tunti tänään
  ///
  /// In en, this message translates to:
  /// **'Cheapest hour today'**
  String get s68fcfcfed1;

  /// fi: Tänään keskihinta
  ///
  /// In en, this message translates to:
  /// **'Average today'**
  String get s86ff059f5e;

  /// fi: Kallein tunti tänään
  ///
  /// In en, this message translates to:
  /// **'Priciest hour today'**
  String get s7b911d48c6;

  /// fi: Hetkellinen kustannus
  ///
  /// In en, this message translates to:
  /// **'Instant cost'**
  String get s29dbf49d92;

  /// fi: halvin
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get s723c887da6;

  /// fi: ka
  ///
  /// In en, this message translates to:
  /// **'avg'**
  String get s3b36524e04;

  /// fi: kallein
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get scaaff6345d;

  /// fi: Kulutus
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get s5f131c3ec4;

  /// fi: Luvut tuntikeskiarvoina
  ///
  /// In en, this message translates to:
  /// **'Figures are hourly averages'**
  String get s039bb374fe;

  /// fi: Vaihe
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get se455dc672b;

  /// fi: Ohita opas
  ///
  /// In en, this message translates to:
  /// **'Skip guide'**
  String get s3ddd2678bf;

  /// fi: Valitse laitteesi alta. Täytät vain sen osoitteen – loput tehdään puolestasi.
  ///
  /// In en, this message translates to:
  /// **'Pick your device below. You only fill in its address – the rest is done for you.'**
  String get s171ac59e67;

  /// fi: Molaplan on kotisi oma ohjauspaneeli. Kokoat siihen itse ne laitteet ja napit, joita tarvitset.
  ///
  /// In en, this message translates to:
  /// **'Molaplan is your home\'\'s own control panel. You put in exactly the devices and buttons you need.'**
  String get se722dfcec9;

  /// fi: Näe tilanne yhdellä silmäyksellä
  ///
  /// In en, this message translates to:
  /// **'See everything at a glance'**
  String get scbac938ead;

  /// fi: Lämpötilat, valot, hälytys ja kamerakuva samassa näkymässä.
  ///
  /// In en, this message translates to:
  /// **'Temperatures, lights, alarm and camera in one view.'**
  String get se25f930e31;

  /// fi: Ohjaa yhdellä napautuksella
  ///
  /// In en, this message translates to:
  /// **'Control with one tap'**
  String get s3e450dba98;

  /// fi: Valot päälle, IV-kone tehostukselle tai "Lähden kotoa" -painike, joka tekee monta asiaa kerralla.
  ///
  /// In en, this message translates to:
  /// **'Lights on, boost the ventilation, or a \"Leaving home\" button that does many things at once.'**
  String get sdda6a3f06e;

  /// fi: Sama koti kaikilla laitteilla
  ///
  /// In en, this message translates to:
  /// **'The same home on all devices'**
  String get sbcac0cd35a;

  /// fi: Halutessasi kirjaudu tilillä, niin PC, tabletti ja puhelin näyttävät saman kodin. Salasanat salataan laitteellasi. Tili
  ///
  /// In en, this message translates to:
  /// **'Sign in if you like, and PC, tablet and phone show the same home. Passwords are encrypted on your device. No account needed.'**
  String get sd43d517cc7;

  /// fi: Minulla on jo Molaplan-tili – kirjaudu
  ///
  /// In en, this message translates to:
  /// **'I already have a Molaplan account – sign in'**
  String get s70fff97e97;

  /// fi: Aloitetaan
  ///
  /// In en, this message translates to:
  /// **'Let\'\'s start'**
  String get sd6561a08ca;

  /// fi: Ruudut ovat valmiina
  ///
  /// In en, this message translates to:
  /// **'Your tiles are ready'**
  String get se5be2a8386;

  /// fi: Lisää ensimmäinen ruutu
  ///
  /// In en, this message translates to:
  /// **'Add your first tile'**
  String get s8162694dbe;

  /// fi: Laitteellesi tehtiin nämä ruudut. Voit muuttaa ja järjestää niitä myöhemmin.
  ///
  /// In en, this message translates to:
  /// **'These tiles were made for your device. You can change and arrange them later.'**
  String get s7b2a30b77c;

  /// fi: Ruutu näyttää tiedon tai ohjaa laitetta. Valitse millainen ruutu tehdään:
  ///
  /// In en, this message translates to:
  /// **'A tile shows information or controls a device. Choose what kind of tile:'**
  String get s39e163fa49;

  /// fi: Teen tämän myöhemmin
  ///
  /// In en, this message translates to:
  /// **'I\'\'ll do this later'**
  String get s4bfb026e45;

  /// fi: Haluatko ohjata kotia myös kodin ulkopuolelta?
  ///
  /// In en, this message translates to:
  /// **'Control your home from outside too?'**
  String get s3f0351473c;

  /// fi: Kotona kaikki toimii jo. Kodin ulkopuolelta tarvitaan kotiin yksi aina päällä oleva laite (vanha tabletti tai PC) – ei r
  ///
  /// In en, this message translates to:
  /// **'At home everything works already. From outside you need one always-on device at home (an old tablet or a PC) – no router settings, no accounts.'**
  String get s6fe6fe631f;

  /// fi: Etäyhteys on käytössä.
  ///
  /// In en, this message translates to:
  /// **'Remote access is on.'**
  String get sb599b7432f;

  /// fi: Tämä laite on kotisilta.
  ///
  /// In en, this message translates to:
  /// **'This device is the home bridge.'**
  String get s33a294d472;

  /// fi: Ei nyt – vain kotona
  ///
  /// In en, this message translates to:
  /// **'Not now – home only'**
  String get s4aa8cce504;

  /// fi: Valmista!
  ///
  /// In en, this message translates to:
  /// **'All set!'**
  String get sd3c370ca52;

  /// fi: Napauta ruutua
  ///
  /// In en, this message translates to:
  /// **'Tap a tile'**
  String get s1359035b73;

  /// fi: Kytkin vaihtuu päälle/pois, painike suorittaa komennon.
  ///
  /// In en, this message translates to:
  /// **'A switch toggles, a button runs its command.'**
  String get sfd26c8e50b;

  /// fi: Kynä-painike ylhäällä
  ///
  /// In en, this message translates to:
  /// **'Pencil button at the top'**
  String get s416c8184a7;

  /// fi: Muokkaa, lisää, poista ja järjestä ruutuja vetämällä.
  ///
  /// In en, this message translates to:
  /// **'Edit, add, delete and drag tiles around.'**
  String get s2ba275defe;

  /// fi: Paina ruutua pitkään
  ///
  /// In en, this message translates to:
  /// **'Long-press a tile'**
  String get se872eeb0f5;

  /// fi: Näet lisätiedot ja selityksen, jos jokin ei toimi.
  ///
  /// In en, this message translates to:
  /// **'See details and an explanation if something is wrong.'**
  String get s63496941fc;

  /// fi: Sieltä löydät tämän oppaan, etäyhteyden ja varmuuskopioinnin.
  ///
  /// In en, this message translates to:
  /// **'Find this guide, remote access and backups there.'**
  String get s080be778d5;

  /// fi: Siirry omaan näkymään
  ///
  /// In en, this message translates to:
  /// **'Go to my dashboard'**
  String get sae0fae7127;

  /// fi: Valitse yhteystyyppi
  ///
  /// In en, this message translates to:
  /// **'Choose connection type'**
  String get s2adc3a77ed;

  /// fi: Ei yhteyksiä vielä. Lisää laite tai palvelu, esim. IV-kone (Modbus), Home Assistant tai kamera.
  ///
  /// In en, this message translates to:
  /// **'No connections yet. Add a device or service, e.g. ventilation unit (Modbus), Home Assistant or a camera.'**
  String get sc6d89693a5;

  /// fi: Pakollinen kenttä
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get s07c82cb0af;

  /// fi: Sama kanava kahdesti?
  ///
  /// In en, this message translates to:
  /// **'The same topic twice?'**
  String get see3fd4862d;

  /// fi: Komentokanava ja Vastauskanava ovat samat. Useimmat laitteet (esim. kameravalvonnan paneeli) kuuntelevat komentoja omall
  ///
  /// In en, this message translates to:
  /// **'The command topic and the reply topic are the same. Most devices (e.g. the camera surveillance panel) listen on their own command topic and answer on your notification topic – then commands never arrive. Save anyway?'**
  String get sb80a9b6813;

  /// fi: Tallenna silti
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get s70f720de6d;

  /// fi: Poistetaanko yhteys?
  ///
  /// In en, this message translates to:
  /// **'Delete connection?'**
  String get sf702cf0ac6;

  /// fi: {p0} ruutua käyttää tätä yhteyttä, ne lakkaavat toimimasta.
  ///
  /// In en, this message translates to:
  /// **'{p0} tiles use this connection and will stop working.'**
  String s6b83de0ab9(String p0);

  /// fi: Yhteys poistetaan tältä laitteelta.
  ///
  /// In en, this message translates to:
  /// **'The connection will be removed from this device.'**
  String get sccd1325381;

  /// fi: IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Ruuduissa näkyy viimeksi lähetetty tila.
  ///
  /// In en, this message translates to:
  /// **'IR is one-way: the heat pump does not confirm commands. Tiles show the last sent state.'**
  String get s837e0fc5e6;

  /// fi: Tuo pumpun rekisterilista (CSV)
  ///
  /// In en, this message translates to:
  /// **'Import the pump\'\'s register list (CSV)'**
  String get sf1ffb49d9c;

  /// fi: Yhteys toimii!
  ///
  /// In en, this message translates to:
  /// **'Connection works!'**
  String get s09737988fd;

  /// fi: Salasanat ja tokenit tallennetaan laitteen suojattuun tallennustilaan.
  ///
  /// In en, this message translates to:
  /// **'Passwords and tokens are stored in the device\'\'s secure storage.'**
  String get s0a972aa85e;

  /// fi: Makuuhuone
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get s7ba50ea69e;

  /// fi: Keittiö
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get s9e9723b263;

  /// fi: Olohuone
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get scce769451b;

  /// fi: Kylpyhuone
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get s9d5dca2dee;

  /// fi: Sauna
  ///
  /// In en, this message translates to:
  /// **'Sauna'**
  String get s2569505205;

  /// fi: Eteinen
  ///
  /// In en, this message translates to:
  /// **'Hallway'**
  String get s1c65dad1f5;

  /// fi: Piha / puutarha
  ///
  /// In en, this message translates to:
  /// **'Yard / garden'**
  String get sa4d90bb5da;

  /// fi: Tekninen tila
  ///
  /// In en, this message translates to:
  /// **'Technical room'**
  String get s4a7be17a36;

  /// fi: Työhuone
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get s01e404f15f;

  /// fi: Lastenhuone
  ///
  /// In en, this message translates to:
  /// **'Kids\'\' room'**
  String get sfd8305add2;

  /// fi: Mökki
  ///
  /// In en, this message translates to:
  /// **'Cottage'**
  String get scd87fb4dd7;

  /// fi: rtsp-transport
  ///
  /// In en, this message translates to:
  /// **'tcp'**
  String get s772c158a57;

  /// fi: network-timeout
  ///
  /// In en, this message translates to:
  /// **'8'**
  String get s2d65587b87;

  /// fi: profile
  ///
  /// In en, this message translates to:
  /// **'low-latency'**
  String get sea00017814;

  /// fi: Sähköpostilla ei ole Molaplan-tiliä.
  ///
  /// In en, this message translates to:
  /// **'There is no Molaplan account with that e-mail.'**
  String get s53a9fe5e42;

  /// fi: Osoitteella ei löytynyt Molaplan-käyttäjää. Hänen pitää kirjautua Molaplan 0.9:ään kerran – tai lähetä hänelle kutsukood
  ///
  /// In en, this message translates to:
  /// **'No Molaplan user with that address. They need to sign in to Molaplan 0.9 once – or send them an invite code.'**
  String get sb4bd4baa5c;

  /// fi: Valituissa ei ole jaettavia laitteita (termostaatteja ei voi vielä jakaa).
  ///
  /// In en, this message translates to:
  /// **'Nothing shareable selected (thermostats cannot be shared yet).'**
  String get s7ed2aecb01;

  /// fi: Kutsua ei enää ole.
  ///
  /// In en, this message translates to:
  /// **'The invite no longer exists.'**
  String get s707b7ff598;

  /// fi: Avaa ensin tilin salaukset tällä laitteella (Tili → Avaa salasanalla). Jakaminen käyttää tilin avainta.
  ///
  /// In en, this message translates to:
  /// **'Unlock the account secrets on this device first (Account → Unlock with password). Sharing uses the account key.'**
  String get s5ea320fb1c;

  /// fi: Tämä on asentajan kutsu, ja sen voi käyttää vain Molaplanin hyväksymä asentaja (Asetukset → Asentaja → Hae asentajaksi).
  ///
  /// In en, this message translates to:
  /// **'This invite is for an installer and only an installer approved by Molaplan can use it (Settings → Installer → Apply).'**
  String get s2855893bfc;

  /// fi: Vain Molaplanin ylläpito voi tehdä tämän.
  ///
  /// In en, this message translates to:
  /// **'Only Molaplan admins can do this.'**
  String get sb8df145fc9;

  /// fi: Koodi on väärä, vanhentunut tai jo käytetty.
  ///
  /// In en, this message translates to:
  /// **'The code is wrong, expired or already used.'**
  String get sa562754cb5;

  /// fi: Kotisilta ei vastaa. Jakaminen tarvitsee kotisillan (Etäkäyttö), koska oikeudet valvotaan siellä.
  ///
  /// In en, this message translates to:
  /// **'The home bridge does not answer. Sharing needs the home bridge (Remote access) – permissions are enforced there.'**
  String get s9c37d7a89c;

  /// fi: Kotisilta on vanha eikä osaa jakamista. Päivitä silta (Etäkäyttö → Päivitä silta).
  ///
  /// In en, this message translates to:
  /// **'The home bridge is too old for sharing. Update it (Remote access → Update bridge).'**
  String get sc858a8f851;

  /// fi: Ei yhteyttä Molaplan-tiliin.
  ///
  /// In en, this message translates to:
  /// **'No connection to the Molaplan account.'**
  String get s1a52f53861;

  /// fi: Tilipalvelu ei hyväksynyt pyyntöä: {p0}
  ///
  /// In en, this message translates to:
  /// **'The account service refused: {p0}'**
  String s2457ec4502(String p0);

  /// fi: Kodin silta ei ole yhteydessä.
  ///
  /// In en, this message translates to:
  /// **'The home bridge is offline.'**
  String get s4bc537975e;

  /// fi: Jako on peruttu.
  ///
  /// In en, this message translates to:
  /// **'The share was revoked.'**
  String get s2fb5fe14e4;

  /// fi: Kotisilta ei vastaa.
  ///
  /// In en, this message translates to:
  /// **'The home bridge does not answer.'**
  String get s7b44d47d45;

  /// fi: Ei yhteyttä.
  ///
  /// In en, this message translates to:
  /// **'No connection.'**
  String get s8eddd585bc;

  /// fi: Ei oikeutta tähän toimintoon.
  ///
  /// In en, this message translates to:
  /// **'Not allowed.'**
  String get s47998395f5;

  /// fi: Vain katselu
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get s7f504a8c64;

  /// fi: Ohjaus
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get s9c067115ef;

  /// fi: Täysi (ohjaus + asetukset)
  ///
  /// In en, this message translates to:
  /// **'Full (control + settings)'**
  String get s8343921765;

  /// fi: Koodi odottaa käyttöä
  ///
  /// In en, this message translates to:
  /// **'Code not used yet'**
  String get s211d9f0a3a;

  /// fi: Odottaa hyväksyntää
  ///
  /// In en, this message translates to:
  /// **'Waiting for acceptance'**
  String get s1e6b3fe5dc;

  /// fi: Vahvistetaan…
  ///
  /// In en, this message translates to:
  /// **'Being confirmed…'**
  String get sb13063b8cd;

  /// fi: Käytössä
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get s13b6f87b0a;

  /// fi: Hylätty
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get sed1d8dbf2b;

  /// fi: Peruttu
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get s0123f33869;

  /// fi: Jakaminen tarvitsee Molaplan-tilin, jotta kutsut löytävät perille ja salaus toimii.
  ///
  /// In en, this message translates to:
  /// **'Sharing needs a Molaplan account so invites can reach people and encryption works.'**
  String get scdfdf5d233;

  /// fi: Anna perheenjäsenelle, naapurille tai asentajalle pääsy valitsemiisi laitteisiin. Salasanat ja osoitteet eivät lähde kot
  ///
  /// In en, this message translates to:
  /// **'Give a family member, neighbour or installer access to the devices you choose. Passwords and addresses never leave home, and you can revoke at any time.'**
  String get s85abc4496d;

  /// fi: Jaa laitteita
  ///
  /// In en, this message translates to:
  /// **'Share devices'**
  String get sb4602bb0a6;

  /// fi: Käytä kutsukoodia
  ///
  /// In en, this message translates to:
  /// **'Use an invite code'**
  String get sffe19ad543;

  /// fi: Kutsut sinulle
  ///
  /// In en, this message translates to:
  /// **'Invites for you'**
  String get s61036a5d51;

  /// fi: laitteita
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get s8af08eb19e;

  /// fi: Hyväksytty
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get sbb84536839;

  /// fi: Jaettu minulle
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get s2fd1394b33;

  /// fi: Jakamasi
  ///
  /// In en, this message translates to:
  /// **'Your shares'**
  String get seaa0c13606;

  /// fi: Et ole jakanut mitään.
  ///
  /// In en, this message translates to:
  /// **'You have not shared anything.'**
  String get s450c60afd0;

  /// fi: Kutsukoodi
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get s33f41d417c;

  /// fi: Perutaanko jako?
  ///
  /// In en, this message translates to:
  /// **'Revoke the share?'**
  String get s9cdf3dcc87;

  /// fi: Pääsy loppuu heti, kun kotisilta saa tiedon (yleensä saman tien).
  ///
  /// In en, this message translates to:
  /// **'Access ends as soon as the home bridge hears of it (usually at once).'**
  String get s9d0ac1d1ee;

  /// fi: Peru jako
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get s4417570cbb;

  /// fi: Jako peruttu
  ///
  /// In en, this message translates to:
  /// **'Share revoked'**
  String get s280e22cbc9;

  /// fi: Nimesi jaoissa
  ///
  /// In en, this message translates to:
  /// **'Your name in shares'**
  String get sd742357fc8;

  /// fi: Turvallisuus: kotisilta tarkistaa jokaisen pyynnön oikeudet. Yhteystunnus kulkee salattuna vain vastaanottajan avaimelle
  ///
  /// In en, this message translates to:
  /// **'Security: the home bridge checks the rights of every request. The connection credential travels encrypted to the recipient\'\'s key only; device passwords and addresses never leave home.'**
  String get sfe0000a1a9;

  /// fi: Lisää asiakas koodilla
  ///
  /// In en, this message translates to:
  /// **'Add a customer with a code'**
  String get s0577e25cbe;

  /// fi: Koodi hyväksytty. Pääsy aukeaa, kun omistajan Molaplan vahvistaa sen (yleensä parissa minuutissa).
  ///
  /// In en, this message translates to:
  /// **'Code accepted. Access opens when the owner\'\'s Molaplan confirms it (usually within a couple of minutes).'**
  String get sce4c69f42c;

  /// fi: Anna koodi (tai linkki) vastaanottajalle: Molaplan → Jakaminen → Käytä kutsukoodia. Voimassa 7 päivää, kerran.
  ///
  /// In en, this message translates to:
  /// **'Give the code (or link) to the recipient: Molaplan → Sharing → Use an invite code. Valid for 7 days, once.'**
  String get sd1520d6367;

  /// fi: Kopioi linkki
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get s563abff5ad;

  /// fi: Kutsu lähetetty – vastaanottaja hyväksyy sen Molaplanissa.
  ///
  /// In en, this message translates to:
  /// **'Invite sent – the recipient accepts it in Molaplan.'**
  String get s0daf5e9cb6;

  /// fi: Muuta jakoa
  ///
  /// In en, this message translates to:
  /// **'Change share'**
  String get s707a062202;

  /// fi: 1. Mitä jaetaan
  ///
  /// In en, this message translates to:
  /// **'1. What to share'**
  String get s79f72dbe13;

  /// fi: Napauta näkymää jakaaksesi sen kaikki laitteet, tai valitse yksittäin.
  ///
  /// In en, this message translates to:
  /// **'Tap a view to share all its devices, or pick them one by one.'**
  String get s58e14dc230;

  /// fi: Koko näkymä
  ///
  /// In en, this message translates to:
  /// **'Whole view'**
  String get sdb49fc5671;

  /// fi: 2. Oikeudet
  ///
  /// In en, this message translates to:
  /// **'2. Rights'**
  String get sa7cf1a01d7;

  /// fi: Katselu
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get s3b2376ac74;

  /// fi: Täysi
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get s6605942623;

  /// fi: Näkee tilat ja mittaukset, ei voi ohjata.
  ///
  /// In en, this message translates to:
  /// **'Sees states and readings, cannot control.'**
  String get s9ccbd78d51;

  /// fi: Voi kytkeä ja säätää, ei muuttaa asetuksia (esim. lämpötilan asetusarvoja).
  ///
  /// In en, this message translates to:
  /// **'Can switch and adjust, cannot change settings (e.g. temperature setpoints).'**
  String get sb143b5c9f1;

  /// fi: Ohjaus ja laitteiden asetukset. Omia näkymiäsi tai salasanoja hän ei näe.
  ///
  /// In en, this message translates to:
  /// **'Control and device settings. Never your own views or passwords.'**
  String get s32dc2aa139;

  /// fi: 3. Kenelle
  ///
  /// In en, this message translates to:
  /// **'3. To whom'**
  String get se153d3c421;

  /// fi: Molaplan-käyttäjälle (sähköposti)
  ///
  /// In en, this message translates to:
  /// **'A Molaplan user (e-mail)'**
  String get s62e68022e1;

  /// fi: Kutsukoodi tai -linkki
  ///
  /// In en, this message translates to:
  /// **'Invite code or link'**
  String get s447da2f746;

  /// fi: Nimi jaolle (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Name for the share (optional)'**
  String get se7272a5713;

  /// fi: Oikeudet laitekohtaisesti
  ///
  /// In en, this message translates to:
  /// **'Rights per device'**
  String get s03f60936b0;

  /// fi: Näe
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get s385022d526;

  /// fi: Ohjaa
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get s482464ebd5;

  /// fi: Ilmoita ntfy-aiheeseen (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Notify an ntfy topic (optional)'**
  String get s5897aaa050;

  /// fi: Viestissä ei ole koodia eikä laitetietoja.
  ///
  /// In en, this message translates to:
  /// **'The message contains no code or device details.'**
  String get sd4faf9db62;

  /// fi: Luo kutsukoodi
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get sdec87898c3;

  /// fi: Lähetä kutsu
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get s19c2104a9d;

  /// fi: Omistaja
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get s8b4d48dfaf;

  /// fi: Huomioitavaa
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get s90944b5e7c;

  /// fi: hälytys
  ///
  /// In en, this message translates to:
  /// **'alarm'**
  String get s1364743ec7;

  /// fi: Suorita
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get s5416a5cdf7;

  /// fi: Näytä kuva
  ///
  /// In en, this message translates to:
  /// **'Show picture'**
  String get s8debff3196;

  /// fi: Asiakkaasi, jotka ovat antaneet sinulle pääsyn. Näet vain jaetut laitteet ja toimit asiakkaan antamin oikeuksin – salasa
  ///
  /// In en, this message translates to:
  /// **'Customers who gave you access. You see only the shared devices and act within the rights the customer gave – never their passwords.'**
  String get s2220ce611a;

  /// fi: Asentajan tilasi ei ole voimassa.
  ///
  /// In en, this message translates to:
  /// **'Your installer status is not valid.'**
  String get s6f3c62fc03;

  /// fi: Ei asiakkaita vielä. Anna asiakkaalle asentajatunnuksesi {p0}: asiakas avaa Asetukset → Asentaja → Anna pääsy.
  ///
  /// In en, this message translates to:
  /// **'No customers yet. Give your customer your installer ID {p0}: they open Settings → Installer → Give access.'**
  String s7ebc2621b7(String p0);

  /// fi: Odottaa asiakkaan Molaplanin vahvistusta
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer\'\'s Molaplan to confirm'**
  String get sa52cf49adc;

  /// fi: huomiota
  ///
  /// In en, this message translates to:
  /// **'alerts'**
  String get s35e8813a82;

  /// fi: Etsii kotiverkosta laitteet, joissa Modbus TCP on päällä (portit 502, 503 ja 5020), ja kokeilee laitteen osoitteet (unit
  ///
  /// In en, this message translates to:
  /// **'Looks for devices with Modbus TCP on (ports 502, 503 and 5020) and tries the unit ids. Takes about half a minute.'**
  String get s1b85ad9e38;

  /// fi: Oma portti (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Own port (optional)'**
  String get seb1f4357ea;

  /// fi: Skannaa uudelleen
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get s06760a6970;

  /// fi: Skannaa
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get s23d146db23;

  /// fi: Skannataan…
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get s18e7ad553e;

  /// fi: Et ole kotona: kotisilta skannasi kotiverkon.
  ///
  /// In en, this message translates to:
  /// **'You are away: the home bridge scanned.'**
  String get s721647a6cd;

  /// fi: Skannaus epäonnistui
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get s08e57d2d85;

  /// fi: Modbus-laitteita ei löytynyt. Tarkista että Modbus TCP on päällä laitteen asetuksista ja että laite on samassa verkossa
  ///
  /// In en, this message translates to:
  /// **'No Modbus devices found. Check that Modbus TCP is on in the device settings and that it is in the same network (not guest Wi-Fi).'**
  String get s4cf60b9350;

  /// fi: Modbus-laite
  ///
  /// In en, this message translates to:
  /// **'Modbus device'**
  String get sbd8ee8a14f;

  /// fi: yhdyskäytävä
  ///
  /// In en, this message translates to:
  /// **'gateway'**
  String get sf0462b25ac;

  /// fi: {p0}-esiasetus
  ///
  /// In en, this message translates to:
  /// **'{p0} preset'**
  String s28d9c4c7dc(String p0);

  /// fi: löytyi ilmoituksesta
  ///
  /// In en, this message translates to:
  /// **'found from its announcement'**
  String get sc6cde0d476;

  /// fi: Laite ei ota yhteyttä vastaan
  ///
  /// In en, this message translates to:
  /// **'The device does not accept a connection'**
  String get s166da70285;

  /// fi: Laitteella voi olla jo yhteys (esim. Home Assistant), lue arvot HA:n kautta. Moni laite sallii vain yhden Modbus TCP -yh
  ///
  /// In en, this message translates to:
  /// **'The device may already have a connection (e.g. Home Assistant) – read the values through HA. Many devices allow only one Modbus TCP connection.'**
  String get sbe97262d91;

  /// fi: Portti auki, mutta ei Modbus-vastausta
  ///
  /// In en, this message translates to:
  /// **'Port open, no Modbus reply'**
  String get s24e5139123;

  /// fi: Tarkista laitteen unit id ja Modbus-asetukset. Napauta käyttääksesi tätä osoitetta.
  ///
  /// In en, this message translates to:
  /// **'Check the unit id and Modbus settings. Tap to use this address.'**
  String get s9041c140be;

  /// fi: Sää
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get sdca1898723;

  /// fi: Aseta kodin sijainti
  ///
  /// In en, this message translates to:
  /// **'Set the home location'**
  String get s64f4d1e11a;

  /// fi: Yritä nyt
  ///
  /// In en, this message translates to:
  /// **'Try now'**
  String get sbf7cc3de9a;

  /// fi: Valitse huoneen kuva
  ///
  /// In en, this message translates to:
  /// **'Choose a room photo'**
  String get sec88246e24;

  /// fi: Minkä huoneen kuva?
  ///
  /// In en, this message translates to:
  /// **'Photo for which room?'**
  String get s252b8e1289;

  /// fi: Valitse valmis huonekuva tai oma kuva. Kuva näkyy otsikkona tai koko näkymän taustana.
  ///
  /// In en, this message translates to:
  /// **'Pick a built-in room picture or your own photo. It is shown as the header or behind the whole view.'**
  String get sa27e5362de;

  /// fi: Valitse oma kuva
  ///
  /// In en, this message translates to:
  /// **'Choose your own picture'**
  String get s84ef77e1ca;

  /// fi: Otsikkokuva
  ///
  /// In en, this message translates to:
  /// **'Header picture'**
  String get s0bec34cd24;

  /// fi: Koko näkymän tausta
  ///
  /// In en, this message translates to:
  /// **'Whole view background'**
  String get s7b1e22fca7;

  /// fi: Himmennys
  ///
  /// In en, this message translates to:
  /// **'Dimming'**
  String get s229e29f9ee;

  /// fi: Sumennus
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get s38285117e6;

  /// fi: Enintään {p0} kuvaa. Poista jokin ensin.
  ///
  /// In en, this message translates to:
  /// **'At most {p0} pictures. Remove one first.'**
  String s6c487e340b(String p0);

  /// fi: Trendi
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get s6f29aeb685;

  /// fi: Mittari + trendi
  ///
  /// In en, this message translates to:
  /// **'Gauge + trend'**
  String get s3298699c1a;

  /// fi: Luku
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get sed593f53ed;

  /// fi: Kerätään dataa…
  ///
  /// In en, this message translates to:
  /// **'Collecting data…'**
  String get s9027c88cb7;

  /// fi: 7 vrk
  ///
  /// In en, this message translates to:
  /// **'7 d'**
  String get sf05d2a09f1;

  /// fi: huom.
  ///
  /// In en, this message translates to:
  /// **'tmrw'**
  String get s3ec9d77947;

  /// fi: nyt
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get sed9b5e52f6;

  /// fi: Yleensä näihin ei tarvitse koskea
  ///
  /// In en, this message translates to:
  /// **'Usually you don\'\'t need these'**
  String get s5d477f3cd8;

  /// fi: esim.
  ///
  /// In en, this message translates to:
  /// **'e.g.'**
  String get s2315e0e739;

  /// fi: 24 h eteenpäin
  ///
  /// In en, this message translates to:
  /// **'24 h ahead'**
  String get s66ad384363;

  /// fi: Tänään + huomenna
  ///
  /// In en, this message translates to:
  /// **'Today + tomorrow'**
  String get s6df3187e65;

  /// fi: 48h
  ///
  /// In en, this message translates to:
  /// **'48 h'**
  String get s76379cf7c6;

  /// fi: tunnin päästä
  ///
  /// In en, this message translates to:
  /// **'in 1 h'**
  String get sff03a35d96;

  /// fi: vanhat hinnat
  ///
  /// In en, this message translates to:
  /// **'old prices'**
  String get sf9e22ac5e7;

  /// fi: Näkymä on lukittu
  ///
  /// In en, this message translates to:
  /// **'The view is locked'**
  String get s58aaa6dade;

  /// fi: Avaa lukitus
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get sdf1af3409c;

  /// fi: Valikko
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get s4629a1695c;

  /// fi: Muokkaa näkymää
  ///
  /// In en, this message translates to:
  /// **'Edit the view'**
  String get scd04aa5d9e;

  /// fi: Huoneen kuva
  ///
  /// In en, this message translates to:
  /// **'Room photo'**
  String get sf98121cd3d;

  /// fi: Lukitse näkymä
  ///
  /// In en, this message translates to:
  /// **'Lock the view'**
  String get s365492a7d0;

  /// fi: Laitteita voi edelleen ohjata, mutta muokkaus, asetukset ja laitteiden lisäys piilotetaan. Avaa lukitus rataskuvakkeesta
  ///
  /// In en, this message translates to:
  /// **'Devices can still be controlled, but editing, settings and adding devices are hidden. Unlock from the gear icon.'**
  String get sb2f38410ee;

  /// fi: PIN-koodi (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'PIN code (optional)'**
  String get se497d27174;

  /// fi: Ilman PIN-koodia lukitus avataan yhdellä napautuksella.
  ///
  /// In en, this message translates to:
  /// **'Without a PIN one tap unlocks.'**
  String get sd21180a166;

  /// fi: Lukitse
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get sd86ff8e28a;

  /// fi: Avaa lukitus?
  ///
  /// In en, this message translates to:
  /// **'Unlock?'**
  String get s872f93a062;

  /// fi: Muokkaus ja asetukset tulevat taas näkyviin.
  ///
  /// In en, this message translates to:
  /// **'Editing and settings become visible again.'**
  String get s0cd88e27f4;

  /// fi: Avaa
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get sa5283191be;

  /// fi: Väärä PIN-koodi
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN code'**
  String get sca710b76b5;

  /// fi: Valot
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get s72a2328ddd;

  /// fi: Kytkimet
  ///
  /// In en, this message translates to:
  /// **'Switches'**
  String get sca12be80ca;

  /// fi: Lämpöpumput ja ilmastointi
  ///
  /// In en, this message translates to:
  /// **'Heat pumps and AC'**
  String get sa4c0eeea02;

  /// fi: Anturit
  ///
  /// In en, this message translates to:
  /// **'Sensors'**
  String get s662fecdc8d;

  /// fi: Tila-anturit
  ///
  /// In en, this message translates to:
  /// **'Binary sensors'**
  String get sa8dbf04ad3;

  /// fi: Verhot ja ovet
  ///
  /// In en, this message translates to:
  /// **'Covers and doors'**
  String get sa7690acf57;

  /// fi: Lukot
  ///
  /// In en, this message translates to:
  /// **'Locks'**
  String get s487bf00fc7;

  /// fi: Kamerat
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get s88ac47e6d1;

  /// fi: Puhaltimet
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get sbe76826428;

  /// fi: Painikkeet
  ///
  /// In en, this message translates to:
  /// **'Buttons'**
  String get s4b53bcaaf0;

  /// fi: Säätimet
  ///
  /// In en, this message translates to:
  /// **'Number inputs'**
  String get s5c92d42edd;

  /// fi: Apukytkimet
  ///
  /// In en, this message translates to:
  /// **'Helper toggles'**
  String get s3c2ed0c522;

  /// fi: Mediasoittimet
  ///
  /// In en, this message translates to:
  /// **'Media players'**
  String get sea20d169a3;

  /// fi: Robotti-imurit
  ///
  /// In en, this message translates to:
  /// **'Robot vacuums'**
  String get s5bfb23a680;

  /// fi: Venttiilit
  ///
  /// In en, this message translates to:
  /// **'Valves'**
  String get sc9735275b2;

  /// fi: Ilmankostuttimet
  ///
  /// In en, this message translates to:
  /// **'Humidifiers'**
  String get s28cdff43bf;

  /// fi: Tunnus (token) ei kelpaa. Luo uusi Home Assistantissa.
  ///
  /// In en, this message translates to:
  /// **'The token is not accepted. Create a new one in Home Assistant.'**
  String get sbcb95e1e78;

  /// fi: Home Assistantiin ei saatu yhteyttä. Tarkista osoite.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Home Assistant. Check the address.'**
  String get s0b80dc2642;

  /// fi: kamerat
  ///
  /// In en, this message translates to:
  /// **'cameras'**
  String get sf32b7f15d8;

  /// fi: Valitse Home Assistantin laitteet
  ///
  /// In en, this message translates to:
  /// **'Pick Home Assistant devices'**
  String get sa7a829cefb;

  /// fi: Haetaan laitteita…
  ///
  /// In en, this message translates to:
  /// **'Loading devices…'**
  String get sefdf8e3316;

  /// fi: Huoneittain omiin näkymiin
  ///
  /// In en, this message translates to:
  /// **'One view per room'**
  String get s26583a1933;

  /// fi: Hae nimellä tai tunnuksella
  ///
  /// In en, this message translates to:
  /// **'Search by name or id'**
  String get sb3e6b54bce;

  /// fi: Kaikki huoneet
  ///
  /// In en, this message translates to:
  /// **'All rooms'**
  String get safedc10c48;

  /// fi: Ei huonetta
  ///
  /// In en, this message translates to:
  /// **'No room'**
  String get s407f3f7a0c;

  /// fi: {p0} valoa on Philips Hue -valoja
  ///
  /// In en, this message translates to:
  /// **'{p0} lights are Philips Hue lights'**
  String s140aba8cd7(String p0);

  /// fi: Suoraan Hue-sillan kautta ne toimivat nopeammin ja ilman Home Assistantia.
  ///
  /// In en, this message translates to:
  /// **'Directly through the Hue Bridge they respond faster and work without Home Assistant.'**
  String get s16aee2aa30;

  /// fi: Lisää Hue-silta
  ///
  /// In en, this message translates to:
  /// **'Add Hue Bridge'**
  String get s3816288db1;

  /// fi: Näytä kaikki
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get sa765c9294a;

  /// fi: {p0} teknistä kohdetta piilotettu (diagnostiikka, asetukset, päivitykset)
  ///
  /// In en, this message translates to:
  /// **'{p0} technical items hidden (diagnostics, configuration, updates)'**
  String sdb088f47a8(String p0);

  /// fi: Huoneita ei saatu luettua – näytetään laitteet ilman huoneita.
  ///
  /// In en, this message translates to:
  /// **'Rooms could not be read – showing devices without rooms.'**
  String get s3ee8d0a5e3;

  /// fi: Ei osumia
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get sf55fca7a32;

  /// fi: jo lisätty
  ///
  /// In en, this message translates to:
  /// **'already added'**
  String get s78cdce874e;

  /// fi: Näytä Molaplan
  ///
  /// In en, this message translates to:
  /// **'Show Molaplan'**
  String get sc80648d495;

  /// fi: Lopeta
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get sa4e9c86a86;

  /// fi: Valvonta päälle
  ///
  /// In en, this message translates to:
  /// **'Armed'**
  String get s9f02ad954d;

  /// fi: Valvonta päälle (kotona)
  ///
  /// In en, this message translates to:
  /// **'Armed (at home)'**
  String get s8352b34316;

  /// fi: Valvonta pois
  ///
  /// In en, this message translates to:
  /// **'Disarmed'**
  String get s49e6af4fbd;

  /// fi: HÄLYTYS
  ///
  /// In en, this message translates to:
  /// **'ALARM'**
  String get s3dfa789b85;

  /// fi: Lähtöviive
  ///
  /// In en, this message translates to:
  /// **'Exit delay'**
  String get s06273ba893;

  /// fi: Tuloviive
  ///
  /// In en, this message translates to:
  /// **'Entry delay'**
  String get sfcf7462d8b;

  /// fi: Hälytys / auki / liike
  ///
  /// In en, this message translates to:
  /// **'Alarm / open / motion'**
  String get s55142f0816;

  /// fi: Rauhallinen / kiinni
  ///
  /// In en, this message translates to:
  /// **'Calm / closed'**
  String get s6f0481deb7;

  /// fi: Tämä laite (Molaplan)
  ///
  /// In en, this message translates to:
  /// **'This device (Molaplan)'**
  String get s4b77da40d6;

  /// fi: Poistettu ruutu
  ///
  /// In en, this message translates to:
  /// **'Removed tile'**
  String get s1cbfbc5ff7;

  /// fi: 24 h
  ///
  /// In en, this message translates to:
  /// **'24 h'**
  String get s7843a19ea0;

  /// fi: 7 vrk
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get s4b87fa9575;

  /// fi: 30 vrk
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get s1e72f886c1;

  /// fi: Vain kun arvo muuttuu
  ///
  /// In en, this message translates to:
  /// **'Only when the value changes'**
  String get s78266c553c;

  /// fi: Muutokset ja vähintään minuutin välein
  ///
  /// In en, this message translates to:
  /// **'Changes and at least every minute'**
  String get sf224f07b80;

  /// fi: Muutokset ja vähintään 5 min välein
  ///
  /// In en, this message translates to:
  /// **'Changes and at least every 5 min'**
  String get s41ef71d809;

  /// fi: Muutokset ja vähintään 15 min välein
  ///
  /// In en, this message translates to:
  /// **'Changes and at least every 15 min'**
  String get s12e38f800c;

  /// fi: Muutokset ja vähintään kerran tunnissa
  ///
  /// In en, this message translates to:
  /// **'Changes and at least hourly'**
  String get sa7c19cc4e2;

  /// fi: Lokeja voi olla enintään 40.
  ///
  /// In en, this message translates to:
  /// **'You can have at most 40 logs.'**
  String get sc0d4464ce2;

  /// fi: Ei ruutuja, joista voisi kerätä lokia.
  ///
  /// In en, this message translates to:
  /// **'No tiles to log yet.'**
  String get s7001f80c75;

  /// fi: Mistä ruudusta?
  ///
  /// In en, this message translates to:
  /// **'Which tile?'**
  String get s25729ac0be;

  /// fi: Tapahtumaloki
  ///
  /// In en, this message translates to:
  /// **'Event log'**
  String get se93448dca9;

  /// fi: Onnistuneet haut ja hakuvirheet tällä laitteella
  ///
  /// In en, this message translates to:
  /// **'Successful fetches and fetch errors on this device'**
  String get sb7bd245cdc;

  /// fi: Rakenna loki tai trendi mistä tahansa ruudusta: lämpötila, teho, hinta, anturi, rele tai tila. Paina Lisää tai pidä ruut
  ///
  /// In en, this message translates to:
  /// **'Build a log or trend from any tile: temperature, power, price, sensor, relay or state. Tap Add, or long-press a tile and choose Add log / trend.'**
  String get s79a52f607c;

  /// fi: säilytys
  ///
  /// In en, this message translates to:
  /// **'kept'**
  String get s4ff01d5c5f;

  /// fi: vrk
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get s11c71ee131;

  /// fi: Tiedot tallennetaan tälle laitteelle. Keräys toimii aina, kun Molaplan on käynnissä (myös taustalla Windowsissa ja kotis
  ///
  /// In en, this message translates to:
  /// **'Data is stored on this device. Collection runs whenever Molaplan runs (also in the background on Windows and as a home bridge). On Android values are also read about every 15 minutes with the app closed. In the browser collection runs only while the page is open; prices and devices with their own history fill the gaps.'**
  String get sbbb938f28f;

  /// fi: Uusi loki / trendi
  ///
  /// In en, this message translates to:
  /// **'New log / trend'**
  String get s5e9f9fcae5;

  /// fi: Nimi (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get sb0ced9bdb6;

  /// fi: Kuvaaja
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get s237da9d739;

  /// fi: Viiva
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get s89fd2c0b0b;

  /// fi: Tallenna
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get se256c45d40;

  /// fi: Mitkä muutokset kirjataan
  ///
  /// In en, this message translates to:
  /// **'Which changes are logged'**
  String get sd185524df1;

  /// fi: Kaikki muutokset
  ///
  /// In en, this message translates to:
  /// **'Every change'**
  String get s0918947c1c;

  /// fi: Arvot tulevat näkyviin, kun ruutu on raportoinut niitä. Kirjaa siihen asti kaikki muutokset.
  ///
  /// In en, this message translates to:
  /// **'Values appear here once the tile has reported them. Until then log every change.'**
  String get sae3c62f7d0;

  /// fi: Kirjaa kuka / mikä muutti
  ///
  /// In en, this message translates to:
  /// **'Record who / what changed it'**
  String get s16b24be503;

  /// fi: Kun laite kertoo sen (esim. hälytyspaneelin käyttäjä) tai muutos tehtiin tästä sovelluksesta.
  ///
  /// In en, this message translates to:
  /// **'When the device tells (e.g. the alarm panel user) or the change was made from this app.'**
  String get se2badd71f2;

  /// fi: Näytä ruutuna etusivulla
  ///
  /// In en, this message translates to:
  /// **'Show as a tile on the dashboard'**
  String get s56acf29de0;

  /// fi: Lisäasetukset
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get s40e7046009;

  /// fi: Säilytä tiedot
  ///
  /// In en, this message translates to:
  /// **'Keep data for'**
  String get s3f5977d9b6;

  /// fi: Oletusaikaväli
  ///
  /// In en, this message translates to:
  /// **'Default range'**
  String get se668520c52;

  /// fi: Ohita pienemmät muutokset kuin
  ///
  /// In en, this message translates to:
  /// **'Ignore changes smaller than'**
  String get s92c8a02204;

  /// fi: Vanhat tiedot tiivistetään: minuutin tarkkuus 6 h, sitten 5 min, 15 min, tunti. Tieto pysyy tällä laitteella; vie CSV, j
  ///
  /// In en, this message translates to:
  /// **'Older data is condensed: 1-minute detail for 6 h, then 5 min, 15 min, 1 hour. Data stays on this device; export CSV to use it elsewhere.'**
  String get sf84e8b990b;

  /// fi: Enintään 2000 tapahtumaa. Tieto pysyy tällä laitteella; vie CSV, jos haluat sen muualle.
  ///
  /// In en, this message translates to:
  /// **'At most 2000 events. Data stays on this device; export CSV to use it elsewhere.'**
  String get s7036f1191e;

  /// fi: Vie CSV
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get s62cd475497;

  /// fi: CSV viety
  ///
  /// In en, this message translates to:
  /// **'CSV exported'**
  String get sd0271d93a1;

  /// fi: Ruutu lisätty etusivulle
  ///
  /// In en, this message translates to:
  /// **'Tile added to the dashboard'**
  String get sb130aae279;

  /// fi: Tyhjennetäänkö tiedot?
  ///
  /// In en, this message translates to:
  /// **'Clear the data?'**
  String get s950023174c;

  /// fi: Kerätyt tiedot poistetaan tältä laitteelta. Keräys jatkuu.
  ///
  /// In en, this message translates to:
  /// **'The collected data is removed from this device. Collection continues.'**
  String get s5c6181d628;

  /// fi: Poistetaanko loki?
  ///
  /// In en, this message translates to:
  /// **'Delete the log?'**
  String get s6d02a02a84;

  /// fi: Loki, sen tiedot ja sen ruutu poistetaan.
  ///
  /// In en, this message translates to:
  /// **'The log, its data and its tile are removed.'**
  String get s352ff3dfcd;

  /// fi: Loki on poistettu.
  ///
  /// In en, this message translates to:
  /// **'The log was removed.'**
  String get s4a997986a1;

  /// fi: Tyhjennä tiedot
  ///
  /// In en, this message translates to:
  /// **'Clear data'**
  String get s7a0680e628;

  /// fi: Poista loki
  ///
  /// In en, this message translates to:
  /// **'Delete log'**
  String get sdbf5997eb6;

  /// fi: Ei vielä tietoja tältä ajalta. Keräys on käynnissä.
  ///
  /// In en, this message translates to:
  /// **'No data for this range yet. Collecting.'**
  String get s861cfdceb8;

  /// fi: ≈ Arvio: laskettu laitteen nimellistehosta niinä aikoina, kun laite on päällä. Ei mittaus.
  ///
  /// In en, this message translates to:
  /// **'≈ Estimate: worked out from the device\'\'s nominal power while it is on. Not a measurement.'**
  String get sdf891d4e5b;

  /// fi: Min
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get saa1ac2854a;

  /// fi: Max
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get s3f80c515c3;

  /// fi: Viimeisin
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get s0995036cd3;

  /// fi: Ei tapahtumia vielä. Loki kirjaa valitut muutokset tästä eteenpäin.
  ///
  /// In en, this message translates to:
  /// **'No events yet. The log records the chosen changes from now on.'**
  String get safecdd6b93;

  /// fi: Kesti
  ///
  /// In en, this message translates to:
  /// **'Lasted'**
  String get s4ba3b23ae1;

  /// fi: Kuka
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get s5fb1d3d53a;

  /// fi: Kerätään…
  ///
  /// In en, this message translates to:
  /// **'Collecting…'**
  String get s23f691770e;

  /// fi: Ei tapahtumia vielä
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get s35be191f52;

  /// fi: Kaikki rauhallista.
  ///
  /// In en, this message translates to:
  /// **'All quiet.'**
  String get sfe55fd97fa;

  /// fi: {p0}: valmis
  ///
  /// In en, this message translates to:
  /// **'{p0}: done'**
  String s162c54ed4c(String p0);

  /// fi: maanantai
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get se26e839c2f;

  /// fi: tiistai
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get s763254941f;

  /// fi: keskiviikko
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get sf3448cdd52;

  /// fi: torstai
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get sc34ca7eddb;

  /// fi: perjantai
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get sfa82438bec;

  /// fi: lauantai
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get s517c348371;

  /// fi: sunnuntai
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sb1f0e72163;

  /// fi: Selain ei pääse kotiverkon laitteisiin
  ///
  /// In en, this message translates to:
  /// **'The browser cannot reach devices on your home network'**
  String get sd24649df81;

  /// fi: Verkkosivu ei voi etsiä eikä avata yhteyttä kotiverkon laitteisiin (esim. {p0}). Käytä Molaplan Windows- tai Android-sov
  ///
  /// In en, this message translates to:
  /// **'A web page cannot search for or open connections to devices on your home network (e.g. {p0}). Use the Molaplan Windows or Android app on the home network, or set up the home bridge – then search and control go through a device at home.'**
  String s634ae3a263(String p0);

  /// fi: Tämä laite ei ole yhteydessä wifiin
  ///
  /// In en, this message translates to:
  /// **'This device is not on Wi-Fi'**
  String get s55d52c5ae1;

  /// fi: Yhdistä tämä laite kodin wifiin (samaan, jossa {p0} on). Tai jos olet kodin ulkopuolella, ota käyttöön kotisilta – sillo
  ///
  /// In en, this message translates to:
  /// **'Connect this device to your home Wi-Fi (the one {p0} uses). Or, if you are away, set up the home bridge so the search runs on a device at home.'**
  String s9a4dece965(String p0);

  /// fi: Laitetta ei tavoitettu
  ///
  /// In en, this message translates to:
  /// **'Could not reach the device'**
  String get s3972820cd6;

  /// fi: Laitetta ei tavoitettu osoitteesta {p0}
  ///
  /// In en, this message translates to:
  /// **'Could not reach the device at {p0}'**
  String s0f480abb4a(String p0);

  /// fi: 1. Tarkista että {p0} on päällä (valo palaa).
  /// 2. Tämän laitteen (tai kotisillan) pitää olla samassa wifissä kuin {p1}.
  /// 3
  ///
  /// In en, this message translates to:
  /// **'1. Check that {p0} is powered.\n2. This device (or the home bridge) must be on the same Wi-Fi.\n3. Check the address – it can change. Tap \"Back\" and search again.'**
  String sa82143ee02(String p0, String p1);

  /// fi: Osoitteessa on jokin muu laite
  ///
  /// In en, this message translates to:
  /// **'A different device answered'**
  String get sd4d7ad1bab;

  /// fi: Osoitteesta vastasi laite, joka ei ole {p0}. Tarkista osoite ja kokeile uudelleen. Tarkempi syy näkyy teknisissä tiedois
  ///
  /// In en, this message translates to:
  /// **'The device at that address is not {p0}. Check the address. The technical details show what answered.'**
  String s49a0fab5c2(String p0);

  /// fi: Laite pyytää salasanaa
  ///
  /// In en, this message translates to:
  /// **'The device asks for a password'**
  String get sdac5622fa8;

  /// fi: Olet asettanut laitteeseen salasanan. Kirjoita se alle ja paina "Yhdistä".
  ///
  /// In en, this message translates to:
  /// **'A password is set on the device. Type it below and tap \"Connect\".'**
  String get sbf9ee8aaec;

  /// fi: Tarvitaan vielä yksi tieto
  ///
  /// In en, this message translates to:
  /// **'One more detail is needed'**
  String get s9e22388413;

  /// fi: {p0} ei kerro tätä itse. Kirjoita se alle ja paina "Yhdistä".
  ///
  /// In en, this message translates to:
  /// **'{p0} does not tell this by itself. Type it below and tap \"Connect\".'**
  String sc8702d4da2(String p0);

  /// fi: Salasana ei kelpaa
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get s83f57c7c24;

  /// fi: Tarkista salasana (isot ja pienet kirjaimet). Sen voi vaihtaa laitteen omasta sovelluksesta.
  ///
  /// In en, this message translates to:
  /// **'Check the password (case matters). You can change it in the device app.'**
  String get s32e85a0ba2;

  /// fi: Painiketta ei painettu ajoissa
  ///
  /// In en, this message translates to:
  /// **'The button was not pressed in time'**
  String get sb1d36bfdd3;

  /// fi: Paina "Yritä uudelleen" ja paina sitten painiketta heti.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Try again\" and then press the button right away.'**
  String get sc994f6ec6e;

  /// fi: Laitteelta ei löytynyt ohjattavaa
  ///
  /// In en, this message translates to:
  /// **'Nothing to control was found'**
  String get s663202243e;

  /// fi: Laite vastasi, mutta siinä ei ollut kytkimiä tai valoja. Jos käytät pilveä, kirjoita laitteen tunnus (Device ID) käsin.
  ///
  /// In en, this message translates to:
  /// **'The device answered but has no switches or lights. For the cloud, type the Device ID.'**
  String get sb03997d94b;

  /// fi: Kamera löytyi, mutta videon osoitetta ei löytynyt
  ///
  /// In en, this message translates to:
  /// **'Camera found, but not its video address'**
  String get se6e01118ac;

  /// fi: Kamera vastasi, mutta ei kertonut videokuvan osoitetta, eikä yksikään yleisistä RTSP-osoitteista toiminut tällä tunnukse
  ///
  /// In en, this message translates to:
  /// **'The camera answered but did not tell its video address, and none of the usual RTSP addresses worked with this login. Check that RTSP/ONVIF is on in the camera app, or pick the brand below and tap \"Connect\".'**
  String get sca994210fb;

  /// fi: Pilviavain tai palvelin ei kelpaa
  ///
  /// In en, this message translates to:
  /// **'Cloud key or server not accepted'**
  String get s869571042f;

  /// fi: Kopioi avain ja palvelimen osoite uudelleen Shelly-sovelluksesta (Käyttäjäasetukset → Authorization cloud key).
  ///
  /// In en, this message translates to:
  /// **'Copy the key and server again from the Shelly app (User settings → Authorization cloud key).'**
  String get sab1763c592;

  /// fi: Pilveen ei saatu yhteyttä
  ///
  /// In en, this message translates to:
  /// **'Could not reach the cloud'**
  String get s855ffbfd24;

  /// fi: Tarkista nettiyhteys ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Check the internet connection.'**
  String get s739d569a9c;

  /// fi: Liian monta pyyntöä
  ///
  /// In en, this message translates to:
  /// **'Too many requests'**
  String get sc96a3502b5;

  /// fi: Pilvi rajoittaa pyyntöjä. Odota hetki ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The cloud limits requests. Wait a moment.'**
  String get sed917dc2a2;

  /// fi: Kotisilta on vanha versio
  ///
  /// In en, this message translates to:
  /// **'The home bridge is out of date'**
  String get s516dbdd784;

  /// fi: Päivitä kotisillan Molaplan (Asetukset → Tarkista päivitykset) ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Update Molaplan on the bridge (Settings → Check for updates).'**
  String get s70089507bf;

  /// fi: Laite vastaa, mutta ONVIF-portti on kiinni
  ///
  /// In en, this message translates to:
  /// **'The device answers, but the ONVIF port is closed'**
  String get s496aaf125a;

  /// fi: Laite vastaa, mutta ONVIF-portti on kiinni (yritettiin portteja {p0})
  ///
  /// In en, this message translates to:
  /// **'The device answers, but the ONVIF port is closed (tried ports {p0})'**
  String scfbd591df7(String p0);

  /// fi: Tarkista kameran ONVIF-portti ja kirjoita se tarvittaessa (Tapo: 2020). Tapo-sovellus → kamera → Lisäasetukset → Kameran
  ///
  /// In en, this message translates to:
  /// **'Check the camera\'\'s ONVIF port and type it if needed (Tapo: 2020). Tapo app → camera → Advanced settings → Camera account: create a user and password there (not your Tapo cloud login).'**
  String get s8be90444f0;

  /// fi: Kotisilta ei ole päällä
  ///
  /// In en, this message translates to:
  /// **'The home bridge is off'**
  String get s7e11595f9e;

  /// fi: Tarkista että kotona oleva kotisilta (tabletti tai PC) on päällä, Molaplan on auki ja sillä on netti.
  ///
  /// In en, this message translates to:
  /// **'Check that the bridge at home is on, Molaplan is open and it has internet.'**
  String get scc1918f2dc;

  /// fi: Laitteeseen ei saatu yhteyttä
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the device'**
  String get se11f9b5084;

  /// fi: Tarkista osoite ja että laite on päällä, ja yritä uudelleen. Tarkempi syy näkyy teknisissä tiedoissa.
  ///
  /// In en, this message translates to:
  /// **'Check the address and that the device is on, then try again. The technical details show the exact reason.'**
  String get s979376dca6;

  /// fi: Kirjoita ensin osoite
  ///
  /// In en, this message translates to:
  /// **'Type the address first'**
  String get sce6d01c270;

  /// fi: Tarkista osoite
  ///
  /// In en, this message translates to:
  /// **'Check the address'**
  String get s65bbf3cab4;

  /// fi: {p0} ei ole kotiverkon osoite. Kotiverkon osoitteet alkavat yleensä 192.168. – katso osoite uudelleen {p1}-sovelluksesta
  ///
  /// In en, this message translates to:
  /// **'{p0} is not a home network address. They usually start with 192.168. – check it again in the {p1} app.'**
  String sb711cc1ce2(String p0, String p1);

  /// fi: Tarkoititko {p0}?
  ///
  /// In en, this message translates to:
  /// **'Did you mean {p0}?'**
  String se60794c266(String p0);

  /// fi: Korjaan itse
  ///
  /// In en, this message translates to:
  /// **'I\'\'ll fix it'**
  String get s264fda2dee;

  /// fi: Kokeile silti
  ///
  /// In en, this message translates to:
  /// **'Try anyway'**
  String get s0a6098ac78;

  /// fi: Käytä {p0}
  ///
  /// In en, this message translates to:
  /// **'Use {p0}'**
  String sc1039f5cf6(String p0);

  /// fi: Osoite on eri verkossa
  ///
  /// In en, this message translates to:
  /// **'The address is on another network'**
  String get s20f777bfef;

  /// fi: Osoite {p0} ei ole samassa verkossa kuin tämä laite ({p1}.x). Yleensä se tarkoittaa, että tämä laite on eri wifissä kuin
  ///
  /// In en, this message translates to:
  /// **'Address {p0} is not on the same network as this device ({p1}.x). Usually this device is on a different Wi-Fi than {p2}.\n\nJoin the same Wi-Fi, or set up the home bridge.'**
  String sbb1730fa00(String p0, String p1, String p2, String p3);

  /// fi: Osoite on eri verkossa kuin tämä laite – yhteys kameran kanssa tehdään kotisillan kautta.
  ///
  /// In en, this message translates to:
  /// **'The address is on a different network than this device – the camera is reached through the home bridge.'**
  String get s8947447763;

  /// fi: Valitse vähintään yksi
  ///
  /// In en, this message translates to:
  /// **'Pick at least one'**
  String get s915c9a0db3;

  /// fi: Lisää: {p0}
  ///
  /// In en, this message translates to:
  /// **'Add: {p0}'**
  String sb160156a36(String p0);

  /// fi: Lisää kotinäkymään
  ///
  /// In en, this message translates to:
  /// **'Add to home view'**
  String get s43d448a950;

  /// fi: Näytä kotinäkymä
  ///
  /// In en, this message translates to:
  /// **'Show home view'**
  String get sd890121a57;

  /// fi: A) Ilman kotisiltaa
  ///
  /// In en, this message translates to:
  /// **'A) Without a home bridge'**
  String get sb1717cc67c;

  /// fi: Käytä Shelly Cloudia (ei kotisiltaa)
  ///
  /// In en, this message translates to:
  /// **'Use Shelly Cloud (no bridge)'**
  String get s2082568a23;

  /// fi: Paras, jos mikään laite ei ole aina kotona – esim. kun tabletti kulkee mukanasi. Ohjaus kulkee Shellyn oman pilven kautt
  ///
  /// In en, this message translates to:
  /// **'Best if no device always stays at home – e.g. your tablet travels with you. Control goes via Shelly\'\'s own cloud. You need a key from the Shelly app (we show where).'**
  String get s5080d486b8;

  /// fi: B) Kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'B) Through a home bridge'**
  String get s82985d5078;

  /// fi: Miten ohjaat kotia muualta?
  ///
  /// In en, this message translates to:
  /// **'How will you control your home when away?'**
  String get s78aec2034d;

  /// fi: Kotisilta on laite, joka on AINA kotona, päällä ja samassa wifissä kuin {p0} – esim. vanha puhelin, tabletti tai PC. Muu
  ///
  /// In en, this message translates to:
  /// **'A home bridge is a device that ALWAYS stays at home, switched on and on the same Wi-Fi as {p0} – e.g. an old phone, tablet or PC. Your other devices reach it over the internet (encrypted, no port forwarding). A device you carry around is not a good bridge.'**
  String s03b3c3b3c8(String p0);

  /// fi: Koska olet kirjautunut, kotiyhteys siirtyy kaikille laitteillesi automaattisesti.
  ///
  /// In en, this message translates to:
  /// **'As you are signed in, the home connection reaches all your devices automatically.'**
  String get s688d1308d7;

  /// fi: Tämä laite jää aina kotiin – tee siitä kotisilta
  ///
  /// In en, this message translates to:
  /// **'This device always stays home – make it the bridge'**
  String get s96feb2f60a;

  /// fi: Pidä laite laturissa ja Molaplan auki. Muut laitteet yhdistetään siihen QR-koodilla tai kirjautumalla samalle tilille.
  ///
  /// In en, this message translates to:
  /// **'Keep it charging with Molaplan open. Other devices connect with a QR code or by signing in to the same account.'**
  String get sb2a33a1ec4;

  /// fi: Kotisilta on jo toisella laitteella – yhdistä siihen
  ///
  /// In en, this message translates to:
  /// **'The bridge is on another device – connect to it'**
  String get s1b9f4ae6d5;

  /// fi: Skannaa kotisillan QR-koodi. Sen jälkeen laitteet haetaan kotisillan kautta, vaikka olisit muualla.
  ///
  /// In en, this message translates to:
  /// **'Scan the bridge QR code. Devices are then found through the bridge, even when you are away.'**
  String get s13d739b710;

  /// fi: Ohita nyt – lisään laitteen kotiverkossa (etäyhteyden voi ottaa käyttöön myöhemmin)
  ///
  /// In en, this message translates to:
  /// **'Skip for now – add on the home network (remote access can be set up later)'**
  String get sda6a1e50e9;

  /// fi: Etsitään: {p0}
  ///
  /// In en, this message translates to:
  /// **'Finding: {p0}'**
  String s6f326a48f9(String p0);

  /// fi: Selain ei voi etsiä laitteita omasta verkostaan, joten haku tehdään kotisillan kautta (toimii myös kodin ulkopuolella).
  ///
  /// In en, this message translates to:
  /// **'A browser cannot search its own network, so the search goes through the home bridge (works away from home too).'**
  String get sd621d69823;

  /// fi: Selain ei voi etsiä laitteita kotiverkosta. Käytä Windows- tai Android-sovellusta, ota kotisilta käyttöön tai kirjoita l
  ///
  /// In en, this message translates to:
  /// **'A browser cannot search the home network. Use the Windows or Android app, set up the home bridge, or type the device address.'**
  String get s6989f8d0c7;

  /// fi: Etsin sekä tämän laitteen wifistä että kotisillan kautta (toimii myös kodin ulkopuolella). Napauta omaasi.
  ///
  /// In en, this message translates to:
  /// **'Searching both on this device\'\'s Wi-Fi and through the home bridge (works away from home too). Tap yours.'**
  String get s0ae25246a7;

  /// fi: Etsin laitteita tämän laitteen wifistä. Napauta omaasi.
  ///
  /// In en, this message translates to:
  /// **'Looking on this device\'\'s Wi-Fi. Tap yours.'**
  String get saa8c9298e3;

  /// fi: Tässä verkossa
  ///
  /// In en, this message translates to:
  /// **'On this network'**
  String get sf7eb5738cc;

  /// fi: Kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'Through the home bridge'**
  String get sf35976eff1;

  /// fi: Avaa wifi-asetukset
  ///
  /// In en, this message translates to:
  /// **'Open Wi-Fi settings'**
  String get sda2b4c9721;

  /// fi: Yhdistin – etsi uudelleen
  ///
  /// In en, this message translates to:
  /// **'Connected – search again'**
  String get sc93d9cc14b;

  /// fi: Etsitään… (noin 5 sekuntia)
  ///
  /// In en, this message translates to:
  /// **'Searching… (about 5 seconds)'**
  String get s13f0596b74;

  /// fi: tässä verkossa ja kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'on this network and via the home bridge'**
  String get sa8cf19feed;

  /// fi: tässä verkossa
  ///
  /// In en, this message translates to:
  /// **'on this network'**
  String get s4019a442d9;

  /// fi: Kirjoita osoite itse
  ///
  /// In en, this message translates to:
  /// **'Type the address'**
  String get sa616ab181e;

  /// fi: Tai kirjoita osoite itse
  ///
  /// In en, this message translates to:
  /// **'Or type the address'**
  String get sb439b8abc3;

  /// fi: Mistä löydän sen?
  ///
  /// In en, this message translates to:
  /// **'Where do I find it?'**
  String get scf487a3699;

  /// fi:  (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **' (optional)'**
  String get s9b9b0d01a2;

  /// fi: Kirjaudu ja hyväksy
  ///
  /// In en, this message translates to:
  /// **'Sign in and approve'**
  String get s7acc8096d2;

  /// fi: Avaa kirjautumissivu
  ///
  /// In en, this message translates to:
  /// **'Open the sign-in page'**
  String get sa2ffc9d3a6;

  /// fi: Aikaa jäljellä {p0} s
  ///
  /// In en, this message translates to:
  /// **'{p0} s left'**
  String s43118959d5(String p0);

  /// fi: Paina painiketta nyt
  ///
  /// In en, this message translates to:
  /// **'Press the button now'**
  String get s0a7134d0e3;

  /// fi: Kirjaudu kameraan
  ///
  /// In en, this message translates to:
  /// **'Sign in to the camera'**
  String get s46c87a553f;

  /// fi: Järjestelmän salasana
  ///
  /// In en, this message translates to:
  /// **'System password'**
  String get sf11edd7621;

  /// fi: Laitteen salasana
  ///
  /// In en, this message translates to:
  /// **'Device password'**
  String get se4095d7d95;

  /// fi: Lisää silti ONVIF/RTSP-kamerana
  ///
  /// In en, this message translates to:
  /// **'Add anyway as an ONVIF/RTSP camera'**
  String get s117fa4a840;

  /// fi: Olen kodin ulkopuolella
  ///
  /// In en, this message translates to:
  /// **'I am away from home'**
  String get s8f610a3bb2;

  /// fi: Kameran merkki
  ///
  /// In en, this message translates to:
  /// **'Camera brand'**
  String get sb629592b4b;

  /// fi: RTSP-osoite
  ///
  /// In en, this message translates to:
  /// **'RTSP address'**
  String get se3aa0f7164;

  /// fi: Ilman tunnusta – käyttäjä ja salasana lisätään itse.
  ///
  /// In en, this message translates to:
  /// **'Without the login – the user and password are added automatically.'**
  String get s722ac06c6d;

  /// fi: Löytyi: {p0}
  ///
  /// In en, this message translates to:
  /// **'Found: {p0}'**
  String s77ec7b376b(String p0);

  /// fi: Valitse mitkä tulevat kotinäkymään ja anna niille nimet (esim. Lämmitys, Ulkovalot).
  ///
  /// In en, this message translates to:
  /// **'Pick what goes on the home view and name them.'**
  String get sac4debdb9c;

  /// fi: Poista valinnat
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get sfe5661e401;

  /// fi: Valitse kaikki ({p0})
  ///
  /// In en, this message translates to:
  /// **'Select all ({p0})'**
  String s2618555da0(String p0);

  /// fi: Lisää myös kirkkaus / teho
  ///
  /// In en, this message translates to:
  /// **'Also add brightness / power'**
  String get s86c3f92546;

  /// fi: Näytä myös teho (W)
  ///
  /// In en, this message translates to:
  /// **'Also show power (W)'**
  String get s91571486e4;

  /// fi: Valmis! {p0} ruutua lisätty
  ///
  /// In en, this message translates to:
  /// **'Done! {p0} tiles added'**
  String sf86536db42(String p0);

  /// fi: Ruudut toimivat kotona ja kodin ulkopuolella pilven kautta – mitään muuta ei tarvitse tehdä.
  ///
  /// In en, this message translates to:
  /// **'The tiles work at home and away through the cloud – nothing else to do.'**
  String get sbfaea66122;

  /// fi: Ruudut toimivat kotona ja kodin ulkopuolella kotisillan kautta – mitään muuta ei tarvitse tehdä.
  ///
  /// In en, this message translates to:
  /// **'The tiles work at home and away through the home bridge – nothing else to do.'**
  String get se7c68b3bed;

  /// fi: Ruudut toimivat nyt kotiverkossa. Jotta voit ohjata kotia mistä tahansa, ota kotisilta käyttöön.
  ///
  /// In en, this message translates to:
  /// **'The tiles work on your home network. To control from anywhere, set up the home bridge.'**
  String get sbc8469cce1;

  /// fi: osto
  ///
  /// In en, this message translates to:
  /// **'import'**
  String get s4de5ee4441;

  /// fi: myynti
  ///
  /// In en, this message translates to:
  /// **'export'**
  String get s3cf7906f3c;

  /// fi: Verkko
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get s5ae6b0f79a;

  /// fi: Aurinko
  ///
  /// In en, this message translates to:
  /// **'Solar'**
  String get sdfa9343ba4;

  /// fi: lataa
  ///
  /// In en, this message translates to:
  /// **'charging'**
  String get sacee730b62;

  /// fi: purkaa
  ///
  /// In en, this message translates to:
  /// **'discharging'**
  String get s1b19569f79;

  /// fi: arvio
  ///
  /// In en, this message translates to:
  /// **'estimate'**
  String get s4010949312;

  /// fi: syöttää
  ///
  /// In en, this message translates to:
  /// **'feeding'**
  String get s0f696df379;

  /// fi: +{p0} muuta
  ///
  /// In en, this message translates to:
  /// **'+{p0} more'**
  String sd8070dcde7(String p0);

  /// fi: Valitse näytettävät mittaukset ruudun asetuksista.
  ///
  /// In en, this message translates to:
  /// **'Pick the readings to show in the tile settings.'**
  String get s2aaf585b6f;

  /// fi: Ostettu verkosta
  ///
  /// In en, this message translates to:
  /// **'Imported from the grid'**
  String get s49ee71cd97;

  /// fi: Myyty verkkoon
  ///
  /// In en, this message translates to:
  /// **'Exported to the grid'**
  String get s5d21321a6f;

  /// fi: Aurinkosähkö
  ///
  /// In en, this message translates to:
  /// **'Solar'**
  String get s7f605ef5bc;

  /// fi: Ladattu akkuun
  ///
  /// In en, this message translates to:
  /// **'Charged into the battery'**
  String get sd07fb61b79;

  /// fi: Purettu akusta
  ///
  /// In en, this message translates to:
  /// **'Discharged from the battery'**
  String get s0c7fceb3ee;

  /// fi: Kodin kulutus
  ///
  /// In en, this message translates to:
  /// **'Home consumption'**
  String get sfee551e69b;

  /// fi: mitattu
  ///
  /// In en, this message translates to:
  /// **'measured'**
  String get sdfe10bf834;

  /// fi: laskettu verkosta, aurinkosähköstä ja akusta
  ///
  /// In en, this message translates to:
  /// **'worked out from grid, solar and battery'**
  String get sae6d1ca515;

  /// fi: valittujen laitteiden summa
  ///
  /// In en, this message translates to:
  /// **'sum of the chosen devices'**
  String get s87cfa01b07;

  /// fi: ei tietoa
  ///
  /// In en, this message translates to:
  /// **'no data'**
  String get sbd8dc92226;

  /// fi: Nyt / tänään
  ///
  /// In en, this message translates to:
  /// **'Now / today'**
  String get sa0a5f02f3c;

  /// fi: Päivän kWh kertyy, kun Molaplan on käynnissä ja ruutu näkyy. ≈ = arvio laitteen nimellistehosta, ei mittaus.
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s kWh adds up while Molaplan runs and the tile is shown. ≈ = estimate from a device\'\'s nominal power, not a measurement.'**
  String get s21e98de336;

  /// fi: Energiavirta
  ///
  /// In en, this message translates to:
  /// **'Energy flow'**
  String get sac7ed506f3;

  /// fi: Ei käytössä
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get s510927a4e5;

  /// fi: Valitse jokaiselle osalle ruutu, joka mittaa tehoa (W tai kW). Osa, jolle ei ole mittausta, jätetään kuvasta pois.
  ///
  /// In en, this message translates to:
  /// **'Pick a tile that measures power (W or kW) for each part. Parts without a reading are left out of the picture.'**
  String get s5369fe2e34;

  /// fi: Sähköverkko
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get s915d1474dc;

  /// fi: Pääsähkömittari tai invertterin verkkolukema: + = osto, − = myynti.
  ///
  /// In en, this message translates to:
  /// **'Main meter or the inverter\'\'s grid reading: + = import, − = export.'**
  String get sd03d6b17cd;

  /// fi: Verkon teho
  ///
  /// In en, this message translates to:
  /// **'Grid power'**
  String get sef19b9c914;

  /// fi: Käännä etumerkki
  ///
  /// In en, this message translates to:
  /// **'Invert the sign'**
  String get s3e06947388;

  /// fi: Jos mittari näyttää myynnin positiivisena.
  ///
  /// In en, this message translates to:
  /// **'If the meter shows export as positive.'**
  String get s3e2c1fac2f;

  /// fi: Näytä sähkön hinta nyt
  ///
  /// In en, this message translates to:
  /// **'Show the current electricity price'**
  String get s96b28d777e;

  /// fi: Sama hinta kuin sähkön hinta -ruudussa tai sopimuksessasi.
  ///
  /// In en, this message translates to:
  /// **'The same price as the electricity price tile or your contract.'**
  String get se587115beb;

  /// fi: Tuotto nyt
  ///
  /// In en, this message translates to:
  /// **'Production now'**
  String get sabe392a0ed;

  /// fi: + = lataus, − = purku.
  ///
  /// In en, this message translates to:
  /// **'+ = charging, − = discharging.'**
  String get s25c37e112b;

  /// fi: Akun teho
  ///
  /// In en, this message translates to:
  /// **'Battery power'**
  String get s9192f64397;

  /// fi: Akun varaus (%)
  ///
  /// In en, this message translates to:
  /// **'Battery charge (%)'**
  String get s275ffaa691;

  /// fi: Jos laite näyttää purun positiivisena.
  ///
  /// In en, this message translates to:
  /// **'If the device shows discharging as positive.'**
  String get sf5e16169f6;

  /// fi: Lasketaan automaattisesti: osto + aurinko + akun purku − myynti − akun lataus. Valitse mittaus vain, jos kulutus mitataa
  ///
  /// In en, this message translates to:
  /// **'Worked out automatically: import + solar + battery discharge − export − battery charge. Pick a reading only if the use is measured separately.'**
  String get sa11ddb5c95;

  /// fi: Mitattu kulutus
  ///
  /// In en, this message translates to:
  /// **'Measured use'**
  String get sfb9788b87b;

  /// fi: Laske automaattisesti
  ///
  /// In en, this message translates to:
  /// **'Work out automatically'**
  String get s9af24b04b0;

  /// fi: Auton lataus
  ///
  /// In en, this message translates to:
  /// **'EV charging'**
  String get sfa9be496e3;

  /// fi: + = auto latautuu, − = auto syöttää kotiin.
  ///
  /// In en, this message translates to:
  /// **'+ = charging the car, − = the car feeds the home.'**
  String get sc8fa6ad802;

  /// fi: Laturin teho
  ///
  /// In en, this message translates to:
  /// **'Charger power'**
  String get s522196a074;

  /// fi: Auton akun varaus (%), jos saatavilla
  ///
  /// In en, this message translates to:
  /// **'Car battery charge (%), if available'**
  String get s14584ca6fc;

  /// fi: Jos laturi näyttää latauksen negatiivisena.
  ///
  /// In en, this message translates to:
  /// **'If the charger shows charging as negative.'**
  String get s337d44cf0e;

  /// fi: Lisää laturi
  ///
  /// In en, this message translates to:
  /// **'Add a charger'**
  String get scb742074fc;

  /// fi: Näytä yksittäisiä laitteita kodin vieressä. Vakiotehoiselle laitteelle (esim. lämmitin, sauna, pumppu) voit asettaa nime
  ///
  /// In en, this message translates to:
  /// **'Show single devices next to the home. For a constant-power device (e.g. a heater, sauna or pump) you can set a nominal power in its switch tile settings (Advanced); its use then shows as an estimate (≈).'**
  String get sa5564fdf2d;

  /// fi: Ei vielä laitteita, jotka kertovat tehon.
  ///
  /// In en, this message translates to:
  /// **'No devices that report power yet.'**
  String get s16e6172f72;

  /// fi: päällä ollessa (arvio)
  ///
  /// In en, this message translates to:
  /// **'while on (estimate)'**
  String get sf43fda9dad;

  /// fi: Mitattu teho
  ///
  /// In en, this message translates to:
  /// **'Measured power'**
  String get s036ab2e742;

  /// fi: Liikkuvat virtapisteet
  ///
  /// In en, this message translates to:
  /// **'Moving flow dots'**
  String get s5b72e0dd48;

  /// fi: Pysähtyy itsestään, kun laite pyytää vähemmän liikettä, animaatiot on poistettu asetuksista tai virransäästö on päällä.
  ///
  /// In en, this message translates to:
  /// **'Stops by itself when the device asks for less motion, animations are off in the settings or battery saver is on.'**
  String get sfa60643b58;

  /// fi: Loki
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get sf3b3b45b00;

  /// fi: Ei tapahtumia vielä. Loki kerää valvonnan kytkennät ja hälytykset.
  ///
  /// In en, this message translates to:
  /// **'No events yet. The log collects arming, disarming and alarms.'**
  String get s87c07d09ce;

  /// fi: Valvonta päälle
  ///
  /// In en, this message translates to:
  /// **'Monitoring on'**
  String get s6a2900d1fc;

  /// fi: Valvonta pois
  ///
  /// In en, this message translates to:
  /// **'Monitoring off'**
  String get sdfb732c84f;

  /// fi: Päättyi
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get s6b2ed1dd31;

  /// fi: Käynnissä tai päättymisaika ei tiedossa
  ///
  /// In en, this message translates to:
  /// **'Ongoing or end time unknown'**
  String get sa7e8a5c23b;

  /// fi: Syy
  ///
  /// In en, this message translates to:
  /// **'Cause'**
  String get s9909138be0;

  /// fi: Valvonta päällä
  ///
  /// In en, this message translates to:
  /// **'Armed'**
  String get s93b4695981;

  /// fi: Valvonta päällä (kotona)
  ///
  /// In en, this message translates to:
  /// **'Armed (at home)'**
  String get s489ed73bfa;

  /// fi: Lähtöviive – valvonta kytkeytyy
  ///
  /// In en, this message translates to:
  /// **'Exit delay – arming'**
  String get s1ba2cffb00;

  /// fi: Tuloviive – anna PIN
  ///
  /// In en, this message translates to:
  /// **'Entry delay – enter PIN'**
  String get s2b765e2c1f;

  /// fi: HÄLYTYS!
  ///
  /// In en, this message translates to:
  /// **'ALARM!'**
  String get s34de2943cc;

  /// fi: Mittaukset
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get s02480e4c13;

  /// fi: Ohjaukset
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get sd1c778324e;

  /// fi: Hintapalvelu
  ///
  /// In en, this message translates to:
  /// **'The price service'**
  String get sc1e35d5171;

  /// fi: Sääpalvelu
  ///
  /// In en, this message translates to:
  /// **'The weather service'**
  String get s8b22e8d330;

  /// fi: Shelly Cloud
  ///
  /// In en, this message translates to:
  /// **'Shelly Cloud'**
  String get s252ebed5af;

  /// fi: Tuya
  ///
  /// In en, this message translates to:
  /// **'Tuya'**
  String get s07d3467ef6;

  /// fi: ntfy-palvelin
  ///
  /// In en, this message translates to:
  /// **'The ntfy server'**
  String get s10edebf3fa;

  /// fi: Airthings-pilvi
  ///
  /// In en, this message translates to:
  /// **'The Airthings cloud'**
  String get sc08176420f;

  /// fi: Palvelu
  ///
  /// In en, this message translates to:
  /// **'The service'**
  String get sd3d9c263ed;

  /// fi: ntfy.sh sallii 250 viestiä 12 tunnissa kotisi julkisesta IP-osoitteesta (kaikki puhelimet, tabletit, PC ja laitteen omat
  ///
  /// In en, this message translates to:
  /// **'ntfy.sh allows 250 messages per 12 hours from your home\'\'s public IP (all phones, tablets, PCs and the device\'\'s own replies together). Messages free up every few minutes – the app now asks for the state less often. A lasting fix: your own ntfy server or an ntfy account with a higher limit.'**
  String get s5d151d0815;

  /// fi: Komento lähti ntfy-palvelimelle, mutta laitteen vastausta ei tullut. Tarkista yhteyden "Vastauskanava" – laite voi vasta
  ///
  /// In en, this message translates to:
  /// **'The command reached the ntfy server, but no reply came from the device. Check the connection\'\'s \"Reply topic\" – the device may answer on your own notification topic – and that the device is online.'**
  String get s7aa9e16c41;

  /// fi: Hälytys on päällä – kuittaa hälytys ensin
  ///
  /// In en, this message translates to:
  /// **'The alarm is on – acknowledge the alarm first'**
  String get sa6d9ad626d;

  /// fi: Laite ei salli tätä komentoa hälytyksen aikana. Kuittaa hälytys ensin – kuittaus sammuttaa myös sireenin.
  ///
  /// In en, this message translates to:
  /// **'The device does not allow this command during an alarm. Acknowledge the alarm first – that also turns the siren off.'**
  String get s40ddc7d4c4;

  /// fi: Sisävaloa ei seurata eikä ohjata päivällä. Valo ei ole pois – se ei ole seurannassa.
  ///
  /// In en, this message translates to:
  /// **'The indoor light is not tracked or controlled during the day. It is not off – it is not being followed.'**
  String get sb7b4d4f624;

  /// fi: Ei nettiyhteyttä
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get sdfb639365a;

  /// fi: {p0} on internetissä, eikä siihen saatu yhteyttä. Tarkista tämän laitteen nettiyhteys. Viimeisimmät tiedot näytetään, ku
  ///
  /// In en, this message translates to:
  /// **'{p0} is on the internet and could not be reached. Check this device\'\'s internet connection. The latest data is shown when available.'**
  String s390dd51af3(String p0);

  /// fi: {p0} ei vastaa, yritetään varalähdettä
  ///
  /// In en, this message translates to:
  /// **'{p0} is not answering, trying a backup source'**
  String sbb750bf9d6(String p0);

  /// fi: {p0} ei vastaa
  ///
  /// In en, this message translates to:
  /// **'{p0} is not answering'**
  String s4284ebac1e(String p0);

  /// fi: Myöskään varalähteistä ei saatu tietoja juuri nyt. Vika on todennäköisesti palveluissa, ei kotiverkossasi. Yritetään aut
  ///
  /// In en, this message translates to:
  /// **'The backup sources did not answer right now either. The problem is most likely at the services, not your home network. Retrying automatically.'**
  String get s828d009fa6;

  /// fi: Palvelussa on häiriö. Vika on todennäköisesti palvelussa, ei kotiverkossasi. Yritetään automaattisesti uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The service has a problem, most likely at the service and not your home network. Retrying automatically.'**
  String get se21c801ba6;

  /// fi: Kirjautuminen palveluun ei onnistunut
  ///
  /// In en, this message translates to:
  /// **'Signing in to the service failed'**
  String get s35e0766add;

  /// fi: Tarkista palvelun tunnus, avain tai token ({p0}).
  ///
  /// In en, this message translates to:
  /// **'Check the account, key or token for {p0}.'**
  String sa4d255e53c(String p0);

  /// fi: Osoitteessa ei vastaa odotettu laite – tarkista osoite (http vai https?)
  ///
  /// In en, this message translates to:
  /// **'The expected device does not answer at this address – check it (http or https?)'**
  String get sd0a2130950;

  /// fi: Osoitteessa vastaa jokin, mutta ei odotetulla tavalla. Kokeile https:// tai http:// osoitteen alkuun ja tarkista portti.
  ///
  /// In en, this message translates to:
  /// **'Something answers, but not as expected. Try https:// or http:// in front and check the port.'**
  String get sdd5742468b;

  /// fi: Osoitetta ei löydy
  ///
  /// In en, this message translates to:
  /// **'Address not found'**
  String get s03c0a5192b;

  /// fi: Tarkista osoitteen kirjoitusasu. Kokeile IP-osoitetta (esim. 192.168.1.50) nimen sijaan.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling. Try the IP address (e.g. 192.168.1.50) instead of a name.'**
  String get sb3ef01a6fa;

  /// fi: Laitetta ei löydy osoitteesta
  ///
  /// In en, this message translates to:
  /// **'Device not found at this address'**
  String get s274a753ad6;

  /// fi: Tarkista että laite on päällä ja että puhelin tai PC on samassa wifissä. Tarkista myös IP-osoite – se voi vaihtua, joten
  ///
  /// In en, this message translates to:
  /// **'Check that the device is on and that your phone or PC is on the same Wi-Fi. Also check the IP address – it can change, so reserve a fixed address in your router.'**
  String get s2b503695b6;

  /// fi: Laite löytyi, mutta ei vastaa tähän porttiin
  ///
  /// In en, this message translates to:
  /// **'Device found but the port is closed'**
  String get sff9ca463e3;

  /// fi: Tarkista portin numero ja että palvelu (esim. web-käyttöliittymä, MQTT tai Modbus TCP) on laitteessa päällä.
  ///
  /// In en, this message translates to:
  /// **'Check the port number and that the service (web UI, MQTT or Modbus TCP) is enabled on the device.'**
  String get s1d4f4506de;

  /// fi: Suojattu yhteys (https) epäonnistui
  ///
  /// In en, this message translates to:
  /// **'Secure connection (https) failed'**
  String get s8523a9cfd0;

  /// fi: Kokeile osoitetta http:// -alkuisena, tai Lisäasetuksista "Salli itse allekirjoitettu sertifikaatti".
  ///
  /// In en, this message translates to:
  /// **'Try http:// instead, or enable \"Allow self-signed certificate\" under Advanced.'**
  String get sdfd499c1f1;

  /// fi: Tunnus, salasana tai token ei kelpaa
  ///
  /// In en, this message translates to:
  /// **'Login, password or token rejected'**
  String get s3fabccc1cd;

  /// fi: Tarkista tunnukset. Home Assistantissa voit luoda uuden pitkäikäisen tunnuksen omasta profiilista.
  ///
  /// In en, this message translates to:
  /// **'Check the credentials. In Home Assistant you can create a new long-lived token in your profile.'**
  String get sdc2d65f8eb;

  /// fi: Laite vastasi, mutta kohdetta ei löytynyt
  ///
  /// In en, this message translates to:
  /// **'Device answered but the item was not found'**
  String get se0a7cef6c4;

  /// fi: Tarkista polku tai entiteetin nimi (esim. light.olohuone). Isot ja pienet kirjaimet ovat merkitseviä.
  ///
  /// In en, this message translates to:
  /// **'Check the path or entity name (e.g. light.living_room).'**
  String get see02239a35;

  /// fi: Laitteessa tapahtui virhe
  ///
  /// In en, this message translates to:
  /// **'The device reported an error'**
  String get sdec83d1e90;

  /// fi: Komento tai kysely ei kelvannut laitteelle. Tarkista polku ja lähetettävä sisältö.
  ///
  /// In en, this message translates to:
  /// **'Check the path and payload.'**
  String get s3de239ffc5;

  /// fi: Laite ei tunne tätä rekisteriä
  ///
  /// In en, this message translates to:
  /// **'Unknown register on the device'**
  String get s6121e8d8f1;

  /// fi: Tarkista rekisterin numero laitteen Modbus-taulukosta. Jos taulukko alkaa 1:stä (esim. 40001), vähennä 1. Tarkista myös
  ///
  /// In en, this message translates to:
  /// **'Check the register number. If the table starts at 1 (e.g. 40001), subtract 1. Also check holding vs input.'**
  String get s3474aedf54;

  /// fi: Laite ei tue tätä rekisterityyppiä
  ///
  /// In en, this message translates to:
  /// **'Register type not supported'**
  String get s2c303f6774;

  /// fi: Kokeile toista rekisterityyppiä (holding ↔ input).
  ///
  /// In en, this message translates to:
  /// **'Try the other register type (holding ↔ input).'**
  String get s945685fcda;

  /// fi: Laite ei hyväksynyt arvoa
  ///
  /// In en, this message translates to:
  /// **'Value rejected by the device'**
  String get s07ffbc349a;

  /// fi: Arvo on luultavasti sallitun alueen ulkopuolella. Tarkista myös kerroin.
  ///
  /// In en, this message translates to:
  /// **'The value is probably out of range. Check the scale too.'**
  String get s76b95eef9f;

  /// fi: Laite löytyi, mutta Modbus TCP ei ole päällä
  ///
  /// In en, this message translates to:
  /// **'Device found, but Modbus TCP is off'**
  String get s7746921882;

  /// fi: Osoitteessa on laite, mutta se ei ota vastaan Modbus-yhteyttä tähän porttiin. Laita Modbus TCP päälle laitteen asetuksis
  ///
  /// In en, this message translates to:
  /// **'There is a device at this address, but it does not accept Modbus on this port. Turn on Modbus TCP in the device settings (often under Network / Modbus / Remote control) and check the port (usually 502). You can also tap \"Scan Modbus\". If the device works in Home Assistant, it may already have a connection (many allow only one) – read the values through HA.'**
  String get s7e552bd146;

  /// fi: Laite on estotilassa, yritetään uudelleen klo {p0}
  ///
  /// In en, this message translates to:
  /// **'The device is in lockout, retrying at {p0}'**
  String s0ebc613f20(String p0);

  /// fi: Laite ei vastannut, joten sitä ei kysytä hetkeen – moni laite menee estotilaan, jos sitä kysytään liian usein. Tauko pit
  ///
  /// In en, this message translates to:
  /// **'The device did not answer, so it is left alone for a while – many devices lock out clients that poll too often. The pause grows from 30 seconds to 5 minutes. If the device already has a connection (e.g. Home Assistant), read the values through HA. The read interval and pauses are under Advanced in the connection.'**
  String get s317b2b59af;

  /// fi: Laitteen osoite puuttuu
  ///
  /// In en, this message translates to:
  /// **'The device address is missing'**
  String get s33e09089b2;

  /// fi: Avaa yhteys ja anna laitteen IP-osoite, tai paina "Skannaa Modbus", niin sovellus etsii laitteen verkosta.
  ///
  /// In en, this message translates to:
  /// **'Open the connection and enter the device IP address, or tap \"Scan Modbus\" to find the device on the network.'**
  String get s6180bd540e;

  /// fi: Laitteella voi olla jo yhteys
  ///
  /// In en, this message translates to:
  /// **'The device may already have a connection'**
  String get sd73581c910;

  /// fi: Laite katkaisi Modbus-yhteyden heti. Moni laite sallii vain yhden Modbus TCP -yhteyden kerrallaan. Jos laite on jo Home
  ///
  /// In en, this message translates to:
  /// **'The device dropped the Modbus connection right away. Many devices allow only one Modbus TCP connection at a time. If the device is already in Home Assistant (e.g. modbus.yaml), read the values through HA.'**
  String get scee8d982a2;

  /// fi: Osoitteessa ei ole laitetta
  ///
  /// In en, this message translates to:
  /// **'Nothing at this address'**
  String get s6ca672a111;

  /// fi: Tähän IP-osoitteeseen ei saatu yhteyttä. Tarkista että laite on päällä ja samassa verkossa, ja että IP-osoite on oikein
  ///
  /// In en, this message translates to:
  /// **'Nothing answered at this IP address. Check that the device is on and in the same network and that the IP is right (it can change – reserve a fixed address in the router). \"Scan Modbus\" finds devices on the network.'**
  String get sf7a98e1c70;

  /// fi: Modbus-laite ei vastannut ajoissa
  ///
  /// In en, this message translates to:
  /// **'The Modbus device did not answer in time'**
  String get scb0cba44ea;

  /// fi: Yhteyttä porttiin ei saatu muodostettua. Yleisimmät syyt: väärä IP-osoite, laite on toisessa verkossa (vieras-wifi), Mod
  ///
  /// In en, this message translates to:
  /// **'Could not open the port. Most common causes: wrong IP, the device is in another network (guest Wi-Fi), Modbus TCP is off or a firewall blocks the port. Check the address and port or tap \"Scan Modbus\".'**
  String get sc03ae7e1c5;

  /// fi: Yhdyskäytävä ei tavoita laitetta tällä unit id:llä
  ///
  /// In en, this message translates to:
  /// **'The gateway cannot reach a device with this unit id'**
  String get sefba540275;

  /// fi: Modbus-yhdyskäytävä vastasi, mutta sen takana ei ole laitetta tällä osoitteella (unit id). Tarkista laitteen Modbus-osoi
  ///
  /// In en, this message translates to:
  /// **'The Modbus gateway answered, but no device with this unit id is behind it. Check the device\'\'s Modbus address (often 1) and the serial speed and parity. \"Scan Modbus\" tries addresses 1–247.'**
  String get s6e4ed361f3;

  /// fi: Laite ei vastannut Modbus-kyselyyn
  ///
  /// In en, this message translates to:
  /// **'No Modbus reply'**
  String get sb66bc0e677;

  /// fi: Yhteys aukesi, mutta vastausta ei tullut. Tarkista laitteen osoite (unit id, usein 1) ja yhdyskäytävän sarjaportin asetu
  ///
  /// In en, this message translates to:
  /// **'Connected but no reply. Check the unit id (often 1) and the gateway serial settings.'**
  String get s6ef5539bc2;

  /// fi: Laite ei vastannut
  ///
  /// In en, this message translates to:
  /// **'No reply from the device'**
  String get s17ea4c52d5;

  /// fi: Yhteys toimi, mutta vastausta ei tullut ajoissa. Tarkista lähetettävä viesti.
  ///
  /// In en, this message translates to:
  /// **'Connected but no reply in time. Check the message.'**
  String get s50ecf9ba6f;

  /// fi: Asetuksissa on virhe
  ///
  /// In en, this message translates to:
  /// **'There is a mistake in the settings'**
  String get sf93db545a1;

  /// fi: Tarkista kentät, esim. että osoite alkaa http:// ja että numerot ovat numeroita.
  ///
  /// In en, this message translates to:
  /// **'Check the fields, e.g. that the address starts with http:// and numbers are numbers.'**
  String get sf19a9f0856;

  /// fi: Ruudulta puuttuu laite
  ///
  /// In en, this message translates to:
  /// **'This tile has no device'**
  String get s3976954bef;

  /// fi: Avaa muokkaus (kynä) ja valitse ruudulle laite.
  ///
  /// In en, this message translates to:
  /// **'Open edit mode (pencil) and choose a device for the tile.'**
  String get sc025e0a1f4;

  /// fi: Etäyhteys kulkee kotona olevan sillan (tabletti tai PC) kautta. Tarkista että se on päällä, Molaplan on auki ja sillä on
  ///
  /// In en, this message translates to:
  /// **'Remote access goes through the bridge at home (tablet or PC). Check that it is on, Molaplan is open and it has internet.'**
  String get s2cd1df086e;

  /// fi: Laitteesi ei saa yhteyttä Molaplanin etäpalveluun. Tarkista mobiilidata tai wifi.
  ///
  /// In en, this message translates to:
  /// **'Your device cannot reach the Molaplan remote service. Check mobile data or Wi-Fi.'**
  String get sdbf06d05d9;

  /// fi: Etäyhteys on poistettu
  ///
  /// In en, this message translates to:
  /// **'Remote access was removed'**
  String get s8b737f4026;

  /// fi: Tämä laite on poistettu kotisillalta. Yhdistä uudelleen: Asetukset → Etäyhteys.
  ///
  /// In en, this message translates to:
  /// **'This device was removed on the home bridge. Pair again: Settings → Remote access.'**
  String get s4b9e4ca079;

  /// fi: Kotisilta ei vastannut ajoissa
  ///
  /// In en, this message translates to:
  /// **'The home bridge did not answer in time'**
  String get s5b3116ed94;

  /// fi: Yhteys voi olla hidas. Yritä hetken päästä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The connection may be slow. Try again in a moment.'**
  String get se082095a34;

  /// fi: Koodi ei kelpaa
  ///
  /// In en, this message translates to:
  /// **'The code is not valid'**
  String get s688a4f4ccb;

  /// fi: Tarkista 6 numeroa kotisillan näytöltä. Koodi on voimassa 10 minuuttia ja kelpaa kerran – paina tarvittaessa sillalla "Y
  ///
  /// In en, this message translates to:
  /// **'Check the 6 digits on the bridge screen. A code is valid for 10 minutes and works once – press \"Pair a phone\" on the bridge again if needed.'**
  String get sfa0e226cd0;

  /// fi: Kotisilta ei hyväksynyt laitetta
  ///
  /// In en, this message translates to:
  /// **'The bridge did not accept this device'**
  String get sfa5c1fb1ac;

  /// fi: Kun yhdistät koodilla, sillan näytölle tulee kysymys – paina siellä "Hyväksy". Tai skannaa QR-koodi, silloin hyväksyntää
  ///
  /// In en, this message translates to:
  /// **'When pairing with the code, the bridge asks for confirmation – press \"Accept\" there. Or scan the QR code, then no confirmation is needed.'**
  String get s9ad07ab36e;

  /// fi: Turvatarkistus epäonnistui
  ///
  /// In en, this message translates to:
  /// **'Security check failed'**
  String get sb5c271ae6a;

  /// fi: Yhteyttä ei voitu varmistaa turvalliseksi, joten sitä ei otettu käyttöön. Yritä uudelleen QR-koodilla.
  ///
  /// In en, this message translates to:
  /// **'The connection could not be verified as safe, so it was not used. Try again with the QR code.'**
  String get s3d7ca280db;

  /// fi: Kotisilta ei vastannut
  ///
  /// In en, this message translates to:
  /// **'The bridge did not answer'**
  String get s0061b44673;

  /// fi: Hyväksy laite sillan näytöllä 3 minuutin sisällä, tai skannaa QR-koodi.
  ///
  /// In en, this message translates to:
  /// **'Accept the device on the bridge screen within 3 minutes, or scan the QR code.'**
  String get sceb894b9b3;

  /// fi: Yhteys ei onnistunut
  ///
  /// In en, this message translates to:
  /// **'The connection did not work'**
  String get s700b0ef4de;

  /// fi: Tarkista osoite ja asetukset ja yritä uudelleen. Tarkempi syy näkyy teknisissä tiedoissa.
  ///
  /// In en, this message translates to:
  /// **'Check the address and settings and try again. The technical details show the exact reason.'**
  String get s53a891e670;

  /// fi: Toimii sovelluksessa tai kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'Works in the app or through a home bridge'**
  String get s1e02f457b4;

  /// fi: Ei tietoa
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get s8f2ee89c28;

  /// fi: Avaa Molaplan laitteella, jossa laatta on näkyvissä
  ///
  /// In en, this message translates to:
  /// **'Open Molaplan on a device where the tile is shown'**
  String get sa2029e688b;

  /// fi: min vanha
  ///
  /// In en, this message translates to:
  /// **'min old'**
  String get sfdaa9523b0;

  /// fi: päivitetty
  ///
  /// In en, this message translates to:
  /// **'updated'**
  String get s0c3b4eb370;

  /// fi: iPhonen widget Scriptable-sovellukseen (ilmainen, App Store). Ohje: molaplan.com → laatta → Pikakomento.
  ///
  /// In en, this message translates to:
  /// **'iPhone widget for the Scriptable app (free, App Store). Help: molaplan.com → tile → Shortcut.'**
  String get s34705bcd0b;

  /// fi: Ei sisällä PIN-koodeja eikä salasanoja.
  ///
  /// In en, this message translates to:
  /// **'Contains no PINs or passwords.'**
  String get sae2303f670;

  /// fi: Pikakomento: {p0}
  ///
  /// In en, this message translates to:
  /// **'Shortcut: {p0}'**
  String se0620d25d1(String p0);

  /// fi: Avaa Pikakomennot-sovellus ja paina +.
  ///
  /// In en, this message translates to:
  /// **'Open the Shortcuts app and tap +.'**
  String get s04a78db719;

  /// fi: Lisää toiminto "Avaa URL-osoitteet" ja liitä osoite:
  ///
  /// In en, this message translates to:
  /// **'Add the action \"Open URLs\" and paste the address:'**
  String get s72698a5ad4;

  /// fi: Nimeä pikakomento laatan nimellä – silloin "Hei Siri, {p0}" toimii.
  ///
  /// In en, this message translates to:
  /// **'Name the shortcut after the tile – then \"Hey Siri, {p0}\" works.'**
  String s67f213ee2b(String p0);

  /// fi: Jaa → Lisää Koti-valikkoon, niin saat oman kuvakkeen.
  ///
  /// In en, this message translates to:
  /// **'Share → Add to Home Screen gives it its own icon.'**
  String get sa19a41e8bc;

  /// fi: Molaplan avautuu Safarissa ja kysyy joka kerta vahvistuksen ja tarvittaessa PIN-koodin. PIN-koodia ei tallenneta linkkii
  ///
  /// In en, this message translates to:
  /// **'Molaplan opens in Safari and asks for confirmation and, if needed, the PIN every time. The PIN is never stored in the link. Sign in to molaplan.com in Safari once.'**
  String get s5868f0efb3;

  /// fi: Pikakomento (avaa laatta): {p0}
  ///
  /// In en, this message translates to:
  /// **'Shortcut (open the tile): {p0}'**
  String s6bb11e2974(String p0);

  /// fi: Pikakomento (lue arvo): {p0}
  ///
  /// In en, this message translates to:
  /// **'Shortcut (read the value): {p0}'**
  String s3457f68fe8(String p0);

  /// fi: Lisää toiminto "Hae URL-osoitteen sisältö" osoitteella:
  ///
  /// In en, this message translates to:
  /// **'Add the action \"Get Contents of URL\" with the address:'**
  String get sf49ecc47f8;

  /// fi: Lisää "Hae sanakirja syötteestä" ja sitten "Hae sanakirjan arvo": message.
  ///
  /// In en, this message translates to:
  /// **'Add \"Get Dictionary from Input\", then \"Get Dictionary Value\": message.'**
  String get sbd6df96c54;

  /// fi: Lisää uudelleen "Hae sanakirja syötteestä" ja "Hae sanakirjan arvo": value.
  ///
  /// In en, this message translates to:
  /// **'Add \"Get Dictionary from Input\" again and \"Get Dictionary Value\": value.'**
  String get s7ef682753c;

  /// fi: Lisää "Puhu teksti" tai "Näytä tulos".
  ///
  /// In en, this message translates to:
  /// **'Add \"Speak Text\" or \"Show Result\".'**
  String get s0276650db2;

  /// fi: ei vastaa ({p0} min)
  ///
  /// In en, this message translates to:
  /// **'not answering ({p0} min)'**
  String s6c33f19716(String p0);

  /// fi: pois päältä
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get scebcdabe25;

  /// fi: Kokeilu
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get sd4be8bca5f;

  /// fi: Vesivuoto → hälytys
  ///
  /// In en, this message translates to:
  /// **'Water leak → alarm'**
  String get sd76aadb97c;

  /// fi: Kiireellinen ilmoitus heti, kun vuotoanturi havaitsee vettä (myös hiljaisena aikana).
  ///
  /// In en, this message translates to:
  /// **'An urgent notification as soon as a leak sensor detects water (also during quiet hours).'**
  String get s0bd0724e83;

  /// fi: Valot päälle auringonlaskulla
  ///
  /// In en, this message translates to:
  /// **'Lights on at sunset'**
  String get sa9f114c81d;

  /// fi: Valitut valot syttyvät, kun aurinko laskee.
  ///
  /// In en, this message translates to:
  /// **'The chosen lights turn on when the sun sets.'**
  String get s02402a38eb;

  /// fi: Kaikki pois klo 23
  ///
  /// In en, this message translates to:
  /// **'Everything off at 23:00'**
  String get s386fda8330;

  /// fi: Valitut laitteet sammuvat illalla.
  ///
  /// In en, this message translates to:
  /// **'The chosen devices turn off in the evening.'**
  String get s3508664550;

  /// fi: Ilmoita, kun laite ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Notify when a device stops answering'**
  String get s3775470669;

  /// fi: Ilmoitus, jos laite on ollut tavoittamattomissa 10 minuuttia.
  ///
  /// In en, this message translates to:
  /// **'A notification when a device has been unreachable for 10 minutes.'**
  String get s5c07969ac8;

  /// fi: Ilmoita, kun lämpötila laskee
  ///
  /// In en, this message translates to:
  /// **'Notify when the temperature drops'**
  String get s2cdd15be92;

  /// fi: Ilmoitus, kun anturin lukema laskee rajan alle.
  ///
  /// In en, this message translates to:
  /// **'A notification when a sensor reading drops below a limit.'**
  String get sa74faa4635;

  /// fi: Halvimmat tunnit: laite päälle
  ///
  /// In en, this message translates to:
  /// **'Cheapest hours: device on'**
  String get s94ed692877;

  /// fi: Laite päälle päivän halvimpina tunteina (esim. varaaja).
  ///
  /// In en, this message translates to:
  /// **'A device on during the day’s cheapest hours (e.g. a water heater).'**
  String get s9b99909a7c;

  /// fi: Ilmoita kalliista sähköstä
  ///
  /// In en, this message translates to:
  /// **'Notify about expensive electricity'**
  String get s90d5d2954d;

  /// fi: Ilmoitus, kun pörssisähkö nousee yli 20 c/kWh.
  ///
  /// In en, this message translates to:
  /// **'A notification when the spot price goes above 20 c/kWh.'**
  String get s876690515a;

  /// fi: Lataa auto aurinkosähkön ylijäämällä
  ///
  /// In en, this message translates to:
  /// **'Charge the car on solar surplus'**
  String get s602af22563;

  /// fi: Laturi päälle, kun verkkoon myydään yli 1,4 kW. Pois, kun verkosta ostetaan yli 1 kW (vähintään 10 min lataus).
  ///
  /// In en, this message translates to:
  /// **'Charger on when more than 1.4 kW is exported. Off when more than 1 kW is imported (at least 10 min of charging).'**
  String get s9ce0e97a38;

  /// fi: Lataa auto halvimpina tunteina
  ///
  /// In en, this message translates to:
  /// **'Charge the car in the cheapest hours'**
  String get scbad5277ee;

  /// fi: Laturi päälle päivän 4 halvimpana tuntina ja pois, kun halvat tunnit loppuvat.
  ///
  /// In en, this message translates to:
  /// **'Charger on in the day’s 4 cheapest hours and off when they end.'**
  String get sb6dc0d48ed;

  /// fi: Pakkasvaroitus
  ///
  /// In en, this message translates to:
  /// **'Frost warning'**
  String get s1906ecb28c;

  /// fi: Ilmoitus, kun ulkona on alle −15 °C.
  ///
  /// In en, this message translates to:
  /// **'A notification when it is below −15 °C outside.'**
  String get s036ecd266d;

  /// fi: Aamukatsaus klo 7
  ///
  /// In en, this message translates to:
  /// **'Morning summary at 7:00'**
  String get sacf213e078;

  /// fi: Sää, sähkön hinta ja kodin tila ilmoituksena joka aamu.
  ///
  /// In en, this message translates to:
  /// **'Weather, electricity price and the state of your home as a notification every morning.'**
  String get sef21ad6784;

  /// fi: VESIVUOTO!
  ///
  /// In en, this message translates to:
  /// **'WATER LEAK!'**
  String get s5d308e6986;

  /// fi: Lämpötila laski
  ///
  /// In en, this message translates to:
  /// **'Temperature dropped'**
  String get s13017ce3b0;

  /// fi: Sähkö on kallista
  ///
  /// In en, this message translates to:
  /// **'Electricity is expensive'**
  String get s4c52f38c8b;

  /// fi: Huomenta
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get sc797ab9c4c;

  /// fi: Ruutu puuttuu
  ///
  /// In en, this message translates to:
  /// **'Tile missing'**
  String get scec02139b6;

  /// fi: Ryhmän laitteet eivät vastaa
  ///
  /// In en, this message translates to:
  /// **'Group not answering'**
  String get s66f19d787b;

  /// fi: {p0}: komento puuttuu
  ///
  /// In en, this message translates to:
  /// **'{p0}: no command'**
  String sed9788d6dc(String p0);

  /// fi: {p0} laitetta päällä
  ///
  /// In en, this message translates to:
  /// **'{p0} devices on'**
  String sd39874fbe2(String p0);

  /// fi: {p0} ei vastaa
  ///
  /// In en, this message translates to:
  /// **'{p0} not answering'**
  String sbe208615d0(String p0);

  /// fi: Huomenna sähkö maksaa keskimäärin {avg} c/kWh (kallein {max} klo {hour}). Lämmitä takka.
  ///
  /// In en, this message translates to:
  /// **'\'Tomorrow electricity averages {avg} c/kWh (peak {max} at {hour}). Light the fireplace.\''**
  String get seec5bf7f8d;

  /// fi: Tänään sähkö on poikkeuksellisen kallista: keskimäärin {avg} c/kWh, kallein {max} klo {hour}.
  ///
  /// In en, this message translates to:
  /// **'\'Electricity is exceptionally expensive today: average {avg} c/kWh, peak {max} at {hour}.\''**
  String get s4a7ea7d7f1;

  /// fi: Huomenna sähkö on poikkeuksellisen kallista: keskimäärin {avg} c/kWh, kallein {max} klo {hour}.
  ///
  /// In en, this message translates to:
  /// **'\'Electricity is exceptionally expensive tomorrow: average {avg} c/kWh, peak {max} at {hour}.\''**
  String get se8a2912e3e;

  /// fi: Mökille tulo {arrival}. Laita lämmitys päälle nyt, tavoite {target} °C.
  ///
  /// In en, this message translates to:
  /// **'\'Arriving at the cabin {arrival}. Turn the heating on now, target {target} °C.\''**
  String get s0818fd54b1;

  /// fi: Huomenna sähkö keskimäärin {avg} c/kWh, kallein {max} klo {hour}.
  ///
  /// In en, this message translates to:
  /// **'\'Tomorrow: average {avg} c/kWh, peak {max} at {hour}.\''**
  String get s57aad0f6c3;

  /// fi: Tänään sähkö keskimäärin {avg} c/kWh, kallein {max} klo {hour}.
  ///
  /// In en, this message translates to:
  /// **'\'Today: average {avg} c/kWh, peak {max} at {hour}.\''**
  String get s05394a7333;

  /// fi: Poikkeuksellisen kallis sähkö {date}: keskimäärin {avg} c/kWh, kallein {max} klo {hour}.
  ///
  /// In en, this message translates to:
  /// **'\'Exceptionally expensive electricity {date}: average {avg} c/kWh, peak {max} at {hour}.\''**
  String get s412e06dba4;

  /// fi: Sääennuste {date}: {temp} °C.
  ///
  /// In en, this message translates to:
  /// **'\'Forecast {date}: {temp} °C.\''**
  String get s7f8a4ab629;

  /// fi: {tile}: {value}
  ///
  /// In en, this message translates to:
  /// **'\'{tile}: {value}\''**
  String get s326f105e40;

  /// fi: Saapuminen {arrival}. Laita lämmitys päälle, tavoite {target} °C.
  ///
  /// In en, this message translates to:
  /// **'\'Arriving {arrival}. Turn the heating on, target {target} °C.\''**
  String get s65afe3ff6f;

  /// fi: yhteys katkesi
  ///
  /// In en, this message translates to:
  /// **'connection closed'**
  String get sae56ce66d4;

  /// fi: Tuya: väärä paikallinen avain (local key) tai protokollaversio
  ///
  /// In en, this message translates to:
  /// **'Tuya: wrong local key or protocol version'**
  String get sb6a87586a8;

  /// fi: laite ei vastannut
  ///
  /// In en, this message translates to:
  /// **'no answer from the device'**
  String get s2b1a0a5a05;

  /// fi: Tuya {p0}: laite ei vastannut kättelyyn – väärä paikallinen avain (local key) tai protokollaversio?
  ///
  /// In en, this message translates to:
  /// **'Tuya {p0}: no answer to the handshake – wrong local key or protocol version?'**
  String sc4fdd8a4a3(String p0);

  /// fi: kättely epäonnistui
  ///
  /// In en, this message translates to:
  /// **'handshake failed'**
  String get sa291ffb35a;

  /// fi: Tuya: väärä paikallinen avain (local key)
  ///
  /// In en, this message translates to:
  /// **'Tuya: wrong local key'**
  String get se2a4cc6409;

  /// fi: ei löytynyt kotiverkosta
  ///
  /// In en, this message translates to:
  /// **'not found on the home network'**
  String get s7b8131a396;

  /// fi: Powerant / Tuya / Smart Life
  ///
  /// In en, this message translates to:
  /// **'Powerant / Tuya / Smart Life'**
  String get s210907044a;

  /// fi: Pistorasiat, kytkimet, himmentimet, lamput ja anturit. Ohjataan kotiverkossa ilman pilveä.
  ///
  /// In en, this message translates to:
  /// **'Plugs, switches, dimmers, bulbs and sensors. Controlled on your home network without the cloud.'**
  String get sa8d1873781;

  /// fi: Oma ilmainen Tuya-kehittäjäprojekti: iot.tuya.com → Cloud → Create Cloud Project (data center: Central Europe) → Devices
  ///
  /// In en, this message translates to:
  /// **'Your own free Tuya developer project: iot.tuya.com → Cloud → Create Cloud Project (data center: Central Europe) → Devices → Link App Account → scan the QR code with the Smart Life / Tuya / Powerant app. The Access ID is on the project\'\'s Overview page.'**
  String get s3530ee658b;

  /// fi: Samalta Overview-sivulta. Tallentuu vain tälle laitteelle (ja omaan salattuun holviisi) – ei Molaplanin palvelimille.
  ///
  /// In en, this message translates to:
  /// **'From the same Overview page. Stored only on this device (and your own encrypted vault) – never on Molaplan\'\'s servers.'**
  String get s39d3fce33c;

  /// fi: Projektin data center. Suomessa yleensä eu (Central Europe). Western Europe = weu.
  ///
  /// In en, this message translates to:
  /// **'The project\'\'s data center. Usually eu (Central Europe) in Europe. Western Europe = weu.'**
  String get s12e2e8638b;

  /// fi: Vain jos laitteita ei löydy: sovellus → laite → kynä → Laitetiedot → Virtuaalinen ID.
  ///
  /// In en, this message translates to:
  /// **'Only if no devices are found: app → device → pencil → Device information → Virtual ID.'**
  String get sfc77cb8d11;

  /// fi: Tuya paikallisella avaimella
  ///
  /// In en, this message translates to:
  /// **'Tuya with a local key'**
  String get s7938176623;

  /// fi: Jos tiedät jo laitteen tunnuksen ja paikallisen avaimen (local key).
  ///
  /// In en, this message translates to:
  /// **'If you already know the device ID and its local key.'**
  String get sf11f3cf10e;

  /// fi: Reitittimen laitelistasta (laitteen nimi usein ESP_ tai wlan0).
  ///
  /// In en, this message translates to:
  /// **'From your router\'\'s device list (often named ESP_ or wlan0).'**
  String get s3dcff9c852;

  /// fi: 16 merkin avain. Saat sen Tuya-kehittäjäprojektista tai helpoimmin valitsemalla "Powerant / Tuya / Smart Life".
  ///
  /// In en, this message translates to:
  /// **'A 16-character key. Get it from a Tuya developer project, or simply pick \"Powerant / Tuya / Smart Life\".'**
  String get s3cc607ceba;

  /// fi: Täytetään automaattisesti, jos laite löytyi verkosta.
  ///
  /// In en, this message translates to:
  /// **'Filled in automatically when the device was found on the network.'**
  String get s4105c416c6;

  /// fi: 3.3, 3.4 tai 3.5. Tunnistetaan automaattisesti, jos laite löytyi verkosta.
  ///
  /// In en, this message translates to:
  /// **'3.3, 3.4 or 3.5. Detected automatically when the device was found on the network.'**
  String get s39dfcd0595;

  /// fi: kanava {p0}
  ///
  /// In en, this message translates to:
  /// **'channel {p0}'**
  String s991d0c0cdc(String p0);

  /// fi: kirkkaus
  ///
  /// In en, this message translates to:
  /// **'brightness'**
  String get see129fb410;

  /// fi: värilämpötila
  ///
  /// In en, this message translates to:
  /// **'colour temperature'**
  String get sc8b1b10046;

  /// fi: teho
  ///
  /// In en, this message translates to:
  /// **'power'**
  String get se78754330c;

  /// fi: energia
  ///
  /// In en, this message translates to:
  /// **'energy'**
  String get s0ceafaa97c;

  /// fi: jännite
  ///
  /// In en, this message translates to:
  /// **'voltage'**
  String get sdb8ea154be;

  /// fi: virta
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get s37f61ae645;

  /// fi: lämpötila
  ///
  /// In en, this message translates to:
  /// **'temperature'**
  String get s68e711123b;

  /// fi: kosteus
  ///
  /// In en, this message translates to:
  /// **'humidity'**
  String get s736646b3b0;

  /// fi: paristo
  ///
  /// In en, this message translates to:
  /// **'battery'**
  String get s03a198454c;

  /// fi: Tuya / Powerant (paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Tuya / Powerant (local)'**
  String get sc20488a1f0;

  /// fi: Tuya-pilven alue
  ///
  /// In en, this message translates to:
  /// **'Tuya cloud region'**
  String get sc849342970;

  /// fi: Vain avainten hakuun. Suomessa yleensä Keski-Eurooppa.
  ///
  /// In en, this message translates to:
  /// **'Only for fetching the keys. Usually Central Europe in Europe.'**
  String get s49c53b561d;

  /// fi: Keski-Eurooppa
  ///
  /// In en, this message translates to:
  /// **'Central Europe'**
  String get s7cf3dec993;

  /// fi: Länsi-Eurooppa
  ///
  /// In en, this message translates to:
  /// **'Western Europe'**
  String get seead5e286d;

  /// fi: Länsi-USA
  ///
  /// In en, this message translates to:
  /// **'Western America'**
  String get s081e2e881d;

  /// fi: Itä-USA
  ///
  /// In en, this message translates to:
  /// **'Eastern America'**
  String get s5b9587ae93;

  /// fi: Kiina
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get sc5401d63d5;

  /// fi: Intia
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get sb6786f25b9;

  /// fi: Singapore
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get scd78f804bb;

  /// fi: Access ID (iot.tuya.com)
  ///
  /// In en, this message translates to:
  /// **'Access ID (iot.tuya.com)'**
  String get s61b325e35c;

  /// fi: Oman pilviprojektisi Access ID. Tarvitaan vain avainten hakuun.
  ///
  /// In en, this message translates to:
  /// **'Access ID of your own cloud project. Only needed to fetch the keys.'**
  String get s925e495479;

  /// fi: Access Secret
  ///
  /// In en, this message translates to:
  /// **'Access Secret'**
  String get sb07c0dad24;

  /// fi: Oman pilviprojektisi Access Secret. Tallentuu vain tälle laitteelle / omaan holviisi.
  ///
  /// In en, this message translates to:
  /// **'Access Secret of your own cloud project. Stored only on this device / in your own vault.'**
  String get s45bcef5c09;

  /// fi: Paikalliset avaimet
  ///
  /// In en, this message translates to:
  /// **'Local keys'**
  String get s295cf46412;

  /// fi: Laitteiden paikalliset avaimet (haetaan automaattisesti).
  ///
  /// In en, this message translates to:
  /// **'The devices\'\' local keys (fetched automatically).'**
  String get sf58ae26c82;

  /// fi: Pysyvä yhteys (heti päivittyvät ruudut)
  ///
  /// In en, this message translates to:
  /// **'Keep connected (instant updates)'**
  String get s0c1a9d4ab9;

  /// fi: Laite ilmoittaa muutoksista heti. Moni Tuya-laite sallii vain yhden yhteyden kerrallaan – käytä vain yhdellä laitteella.
  ///
  /// In en, this message translates to:
  /// **'The device reports changes at once. Many Tuya devices allow only one connection – use on one device only.'**
  String get s121fb2c5fc;

  /// fi: Laitteen tunnus
  ///
  /// In en, this message translates to:
  /// **'Device id'**
  String get s65514aef3c;

  /// fi: Tuya-laitteen id.
  ///
  /// In en, this message translates to:
  /// **'The Tuya device id.'**
  String get se42a336655;

  /// fi: DP-numero
  ///
  /// In en, this message translates to:
  /// **'DP number'**
  String get sff3cf64925;

  /// fi: Datapisteen numero (1 = virta useimmissa).
  ///
  /// In en, this message translates to:
  /// **'Data point number (1 = power on most).'**
  String get sfec9b1a643;

  /// fi: Kerroin
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get see24ec5d84;

  /// fi: Esim. 0.1, jos laite ilmoittaa kymmenyksinä.
  ///
  /// In en, this message translates to:
  /// **'E.g. 0.1 when the device reports tenths.'**
  String get s2fa7dedd1b;

  /// fi: Datapisteen numero.
  ///
  /// In en, this message translates to:
  /// **'Data point number.'**
  String get se30676cace;

  /// fi: Arvo ({{value}})
  ///
  /// In en, this message translates to:
  /// **'\'Value ({{value}})\''**
  String get seb4c438a42;

  /// fi: Lähetettävä arvo; {{value}} = ruudun arvo.
  ///
  /// In en, this message translates to:
  /// **'\'Value to send; {{value}} = the tile\'\'s value.\''**
  String get s033b6b8c6c;

  /// fi: Arvon tyyppi
  ///
  /// In en, this message translates to:
  /// **'Value type'**
  String get s784e702cc1;

  /// fi: Päällä/pois kytkimille, numero kirkkaudelle.
  ///
  /// In en, this message translates to:
  /// **'On/off for switches, number for brightness.'**
  String get safadcc12c8;

  /// fi: Päällä/pois
  ///
  /// In en, this message translates to:
  /// **'On/off'**
  String get s8c8b6cb6d4;

  /// fi: Numero
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get s695fe25f79;

  /// fi: Tuya-laitetta {p0} ei ole tässä yhteydessä
  ///
  /// In en, this message translates to:
  /// **'Tuya device {p0} is not in this connection'**
  String s9abc332fb8(String p0);

  /// fi: Tuya: laitteen paikallinen avain puuttuu – hae avaimet uudelleen
  ///
  /// In en, this message translates to:
  /// **'Tuya: the device\'\'s local key is missing – fetch the keys again'**
  String get s8b84454b87;

  /// fi: Tuya: laitteen IP-osoite puuttuu
  ///
  /// In en, this message translates to:
  /// **'Tuya: the device\'\'s IP address is missing'**
  String get s764b6993c6;

  /// fi: Viesti ({{value}} = arvo)
  ///
  /// In en, this message translates to:
  /// **'\'Payload ({{value}} = value)\''**
  String get s120726c79a;

  /// fi: Viesti heksana
  ///
  /// In en, this message translates to:
  /// **'Payload is hex'**
  String get s1b5b0421c0;

  /// fi: Odota vastausta
  ///
  /// In en, this message translates to:
  /// **'Wait for response'**
  String get s44ab1d33df;

  /// fi: Vastaus heksana
  ///
  /// In en, this message translates to:
  /// **'Response as hex'**
  String get s341bf61e36;

  /// fi: Regex (ryhmä 1)
  ///
  /// In en, this message translates to:
  /// **'Regex (group 1)'**
  String get s10813e25b3;

  /// fi: JSON-polku
  ///
  /// In en, this message translates to:
  /// **'JSON path'**
  String get s55c951a8ad;

  /// fi: Aikakatkaisu (ms)
  ///
  /// In en, this message translates to:
  /// **'Timeout (ms)'**
  String get s15e327bf8e;

  /// fi: IP-osoite
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get sa70cc38354;

  /// fi: Portti
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get s800d13debd;

  /// fi: TCP (raaka)
  ///
  /// In en, this message translates to:
  /// **'TCP (raw)'**
  String get se7cff2d61e;

  /// fi: UDP
  ///
  /// In en, this message translates to:
  /// **'UDP'**
  String get s1dfeacd9f6;

  /// fi: HTTP / REST
  ///
  /// In en, this message translates to:
  /// **'HTTP / REST'**
  String get s0477f24b6b;

  /// fi: Perusosoite
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get s3102ae3a16;

  /// fi: Tunnistus
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get s38d0517a8d;

  /// fi: Ei tunnistusta
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sade17bf83e;

  /// fi: Käyttäjä + salasana (Basic)
  ///
  /// In en, this message translates to:
  /// **'User + password (Basic)'**
  String get s9cbb9f048d;

  /// fi: Käyttäjä + salasana (Digest)
  ///
  /// In en, this message translates to:
  /// **'User + password (Digest)'**
  String get s3cb806781e;

  /// fi: Avain / token (Bearer)
  ///
  /// In en, this message translates to:
  /// **'Token (Bearer)'**
  String get sb1920b9d9b;

  /// fi: Käyttäjätunnus
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get sed995f57b8;

  /// fi: Token
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get s65e35b7cc4;

  /// fi: Lisäotsakkeet (Nimi: arvo / rivi)
  ///
  /// In en, this message translates to:
  /// **'Extra headers (Name: value per line)'**
  String get s51510ae27a;

  /// fi: Salli itse allekirjoitettu sertifikaatti
  ///
  /// In en, this message translates to:
  /// **'Allow self-signed certificate'**
  String get s2c4fd261e2;

  /// fi: Aikakatkaisu (s)
  ///
  /// In en, this message translates to:
  /// **'Timeout (s)'**
  String get s361419c448;

  /// fi: Metodi
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get sf235ce5ec0;

  /// fi: Polku
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get s484291707c;

  /// fi: Runko
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get s54c8aed8bc;

  /// fi: Runko ({{value}} = arvo)
  ///
  /// In en, this message translates to:
  /// **'\'Body ({{value}} = value)\''**
  String get s5c5e9b662c;

  /// fi: Content-Type
  ///
  /// In en, this message translates to:
  /// **'Content-Type'**
  String get s8e82ca13cf;

  /// fi: Testattiin: GET {p0} (perusosoite, {p1} tavua, {p2} ms).
  ///
  /// In en, this message translates to:
  /// **'Tested: GET {p0} (base address, {p1} bytes, {p2} ms).'**
  String s3c045f21ee(String p0, String p1, String p2);

  /// fi: Komentoja ei lähetetty eikä ruutujen polkuja testattu.
  ///
  /// In en, this message translates to:
  /// **'No commands were sent and tile paths were not tested.'**
  String get s7797602869;

  /// fi: HTTP {p0}: laite vastasi, mutta ei hyväksynyt kirjautumista. Tarkista käyttäjätunnus, salasana tai token. {p1}
  ///
  /// In en, this message translates to:
  /// **'HTTP {p0}: the device answered but refused the login. Check username, password or token. {p1}'**
  String sbf349dfcbd(String p0, String p1);

  /// fi: HTTP {p0}: laite vastasi virheellä (palvelinvirhe). {p1}
  ///
  /// In en, this message translates to:
  /// **'HTTP {p0}: the device answered with a server error. {p1}'**
  String s3bd10f0ae2(String p0, String p1);

  /// fi: ✓ Laite vastasi osoitteessa {p0} (HTTP 404: perusosoitteessa ei ole sivua – se on normaalia monille laitteille). Yhteys
  ///
  /// In en, this message translates to:
  /// **'✓ The device answered at {p0} (HTTP 404: no page at the base address – normal for many devices). The connection works. {p1}'**
  String s2a7fa26dd6(String p0, String p1);

  /// fi: ✓ Yhteys toimii: HTTP {p0}. {p1} {p2}
  ///
  /// In en, this message translates to:
  /// **'✓ Connection works: HTTP {p0}. {p1} {p2}'**
  String sb2821916bc(String p0, String p1, String p2);

  /// fi: Bq/m³
  ///
  /// In en, this message translates to:
  /// **'radon'**
  String get scbc6aa5e63;

  /// fi: ppm
  ///
  /// In en, this message translates to:
  /// **'co2'**
  String get sfc402d7bce;

  /// fi: ppb
  ///
  /// In en, this message translates to:
  /// **'air_quality'**
  String get s7410329f6d;

  /// fi: °C
  ///
  /// In en, this message translates to:
  /// **'thermostat'**
  String get s05ff8e0c34;

  /// fi: %
  ///
  /// In en, this message translates to:
  /// **'humidity'**
  String get s26e6d96d7e;

  /// fi: hPa
  ///
  /// In en, this message translates to:
  /// **'speed'**
  String get sfabcfc0188;

  /// fi: µg/m³
  ///
  /// In en, this message translates to:
  /// **'air_quality'**
  String get s12a1c5653a;

  /// fi: %
  ///
  /// In en, this message translates to:
  /// **'battery'**
  String get s2f37dd80ed;

  /// fi: Airthings (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Airthings (cloud)'**
  String get sd4025b7a32;

  /// fi: Client ID
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get sf7d012472a;

  /// fi: dashboard.airthings.com → Integrations → API → Create client (Client credentials).
  ///
  /// In en, this message translates to:
  /// **'dashboard.airthings.com → Integrations → API → Create client (Client credentials).'**
  String get s94bccb8598;

  /// fi: Client secret
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get sb1a9b21d4f;

  /// fi: Näkyy samassa paikassa kuin Client ID. Pidä se salassa.
  ///
  /// In en, this message translates to:
  /// **'Shown next to the Client ID. Keep it secret.'**
  String get s2403198fe5;

  /// fi: Päivitysväli (min)
  ///
  /// In en, this message translates to:
  /// **'Update interval (min)'**
  String get s21b52207e8;

  /// fi: Mittarit päivittävät arvot 5 minuutin välein; tiheämpi kysely ei tuo uutta tietoa.
  ///
  /// In en, this message translates to:
  /// **'The monitors update every 5 minutes; asking more often brings nothing new.'**
  String get saad5ced5fe;

  /// fi: Sarjanumero
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get sc844e90e0f;

  /// fi: Mittarin sarjanumero (10 numeroa) – täyttyy itse, kun lisäät mittarin listasta.
  ///
  /// In en, this message translates to:
  /// **'The monitor\'\'s serial number (10 digits) – filled in when you add it from the list.'**
  String get s8cee566dd7;

  /// fi: Mittaus
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get s2d79014611;

  /// fi: Mikä mittauksen arvo ruudussa näkyy (radon Bq/m³, CO₂ ppm, VOC ppb, °C, %, hPa, µg/m³, akku %).
  ///
  /// In en, this message translates to:
  /// **'Which measurement the tile shows (radon Bq/m³, CO₂ ppm, VOC ppb, °C, %, hPa, µg/m³, battery %).'**
  String get s852b4e5c75;

  /// fi: Radon (lyhyt keskiarvo)
  ///
  /// In en, this message translates to:
  /// **'Radon (short-term)'**
  String get s6cd83fc216;

  /// fi: Radon (pitkä keskiarvo)
  ///
  /// In en, this message translates to:
  /// **'Radon (long-term)'**
  String get s0c4b6446cd;

  /// fi: VOC
  ///
  /// In en, this message translates to:
  /// **'VOC'**
  String get s96cc1b3741;

  /// fi: Ilmanpaine
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get sf8496cb6dc;

  /// fi: Pienhiukkaset PM2.5
  ///
  /// In en, this message translates to:
  /// **'PM2.5'**
  String get s99e44237af;

  /// fi: Pienhiukkaset PM1
  ///
  /// In en, this message translates to:
  /// **'PM1'**
  String get s951d501a1a;

  /// fi: Airthings Wave (Bluetooth)
  ///
  /// In en, this message translates to:
  /// **'Airthings Wave (Bluetooth)'**
  String get sb6d80b9662;

  /// fi: Mittarin takana tai pohjassa (10 numeroa, esim. 2930xxxxxx).
  ///
  /// In en, this message translates to:
  /// **'On the back or bottom of the monitor (10 digits, e.g. 2930xxxxxx).'**
  String get s83d2446b44;

  /// fi: Z-Wave JS (Z-Wave JS UI)
  ///
  /// In en, this message translates to:
  /// **'Z-Wave JS (Z-Wave JS UI)'**
  String get sfb74e5d7c3;

  /// fi: WebSocket-osoite
  ///
  /// In en, this message translates to:
  /// **'WebSocket URL'**
  String get sd99fdf7d94;

  /// fi: Z-Wave JS UI: Asetukset → Home Assistant → WS Server (portti 3000) päälle.
  ///
  /// In en, this message translates to:
  /// **'Z-Wave JS UI: Settings → Home Assistant → WS Server (port 3000) on.'**
  String get sb58c79788d;

  /// fi: Laite (node)
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get s8c921666e5;

  /// fi: Laitteen numero Z-Wave JS UI:n laitelistassa (ID).
  ///
  /// In en, this message translates to:
  /// **'The device number in the Z-Wave JS UI device list (ID).'**
  String get s11be58bda2;

  /// fi: Command class
  ///
  /// In en, this message translates to:
  /// **'Command class'**
  String get s3c1d88fa83;

  /// fi: Arvon komentoluokka: 37 = kytkin, 38 = himmennin, 49 = anturi, 50 = mittari, 67 = asetusarvo.
  ///
  /// In en, this message translates to:
  /// **'Command class of the value: 37 = switch, 38 = dimmer, 49 = sensor, 50 = meter, 67 = setpoint.'**
  String get s4c3afcaf0d;

  /// fi: Endpoint
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get se51e5f226d;

  /// fi: Monikanavaisen laitteen kanava; yleensä 0.
  ///
  /// In en, this message translates to:
  /// **'Channel of a multi-channel device; usually 0.'**
  String get s04605ae798;

  /// fi: Ominaisuus
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get s106bae7046;

  /// fi: Luettava ominaisuus, esim. currentValue.
  ///
  /// In en, this message translates to:
  /// **'Property to read, e.g. currentValue.'**
  String get s341f9093c6;

  /// fi: Ominaisuuden avain
  ///
  /// In en, this message translates to:
  /// **'Property key'**
  String get sb29bffe780;

  /// fi: Vain osalla arvoista (esim. mittarin tyyppi). Näkyy Z-Wave JS UI:n arvon tiedoissa.
  ///
  /// In en, this message translates to:
  /// **'Only for some values (e.g. meter type). Shown in the value details in Z-Wave JS UI.'**
  String get se0f247676e;

  /// fi: Asetettava ominaisuus, esim. targetValue.
  ///
  /// In en, this message translates to:
  /// **'Property to set, e.g. targetValue.'**
  String get s6a09bb69b3;

  /// fi: Lähetettävä arvo; {{value}} = ruudun arvo (true/false tai numero).
  ///
  /// In en, this message translates to:
  /// **'\'Value to send; {{value}} = the tile value (true/false or a number).\''**
  String get s914c361844;

  /// fi: palvelimeen ei saatu yhteyttä
  ///
  /// In en, this message translates to:
  /// **'server not reachable'**
  String get s60ceb3dcc4;

  /// fi: laitetta
  ///
  /// In en, this message translates to:
  /// **'nodes'**
  String get s6e32a590a2;

  /// fi: Modbus TCP
  ///
  /// In en, this message translates to:
  /// **'Modbus TCP'**
  String get s36fb6ba26f;

  /// fi: Laitteen osoite (unit id)
  ///
  /// In en, this message translates to:
  /// **'Unit id'**
  String get sdc5301b750;

  /// fi: Kehystys
  ///
  /// In en, this message translates to:
  /// **'Framing'**
  String get s666811be3d;

  /// fi: Halpa RS485–wifi/ethernet-muunnin läpinäkyvässä tilassa käyttää RTU-kehyksiä.
  ///
  /// In en, this message translates to:
  /// **'A cheap RS485 to Wi-Fi/Ethernet converter in transparent mode uses RTU frames.'**
  String get s0f2d3b7a42;

  /// fi: Modbus TCP (tavallinen)
  ///
  /// In en, this message translates to:
  /// **'Modbus TCP (normal)'**
  String get s12ca822cd8;

  /// fi: Modbus RTU TCP:n yli (RS485-yhdyskäytävä)
  ///
  /// In en, this message translates to:
  /// **'Modbus RTU over TCP (RS485 gateway)'**
  String get s731c92978b;

  /// fi: Lukuväli vähintään (s)
  ///
  /// In en, this message translates to:
  /// **'Minimum read interval (s)'**
  String get s570f11bec8;

  /// fi: Samaa rekisteriä ei lueta tätä useammin, vaikka laattoja olisi monta.
  ///
  /// In en, this message translates to:
  /// **'The same register is never read more often, however many tiles show it.'**
  String get s13e54dbff1;

  /// fi: Tauko kyselyjen välissä (ms)
  ///
  /// In en, this message translates to:
  /// **'Pause between requests (ms)'**
  String get s95d4c6dd5b;

  /// fi: Odotus yhdistämisen jälkeen (ms)
  ///
  /// In en, this message translates to:
  /// **'Wait after connecting (ms)'**
  String get s77b6667fdb;

  /// fi: Yhdistä peräkkäiset luvut
  ///
  /// In en, this message translates to:
  /// **'Batch adjacent reads'**
  String get sf4b0409574;

  /// fi: Rekistereitä yhdessä luvussa enintään
  ///
  /// In en, this message translates to:
  /// **'Max registers per read'**
  String get sc011aad1a9;

  /// fi: Estotilan tauko alussa (s)
  ///
  /// In en, this message translates to:
  /// **'Lockout pause at first (s)'**
  String get s942a690567;

  /// fi: Kun laite ei vastaa, sitä ei kysytä hetkeen. Tauko kaksinkertaistuu enimmäisarvoon asti.
  ///
  /// In en, this message translates to:
  /// **'When the device does not answer, it is left alone for a while. The pause doubles up to the maximum.'**
  String get s3746551251;

  /// fi: Estotilan tauko enintään (s)
  ///
  /// In en, this message translates to:
  /// **'Lockout pause at most (s)'**
  String get sf71d800450;

  /// fi: Sulje yhteys virheen jälkeen
  ///
  /// In en, this message translates to:
  /// **'Close the connection after an error'**
  String get sbce68f8691;

  /// fi: Kysy uudelleen tyhjän vastauksen jälkeen
  ///
  /// In en, this message translates to:
  /// **'Retry on an empty reply'**
  String get sf96bb0c03d;

  /// fi: Rekisterityyppi
  ///
  /// In en, this message translates to:
  /// **'Register table'**
  String get s943b8b6bf3;

  /// fi: Pitorekisteri (4x)
  ///
  /// In en, this message translates to:
  /// **'Holding register (4x)'**
  String get s8283ed1c89;

  /// fi: Kela (0x)
  ///
  /// In en, this message translates to:
  /// **'Coil (0x)'**
  String get s94cf36d710;

  /// fi: Syöttörekisteri (3x)
  ///
  /// In en, this message translates to:
  /// **'Input register (3x)'**
  String get sfb6d4a8639;

  /// fi: Diskreetti tulo (1x)
  ///
  /// In en, this message translates to:
  /// **'Discrete input (1x)'**
  String get s0bbedf814a;

  /// fi: Osoite (0-pohjainen)
  ///
  /// In en, this message translates to:
  /// **'Address (0-based)'**
  String get sf51ad986eb;

  /// fi: Tietotyyppi
  ///
  /// In en, this message translates to:
  /// **'Data type'**
  String get s601f118ac0;

  /// fi: Sanajärjestys käänteinen (CDAB)
  ///
  /// In en, this message translates to:
  /// **'Swap words (CDAB)'**
  String get sddd62d21b0;

  /// fi: Siirtymä
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get s0a239b832b;

  /// fi: Unit id (tyhjä = yhteyden)
  ///
  /// In en, this message translates to:
  /// **'Unit id (empty = connection)'**
  String get s5f374d3643;

  /// fi: Kirjoitettava
  ///
  /// In en, this message translates to:
  /// **'Write to'**
  String get sef11962984;

  /// fi: Arvo ({{value}} = liukusäädin/kytkin)
  ///
  /// In en, this message translates to:
  /// **'\'Value ({{value}} = slider/toggle)\''**
  String get s779b59ba4b;

  /// fi: ntfy-komentolaite (komennot + tila)
  ///
  /// In en, this message translates to:
  /// **'ntfy command device (commands + state)'**
  String get s30ae7f76e6;

  /// fi: Komentokanava (aihe tai koko osoite)
  ///
  /// In en, this message translates to:
  /// **'Command topic (name or full URL)'**
  String get s6a4516e0fe;

  /// fi: Aihe, jota kotilaite kuuntelee (laitteen oma kanava – ei sinun ilmoituskanavasi). Aiheen nimi on kuin salasana: pidä se
  ///
  /// In en, this message translates to:
  /// **'The topic the home device listens to (the device\'\'s own topic – not your notification topic). The topic name works like a password: keep it long and random.'**
  String get scab58fae92;

  /// fi: Vastauskanava (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Reply topic (optional)'**
  String get s800cd08229;

  /// fi: Jos laite vastaa toiseen aiheeseen (esim. henkilökohtaiseen ilmoitusaiheeseen), kirjoita se tähän. Tyhjä = sama kuin kom
  ///
  /// In en, this message translates to:
  /// **'If the device answers on another topic (e.g. your personal notification topic), type it here. Empty = the command topic.'**
  String get s7e8c7a0cfc;

  /// fi: Tilakanava (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'State topic (optional)'**
  String get sfb1f03903c;

  /// fi: Laitteen tilakanava (esim. paneelin Laite → Etäohjaus → Tilakanava, fw 0.2.51+). Kun asetettu, Molaplan kuuntelee laitte
  ///
  /// In en, this message translates to:
  /// **'The device\'\'s state topic (e.g. the panel\'\'s Device → Remote → State channel, fw 0.2.51+). When set, Molaplan listens for the device\'\'s own state messages and does not poll. No PIN is needed. If a PIN-protected status reply includes state_topic and it differs from the stored value (e.g. after the panel\'\'s \"New channel and key\"), the subscription is updated automatically. If no message arrives on the state topic for over 35 minutes, Molaplan falls back to scheduled status requests.'**
  String get s1acfb0da58;

  /// fi: PIN-koodi (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'PIN code (optional)'**
  String get s7ea9d85150;

  /// fi: Tallennetaan salattuna tähän laitteeseen. Lisätään komentoon mallin {pin}-kohtaan.
  ///
  /// In en, this message translates to:
  /// **'\'Stored encrypted on this device. Inserted where the template says {pin}.\''**
  String get s0694fe4d2b;

  /// fi: Tilan kysely enintään (s)
  ///
  /// In en, this message translates to:
  /// **'Ask the state at most every (s)'**
  String get s63971a3ad4;

  /// fi: Automaattinen tilakysely korkeintaan näin usein (kaikki laitteet yhteensä käyttävät viimeisintä vastausta). Jokainen kys
  ///
  /// In en, this message translates to:
  /// **'Automatic status request at most this often (all devices reuse the latest reply). Each request is two messages; ntfy.sh allows 250 messages / 12 h for the whole home network. Presses and commands ask at once.'**
  String get scf38de4909;

  /// fi: Komennon malli
  ///
  /// In en, this message translates to:
  /// **'Command template'**
  String get s4313c720cc;

  /// fi: {cmd} = painikkeen komento, {pin} = PIN, {cid} = tunniste jonka laite toistaa vastauksessa, {value} = arvo (on/off tai l
  ///
  /// In en, this message translates to:
  /// **'\'{cmd} = the button\'\'s command, {pin} = PIN, {cid} = an id the device echoes in its reply, {value} = the value (on/off or a number). E.g. \"{cmd} {pin}\" → \"light on 1234\".\''**
  String get sd904dac1cc;

  /// fi: Tilakomento
  ///
  /// In en, this message translates to:
  /// **'Status command'**
  String get sa45b65f571;

  /// fi: Komento, johon laite vastaa tilallaan (esim. "tila" tai "tila json"). Kaikki tämän laitteen ruudut käyttävät samaa vasta
  ///
  /// In en, this message translates to:
  /// **'The command the device answers with its state (e.g. \"status\" or \"status json\"). All tiles of this device share the reply.'**
  String get se464d5ed51;

  /// fi: Vastauksen otsikko sisältää (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Reply title contains (optional)'**
  String get s821e8d2d9d;

  /// fi: Vain viestit, joiden otsikossa on tämä teksti, lasketaan vastaukseksi – hyödyllinen, kun vastauskanavalla on muitakin il
  ///
  /// In en, this message translates to:
  /// **'Only messages whose title contains this text count as the reply – useful when the reply topic carries other notifications too.'**
  String get s949ee12ae6;

  /// fi: Vastauksen tunniste (regex, vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Reply must contain (regex, optional)'**
  String get sfbcb5f18bd;

  /// fi: Säännöllinen lauseke, joka vastauksessa pitää olla (otsikko + viesti).
  ///
  /// In en, this message translates to:
  /// **'A regular expression the reply (title + message) must contain.'**
  String get s79c983aa94;

  /// fi: Tekstin tulkinta tiloiksi
  ///
  /// In en, this message translates to:
  /// **'Text to state map'**
  String get s081eff543d;

  /// fi: Rivi per sääntö: "kuvio = arvo". Kuvio on regex, jonka pitää vastata koko luettua tekstiä (kirjainkoolla ei väliä). Tyhj
  ///
  /// In en, this message translates to:
  /// **'One rule per line: \"pattern = value\". The pattern is a regex matching the whole captured text (case-insensitive). Empty = built-in Finnish and English on/off words.'**
  String get s2afc1f1fb8;

  /// fi: Virhevastaus (regex)
  ///
  /// In en, this message translates to:
  /// **'Error reply (regex)'**
  String get s0976f767e2;

  /// fi: Vastaus, joka tarkoittaa virhettä (näytetään punaisena). Tyhjä = oletus (väärä PIN, virhe, error, denied…). JSON-vastauk
  ///
  /// In en, this message translates to:
  /// **'A reply meaning an error (shown in red). Empty = default (wrong PIN, error, denied…). For JSON: ok:false or an error field.'**
  String get sc0fd47e896;

  /// fi: Komentojen väli vähintään (s)
  ///
  /// In en, this message translates to:
  /// **'Minimum time between commands (s)'**
  String get s98d9efa888;

  /// fi: Jos laite vastaa vain esim. 30 sekunnin välein, kirjoita 30: seuraava komento odottaa vuoroaan eikä huku.
  ///
  /// In en, this message translates to:
  /// **'If the device answers only e.g. every 30 seconds, type 30: the next command waits its turn instead of being lost.'**
  String get sa893722568;

  /// fi: Vastauksen odotus (s)
  ///
  /// In en, this message translates to:
  /// **'Wait for reply (s)'**
  String get sbdcbe301b9;

  /// fi: Kuinka kauan vastausta odotetaan ennen virheilmoitusta.
  ///
  /// In en, this message translates to:
  /// **'How long to wait for the reply before showing an error.'**
  String get s5e8e483f10;

  /// fi: Tilavastaus voimassa (s)
  ///
  /// In en, this message translates to:
  /// **'Status reply valid for (s)'**
  String get s31312f141c;

  /// fi: Saman laitteen ruudut käyttävät samaa tilavastausta tämän ajan – laitetta ei kysytä turhaan.
  ///
  /// In en, this message translates to:
  /// **'Tiles of the same device share one status reply for this long – the device is not asked needlessly.'**
  String get s0611790300;

  /// fi: Käyttöoikeustunnus (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Access token (optional)'**
  String get s5bc736c04a;

  /// fi: Vain suojatulle aiheelle (ntfy-tili → Access tokens).
  ///
  /// In en, this message translates to:
  /// **'Only for a protected topic (ntfy account → Access tokens).'**
  String get scece580659;

  /// fi: Oletus on julkinen ntfy.sh. Jos liitit yllä koko osoitteen, palvelin luetaan siitä.
  ///
  /// In en, this message translates to:
  /// **'Default is the public ntfy.sh. A full URL above overrides this.'**
  String get s7e91b10006;

  /// fi: JSON-polku (JSON-vastaus)
  ///
  /// In en, this message translates to:
  /// **'JSON path (JSON reply)'**
  String get s1b5501c73f;

  /// fi: Kun laite vastaa JSONilla, esim. $.pihavalo tai $.lahdot.sireeni.
  ///
  /// In en, this message translates to:
  /// **'When the device answers with JSON, e.g. \$.light or \$.outputs.siren.'**
  String get s1320bcddf2;

  /// fi: Tekstistä (regex, ryhmä 1)
  ///
  /// In en, this message translates to:
  /// **'From text (regex, group 1)'**
  String get s4dc975c1cd;

  /// fi: Kun vastaus on tekstiä: säännöllinen lauseke, jonka ensimmäinen sulkuryhmä on tila, esim. pihavalo:\s*(\S+).
  ///
  /// In en, this message translates to:
  /// **'For a text reply: a regular expression whose first group is the state, e.g. light:\\s*(\\S+).'**
  String get s21c23314ed;

  /// fi: Tilakomento tälle ruudulle (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Status command for this tile (optional)'**
  String get s63a305f2ab;

  /// fi: Tyhjä = laitteen tilakomento.
  ///
  /// In en, this message translates to:
  /// **'Empty = the device\'\'s status command.'**
  String get s89ad1c43b4;

  /// fi: Esim. "pihavalo on". PIN ja muut kohdat lisätään laitteen komentomallin mukaan.
  ///
  /// In en, this message translates to:
  /// **'E.g. \"light on\". The PIN and other parts are added by the device\'\'s command template.'**
  String get sec7af7b376;

  /// fi: Odota vastausta
  ///
  /// In en, this message translates to:
  /// **'Wait for the reply'**
  String get sfee393b70e;

  /// fi: Näyttää laitteen vastauksen (tai selkeän virheen) ruudussa.
  ///
  /// In en, this message translates to:
  /// **'Shows the device\'\'s reply (or a clear error) on the tile.'**
  String get s3f4dda1fb9;

  /// fi: Vastaus näkyy ruudussa (s)
  ///
  /// In en, this message translates to:
  /// **'Reply stays on the tile (s)'**
  String get sa53638cfea;

  /// fi: Kuinka kauan vastaus näkyy ruudussa. 0 = kunnes painat uudelleen.
  ///
  /// In en, this message translates to:
  /// **'How long the reply stays on the tile. 0 = until the next press.'**
  String get se6d21484a8;

  /// fi: ntfy: komento puuttuu
  ///
  /// In en, this message translates to:
  /// **'ntfy: command missing'**
  String get sb56e7e9f81;

  /// fi: Komento lähti, mutta laite ei vastannut {p0} s:ssa – onko laite verkossa? Tarkista myös PIN-koodi: moni laite ei vastaa
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but the device did not answer within {p0} s – is the device online? Also check the PIN: many devices do not answer a wrong PIN at all (topic \"{p1}\").'**
  String s02e16b2c5c(String p0, String p1);

  /// fi: Komento lähti, mutta laite ei vastannut {p0} s:ssa – onko laite verkossa? Jos laite vastaa vain tietyin väliajoin, kasva
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but the device did not answer within {p0} s – is the device online? If it answers only at intervals, increase \"Minimum time between commands\" (topic \"{p1}\").'**
  String sdf4ecde616(String p0, String p1);

  /// fi: Komento lähti, mutta tilaa ei tullut {p0} s:ssa tilakanavalle eikä vastauskanavalle.
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but no state arrived on the state or reply topic within {p0} s.'**
  String s9e974e06df(String p0);

  /// fi: Laite vastasi: {p0}
  ///
  /// In en, this message translates to:
  /// **'The device answered: {p0}'**
  String s1257447096(String p0);

  /// fi: Jos laite vastaa toiselle kanavalle (esim. ilmoituskanavallesi), aseta se kohtaan "Vastauskanava".
  ///
  /// In en, this message translates to:
  /// **'If the device replies on another topic (e.g. your notification topic), set it as \"Reply topic\".'**
  String get sc112a20bf5;

  /// fi: Tilakanavaa kuunnellaan, mutta tilaa ei ole vielä tullut.
  ///
  /// In en, this message translates to:
  /// **'The state topic is being listened to, but no state has arrived yet.'**
  String get sb9873b4f15;

  /// fi:  PIN on tallennettu.
  ///
  /// In en, this message translates to:
  /// **' A PIN is stored.'**
  String get sf03877dd0a;

  /// fi:  Tilakanavaa kuunnellaan.
  ///
  /// In en, this message translates to:
  /// **' The state topic is being listened to.'**
  String get s91089c4d9f;

  /// fi: Laite ei ole lähettänyt tilaa yli tuntiin – onko laite verkossa?
  ///
  /// In en, this message translates to:
  /// **'The device has not sent state in over an hour – is the device online?'**
  String get sab4a606e33;

  /// fi: Komento lähti, mutta laite ei vastannut ajoissa – onko laite verkossa? (ntfy-palvelin toimii.)
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but the device did not answer in time – is the device online? (The ntfy server works.)'**
  String get s33cfb86f9f;

  /// fi: ei sallittu päivällä (day_blocked) – valo ohjautuu päivänvalon mukaan
  ///
  /// In en, this message translates to:
  /// **'not allowed in daylight (day_blocked) – the light follows daylight'**
  String get s7087533324;

  /// fi: väärä PIN-koodi ({p0})
  ///
  /// In en, this message translates to:
  /// **'wrong PIN ({p0})'**
  String sf3066f08eb(String p0);

  /// fi: liian monta komentoa – odota hetki ({p0})
  ///
  /// In en, this message translates to:
  /// **'too many commands – wait a moment ({p0})'**
  String s14fac6d719(String p0);

  /// fi: Kamera (MJPEG / JPEG / RTSP)
  ///
  /// In en, this message translates to:
  /// **'Camera (MJPEG / JPEG / RTSP)'**
  String get s58648dc3fc;

  /// fi: Kameran osoite
  ///
  /// In en, this message translates to:
  /// **'Camera base URL'**
  String get s1534821f4a;

  /// fi: RTSP-osoite (live-kuva kotiverkossa)
  ///
  /// In en, this message translates to:
  /// **'RTSP address (live video at home)'**
  String get s95533426a3;

  /// fi: RTSP-osoite, kevyt (ruutu)
  ///
  /// In en, this message translates to:
  /// **'RTSP address, light (tile)'**
  String get sa1115d4b0b;

  /// fi: Tila
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get se995a6862d;

  /// fi: Liikkuva kuva (MJPEG)
  ///
  /// In en, this message translates to:
  /// **'Live (MJPEG)'**
  String get s7cf6da2822;

  /// fi: Still-kuva välein
  ///
  /// In en, this message translates to:
  /// **'Snapshots'**
  String get s4cb8ad767b;

  /// fi: RTSP-video
  ///
  /// In en, this message translates to:
  /// **'RTSP video'**
  String get s15f9cd477c;

  /// fi: Kuvan päivitysväli (s, snapshot)
  ///
  /// In en, this message translates to:
  /// **'Refresh (s, snapshot)'**
  String get s4f356d158a;

  /// fi: ntfy (viestikanava / komennot)
  ///
  /// In en, this message translates to:
  /// **'ntfy (message channel / commands)'**
  String get sefaea1b818;

  /// fi: Aihe, johon komennot lähetetään. Voit liittää koko osoitteen, esim. https://ntfy.sh/oma-aihe – sama osoite jota iPhonen
  ///
  /// In en, this message translates to:
  /// **'Topic the commands are sent to. You can paste the full URL, e.g. https://ntfy.sh/my-topic – the same one your iPhone Shortcut uses. The topic name works like a password: keep it long and random.'**
  String get se003ecc10b;

  /// fi: Jos kotilaite vastaa eri aiheeseen, kirjoita se tähän. Jätä tyhjäksi, jos vastaus tulee samaan aiheeseen – silloin oma l
  ///
  /// In en, this message translates to:
  /// **'If the home device replies on another topic, type it here. Leave empty if the reply comes on the same topic – our own command is then ignored and the next message is shown as the reply.'**
  String get s2e3a66d384;

  /// fi: Tarvitaan vain, jos aihe on suojattu (ntfy-tili → Access tokens). Julkiseen aiheeseen jätä tyhjäksi.
  ///
  /// In en, this message translates to:
  /// **'Only needed for a protected topic (ntfy account → Access tokens). Leave empty for a public topic.'**
  String get s77feae14f5;

  /// fi: Oletus on julkinen ntfy.sh. Vaihda vain, jos käytät omaa ntfy-palvelinta. Jos liitit yllä koko osoitteen, palvelin lueta
  ///
  /// In en, this message translates to:
  /// **'Default is the public ntfy.sh. Change only for your own ntfy server. A full URL above overrides this.'**
  String get seca0d75969;

  /// fi: latest = viimeisin viesti, log = useita viimeisimpiä viestejä allekkain (uusin ylimpänä).
  ///
  /// In en, this message translates to:
  /// **'latest = the newest message, log = several recent messages (newest first).'**
  String get sddbea594a4;

  /// fi: Viimeisin viesti
  ///
  /// In en, this message translates to:
  /// **'Latest message'**
  String get s580abde883;

  /// fi: Viestiloki
  ///
  /// In en, this message translates to:
  /// **'Message log'**
  String get sf6455b6631;

  /// fi: Aihe (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Topic (optional)'**
  String get s2bd0e69d44;

  /// fi: Mistä aiheesta viestit luetaan. Tyhjä = yhteyden vastauskanava (tai komentokanava, jos vastauskanavaa ei ole).
  ///
  /// In en, this message translates to:
  /// **'Topic to read. Empty = the connection\'\'s reply topic (or the command topic).'**
  String get s4eb1e8ac15;

  /// fi: Viestien määrä (log)
  ///
  /// In en, this message translates to:
  /// **'Number of messages (log)'**
  String get s09fa5c0332;

  /// fi: Montako viimeisintä viestiä näytetään log-tilassa.
  ///
  /// In en, this message translates to:
  /// **'How many recent messages the log shows.'**
  String get s17fda9fb06;

  /// fi: Kuinka kaukaa
  ///
  /// In en, this message translates to:
  /// **'How far back'**
  String get s78f2f0d783;

  /// fi: Esim. 30m, 12h tai 2d. Julkinen ntfy.sh säilyttää viestejä noin 12 tuntia.
  ///
  /// In en, this message translates to:
  /// **'E.g. 30m, 12h or 2d. The public ntfy.sh keeps messages for about 12 hours.'**
  String get s79bdbfd820;

  /// fi: Komento (lähetettävä teksti)
  ///
  /// In en, this message translates to:
  /// **'Command (text to send)'**
  String get sfe357edcec;

  /// fi: Teksti joka lähetetään, esim. "päivitä". Jos PIN kysytään, se lisätään perään välilyönnillä: "päivitä 1234".
  ///
  /// In en, this message translates to:
  /// **'The text to send, e.g. \"update\". With a PIN it is appended after a space: \"update 1234\".'**
  String get s48e102023d;

  /// fi: Kysy PIN painettaessa
  ///
  /// In en, this message translates to:
  /// **'Ask for a PIN on press'**
  String get saf2ebedf61;

  /// fi: Kysyy PIN-koodin (piilotettuna) joka painalluksella ja lisää sen komennon perään. PIN-koodia ei tallenneta, ellet itse v
  ///
  /// In en, this message translates to:
  /// **'Asks for a PIN (hidden) on every press and appends it to the command. The PIN is not stored unless you choose \"Remember on this device\".'**
  String get sfcb5608064;

  /// fi: Kuuntelee kotilaitteen vastausta ja näyttää sen tässä ruudussa (ja ilmoituksena, jos sovellus on taustalla).
  ///
  /// In en, this message translates to:
  /// **'Listens for the home device\'\'s reply and shows it in this tile (and as a notification when the app is in the background).'**
  String get sfff5bc52e5;

  /// fi: Kuinka kauan vastausta odotetaan, ennen kuin kerrotaan ettei vastausta tullut.
  ///
  /// In en, this message translates to:
  /// **'How long to wait before saying that no reply came.'**
  String get s121542d6d7;

  /// fi: Viestin otsikko (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Message title (optional)'**
  String get s74d68a98d6;

  /// fi: ntfy-viestin otsikko. Yleensä tyhjä – jätä tyhjäksi, ellei kotilaite sitä vaadi.
  ///
  /// In en, this message translates to:
  /// **'ntfy message title. Usually empty.'**
  String get sc2492ac3ab;

  /// fi: ntfy: aihe "{p0}" on suojattu (HTTP {p1}). Lisää käyttöoikeustunnus (tk_…) yhteyden asetuksiin.
  ///
  /// In en, this message translates to:
  /// **'ntfy: topic \"{p0}\" is protected (HTTP {p1}). Add an access token (tk_…) to the connection.'**
  String s54ea45f27f(String p0, String p1);

  /// fi: ntfy: komentokanava puuttuu
  ///
  /// In en, this message translates to:
  /// **'ntfy: command topic missing'**
  String get s0870daf796;

  /// fi: Komento lähetettiin, mutta vastausta ei tullut {p0} sekunnissa. Tarkista, että kotilaite on päällä ja kuuntelee aihetta
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but no reply came within {p0} s. Check that the home device is on and listens to \"{p1}\".'**
  String sa4313864fe(String p0, String p1);

  /// fi: ntfy: yhteys katkesi ennen vastausta
  ///
  /// In en, this message translates to:
  /// **'ntfy: connection closed before the reply'**
  String get s28dc7ea012;

  /// fi: (ei viestejä)
  ///
  /// In en, this message translates to:
  /// **'(no messages)'**
  String get s85a1947a44;

  /// fi: ntfy: komennon teksti puuttuu
  ///
  /// In en, this message translates to:
  /// **'ntfy: command text missing'**
  String get s7069b18b7d;

  /// fi:  Vastauskanava: {p0}.
  ///
  /// In en, this message translates to:
  /// **' Reply topic: {p0}.'**
  String s43de3fd299(String p0);

  /// fi: ✓ ntfy-palvelin {p0} vastasi ja aihe "{p1}" on luettavissa ({p2} viestiä viimeisen tunnin aikana).{p3} Testi ei lähettän
  ///
  /// In en, this message translates to:
  /// **'✓ ntfy server {p0} answered and topic \"{p1}\" is readable ({p2} messages in the last hour).{p3} No command was sent – tap the tile to try.'**
  String s9ed9eb7f92(String p0, String p1, String p2, String p3);

  /// fi: ntfy: viestiraja täynnä (HTTP 429). Palvelin ei ota vastaan enempää viestejä tästä verkosta (ntfy.sh: 250 viestiä / 12 h
  ///
  /// In en, this message translates to:
  /// **'\'ntfy: message limit reached (HTTP 429). The server takes no more messages from this network (ntfy.sh: 250 messages / 12 h for all devices behind the same public IP, the device\'\'s own replies too). New messages free up every few minutes\'\'}.\''**
  String sb9c91fd519(String p0);

  /// fi: Home Assistant
  ///
  /// In en, this message translates to:
  /// **'Home Assistant'**
  String get sf0ef0140c3;

  /// fi: Osoite
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get sfcbb753f53;

  /// fi: Pitkäikäinen käyttöoikeustunnus
  ///
  /// In en, this message translates to:
  /// **'Long-lived access token'**
  String get s1f90ee6992;

  /// fi: Reaaliaikaiset päivitykset (websocket)
  ///
  /// In en, this message translates to:
  /// **'Live updates (websocket)'**
  String get sccb0cca8e3;

  /// fi: Entiteetti
  ///
  /// In en, this message translates to:
  /// **'Entity id'**
  String get s8f8e1cfad3;

  /// fi: Attribuutti (tyhjä = tila)
  ///
  /// In en, this message translates to:
  /// **'Attribute (empty = state)'**
  String get s382111aebc;

  /// fi: Palvelu
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get sf500d0ad67;

  /// fi: Lisädata JSON ({{value}} = arvo)
  ///
  /// In en, this message translates to:
  /// **'\'Extra data JSON ({{value}} = value)\''**
  String get s7286715019;

  /// fi: puhallin {p0}
  ///
  /// In en, this message translates to:
  /// **'fan {p0}'**
  String s91c3d72d1e(String p0);

  /// fi: , suuntaus
  ///
  /// In en, this message translates to:
  /// **', swing'**
  String get s40032ddea9;

  /// fi: , siivekkeet {p0}
  ///
  /// In en, this message translates to:
  /// **', vane '**
  String s7dcc5e6c76(String p0);

  /// fi: ei vielä lähetetty
  ///
  /// In en, this message translates to:
  /// **'not sent yet'**
  String get s7c815852f2;

  /// fi: lähetetty klo {p0}
  ///
  /// In en, this message translates to:
  /// **'sent at {p0}'**
  String s4795d331a5(String p0);

  /// fi: lähetetty {p0}.{p1}. klo {p2}
  ///
  /// In en, this message translates to:
  /// **'sent {p0}.{p1}. at {p2}'**
  String sff577ce033(String p0, String p1, String p2);

  /// fi: Koodia ei tunnistettu eikä raakadataa tullut. Ota Tasmotassa käyttöön raakadata (SetOption58 1) ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Unknown code without raw data. Enable raw data in Tasmota (SetOption58 1) and try again.'**
  String get s7068e8892e;

  /// fi: IR-lähetin (ilmalämpöpumppu)
  ///
  /// In en, this message translates to:
  /// **'IR blaster (heat pump)'**
  String get s6207a45bff;

  /// fi: Lähettimen ohjelmisto
  ///
  /// In en, this message translates to:
  /// **'Blaster firmware'**
  String get s859c2e7734;

  /// fi: tasmota_http = Tasmota (tasmota-ir) suoraan IP-osoitteella. tasmota_mqtt = Tasmota MQTT-välittäjän kautta. esphome = ESP
  ///
  /// In en, this message translates to:
  /// **'tasmota_http = Tasmota (tasmota-ir) by IP. tasmota_mqtt = Tasmota via an MQTT broker. esphome = ESPHome climate_ir. http/mqtt = other blaster with your own templates.'**
  String get s3f8d3fb444;

  /// fi: Tasmota (HTTP)
  ///
  /// In en, this message translates to:
  /// **'Tasmota (HTTP)'**
  String get s4fb133b1c8;

  /// fi: Tasmota (MQTT)
  ///
  /// In en, this message translates to:
  /// **'Tasmota (MQTT)'**
  String get sdd5d31034c;

  /// fi: ESPHome
  ///
  /// In en, this message translates to:
  /// **'ESPHome'**
  String get see30b7398b;

  /// fi: Oma HTTP
  ///
  /// In en, this message translates to:
  /// **'Custom HTTP'**
  String get scb2d23e10b;

  /// fi: Oma MQTT
  ///
  /// In en, this message translates to:
  /// **'Custom MQTT'**
  String get s5c6c30aac6;

  /// fi: Lähettimen osoite
  ///
  /// In en, this message translates to:
  /// **'Blaster address'**
  String get s38471ae691;

  /// fi: IR-lähettimen IP-osoite (Tasmota tai ESPHome). Löytyy reitittimen laitelistasta.
  ///
  /// In en, this message translates to:
  /// **'IP address of the IR blaster (Tasmota or ESPHome).'**
  String get sda91fafa54;

  /// fi: Merkin IR-protokolla
  ///
  /// In en, this message translates to:
  /// **'Brand IR protocol'**
  String get sf9220a3e4d;

  /// fi: Tasmotan IRhvac-valmistajanimi, esim. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. Jos laite ei reagoi, kokeile saman merkin toi
  ///
  /// In en, this message translates to:
  /// **'Tasmota IRhvac vendor, e.g. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. If nothing happens, try another protocol of the same brand.'**
  String get s423f2576c4;

  /// fi: Malli (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Model (optional)'**
  String get s74ff2fd8a8;

  /// fi: IRhvac Model -numero joillekin merkeille (esim. Panasonic). Jätä tyhjäksi, jos et tiedä.
  ///
  /// In en, this message translates to:
  /// **'IRhvac Model number for some brands. Leave empty if unsure.'**
  String get sef4c0e5d90;

  /// fi: Tasmotan aihe (topic)
  ///
  /// In en, this message translates to:
  /// **'Tasmota topic'**
  String get s8e7962c184;

  /// fi: Vain MQTT: Tasmotan asetuksista (Configuration → MQTT → Topic). Komennot menevät aiheeseen cmnd/<aihe>/IRhvac.
  ///
  /// In en, this message translates to:
  /// **'MQTT only: from Tasmota (Configuration → MQTT → Topic).'**
  String get s5ae4cc50db;

  /// fi: MQTT-välittäjän osoite
  ///
  /// In en, this message translates to:
  /// **'MQTT broker address'**
  String get sed30580f59;

  /// fi: Vain MQTT: kone, jolla Mosquitto pyörii (usein Home Assistant -kone).
  ///
  /// In en, this message translates to:
  /// **'MQTT only: the machine running the broker.'**
  String get s744ce256bb;

  /// fi: MQTT-portti
  ///
  /// In en, this message translates to:
  /// **'MQTT port'**
  String get se6754df705;

  /// fi: Tunnus
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get sbfc8ee6c86;

  /// fi: MQTT-tunnus tai Tasmotan web-tunnus (admin).
  ///
  /// In en, this message translates to:
  /// **'MQTT or web user.'**
  String get s711670d91a;

  /// fi: Jätä tyhjäksi, jos ei tarvita.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if not needed.'**
  String get s3bbd70773d;

  /// fi: ESPHome-ilmastoinnin tunnus
  ///
  /// In en, this message translates to:
  /// **'ESPHome climate id'**
  String get s443fe6f350;

  /// fi: Vain ESPHome: climate-entiteetin nimi pienillä kirjaimilla ja alaviivoilla (esim. "Ilmalämpöpumppu" → ilmalampopumppu).
  ///
  /// In en, this message translates to:
  /// **'ESPHome only: the climate object id.'**
  String get s62feae1a9f;

  /// fi: Komennon osoite (muu lähetin)
  ///
  /// In en, this message translates to:
  /// **'Command URL (other blaster)'**
  String get se0efd6dfb3;

  /// fi: Vain http: osoite, johon koko tila lähetetään. Paikkamerkit: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{
  ///
  /// In en, this message translates to:
  /// **'http only: URL that receives the full state. Placeholders as listed.'**
  String get s5366cbd4df;

  /// fi: Viestin pohja (muu lähetin)
  ///
  /// In en, this message translates to:
  /// **'Payload template (other blaster)'**
  String get sce533db7c1;

  /// fi: http (POST-runko) tai mqtt (viesti). Tyhjä = IRhvac-JSON ({{json}}).
  ///
  /// In en, this message translates to:
  /// **'\'http body or mqtt payload. Empty = IRhvac JSON ({{json}}).\''**
  String get s0fa691e7c7;

  /// fi: Mitä näytetään
  ///
  /// In en, this message translates to:
  /// **'What to show'**
  String get s271885dc8b;

  /// fi: summary = koko tila tekstinä. room = lähettimen lämpöanturi (jos on). Muut = viimeksi lähetetty asetus.
  ///
  /// In en, this message translates to:
  /// **'summary = full state as text. room = the blaster\'\'s temperature sensor. Others = last sent setting.'**
  String get s8567c5faa6;

  /// fi: Yhteenveto
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get s5d329a0fea;

  /// fi: Asetuslämpö
  ///
  /// In en, this message translates to:
  /// **'Set temperature'**
  String get s5db6506824;

  /// fi: Siivekkeet
  ///
  /// In en, this message translates to:
  /// **'Vane'**
  String get sa00d64c920;

  /// fi: Lähetysaika
  ///
  /// In en, this message translates to:
  /// **'Sent at'**
  String get s39f8bf0f76;

  /// fi: Mitä muutetaan
  ///
  /// In en, this message translates to:
  /// **'What to change'**
  String get sdd8cd8132c;

  /// fi: Koko tila lähetetään aina kerralla (IR toimii niin). Arvo tulee ruudusta tai kentästä "Arvo".
  ///
  /// In en, this message translates to:
  /// **'The whole state is always sent at once. The value comes from the tile or \"Value\".'**
  String get s2e8b846390;

  /// fi: Esim. heat, cool, auto, dry, fan (tila) tai on/off. Tyhjä = ruudun arvo.
  ///
  /// In en, this message translates to:
  /// **'E.g. heat, cool, auto, dry, fan or on/off. Empty = tile value.'**
  String get sb517d97868;

  /// fi: Opeteltu koodi
  ///
  /// In en, this message translates to:
  /// **'Learned code'**
  String get sda4a1b2eee;

  /// fi: Täyttyy itse, kun tallennat opetellun kaukosäätimen napin. Lähetetään Tasmotan IRsend-komennolla.
  ///
  /// In en, this message translates to:
  /// **'Filled when you save a learned remote button. Sent with Tasmota IRsend.'**
  String get s0cfc723aa2;

  /// fi: ESPHome-painike
  ///
  /// In en, this message translates to:
  /// **'ESPHome button'**
  String get s3f26cb7602;

  /// fi: Vain ESPHome: painikkeen tunnus, jonka teit opetellulle koodille.
  ///
  /// In en, this message translates to:
  /// **'ESPHome only: id of the template button for a learned code.'**
  String get sc71964f422;

  /// fi: Lähettimen osoite puuttuu.
  ///
  /// In en, this message translates to:
  /// **'Blaster address missing.'**
  String get s852a166240;

  /// fi: Tasmota pyytää salasanaa – lisää web-salasana yhteyden asetuksiin.
  ///
  /// In en, this message translates to:
  /// **'Tasmota needs the web password.'**
  String get s75ce01c354;

  /// fi: Tasmota ei tunne komentoa {p0}. Asenna lähettimeen tasmota-ir-versio (sisältää ilmalämpöpumppujen protokollat).
  ///
  /// In en, this message translates to:
  /// **'Tasmota does not know {p0}. Install the tasmota-ir build.'**
  String sf9d84ad23c(String p0);

  /// fi: Tasmota hylkäsi komennon: {p0}
  ///
  /// In en, this message translates to:
  /// **'Tasmota rejected the command: {p0}'**
  String sff167aa9a6(String p0);

  /// fi: Tasmota ei tunne merkin protokollaa "{p0}". Valitse toinen merkki/protokolla.
  ///
  /// In en, this message translates to:
  /// **'Unknown vendor \"{p0}\".'**
  String s385c6a9a2d(String p0);

  /// fi: ESPHome ei löytänyt ilmastointia "{p0}". Tarkista tunnus (web_server-sivulta).
  ///
  /// In en, this message translates to:
  /// **'ESPHome climate \"{p0}\" not found.'**
  String sb4ea2389cb(String p0);

  /// fi: Komennon osoite puuttuu.
  ///
  /// In en, this message translates to:
  /// **'Command URL missing.'**
  String get s34deda2c72;

  /// fi: Lämpötila puuttuu.
  ///
  /// In en, this message translates to:
  /// **'Temperature missing.'**
  String get s04e4777aea;

  /// fi: huone {p0} °C
  ///
  /// In en, this message translates to:
  /// **'room {p0} °C'**
  String s91e5fff1f0(String p0);

  /// fi: Lähettimessä ei ole lämpöanturia (Status 8 ei kertonut lämpötilaa).
  ///
  /// In en, this message translates to:
  /// **'No temperature sensor on the blaster.'**
  String get sfce1a094cb;

  /// fi: Lämpötilaa ei tullut (tele/{p0}/SENSOR).
  ///
  /// In en, this message translates to:
  /// **'No temperature received.'**
  String s4536eb33dd(String p0);

  /// fi: Huonelämpö vain Tasmota/ESPHome-lähettimistä.
  ///
  /// In en, this message translates to:
  /// **'Room temperature only from Tasmota/ESPHome.'**
  String get s9b5bbfa2c6;

  /// fi: RF433-koodeja voi lähettää vain Tasmotalla.
  ///
  /// In en, this message translates to:
  /// **'RF433 needs Tasmota.'**
  String get s5acc16dafb;

  /// fi: Opeteltuja koodeja voi lähettää vain Tasmotalla.
  ///
  /// In en, this message translates to:
  /// **'Learned codes need Tasmota.'**
  String get s8478662ad1;

  /// fi: ESPHome-painiketta "{p0}" ei löytynyt (HTTP {p1}).
  ///
  /// In en, this message translates to:
  /// **'ESPHome button \"{p0}\" not found.'**
  String s9f8263b5a0(String p0, String p1);

  /// fi: Koodia ei tullut {p0} sekunnissa. Osoita kaukosäätimellä suoraan lähettimeen (alle 1 m) ja paina nappia uudelleen. Tarki
  ///
  /// In en, this message translates to:
  /// **'No code within {p0} s. Point the remote straight at the blaster (under 1 m) and press again.'**
  String s3296e8d7e7(String p0);

  /// fi: RF433-opettelu toimii Tasmotalla.
  ///
  /// In en, this message translates to:
  /// **'RF433 learning needs Tasmota.'**
  String get s1e73ba395d;

  /// fi: Opettelu toimii Tasmota- ja ESPHome-lähettimillä.
  ///
  /// In en, this message translates to:
  /// **'Learning works with Tasmota and ESPHome blasters.'**
  String get scc47b4b225;

  /// fi: ✓ Tasmota vastasi (versio {p0}). Testattiin: Status 0 osoitteessa {p1}. {p2} Lämpöpumpulle ei lähetetty mitään.
  ///
  /// In en, this message translates to:
  /// **'✓ Tasmota answered (version {p0}). Tested: Status 0 at {p1}. Nothing was sent to the heat pump.'**
  String s96adaaf2b6(String p0, String p1, String p2);

  /// fi: MQTT-välittäjä toimii, mutta Tasmota "{p0}" ei vastannut. Tarkista aihe.
  ///
  /// In en, this message translates to:
  /// **'Broker OK but Tasmota \"{p0}\" did not answer.'**
  String sfce5c770f1(String p0);

  /// fi: ✓ Tasmota "{p0}" vastasi MQTT:n kautta. Lämpöpumpulle ei lähetetty mitään.
  ///
  /// In en, this message translates to:
  /// **'✓ Tasmota \"{p0}\" answered via MQTT. Nothing sent to the heat pump.'**
  String s2c3b95a054(String p0);

  /// fi: ✓ ESPHome-ilmastointi "{p0}" löytyi (tila {p1}). Testattiin: GET {p2}/climate/{p3}. Mitään ei lähetetty.
  ///
  /// In en, this message translates to:
  /// **'✓ ESPHome climate \"{p0}\" found. Nothing was sent.'**
  String scf9ead3297(String p0, String p1, String p2, String p3);

  /// fi: Muulle lähettimelle ei ole testiä: IR on yksisuuntainen. Paina virtaruutua ja katso, reagoiko lämpöpumppu.
  ///
  /// In en, this message translates to:
  /// **'No test for other blasters: IR is one-way. Press the power tile and watch the heat pump.'**
  String get s8ad50358b9;

  /// fi: Laite vastasi HTTP {p0}. Onko ESPHome-asetuksissa web_server päällä?
  ///
  /// In en, this message translates to:
  /// **'Device answered HTTP {p0}. Is web_server enabled in ESPHome?'**
  String s3b476099a2(String p0);

  /// fi: Laite ei vastannut osoitteessa {p0}.
  ///
  /// In en, this message translates to:
  /// **'No answer from {p0}.'**
  String sd44aec7380(String p0);

  /// fi: Laitetta ei tavoitettu osoitteessa {p0}. Tarkista IP-osoite.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {p0}.'**
  String s120026628c(String p0);

  /// fi: Automaatti
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get s43c9b88580;

  /// fi: automaatti
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get sd3cd4220ae;

  /// fi: ylös
  ///
  /// In en, this message translates to:
  /// **'highest'**
  String get s640687fc2d;

  /// fi: ylhäälle
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get s3516ee9f50;

  /// fi: keskelle
  ///
  /// In en, this message translates to:
  /// **'middle'**
  String get sb847c3774e;

  /// fi: alhaalle
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get sc4ebe5627c;

  /// fi: alas
  ///
  /// In en, this message translates to:
  /// **'lowest'**
  String get saacae8d5c5;

  /// fi: MQTT
  ///
  /// In en, this message translates to:
  /// **'MQTT'**
  String get se1bd60873c;

  /// fi: Välittäjän osoite
  ///
  /// In en, this message translates to:
  /// **'Broker host'**
  String get s85b9781bb7;

  /// fi: TLS
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get s49fa57061a;

  /// fi: WebSocket-yhteys (ws:// tai wss://)
  ///
  /// In en, this message translates to:
  /// **'Use WebSocket (ws:// or wss://)'**
  String get s0fcef98aad;

  /// fi: Client ID (tyhjä = automaattinen)
  ///
  /// In en, this message translates to:
  /// **'Client ID (empty = auto)'**
  String get s5089c65c1f;

  /// fi: Keep alive (s)
  ///
  /// In en, this message translates to:
  /// **'Keep alive (s)'**
  String get s9372a6f755;

  /// fi: Tilan aihe (topic)
  ///
  /// In en, this message translates to:
  /// **'State topic'**
  String get sd373a99107;

  /// fi: Komennon aihe (topic)
  ///
  /// In en, this message translates to:
  /// **'Command topic'**
  String get s518c8aa712;

  /// fi: QoS
  ///
  /// In en, this message translates to:
  /// **'QoS'**
  String get s3660228d11;

  /// fi: Retain
  ///
  /// In en, this message translates to:
  /// **'Retain'**
  String get s1b07c9ba3d;

  /// fi: WebSocket
  ///
  /// In en, this message translates to:
  /// **'WebSocket'**
  String get s3d43664fcc;

  /// fi: Otsakkeet (Nimi: arvo / rivi)
  ///
  /// In en, this message translates to:
  /// **'Headers (Name: value per line)'**
  String get s81479e1555;

  /// fi: Token (Authorization: Bearer)
  ///
  /// In en, this message translates to:
  /// **'Token (Authorization: Bearer)'**
  String get s5811b38d7b;

  /// fi: Viesti yhdistettäessä
  ///
  /// In en, this message translates to:
  /// **'Message on connect'**
  String get sd512dbbfc7;

  /// fi: Suodatin (viesti sisältää)
  ///
  /// In en, this message translates to:
  /// **'Filter (message contains)'**
  String get s4d089aab74;

  /// fi: Kyselyviesti (lähetetään luettaessa)
  ///
  /// In en, this message translates to:
  /// **'Request message (sent on read)'**
  String get s4a282cd247;

  /// fi: Viesti ({{value}} = arvo)
  ///
  /// In en, this message translates to:
  /// **'\'Message ({{value}} = value)\''**
  String get sbeef545d37;

  /// fi: locked=Lukossa;unlocked=Auki;jammed=JUMISSA
  ///
  /// In en, this message translates to:
  /// **'locked=Locked;unlocked=Unlocked;jammed=JAMMED'**
  String get s1becc05ea1;

  /// fi: open=Auki;closed=Kiinni;opening=Aukeaa;closing=Sulkeutuu
  ///
  /// In en, this message translates to:
  /// **'open=Open;closed=Closed;opening=Opening;closing=Closing'**
  String get s259de02f33;

  /// fi: disarmed=Pois;armed_away=Päällä;armed_home=Kotona;armed_night=Yö;triggered=HÄLYTYS;arming=Kytkeytyy
  ///
  /// In en, this message translates to:
  /// **'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming'**
  String get s64d4364336;

  /// fi: playing=Toistaa;paused=Tauolla;idle=Valmiina;on=Päällä;off=Pois;standby=Valmiustila;buffering=Latautuu;unavailable=Ei yh
  ///
  /// In en, this message translates to:
  /// **'playing=Playing;paused=Paused;idle=Idle;on=On;off=Off;standby=Standby;buffering=Buffering;unavailable=Unavailable'**
  String get s73720edff0;

  /// fi: cleaning=Imuroi;docked=Telakassa;returning=Palaa telakkaan;idle=Valmiina;paused=Tauolla;error=VIRHE
  ///
  /// In en, this message translates to:
  /// **'cleaning=Cleaning;docked=Docked;returning=Returning;idle=Idle;paused=Paused;error=ERROR'**
  String get s2df1d5947c;

  /// fi: on=Päällä;off=Pois
  ///
  /// In en, this message translates to:
  /// **'on=On;off=Off'**
  String get s5b1e227dc4;

  /// fi: Suomi on yksi alue (FI). Ruotsissa ja Norjassa alue riippuu asuinpaikasta.
  ///
  /// In en, this message translates to:
  /// **'Finland is one area (FI). In Sweden and Norway it depends on where you live.'**
  String get s2525f9a4f5;

  /// fi: ALV %
  ///
  /// In en, this message translates to:
  /// **'VAT %'**
  String get s8f4a683abf;

  /// fi: Suomessa 25,5 %.
  ///
  /// In en, this message translates to:
  /// **'Your country\'\'s VAT.'**
  String get s1c7d76a774;

  /// fi: Myyjän marginaali (c/kWh)
  ///
  /// In en, this message translates to:
  /// **'Seller margin (c/kWh)'**
  String get se49d0fba92;

  /// fi: Pörssisähkösopimuksen marginaali ilman ALV:tä, esim. 0,5.
  ///
  /// In en, this message translates to:
  /// **'Spot contract margin without VAT.'**
  String get s20a5e2936a;

  /// fi: Siirto + sähkövero (c/kWh)
  ///
  /// In en, this message translates to:
  /// **'Transfer + tax (c/kWh)'**
  String get s923f9739de;

  /// fi: Laskun mukaan ALV:n kanssa. Jätä 0, jos haluat nähdä pelkän energian hinnan.
  ///
  /// In en, this message translates to:
  /// **'From your bill, incl. VAT. Leave 0 for energy only.'**
  String get s2a3498fb0f;

  /// fi: Tuntihinnoitellulle sopimukselle. Pois: 15 min hinnat, kun alueen data on 15 min (EU:n päivämarkkina 1.10.2025 alkaen).
  ///
  /// In en, this message translates to:
  /// **'For hourly-billed contracts. Off: 15-min prices where the area publishes them (EU day-ahead since 1 Oct 2025).'**
  String get s1d9eabe472;

  /// fi: Hintapalvelin
  ///
  /// In en, this message translates to:
  /// **'Price server'**
  String get s515da3a9dd;

  /// fi: Molaplanin oma palvelin hakee hinnat avoimista lähteistä.
  ///
  /// In en, this message translates to:
  /// **'Molaplan\'\'s server fetches prices from open sources.'**
  String get s98cc9f1c14;

  /// fi: Mikä hinnan tieto ruudussa näkyy: hinta nyt, päivän halvin / kallein / keskihinta, seuraava halpa tunti tai kaavio.
  ///
  /// In en, this message translates to:
  /// **'Which price figure the tile shows: now, today\'\'s lowest / highest / average, the next cheap hour or the chart.'**
  String get s1edb6be142;

  /// fi: Päivän halvin
  ///
  /// In en, this message translates to:
  /// **'Lowest today'**
  String get s46aab99b27;

  /// fi: Päivän kallein
  ///
  /// In en, this message translates to:
  /// **'Highest today'**
  String get sf6295f1182;

  /// fi: Päivän keskihinta
  ///
  /// In en, this message translates to:
  /// **'Average today'**
  String get s1aa7abbf72;

  /// fi: Seuraava halpa tunti
  ///
  /// In en, this message translates to:
  /// **'Next cheap hour'**
  String get s65f496b2dc;

  /// fi: Hintakaavio (tänään ja huomenna)
  ///
  /// In en, this message translates to:
  /// **'Price chart (today and tomorrow)'**
  String get se446dc324a;

  /// fi: Tämän päivän hintoja ei ole vielä saatavilla.
  ///
  /// In en, this message translates to:
  /// **'No prices for today yet.'**
  String get s2f754e8ab4;

  /// fi: Hintaa ei ole tälle hetkelle.
  ///
  /// In en, this message translates to:
  /// **'No price for now.'**
  String get s18faad19ed;

  /// fi: Sähkön hinta on vain luettava.
  ///
  /// In en, this message translates to:
  /// **'Electricity price is read-only.'**
  String get s29178b43f4;

  /// fi: Huominen: kyllä.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow: yes.'**
  String get s1a707f2788;

  /// fi: Huominen: ei vielä (julkaistaan n. klo 14).
  ///
  /// In en, this message translates to:
  /// **'Tomorrow: not yet (published around 14:00).'**
  String get sb85af981c1;

  /// fi: ✓ Hinnat haettu alueelle {p0} ({p1} jaksoa, {p2} min, lähde {p3}).
  ///
  /// In en, this message translates to:
  /// **'✓ Prices for {p0} ({p1} slots, {p2} min, source {p3}).'**
  String s6270faf138(String p0, String p1, String p2, String p3);

  /// fi: Löytyy reitittimen laitelistasta tai laitteen sovelluksesta. Voit myös painaa "Etsi verkosta".
  ///
  /// In en, this message translates to:
  /// **'Find it in your router\'\'s device list or the device app. You can also tap \"Search network\".'**
  String get s7e461faf91;

  /// fi: Laitteen IP-osoite
  ///
  /// In en, this message translates to:
  /// **'Device IP address'**
  String get saf4b222a68;

  /// fi: ESP32-CAM-kamera
  ///
  /// In en, this message translates to:
  /// **'ESP32-CAM camera'**
  String get s1bbea216af;

  /// fi: Edullinen wifi-kamera. Näyttää liikkuvan kuvan.
  ///
  /// In en, this message translates to:
  /// **'Low-cost Wi-Fi camera. Shows live video.'**
  String get saaaeccd0cc;

  /// fi: Kameran IP-osoite
  ///
  /// In en, this message translates to:
  /// **'Camera IP address'**
  String get saaea39b2de;

  /// fi: Näkyy kameran sarjamonitorissa käynnistyessä tai reitittimen laitelistassa.
  ///
  /// In en, this message translates to:
  /// **'Shown in the serial monitor at boot or in the router device list.'**
  String get s6ef2a3f197;

  /// fi: Esim. Piha, Eteinen, Autotalli.
  ///
  /// In en, this message translates to:
  /// **'E.g. Yard, Hallway.'**
  String get sae199413a2;

  /// fi: Kuvan tyyppi
  ///
  /// In en, this message translates to:
  /// **'Image type'**
  String get s2dd165b39f;

  /// fi: mjpeg = liikkuva kuva (suositus). snapshot = still-kuva muutaman sekunnin välein, kevyempi.
  ///
  /// In en, this message translates to:
  /// **'mjpeg = live video (recommended). snapshot = still image every few seconds.'**
  String get sb66b153f36;

  /// fi: Shelly-rele / pistorasia
  ///
  /// In en, this message translates to:
  /// **'Shelly relay / plug'**
  String get sf81257929d;

  /// fi: Ohjaa valoa tai laitetta päälle/pois ja näyttää tehon.
  ///
  /// In en, this message translates to:
  /// **'Switch a light or appliance on/off and show power.'**
  String get s2b8ab6defc;

  /// fi: Mitä se ohjaa?
  ///
  /// In en, this message translates to:
  /// **'What does it control?'**
  String get s7fcea114f0;

  /// fi: Uudemmat (Shelly Plus, Pro, Gen3) = Plus / Pro / Gen2+. Vanhat Shelly 1, 2.5, Plug S = Gen1.
  ///
  /// In en, this message translates to:
  /// **'Newer (Plus, Pro, Gen3) = Plus / Pro / Gen2+. Old Shelly 1, 2.5, Plug S = Gen1.'**
  String get s864ba0233b;

  /// fi: Näytä teho (W)
  ///
  /// In en, this message translates to:
  /// **'Show power (W)'**
  String get s92f97cd95e;

  /// fi: Vain malleille, joissa on tehomittaus (esim. Plus 1PM, Plug S).
  ///
  /// In en, this message translates to:
  /// **'Only for models with metering (e.g. Plus 1PM).'**
  String get s54c71d86aa;

  /// fi: Kanava
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get s49671fc56f;

  /// fi: Monikanavaisissa (esim. Shelly 2PM) 0 = ensimmäinen, 1 = toinen.
  ///
  /// In en, this message translates to:
  /// **'For multi-channel devices: 0 = first.'**
  String get s06f8a27d8a;

  /// fi: Vain jos olet asettanut Shellyyn salasanan (Gen1: admin).
  ///
  /// In en, this message translates to:
  /// **'Only if you set a password.'**
  String get s259e46c59a;

  /// fi: Tasmota-ohjelmistolla toimiva rele tai pistorasia.
  ///
  /// In en, this message translates to:
  /// **'Relay or plug running Tasmota firmware.'**
  String get sc130e073ba;

  /// fi: Releet
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get s70d8cb97e6;

  /// fi: Tyhjä = kaikki laitteen ilmoittamat releet (tunnistetaan automaattisesti). Voit rajata: "1", "1,2,4", "1-4" tai "kaikki"
  ///
  /// In en, this message translates to:
  /// **'Empty = every relay the device reports (detected automatically). Narrow it: \"1\", \"1,2,4\", \"1-4\" or \"all\".'**
  String get s7a4c459c3a;

  /// fi: Web-salasana
  ///
  /// In en, this message translates to:
  /// **'Web password'**
  String get s5f1e4a036e;

  /// fi: Vain jos Tasmotaan on asetettu web-salasana (käyttäjä admin).
  ///
  /// In en, this message translates to:
  /// **'Only if a web password is set (user admin).'**
  String get s397e83233d;

  /// fi: Oma ESP32/ESP8266-laite ESPHome-ohjelmistolla (web_server päällä).
  ///
  /// In en, this message translates to:
  /// **'Your own ESP32/ESP8266 with ESPHome (web_server enabled).'**
  String get sa0efcdf688;

  /// fi: Laitteen nimi
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get s631420589f;

  /// fi: Kytkimen tunnus (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Switch id (optional)'**
  String get s1db899640b;

  /// fi: YAML-tiedoston switch-nimi pienillä kirjaimilla, välilyönnit alaviivoiksi. Esim. "Sauna rele" → sauna_rele.
  ///
  /// In en, this message translates to:
  /// **'The switch name from YAML in lower case with underscores.'**
  String get sb2e87033fc;

  /// fi: Anturin tunnus (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Sensor id (optional)'**
  String get s978ae8f1d6;

  /// fi: Sensorin nimi samalla tavalla. Esim. "Lämpötila" → l_mp_tila tai lampotila (katso laitteen web-sivulta).
  ///
  /// In en, this message translates to:
  /// **'Sensor name in the same way (see the device web page).'**
  String get s4ba12c5866;

  /// fi: Anturin yksikkö
  ///
  /// In en, this message translates to:
  /// **'Sensor unit'**
  String get s945273ef29;

  /// fi: Vain jos web_serverille on asetettu tunnus (auth).
  ///
  /// In en, this message translates to:
  /// **'Only if web_server auth is set.'**
  String get s5ca2e25792;

  /// fi: Web-tunnus
  ///
  /// In en, this message translates to:
  /// **'Web username'**
  String get sb847f22473;

  /// fi: Valot, hälytys, anturit – valitse listasta, mitkä haluat ruuduiksi.
  ///
  /// In en, this message translates to:
  /// **'Lights, alarm, sensors – pick from a list which ones become tiles.'**
  String get s76f6067b0f;

  /// fi: Home Assistantin osoite
  ///
  /// In en, this message translates to:
  /// **'Home Assistant address'**
  String get s9f70681d3f;

  /// fi: Sama osoite, jolla avaat Home Assistantin selaimessa.
  ///
  /// In en, this message translates to:
  /// **'The address you open Home Assistant with.'**
  String get s123502628e;

  /// fi: Pitkäikäinen tunnus (token)
  ///
  /// In en, this message translates to:
  /// **'Long-lived token'**
  String get s92e3c4cd40;

  /// fi: Home Assistant → klikkaa omaa nimeäsi vasemmalla alhaalla → Turvallisuus → Pitkäikäiset käyttöoikeustunnukset → Luo tunn
  ///
  /// In en, this message translates to:
  /// **'Home Assistant → your profile → Security → Long-lived access tokens → Create token. Paste it here.'**
  String get s4e3f2052b2;

  /// fi: Lämpöpumppu (Home Assistant)
  ///
  /// In en, this message translates to:
  /// **'Heat pump (Home Assistant)'**
  String get s54e063bd9c;

  /// fi: Ilmalämpöpumppu, joka näkyy Home Assistantissa ilmastointilaitteena (climate).
  ///
  /// In en, this message translates to:
  /// **'Air heat pump shown in Home Assistant as a climate entity.'**
  String get s2afe650320;

  /// fi: Jos Home Assistant on jo lisätty, sama yhteys otetaan käyttöön.
  ///
  /// In en, this message translates to:
  /// **'If already added, the same connection is reused.'**
  String get s48fdd98530;

  /// fi: HA → oma profiili → Turvallisuus → Luo tunnus. Ei tarvita, jos HA on jo lisätty.
  ///
  /// In en, this message translates to:
  /// **'Not needed if HA is already added.'**
  String get sfe5ad3202f;

  /// fi: Lämpöpumpun entiteetti
  ///
  /// In en, this message translates to:
  /// **'Heat pump entity'**
  String get sce069d8d1a;

  /// fi: Alkaa sanalla climate. Löytyy HA:sta Asetukset → Entiteetit.
  ///
  /// In en, this message translates to:
  /// **'Starts with climate.'**
  String get s05e2aaa15c;

  /// fi: Lämpöpumppu (MQTT)
  ///
  /// In en, this message translates to:
  /// **'Heat pump (MQTT)'**
  String get se699281c85;

  /// fi: Esim. mitsubishi2mqtt- tai vastaava ESP-ohjain. Aiheet ovat esimerkkejä – tarkista omasi.
  ///
  /// In en, this message translates to:
  /// **'E.g. mitsubishi2mqtt or similar ESP controller. Topics are examples – verify.'**
  String get s8643040b95;

  /// fi: MQTT-välittäjän IP-osoite
  ///
  /// In en, this message translates to:
  /// **'MQTT broker IP'**
  String get s2a1148ee77;

  /// fi: Kone, jolla Mosquitto tai muu MQTT-välittäjä pyörii (usein Home Assistant -kone).
  ///
  /// In en, this message translates to:
  /// **'Machine running Mosquitto (often the HA box).'**
  String get s53e472c976;

  /// fi: MQTT-tunnus
  ///
  /// In en, this message translates to:
  /// **'MQTT username'**
  String get s29aff3d2a0;

  /// fi: Jätä tyhjäksi, jos välittäjä ei vaadi.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if not required.'**
  String get s37e57de4b9;

  /// fi: MQTT-salasana
  ///
  /// In en, this message translates to:
  /// **'MQTT password'**
  String get sffe00ea1b3;

  /// fi: Perusaihe
  ///
  /// In en, this message translates to:
  /// **'Base topic'**
  String get s407d4a5e56;

  /// fi: Ohjaimen asetuksista. Tila luetaan aiheesta <perusaihe>/state ja komennot lähetetään aiheeseen <perusaihe>/set.
  ///
  /// In en, this message translates to:
  /// **'From the controller settings. State: <base>/state, commands: <base>/set.'**
  String get sc1af622c0a;

  /// fi: huone
  ///
  /// In en, this message translates to:
  /// **'room'**
  String get s9783a8fd53;

  /// fi: asetus
  ///
  /// In en, this message translates to:
  /// **'setpoint'**
  String get sbc996a7d25;

  /// fi: Ilmalämpöpumppu (IR)
  ///
  /// In en, this message translates to:
  /// **'Air heat pump (IR)'**
  String get sa69c0e1ca3;

  /// fi: Ohjaa mitä tahansa kaukosäätimellä toimivaa ilmalämpöpumppua IR-lähettimellä (Tasmota tai ESPHome). IR on yksisuuntainen
  ///
  /// In en, this message translates to:
  /// **'Control any remote-controlled heat pump with an IR blaster (Tasmota or ESPHome). IR is one-way: Molaplan shows what it last sent.'**
  String get s025e7bf04d;

  /// fi: IR-lähetin
  ///
  /// In en, this message translates to:
  /// **'IR blaster'**
  String get sb5d4127728;

  /// fi: Useimmat valmiit IR-lähettimet (esim. Athom, Moes) toimivat Tasmotalla. Asenna niihin tasmota-ir-versio. ESPHome = oma E
  ///
  /// In en, this message translates to:
  /// **'Most ready-made IR blasters run Tasmota (use the tasmota-ir build). ESPHome = your ESPHome device with climate_ir.'**
  String get sc899cf95db;

  /// fi: IR-lähettimen IP-osoite. Jos valitsit MQTT:n, kirjoita tähän MQTT-välittäjän osoite.
  ///
  /// In en, this message translates to:
  /// **'IP of the IR blaster. For MQTT, the broker address.'**
  String get sc096a735fd;

  /// fi: Lämpöpumpun merkki
  ///
  /// In en, this message translates to:
  /// **'Heat pump brand'**
  String get safc7f1325c;

  /// fi: Valitse ulkoyksikön tai kaukosäätimen merkki. Jos lämpöpumppu ei reagoi, kokeile "Muu" ja jotain saman merkin vaihtoehto
  ///
  /// In en, this message translates to:
  /// **'Pick the brand of the unit or remote. If it does not react, try \"Other\" with an alternative protocol.'**
  String get s7675ec1754;

  /// fi: Protokolla (vain "Muu")
  ///
  /// In en, this message translates to:
  /// **'Protocol (only \"Other\")'**
  String get s9702830f91;

  /// fi: Tasmotan IRhvac-valmistajanimi, esim. DAIKIN2, LG2, COOLIX. Täytä vain, jos merkki on "Muu" tai haluat kokeilla toista.
  ///
  /// In en, this message translates to:
  /// **'Tasmota IRhvac vendor name. Only needed for \"Other\" or to try another.'**
  String get s6df0837908;

  /// fi: Näkyy ruutujen otsikossa.
  ///
  /// In en, this message translates to:
  /// **'Shown in tile titles.'**
  String get saa49bfdb90;

  /// fi: Tasmotan aihe (vain MQTT)
  ///
  /// In en, this message translates to:
  /// **'Tasmota topic (MQTT only)'**
  String get sf1971ac29b;

  /// fi: Tasmota → Configuration → MQTT → Topic. Muu MQTT-lähetin: aihe, johon komento lähetetään.
  ///
  /// In en, this message translates to:
  /// **'Tasmota → Configuration → MQTT → Topic. Other MQTT blaster: command topic.'**
  String get s65529d5877;

  /// fi: ESPHome-ilmastoinnin tunnus (vain ESPHome)
  ///
  /// In en, this message translates to:
  /// **'ESPHome climate id (ESPHome only)'**
  String get s321c1677e2;

  /// fi: climate_ir-entiteetin nimi pienillä kirjaimilla ja alaviivoilla. Näkyy ESPHome-laitteen web-sivulla.
  ///
  /// In en, this message translates to:
  /// **'The climate_ir object id, shown on the device web page.'**
  String get s4c07dec7b5;

  /// fi: MQTT-tunnus tai Tasmotan web-tunnus (yleensä admin). Jätä tyhjäksi, jos ei tarvita.
  ///
  /// In en, this message translates to:
  /// **'MQTT or web user.'**
  String get s2229e548f3;

  /// fi: Komennon osoite (vain Muu HTTP)
  ///
  /// In en, this message translates to:
  /// **'Command URL (other HTTP only)'**
  String get s06cff48000;

  /// fi: Paikkamerkit: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.
  ///
  /// In en, this message translates to:
  /// **'\'Placeholders: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.\''**
  String get s5b41e244d6;

  /// fi: Tilanapit (lämmitys, jäähdytys…)
  ///
  /// In en, this message translates to:
  /// **'Mode buttons'**
  String get s9a60c2026e;

  /// fi: Omat napit lämmitykselle, jäähdytykselle, automaatille, kuivaukselle ja puhallukselle.
  ///
  /// In en, this message translates to:
  /// **'Buttons for heat, cool, auto, dry and fan.'**
  String get sd119ce3382;

  /// fi: Puhallinnopeus
  ///
  /// In en, this message translates to:
  /// **'Fan speed'**
  String get s9b8dd7076a;

  /// fi: Liukusäädin 0–5 (0 = automaatti).
  ///
  /// In en, this message translates to:
  /// **'Slider 0–5 (0 = auto).'**
  String get s9597aa1ae9;

  /// fi: Suuntaus (swing)
  ///
  /// In en, this message translates to:
  /// **'Swing'**
  String get secae50c5dd;

  /// fi: Puhallussuunnan heilutus päälle/pois.
  ///
  /// In en, this message translates to:
  /// **'Louver swing on/off.'**
  String get s8bcb8433f9;

  /// fi: Siivekkeiden asento
  ///
  /// In en, this message translates to:
  /// **'Vane position'**
  String get sc5d938e26e;

  /// fi: Liukusäädin puhallussuunnalle (0 = laite päättää, 5 = alas). Lattialle suunnattu lämpö tuntuu lämpimämmältä.
  ///
  /// In en, this message translates to:
  /// **'Slider for the air direction (0 = the unit decides, 5 = lowest).'**
  String get s5ce3991e13;

  /// fi: Huonelämpö lähettimen anturista
  ///
  /// In en, this message translates to:
  /// **'Room temperature from the blaster sensor'**
  String get s78a5e5fa61;

  /// fi: Vain jos lähettimessä on lämpöanturi (Tasmota: näkyy Status 8:ssa; ESPHome: climate_ir:n sensor).
  ///
  /// In en, this message translates to:
  /// **'Only if the blaster has a temperature sensor.'**
  String get s2dd6395602;

  /// fi: Ilmalämpöpumppu (huoltoliitäntä / ESPHome)
  ///
  /// In en, this message translates to:
  /// **'Air heat pump (service port / ESPHome)'**
  String get s4ff78f06ab;

  /// fi: Lämpöpumpun sisäyksikön huoltoliitäntään kytketty ESPHome-ohjain (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, T
  ///
  /// In en, this message translates to:
  /// **'ESPHome controller on the indoor unit service port (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba). Two-way: real state and room temperature.'**
  String get s6cc7b6b499;

  /// fi: Ilmastoinnin tunnus
  ///
  /// In en, this message translates to:
  /// **'Climate id'**
  String get s647e86e5e5;

  /// fi: ESPHome-laitteen climate-entiteetti. Ohjeet-sivun "Etsi lämpöpumput" löytää sen itse.
  ///
  /// In en, this message translates to:
  /// **'The climate entity of the ESPHome device. \"Find heat pumps\" in the guide finds it for you.'**
  String get sbeb6af1e1c;

  /// fi: Vain jos ESPHome web_serverissä on tunnus.
  ///
  /// In en, this message translates to:
  /// **'Only if web_server has auth.'**
  String get sbf36d139cb;

  /// fi: Vain jos ESPHome web_serverissä on salasana.
  ///
  /// In en, this message translates to:
  /// **'Only if web_server has auth.'**
  String get s54d4fdbba4;

  /// fi: RF433-kaukosäädin (Athom IR & RF)
  ///
  /// In en, this message translates to:
  /// **'RF433 remote (Athom IR & RF)'**
  String get s84cd6a5180;

  /// fi: Ohjaa radiokaukosäätimellä toimivia laitteita (pistorasiat, markiisit, autotallin ovet) Athom "Tasmota IR & RF433 Contro
  ///
  /// In en, this message translates to:
  /// **'Control RF433 radio-remote devices (sockets, awnings, garage doors) with the Athom \"Tasmota IR & RF433 Controller\". You teach the buttons right after adding.'**
  String get s4105198757;

  /// fi: Athom-ohjaimen IP-osoite (reitittimen laitelistasta).
  ///
  /// In en, this message translates to:
  /// **'IP of the Athom controller.'**
  String get sbc2bf08889;

  /// fi: Esim. huone tai laite, jota ohjaat.
  ///
  /// In en, this message translates to:
  /// **'E.g. what you control.'**
  String get sc34430eec0;

  /// fi: Vain jos Tasmotaan on asetettu web-salasana.
  ///
  /// In en, this message translates to:
  /// **'Only if a Tasmota web password is set.'**
  String get s12447972e0;

  /// fi: Sähkön hinta (pörssisähkö)
  ///
  /// In en, this message translates to:
  /// **'Electricity price (spot)'**
  String get s6385f1487e;

  /// fi: Tämän ja huomisen päivän pörssisähkön hinta kaaviona, 15 minuutin tarkkuudella: trendi Nyt-viivalla ja/tai pylväät. Hint
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s and tomorrow\'\'s spot price at 15-minute resolution: a trend with a Now line and/or bars. Price control: long-press a device tile → Price control.'**
  String get sead3949d3c;

  /// fi: Maa / hinta-alue
  ///
  /// In en, this message translates to:
  /// **'Country / price area'**
  String get sef8d24c969;

  /// fi: Suomessa FI. Ruotsissa ja Norjassa valitse alue, jolla asut.
  ///
  /// In en, this message translates to:
  /// **'Pick your country; in Sweden and Norway your area.'**
  String get sef4f509f9f;

  /// fi: Laskustasi ALV:n kanssa. 0 = näytä pelkkä energian hinta.
  ///
  /// In en, this message translates to:
  /// **'From your bill incl. VAT. 0 = energy only.'**
  String get sf3a8631d14;

  /// fi: Sopimuksesi marginaali ilman ALV:tä.
  ///
  /// In en, this message translates to:
  /// **'Your contract margin without VAT.'**
  String get sf3be8aac1c;

  /// fi: Sähkön hinta {p0}
  ///
  /// In en, this message translates to:
  /// **'Electricity price {p0}'**
  String s49dfca65a3(String p0);

  /// fi: Hintatrendi
  ///
  /// In en, this message translates to:
  /// **'Price trend'**
  String get sfb2b7ccc87;

  /// fi: Tämän ja huomisen kaavio
  ///
  /// In en, this message translates to:
  /// **'Today and tomorrow chart'**
  String get s4790164c94;

  /// fi: Airthings (radon ja ilmanlaatu, pilvi)
  ///
  /// In en, this message translates to:
  /// **'Airthings (radon and air quality, cloud)'**
  String get s7ba83434d1;

  /// fi: View Plus, View Radon, Hub ja kaikki tiliisi liitetyt mittarit. Wi-Fi-malleissa ei ole paikallista rajapintaa, joten arv
  ///
  /// In en, this message translates to:
  /// **'View Plus, View Radon, Hub and every monitor in your account. The Wi-Fi models have no local API, so values come from the official Airthings API with your own credentials.'**
  String get s39e8df2552;

  /// fi: 1) Avaa dashboard.airthings.com ja kirjaudu Airthings-tunnuksillasi. 2) Integrations → API → Create client (tai "New API
  ///
  /// In en, this message translates to:
  /// **'1) Open dashboard.airthings.com and sign in with your Airthings account. 2) Integrations → API → Create client (\"New API client\"). 3) Name it e.g. Molaplan, choose Flow type \"Client credentials\" and enable it. 4) Copy the Client ID here.'**
  String get sbafe369760;

  /// fi: 5) Kopioi samasta näkymästä Client secret. Se tallennetaan vain tähän laitteeseen ja tiliisi salattuna.
  ///
  /// In en, this message translates to:
  /// **'5) Copy the Client secret from the same view. It is stored only on this device and encrypted in your account.'**
  String get sb6a852ab13;

  /// fi: Wave, Wave Plus, Wave Mini ja Wave Radon toimivat vain Bluetoothilla. Lukee Android-laite tai kotisilta enintään 10 m pä
  ///
  /// In en, this message translates to:
  /// **'Wave, Wave Plus, Wave Mini and Wave Radon use Bluetooth only. Read by an Android device or the home bridge within about 10 m.'**
  String get s2d1dc6624d;

  /// fi: Mittarin takana (10 numeroa). Alku kertoo mallin: 2930 = Wave Plus, 2950 = Wave Radon, 2920 = Wave Mini.
  ///
  /// In en, this message translates to:
  /// **'On the back of the monitor (10 digits). The start tells the model: 2930 = Wave Plus, 2950 = Wave Radon, 2920 = Wave Mini.'**
  String get sff5f25f96f;

  /// fi: Lue kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'Read through the home bridge'**
  String get s8de2de9178;

  /// fi: Päälle, kun Bluetooth-lukija on kotisilta (esim. aina päällä oleva laite mittarin lähellä).
  ///
  /// In en, this message translates to:
  /// **'On when the home bridge (e.g. an always-on device near the sensor) does the Bluetooth reading.'**
  String get s501a17e478;

  /// fi: IV-kone tai lämpöpumppu (Modbus TCP)
  ///
  /// In en, this message translates to:
  /// **'Ventilation unit or heat pump (Modbus TCP)'**
  String get s3330126b01;

  /// fi: Lämpötilat, puhallinnopeus ja asetukset. Valmiit rekisterikartat merkeille (Airfi, Vallox, Enervent, Swegon, Flexit, Ilt
  ///
  /// In en, this message translates to:
  /// **'Temperatures, fan speed and settings. Ready register maps for brands (Airfi, Vallox, Enervent, Swegon, Flexit, Ilto, Nilan, NIBE, Thermia) – verify with your manual.'**
  String get sc16ab2836c;

  /// fi: IV-koneen tai yhdyskäytävän IP-osoite
  ///
  /// In en, this message translates to:
  /// **'Unit or gateway IP'**
  String get sb75966bb58;

  /// fi: Jos koneessa on vain RS485-väylä, tarvitset RS485 → Modbus TCP -muuntimen (esim. Waveshare). Syötä sen IP.
  ///
  /// In en, this message translates to:
  /// **'If the unit has only RS485, you need an RS485 → Modbus TCP gateway. Enter its IP.'**
  String get s751331a84a;

  /// fi: Koneen merkki
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get s658cdb6ff8;

  /// fi: Valitse merkki, niin rekisterit täytetään valmiiksi esimerkkinä. "—" = tyhjä, lisäät ruudut itse.
  ///
  /// In en, this message translates to:
  /// **'Pick a brand to prefill registers as an example. \"—\" = empty.'**
  String get s785c0c264c;

  /// fi: Usein 1. Katso koneen Modbus-asetuksista.
  ///
  /// In en, this message translates to:
  /// **'Often 1.'**
  String get s7e9c785c20;

  /// fi: Lähes aina 502.
  ///
  /// In en, this message translates to:
  /// **'Almost always 502.'**
  String get s0591744c19;

  /// fi: IV-kone
  ///
  /// In en, this message translates to:
  /// **'Ventilation'**
  String get s5ccb7405cf;

  /// fi: MQTT-laite
  ///
  /// In en, this message translates to:
  /// **'MQTT device'**
  String get se7dfa3594e;

  /// fi: Mikä tahansa laite, joka puhuu MQTT:tä (Zigbee2MQTT, oma ESP, ...).
  ///
  /// In en, this message translates to:
  /// **'Any device that speaks MQTT (Zigbee2MQTT, your own ESP, ...).'**
  String get s12ab103795;

  /// fi: Kone, jolla MQTT-välittäjä (esim. Mosquitto) pyörii.
  ///
  /// In en, this message translates to:
  /// **'Machine running the MQTT broker.'**
  String get sffcfefd91c;

  /// fi: Mikä laite on?
  ///
  /// In en, this message translates to:
  /// **'What is it?'**
  String get s6ac05d979c;

  /// fi: switch = kytkin (päälle/pois), sensor = mittari (näyttää arvon).
  ///
  /// In en, this message translates to:
  /// **'switch = on/off, sensor = shows a value.'**
  String get s460d48d0cc;

  /// fi: Tilan aihe
  ///
  /// In en, this message translates to:
  /// **'State topic'**
  String get s850c7e1194;

  /// fi: Aihe, johon laite kertoo tilansa.
  ///
  /// In en, this message translates to:
  /// **'Topic where the device reports its state.'**
  String get s49b7311a1e;

  /// fi: Komentoaihe (kytkimelle)
  ///
  /// In en, this message translates to:
  /// **'Command topic (switch)'**
  String get s579969e7e4;

  /// fi: Aihe, johon päälle/pois-komento lähetetään.
  ///
  /// In en, this message translates to:
  /// **'Topic for the on/off command.'**
  String get s137db4076a;

  /// fi: Päälle-viesti
  ///
  /// In en, this message translates to:
  /// **'On message'**
  String get s4c95226869;

  /// fi: Pois-viesti
  ///
  /// In en, this message translates to:
  /// **'Off message'**
  String get s70f2ea8532;

  /// fi: JSON-kenttä
  ///
  /// In en, this message translates to:
  /// **'JSON field'**
  String get sdc234849ac;

  /// fi: Jos viesti on JSONia, esim. {"temperature": 21}, kirjoita temperature.
  ///
  /// In en, this message translates to:
  /// **'If the message is JSON, the field name.'**
  String get sd3f60d4a71;

  /// fi: Yksikkö (mittarille)
  ///
  /// In en, this message translates to:
  /// **'Unit (sensor)'**
  String get s6cee917658;

  /// fi: Muu wifi-laite (HTTP)
  ///
  /// In en, this message translates to:
  /// **'Other Wi-Fi device (HTTP)'**
  String get s3cd541d271;

  /// fi: Laite, jolla on web-rajapinta. Näyttää yhden arvon, lisää muut ruudut myöhemmin.
  ///
  /// In en, this message translates to:
  /// **'A device with a web API. Shows one value; add more tiles later.'**
  String get s69885630aa;

  /// fi: Tilan osoite (polku)
  ///
  /// In en, this message translates to:
  /// **'Status path'**
  String get s200320e245;

  /// fi: Mistä osoitteesta laite kertoo tilansa. Katso laitteen ohjeesta. Tyhjä = ei ruutua nyt.
  ///
  /// In en, this message translates to:
  /// **'Where the device reports its state. Empty = no tile now.'**
  String get sc5872d2e30;

  /// fi: Näytettävä kenttä
  ///
  /// In en, this message translates to:
  /// **'Field to show'**
  String get s5564de12b2;

  /// fi: Vastauksen kentän nimi, esim. temperature tai data.temp.
  ///
  /// In en, this message translates to:
  /// **'Field name in the reply.'**
  String get s377942beb7;

  /// fi: Komento ja vastaus (ntfy)
  ///
  /// In en, this message translates to:
  /// **'Command and reply (ntfy)'**
  String get sbaf1a279c2;

  /// fi: Lähetä komento ntfy-viestinä (esim. "päivitä" + PIN) ja näe kotilaitteen vastaus samassa ruudussa. Sama kanava kuin iPho
  ///
  /// In en, this message translates to:
  /// **'Send a command as an ntfy message (e.g. \"update\" + PIN) and see the home device\'\'s reply in the same tile. Same channel as an iPhone Shortcut.'**
  String get se0fb2c7eea;

  /// fi: Komentokanavan osoite
  ///
  /// In en, this message translates to:
  /// **'Command topic URL'**
  String get s8231329360;

  /// fi: Liitä sama osoite, johon pikakomento lähettää komennot (esim. https://ntfy.sh/oma-aihe). Pelkkä aiheen nimi riittää myös
  ///
  /// In en, this message translates to:
  /// **'Paste the same URL your Shortcut posts commands to (e.g. https://ntfy.sh/oma-aihe). The topic name alone also works.'**
  String get s206ac44298;

  /// fi: Täytä vain, jos kotilaite vastaa eri aiheeseen. Tyhjä = vastaus tulee samaan aiheeseen, ja oma komento ohitetaan.
  ///
  /// In en, this message translates to:
  /// **'Only if the home device replies on another topic. Empty = same topic, our own command is ignored.'**
  String get s1b3bbae234;

  /// fi: Teksti, joka näkyy ruudussa, esim. "Päivitä" tai "Tila".
  ///
  /// In en, this message translates to:
  /// **'Text shown on the tile, e.g. \"Update\" or \"Status\".'**
  String get s1b08aa4646;

  /// fi: Lähetettävä teksti. PIN lisätään perään välilyönnillä, esim. "päivitä 1234".
  ///
  /// In en, this message translates to:
  /// **'The text to send. The PIN is appended after a space, e.g. \"update 1234\".'**
  String get se2a81ae67d;

  /// fi: Kysy PIN joka painalluksella
  ///
  /// In en, this message translates to:
  /// **'Ask for the PIN on every press'**
  String get s1477964f04;

  /// fi: PIN kysytään piilotettuna eikä sitä tallenneta, ellet valitse "Muista tällä laitteella".
  ///
  /// In en, this message translates to:
  /// **'The PIN is asked hidden and is not stored unless you choose \"Remember on this device\".'**
  String get s62672283f6;

  /// fi: Vain suojatulle aiheelle (ntfy-tili → Access tokens). Julkiseen aiheeseen jätä tyhjäksi.
  ///
  /// In en, this message translates to:
  /// **'Only for a protected topic. Leave empty for a public topic.'**
  String get sb5e914eaf7;

  /// fi: Lisää myös viestiloki-ruutu
  ///
  /// In en, this message translates to:
  /// **'Also add a message log tile'**
  String get s1a98a7e424;

  /// fi: Näyttää aiheen viimeisimmät viestit (esim. kotilaitteen ilmoitukset) omassa ruudussaan.
  ///
  /// In en, this message translates to:
  /// **'Shows the latest messages of the topic in its own tile.'**
  String get s5ab6348524;

  /// fi: Viestit
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get s57e684ac9e;

  /// fi: ntfy-komentolaite
  ///
  /// In en, this message translates to:
  /// **'ntfy command device'**
  String get s021372fd08;

  /// fi: Laite, jota ohjataan ntfy-viesteillä: päälle/pois-kytkimet, tilan luku ja PIN. Toimii kotona ja muualla ilman kotisiltaa
  ///
  /// In en, this message translates to:
  /// **'A device controlled with ntfy messages: on/off switches, state and PIN. Works at home and away without a home bridge.'**
  String get s120a222880;

  /// fi: Valmis malli
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get s6f139b5bcc;

  /// fi: Kameravalvonta: valot, sireeni, hälytys päälle/pois/kuittaa ja tila. Aihe ja PIN täytetään itse.
  ///
  /// In en, this message translates to:
  /// **'Camera surveillance: lights, siren, alarm on/off/acknowledge and state. Topic and PIN are your own.'**
  String get sa149146483;

  /// fi: Oma laite
  ///
  /// In en, this message translates to:
  /// **'Own device'**
  String get sb6b101dd23;

  /// fi: Kameravalvonta (kv-paneeli)
  ///
  /// In en, this message translates to:
  /// **'Camera surveillance (kv panel)'**
  String get s1ffb53e7f3;

  /// fi: Komentokanava
  ///
  /// In en, this message translates to:
  /// **'Command topic'**
  String get s7a46c8c335;

  /// fi: Aihe (tai koko osoite), jota laite kuuntelee – laitteen oma kanava, ei sinun ilmoituskanavasi.
  ///
  /// In en, this message translates to:
  /// **'The topic (or full URL) the device listens to – the device\'\'s own topic, not your notification topic.'**
  String get safaab25703;

  /// fi: Jos laite vastaa toiseen aiheeseen (esim. omaan ilmoitusaiheeseesi). Tyhjä = sama aihe.
  ///
  /// In en, this message translates to:
  /// **'If the device answers on another topic (e.g. your notification topic). Empty = the same topic.'**
  String get sc1ddf7feb4;

  /// fi: Laitteen tilakanava (paneelissa Laite → Etäohjaus → Tilakanava, fw 0.2.51+). Kun asetettu, Molaplan ei kysele tilaa itse
  ///
  /// In en, this message translates to:
  /// **'The device state topic (on the panel: Device → Remote → State channel, fw 0.2.51+). When set, Molaplan does not poll for state. No PIN is needed. If a PIN-protected status reply includes state_topic and it differs from the stored value (e.g. after the panel\'\'s \"New channel and key\"), the subscription is updated automatically. If no message arrives on the state topic for over 35 minutes, Molaplan falls back to scheduled status requests.'**
  String get s5abc26863b;

  /// fi: Jos vastauskanavalla on muitakin viestejä: vain tämän otsikon viestit ovat vastauksia.
  ///
  /// In en, this message translates to:
  /// **'If the reply topic has other messages too: only messages with this title are replies.'**
  String get s24779d22ca;

  /// fi: Tallennetaan salattuna. Lisätään komentoihin mallin mukaan.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted. Added to commands by the template.'**
  String get s17c9df50af;

  /// fi: {cmd} = komento, {pin} = PIN, {cid} = tunniste jonka laite toistaa. Esim. "{cmd} {pin}".
  ///
  /// In en, this message translates to:
  /// **'\'{cmd} = command, {pin} = PIN, {cid} = an id the device echoes. E.g. \"{cmd} {pin}\".\''**
  String get s4427fd3bd1;

  /// fi: Komento, johon laite vastaa tilallaan, esim. "tila" tai "tila json".
  ///
  /// In en, this message translates to:
  /// **'The command the device answers with its state, e.g. \"status\" or \"status json\".'**
  String get s4549a9cb7f;

  /// fi: Tilavastauksen muoto
  ///
  /// In en, this message translates to:
  /// **'Status reply format'**
  String get s5f019b05f1;

  /// fi: JSON: {"valo": 1, …}. Teksti: "Valo: PÄÄLLÄ, …" – tila luetaan nimen perästä.
  ///
  /// In en, this message translates to:
  /// **'\'JSON: {\"light\": 1, …}. Text: \"Light: ON, …\" – the state is read after the name.\''**
  String get sb1f9470ebd;

  /// fi: JSON
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get s96a5a283cf;

  /// fi: Kytkimet (yksi per rivi: Nimi = avain)
  ///
  /// In en, this message translates to:
  /// **'Switches (one per line: Name = key)'**
  String get s3f8b9eaf4b;

  /// fi: Esim. "Pihavalo = pihavalo". Avain on sana, jota laite käyttää komennoissa ja tilassa.
  ///
  /// In en, this message translates to:
  /// **'E.g. \"Yard light = yardlight\". The key is the word the device uses in commands and state.'**
  String get sb7fd9fb70a;

  /// fi: Päälle-komento
  ///
  /// In en, this message translates to:
  /// **'On command'**
  String get s9efd151ae8;

  /// fi: {key} = kytkimen avain. Esim. "{key} on" → "pihavalo on".
  ///
  /// In en, this message translates to:
  /// **'\'{key} = the switch key. E.g. \"{key} on\" → \"light on\".\''**
  String get s29d460cd3b;

  /// fi: Pois-komento
  ///
  /// In en, this message translates to:
  /// **'Off command'**
  String get s8dab09a808;

  /// fi: Kytkimien JSON-polun alku (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'JSON path prefix of the switches (optional)'**
  String get s93698f5ccb;

  /// fi: Jos kytkimet ovat JSONissa ryhmän alla, esim. {"relays":{"valo":1}}, kirjoita "relays." – avain luetaan silloin polusta
  ///
  /// In en, this message translates to:
  /// **'\'If the switches sit under a group in the JSON, e.g. {\"relays\":{\"light\":1}}, type \"relays.\" – the key is then read from relays.light.\''**
  String get s2179eef80d;

  /// fi: Tilaruudun JSON-polku (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Status tile JSON path (optional)'**
  String get s50ade0ed0a;

  /// fi: Mitä tilaruutu näyttää JSON-vastauksesta, esim. "state". Tyhjä = koko vastaus.
  ///
  /// In en, this message translates to:
  /// **'What the status tile shows from a JSON reply, e.g. \"state\". Empty = the whole reply.'**
  String get s9049a8a920;

  /// fi: Tilan päivitysväli (s)
  ///
  /// In en, this message translates to:
  /// **'State refresh interval (s)'**
  String get s54b3e63eca;

  /// fi: Kuinka usein tila kysytään. Ei koskaan lyhyempi kuin laitteen komentojen väli.
  ///
  /// In en, this message translates to:
  /// **'How often the state is asked. Never shorter than the device\'\'s minimum command interval.'**
  String get s22a6e8c7ef;

  /// fi: Jos laite vastaa vain esim. 30 s välein, kirjoita 30.
  ///
  /// In en, this message translates to:
  /// **'If the device answers only e.g. every 30 s, type 30.'**
  String get s91158c0de5;

  /// fi: Valvonta päälle
  ///
  /// In en, this message translates to:
  /// **'Arm'**
  String get sb8011853db;

  /// fi: Valvonta pois
  ///
  /// In en, this message translates to:
  /// **'Disarm'**
  String get s5e2e8d22bc;

  /// fi: Kuittaa hälytys
  ///
  /// In en, this message translates to:
  /// **'Acknowledge alarm'**
  String get s4aff1873a3;

  /// fi: Kuittaa ja valvonta pois
  ///
  /// In en, this message translates to:
  /// **'Acknowledge and disarm'**
  String get s821c81fcdd;

  /// fi: Kameravalvonta: täytä Vastauskanava – paneeli vastaa käyttäjäsi omaan ilmoituskanavaan (paneelilla Asetukset → Käyttäjät
  ///
  /// In en, this message translates to:
  /// **'Camera surveillance: fill in the reply topic – the panel answers on your user\'\'s own notification topic (on the panel: Settings → Users → notification topic).'**
  String get s07f819fc55;

  /// fi: Kameravalvonta: Komentokanava ja Vastauskanava eivät voi olla samat. Komentokanava on paneelin oma kanava (paneelilla As
  ///
  /// In en, this message translates to:
  /// **'Camera surveillance: the command topic and the reply topic cannot be the same. The command topic is the panel\'\'s own topic (on the panel: Settings → ntfy), the reply topic is your notification topic.'**
  String get sa4a5b0baa1;

  /// fi: Komentolaite
  ///
  /// In en, this message translates to:
  /// **'Command device'**
  String get s23f70f51ff;

  /// fi: {p0} – tila
  ///
  /// In en, this message translates to:
  /// **'{p0} – state'**
  String sfeb36cc60a(String p0);

  /// fi: {p0} – lämpötila
  ///
  /// In en, this message translates to:
  /// **'{p0} – temperature'**
  String s3378eb2d0b(String p0);

  /// fi: Viimeksi lähetetty (IR on yksisuuntainen)
  ///
  /// In en, this message translates to:
  /// **'Last sent (IR is one-way)'**
  String get sdfa0c29399;

  /// fi: Puhallin (0 = auto)
  ///
  /// In en, this message translates to:
  /// **'Fan (0 = auto)'**
  String get seab2c72485;

  /// fi: Siivekkeet (0 = auto, 5 = alas)
  ///
  /// In en, this message translates to:
  /// **'Vane (0 = auto, 5 = lowest)'**
  String get s7847d8821b;

  /// fi: {p0} – huone
  ///
  /// In en, this message translates to:
  /// **'{p0} – room'**
  String s3a38b97f7b(String p0);

  /// fi: Varaava lattialämmitys (betoni)
  ///
  /// In en, this message translates to:
  /// **'Storage floor heating (concrete)'**
  String get s2a3f705876;

  /// fi: Betonilaatta varaa lämpöä pitkään: lämmitys keskitetään päivän halvimpiin tunteihin, ja tuntimäärä seuraa sääennustetta.
  ///
  /// In en, this message translates to:
  /// **'A concrete slab stores heat for a long time: heating is moved to the cheapest hours, and the number of hours follows the forecast.'**
  String get se02b21f2e5;

  /// fi: Kevyt lattialämmitys
  ///
  /// In en, this message translates to:
  /// **'Light floor heating'**
  String get sed77dcfc1a;

  /// fi: Kevyt lattia varaa vähän: ohitetaan päivän kalleimmat tunnit, mutta katko on lyhyt.
  ///
  /// In en, this message translates to:
  /// **'A light floor stores little heat: the most expensive hours are skipped, with short breaks only.'**
  String get s4699e792b9;

  /// fi: Suorat sähköpatterit
  ///
  /// In en, this message translates to:
  /// **'Direct electric radiators'**
  String get s5d46662c4e;

  /// fi: Patterit eivät varaa lämpöä: vain kalleimmat tunnit ohitetaan, yksi tunti kerrallaan.
  ///
  /// In en, this message translates to:
  /// **'Radiators do not store heat: only the most expensive hours are skipped, one hour at a time.'**
  String get s12e9bbf847;

  /// fi: Ilmalämpöpumppu
  ///
  /// In en, this message translates to:
  /// **'Air-source heat pump'**
  String get s1c0bf9b38b;

  /// fi: Ilmalämpöpumppu toimii parhaiten tasaisella lämmöllä: tavoitelämpö nousee hieman ennen kallista tai kylmää jaksoa ja las
  ///
  /// In en, this message translates to:
  /// **'A heat pump works best at an even temperature: the target rises a little before expensive or cold spells and drops in expensive hours.'**
  String get s6896be80e0;

  /// fi: Maalämpöpumppu
  ///
  /// In en, this message translates to:
  /// **'Ground-source heat pump'**
  String get s765f87536c;

  /// fi: Maalämpö ja vesikiertoinen lämmitys varaavat jonkin verran: kalleimmat tunnit ohitetaan enintään muutaman tunnin katkoin
  ///
  /// In en, this message translates to:
  /// **'Ground-source heat with water circulation stores some heat: the most expensive hours are skipped in breaks of a few hours at most.'**
  String get s33536024e7;

  /// fi: Lämminvesivaraaja
  ///
  /// In en, this message translates to:
  /// **'Water heater'**
  String get s3a7d2e6848;

  /// fi: Varaaja pysyy lämpimänä vuorokauden: se lämmitetään päivän halvimpina tunteina.
  ///
  /// In en, this message translates to:
  /// **'A water heater stays hot for a day: it is heated in the cheapest hours of the day.'**
  String get s4eec9a0479;

  /// fi: Takka-tila päättyi: huone on alkanut jäähtyä. Lämmitys palaa normaaliksi.
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode ended: the room is cooling. Heating is back to normal.'**
  String get sa2dc343545;

  /// fi: Takka-tila päättyi (aika täynnä). Lämmitys palaa normaaliksi.
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode ended (time is up). Heating is back to normal.'**
  String get s78afbd052c;

  /// fi: Takka-tila lopetettiin. Lämmitys palaa normaaliksi.
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode stopped. Heating is back to normal.'**
  String get s1f08341033;

  /// fi: Selkeää
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get sdd5e97b1e2;

  /// fi: Puolipilvistä
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get sad990c999d;

  /// fi: Pilvistä
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get s80bfe8f9ad;

  /// fi: Sumua
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get s46f3db8514;

  /// fi: Tihkua
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get sbd81101eb4;

  /// fi: Sadetta
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get s960a265544;

  /// fi: Lumisadetta
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get seab38c2b45;

  /// fi: Ukkosta
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get sfc65eafa12;

  /// fi: Huawei SUN2000 (Modbus TCP)
  ///
  /// In en, this message translates to:
  /// **'Huawei SUN2000 (Modbus TCP)'**
  String get sa7f9b278cf;

  /// fi: Fronius (Solar API, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Fronius (Solar API, local)'**
  String get s0d714dece1;

  /// fi: SolarEdge (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'SolarEdge (Modbus TCP, local)'**
  String get sa38a153c07;

  /// fi: SMA (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'SMA (Modbus TCP, local)'**
  String get s833dfe954e;

  /// fi: SMA (SunSpec Modbus)
  ///
  /// In en, this message translates to:
  /// **'SMA (SunSpec Modbus)'**
  String get sc5863d817d;

  /// fi: SMA Energy Meter / Home Manager (Speedwire)
  ///
  /// In en, this message translates to:
  /// **'SMA Energy Meter / Home Manager (Speedwire)'**
  String get s12733504dc;

  /// fi: Growatt (Modbus TCP)
  ///
  /// In en, this message translates to:
  /// **'Growatt (Modbus TCP)'**
  String get sdeb4f39ff0;

  /// fi: Muu SunSpec-invertteri (Modbus TCP)
  ///
  /// In en, this message translates to:
  /// **'Other SunSpec inverter (Modbus TCP)'**
  String get sa1769b666b;

  /// fi: Huawei FusionSolar (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Huawei FusionSolar (cloud)'**
  String get s1694840083;

  /// fi: SolarEdge monitoring (pilvi)
  ///
  /// In en, this message translates to:
  /// **'SolarEdge monitoring (cloud)'**
  String get s205e886d29;

  /// fi: Growatt OpenAPI (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Growatt OpenAPI (cloud)'**
  String get s5bf46ebec4;

  /// fi: Aurinkosähkö / invertteri (oma integraatio)
  ///
  /// In en, this message translates to:
  /// **'Solar / inverter (built-in integration)'**
  String get se7c240ad4f;

  /// fi: Merkki ja yhteystapa
  ///
  /// In en, this message translates to:
  /// **'Brand and connection'**
  String get s46b5445e4a;

  /// fi: Valmistaja ja yhteystapa. Paikalliset toimivat ilman pilveä ja päivittyvät nopeammin.
  ///
  /// In en, this message translates to:
  /// **'Maker and connection type. Local ones work without the cloud and update faster.'**
  String get sef83efed4e;

  /// fi: IP-osoite (paikalliset)
  ///
  /// In en, this message translates to:
  /// **'IP address (local)'**
  String get scc322677fe;

  /// fi: Invertterin, SDonglen tai mittarin IP-osoite (reitittimen laitelistasta).
  ///
  /// In en, this message translates to:
  /// **'IP address of the inverter, SDongle or meter (from the router device list).'**
  String get s6ac1068052;

  /// fi: Tyhjä = oletus (Modbus 502, SolarEdge 1502, Huawein invertterin oma wifi 6607).
  ///
  /// In en, this message translates to:
  /// **'Empty = default (Modbus 502, SolarEdge 1502, Huawei inverter Wi-Fi 6607).'**
  String get sa163739d18;

  /// fi: Modbus unit id
  ///
  /// In en, this message translates to:
  /// **'Modbus unit id'**
  String get s58f0665e29;

  /// fi: Tyhjä = oletus (Huawei 1, SolarEdge 1, SMA 3, SMA SunSpec 126, Growatt 1).
  ///
  /// In en, this message translates to:
  /// **'Empty = default (Huawei 1, SolarEdge 1, SMA 3, SMA SunSpec 126, Growatt 1).'**
  String get sd5e2f52587;

  /// fi: Mittarin sarjanumero (SMA Energy Meter)
  ///
  /// In en, this message translates to:
  /// **'Meter serial (SMA Energy Meter)'**
  String get se49fbf06a8;

  /// fi: Vain jos verkossa on useita SMA-mittareita. Tyhjä = ensimmäinen.
  ///
  /// In en, this message translates to:
  /// **'Only if there are several SMA meters on the network. Empty = the first one.'**
  String get s4a63dcc985;

  /// fi: Käyttäjä (FusionSolar API)
  ///
  /// In en, this message translates to:
  /// **'User (FusionSolar API)'**
  String get s6e391cf987;

  /// fi: FusionSolarin Northbound-API-käyttäjä (asentaja luo: Järjestelmä → Yritys → Northbound).
  ///
  /// In en, this message translates to:
  /// **'FusionSolar Northbound API user (created by the installer: System → Company → Northbound).'**
  String get se76a6f4565;

  /// fi: Salasana / järjestelmäkoodi
  ///
  /// In en, this message translates to:
  /// **'Password / system code'**
  String get s2f3b444057;

  /// fi: Tallentuu vain tälle laitteelle / omaan salattuun holviisi.
  ///
  /// In en, this message translates to:
  /// **'Stored only on this device / in your own encrypted vault.'**
  String get s11298f6c17;

  /// fi: API-avain (SolarEdge / Growatt)
  ///
  /// In en, this message translates to:
  /// **'API key (SolarEdge / Growatt)'**
  String get s68eeca8dbe;

  /// fi: SolarEdge: monitoring-portaali → Admin → Site Access → API. Growatt: OpenAPI-token.
  ///
  /// In en, this message translates to:
  /// **'SolarEdge: monitoring portal → Admin → Site Access → API. Growatt: OpenAPI token.'**
  String get seba7bd613f;

  /// fi: Laitoksen tunnus (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Site / plant id (cloud)'**
  String get s3cda8d5f90;

  /// fi: Tyhjä = tilin ensimmäinen laitos.
  ///
  /// In en, this message translates to:
  /// **'Empty = the first site of the account.'**
  String get see56030ac8;

  /// fi: Verkko: positiivinen = ostat verkosta, negatiivinen = myyt ylijäämää.
  ///
  /// In en, this message translates to:
  /// **'Grid: positive = buying from the grid, negative = selling surplus.'**
  String get s9d61569ac0;

  /// fi: Aurinkosähkö nyt (W)
  ///
  /// In en, this message translates to:
  /// **'Solar power now (W)'**
  String get sc78a29bef9;

  /// fi: Tuotto tänään (kWh)
  ///
  /// In en, this message translates to:
  /// **'Yield today (kWh)'**
  String get s88a9d9b593;

  /// fi: Tuotto yhteensä (kWh)
  ///
  /// In en, this message translates to:
  /// **'Total yield (kWh)'**
  String get s4766881640;

  /// fi: Verkko +osto / −myynti (W)
  ///
  /// In en, this message translates to:
  /// **'Grid +import / −export (W)'**
  String get s4e1e06f64a;

  /// fi: Ostettu yhteensä (kWh)
  ///
  /// In en, this message translates to:
  /// **'Imported total (kWh)'**
  String get s5c5e6866eb;

  /// fi: Myyty yhteensä (kWh)
  ///
  /// In en, this message translates to:
  /// **'Exported total (kWh)'**
  String get s7495975366;

  /// fi: Akku +lataus / −purku (W)
  ///
  /// In en, this message translates to:
  /// **'Battery +charge / −discharge (W)'**
  String get s9da1bd7ed1;

  /// fi: Kodin kulutus (W)
  ///
  /// In en, this message translates to:
  /// **'Home consumption (W)'**
  String get sb6d790453a;

  /// fi: Laite ei kerro tätä lukemaa ({p0})
  ///
  /// In en, this message translates to:
  /// **'The device does not report this reading ({p0})'**
  String sff9335b6df(String p0);

  /// fi: Invertteriä ei ohjata – vain luku
  ///
  /// In en, this message translates to:
  /// **'Inverters are read-only'**
  String get s711b4531bd;

  /// fi: tuotto
  ///
  /// In en, this message translates to:
  /// **'solar'**
  String get s257cf40257;

  /// fi: verkko
  ///
  /// In en, this message translates to:
  /// **'grid'**
  String get sfa32969a23;

  /// fi: Säästävä
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get sc27533ae83;

  /// fi: Lämpö saa vaihdella eniten (+1 / −2 °C). Suurin säästö.
  ///
  /// In en, this message translates to:
  /// **'Temperature may vary the most (+1 / −2 °C). Biggest savings.'**
  String get sdbcb85509b;

  /// fi: Tasapainoinen
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get s380b20be36;

  /// fi: Pieni vaihtelu (+1 / −1 °C). Hyvä oletus.
  ///
  /// In en, this message translates to:
  /// **'Small variation (+1 / −1 °C). A good default.'**
  String get s66ea783264;

  /// fi: Mukavuus
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get see96226e44;

  /// fi: Lähes tasainen lämpö (+0,5 / −0,5 °C). Säästää vähän.
  ///
  /// In en, this message translates to:
  /// **'Almost even temperature (+0.5 / −0.5 °C). Saves a little.'**
  String get sb403e00b3d;

  /// fi: SMA Energy Meter: ei lähetyksiä kotiverkossa (multicast 239.12.255.254:9522)
  ///
  /// In en, this message translates to:
  /// **'SMA Energy Meter: no broadcasts on the home network (multicast 239.12.255.254:9522)'**
  String get s333643b4c4;

  /// fi: alle minuutti
  ///
  /// In en, this message translates to:
  /// **'under a minute'**
  String get s741ad14d6e;

  /// fi: Laite
  ///
  /// In en, this message translates to:
  /// **'The device'**
  String get s61cb8b20cf;

  /// fi: {p0} ei vastaa (yhteys aikakatkaistiin)
  ///
  /// In en, this message translates to:
  /// **'{p0} is not responding (the connection timed out)'**
  String s69e8cc73cb(String p0);

  /// fi: {p0} ei vastaa (aikakatkaisu {p1} s)
  ///
  /// In en, this message translates to:
  /// **'{p0} is not responding (timeout {p1} s)'**
  String sb6b6fb4fe1(String p0, String p1);

  /// fi: {p0} ei ota yhteyttä vastaan (yhteys evätty)
  ///
  /// In en, this message translates to:
  /// **'{p0} refuses the connection (connection refused)'**
  String s6f71cad9b6(String p0);

  /// fi: {p0} ei ole tavoitettavissa (verkkoyhteyttä ei ole)
  ///
  /// In en, this message translates to:
  /// **'{p0} cannot be reached (no network route)'**
  String sc45478e8fd(String p0);

  /// fi: {p0}: osoitetta ei löydy
  ///
  /// In en, this message translates to:
  /// **'{p0}: the address cannot be found'**
  String s0114e1e46c(String p0);

  /// fi: {p0} hylkäsi tunnuksen (HTTP {p1})
  ///
  /// In en, this message translates to:
  /// **'{p0} rejected the login (HTTP {p1})'**
  String s5c5afb4b38(String p0, String p1);

  /// fi: {p0}: osoite ei kelpaa (HTTP {p1})
  ///
  /// In en, this message translates to:
  /// **'{p0}: the address is not valid (HTTP {p1})'**
  String seb34841f6b(String p0, String p1);

  /// fi: {p0} vastasi virheellä (HTTP {p1})
  ///
  /// In en, this message translates to:
  /// **'{p0} answered with an error (HTTP {p1})'**
  String sf2580c0069(String p0, String p1);

  /// fi: Laitteelle ei ole päälle/pois-komentoa
  ///
  /// In en, this message translates to:
  /// **'The device has no on/off command'**
  String get s0528a2ef9e;

  /// fi: Ohjaus ei onnistunut
  ///
  /// In en, this message translates to:
  /// **'The control did not work'**
  String get sd0e9fc6760;

  /// fi: Tarkista, että laite on päällä ja samassa verkossa kotisillan kanssa. Älykäs lämmitys yrittää uudelleen minuutin välein;
  ///
  /// In en, this message translates to:
  /// **'Check that the device is on and on the same network as the home bridge. Smart heating retries every minute; until it works the device stays in its current state.'**
  String get sc056006180;

  /// fi: Tarkista laitteen salasana yhteyden asetuksista.
  ///
  /// In en, this message translates to:
  /// **'Check the device password in the connection settings.'**
  String get s7a1cda0d24;

  /// fi: Tarkista laitteen osoite ja komento ruudun asetuksista.
  ///
  /// In en, this message translates to:
  /// **'Check the device address and command in the tile settings.'**
  String get s4dc27a3272;

  /// fi: Laite vastasi mutta ei hyväksynyt komentoa. Kokeile käynnistää laite uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The device answered but did not accept the command. Try restarting the device.'**
  String get s54dbdeb56b;

  /// fi: Katso tarkempi syy kohdasta Tekniset tiedot.
  ///
  /// In en, this message translates to:
  /// **'See the exact reason under Technical details.'**
  String get s8e9e56f68f;

  /// fi: Manuaalinen ohitus
  ///
  /// In en, this message translates to:
  /// **'Manual override'**
  String get s7279e2bdb1;

  /// fi: Hinta siirtää tavoitetta
  ///
  /// In en, this message translates to:
  /// **'Price shifts the setpoint'**
  String get s8accab3bb7;

  /// fi: Huone riittävän lämmin
  ///
  /// In en, this message translates to:
  /// **'Room warm enough'**
  String get s78188d956e;

  /// fi: Kalleimpien tuntien ohitus
  ///
  /// In en, this message translates to:
  /// **'Skipping expensive hours'**
  String get saa76f06f20;

  /// fi: Pisin tauko
  ///
  /// In en, this message translates to:
  /// **'Longest break'**
  String get s846c49053e;

  /// fi: Hintatiedot
  ///
  /// In en, this message translates to:
  /// **'Price data'**
  String get se79c5ead71;

  /// fi: Lämpöanturi
  ///
  /// In en, this message translates to:
  /// **'Temperature sensor'**
  String get sa30e1a2c14;

  /// fi: Ei käytössä
  ///
  /// In en, this message translates to:
  /// **'Not in use'**
  String get s39147d043d;

  /// fi: Ei lämpötilaa – ei voi tarkistaa
  ///
  /// In en, this message translates to:
  /// **'No temperature – cannot be checked'**
  String get s7d4144c0a0;

  /// fi: {p0} °C on alle {p1} °C – lämmitys päällä
  ///
  /// In en, this message translates to:
  /// **'{p0} °C is below {p1} °C – heating on'**
  String s70d66e5f81(String p0, String p1);

  /// fi: {p0} °C, raja {p1} °C
  ///
  /// In en, this message translates to:
  /// **'{p0} °C, limit {p1} °C'**
  String sd93442ff7c(String p0, String p1);

  /// fi: Päällä {p0} (asti {p1})
  ///
  /// In en, this message translates to:
  /// **'On for {p0} (until {p1})'**
  String s9bf02da8ca(String p0, String p1);

  /// fi: Pois {p0} (asti {p1})
  ///
  /// In en, this message translates to:
  /// **'Off for {p0} (until {p1})'**
  String sb8c4753e09(String p0, String p1);

  /// fi: Takka lämmittää: sähkölämmitystä vähennetään
  ///
  /// In en, this message translates to:
  /// **'The fireplace heats: electric heating is reduced'**
  String get sc9f92f4156;

  /// fi: Poissa: pidetään {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Away: keeping {p0} °C'**
  String sf78c1a349f(String p0);

  /// fi: Ei voimassa nyt
  ///
  /// In en, this message translates to:
  /// **'Not in force now'**
  String get s5faeeab2c8;

  /// fi: Anturi ei vastaa – {p0}
  ///
  /// In en, this message translates to:
  /// **'The sensor is not answering – {p0}'**
  String s2226c324ef(String p0);

  /// fi: {p0} °C, tavoite {p1} °C ± {p2} °C (päällä alle {p3}, pois yli {p4} °C)
  ///
  /// In en, this message translates to:
  /// **'{p0} °C, setpoint {p1} °C ± {p2} °C (on below {p3}, off above {p4} °C)'**
  String se363372312(String p0, String p1, String p2, String p3, String p4);

  /// fi: Ei muutosta tällä tunnilla
  ///
  /// In en, this message translates to:
  /// **'No change in this hour'**
  String get s0f95c71a7a;

  /// fi: Halpa tunti: tavoite +{p0} °C
  ///
  /// In en, this message translates to:
  /// **'Cheap hour: setpoint +{p0} °C'**
  String sc634878941(String p0);

  /// fi: Kallis tunti: tavoite {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Expensive hour: setpoint {p0} °C'**
  String sedcfc0a927(String p0);

  /// fi: {p0} °C ≥ {p1} °C – ei lämmitetä
  ///
  /// In en, this message translates to:
  /// **'{p0} °C ≥ {p1} °C – not heating'**
  String s642427fe2b(String p0, String p1);

  /// fi: {p0} °C, yläraja {p1} °C
  ///
  /// In en, this message translates to:
  /// **'{p0} °C, upper limit {p1} °C'**
  String sda0b91c359(String p0, String p1);

  /// fi: {p0} halvinta tuntia päivässä: nyt {p1} c/kWh {p2} raja {p3} c
  ///
  /// In en, this message translates to:
  /// **'{p0} cheapest hours a day: now {p1} c/kWh {p2} limit {p3} c'**
  String sf3a33e9bc5(String p0, String p1, String p2, String p3);

  /// fi: {p0} kalleinta tuntia ohitetaan: nyt {p1} c/kWh {p2} raja {p3} c
  ///
  /// In en, this message translates to:
  /// **'{p0} most expensive hours skipped: now {p1} c/kWh {p2} limit {p3} c'**
  String s428ce35d71(String p0, String p1, String p2, String p3);

  /// fi: Ei ennustetta
  ///
  /// In en, this message translates to:
  /// **'No forecast'**
  String get s6200d2086c;

  /// fi: Ennuste keskimäärin {p0} °C → {p1} lämmitystuntia päivässä
  ///
  /// In en, this message translates to:
  /// **'Forecast {p0} °C on average → {p1} heating hours a day'**
  String s29d9986638(String p0, String p1);

  /// fi: Pois ollut liian pitkään – lämmitetään tunti
  ///
  /// In en, this message translates to:
  /// **'Off for too long – heating for an hour'**
  String get sdcf4412899;

  /// fi: Enintään {p0} h kerrallaan pois
  ///
  /// In en, this message translates to:
  /// **'Off for at most {p0} h at a time'**
  String s8a9723fbbb(String p0);

  /// fi: Ei rajoitusta
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get s9fe316f0b6;

  /// fi: Odottaa: vähintään {p0} min
  ///
  /// In en, this message translates to:
  /// **'Waiting: at least {p0} min'**
  String s70094ce99b(String p0);

  /// fi: Vähintään {p0} min
  ///
  /// In en, this message translates to:
  /// **'At least {p0} min'**
  String s71d72597eb(String p0);

  /// fi: Hintoja ei ole – lämmitys toimii tavallisesti
  ///
  /// In en, this message translates to:
  /// **'No prices – heating runs normally'**
  String get s84cf358040;

  /// fi: Hinnat saatu
  ///
  /// In en, this message translates to:
  /// **'Prices available'**
  String get s0e19d6ac09;

  /// fi: Ei anturia valittu
  ///
  /// In en, this message translates to:
  /// **'No sensor chosen'**
  String get s9583d61085;

  /// fi: Ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Not answering'**
  String get s756b49f274;

  /// fi: Vastaa: {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Answering: {p0} °C'**
  String s3ddc69fd91(String p0);

  /// fi: Ei vastaa
  ///
  /// In en, this message translates to:
  /// **'Not responding'**
  String get sa0c950bdca;

  /// fi: Vastaa
  ///
  /// In en, this message translates to:
  /// **'Responding'**
  String get sc3b0eaf426;

  /// fi: lämmitys pidetään päällä
  ///
  /// In en, this message translates to:
  /// **'heating is kept on'**
  String get sa3f65879ff;

  /// fi: lämmitys pidetään pois
  ///
  /// In en, this message translates to:
  /// **'heating is kept off'**
  String get s5906232c68;

  /// fi: noudatetaan hintaohjausta
  ///
  /// In en, this message translates to:
  /// **'following the price schedule'**
  String get sc084b8cbdf;

  /// fi: POIS KÄYTÖSTÄ
  ///
  /// In en, this message translates to:
  /// **'DISABLED'**
  String get s136e7941a4;

  /// fi: Tavoite {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Target {p0} °C'**
  String s8847ee78e0(String p0);

  /// fi: EI VASTAA
  ///
  /// In en, this message translates to:
  /// **'NO REPLY'**
  String get sedcddfbb2f;

  /// fi: PÄÄLLÄ
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get s6ab8f97950;

  /// fi: POIS
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get s509c668d7e;

  /// fi: Ohjaus on pois käytöstä
  ///
  /// In en, this message translates to:
  /// **'Control is switched off'**
  String get s70d43f1209;

  /// fi: Anturi ei vastaa – noudatetaan hintaohjausta:
  ///
  /// In en, this message translates to:
  /// **'Sensor not answering – following the price schedule: '**
  String get s4f7ef5d46a;

  /// fi: Jäätymissuoja: {p0} °C on alle {p1} °C
  ///
  /// In en, this message translates to:
  /// **'Frost protection: {p0} °C is below {p1} °C'**
  String s9e31ebc1e8(String p0, String p1);

  /// fi: Lämpötila {p0} °C alle minimin {p1} °C
  ///
  /// In en, this message translates to:
  /// **'Temperature {p0} °C below the minimum {p1} °C'**
  String s7cdb2a0cb6(String p0, String p1);

  /// fi: Manuaalinen ohitus: päällä{p0}
  ///
  /// In en, this message translates to:
  /// **'Manual override: on{p0}'**
  String sf3b0d012da(String p0);

  /// fi: Manuaalinen ohitus: pois{p0}
  ///
  /// In en, this message translates to:
  /// **'Manual override: off{p0}'**
  String s14be0441f7(String p0);

  /// fi: Takka-tila: sähkölämmitystä vähennetään
  ///
  /// In en, this message translates to:
  /// **'Fireplace mode: electric heating is reduced'**
  String get sd735da4378;

  /// fi: Lomatila: huone pidetään viileämpänä
  ///
  /// In en, this message translates to:
  /// **'Holiday mode: the room is kept cooler'**
  String get s482b48b34c;

  /// fi: Lomatila: lämmitetään paluuta varten
  ///
  /// In en, this message translates to:
  /// **'Holiday mode: heating for your return'**
  String get s6a24d44a71;

  /// fi: Tarpeeksi lämmin ({p0} °C ≥ {p1} °C)
  ///
  /// In en, this message translates to:
  /// **'Warm enough ({p0} °C ≥ {p1} °C)'**
  String s247db88d99(String p0, String p1);

  /// fi: Halpa tunti ({p0} c/kWh ≤ raja {p1} c)
  ///
  /// In en, this message translates to:
  /// **'Cheap hour ({p0} c/kWh ≤ limit {p1} c)'**
  String s0d09da9167(String p0, String p1);

  /// fi: Lämmitetään, ettei tauko veny liian pitkäksi ({p0} c/kWh)
  ///
  /// In en, this message translates to:
  /// **'Heating so that the break does not get too long ({p0} c/kWh)'**
  String sbbcaad0790(String p0);

  /// fi: {p0} c/kWh > raja {p1} c
  ///
  /// In en, this message translates to:
  /// **'{p0} c/kWh > limit {p1} c'**
  String sf56f514430(String p0, String p1);

  /// fi: Kallis tunti – varaava lattia riittää ({p0})
  ///
  /// In en, this message translates to:
  /// **'Expensive hour – the storing floor is enough ({p0})'**
  String s9cdd4b289a(String p0);

  /// fi: Ei halpa tunti – odottaa ({p0})
  ///
  /// In en, this message translates to:
  /// **'Not a cheap hour – waiting ({p0})'**
  String sbf758df617(String p0);

  /// fi: {p0} c/kWh ≥ raja {p1} c
  ///
  /// In en, this message translates to:
  /// **'{p0} c/kWh ≥ limit {p1} c'**
  String s03e2decc6e(String p0, String p1);

  /// fi: Kallis tunti ohitetaan ({p0})
  ///
  /// In en, this message translates to:
  /// **'Expensive hour skipped ({p0})'**
  String s8285023fb8(String p0);

  /// fi: Normaali lämmitys
  ///
  /// In en, this message translates to:
  /// **'Normal heating'**
  String get s8851083ec4;

  /// fi: Ei hintatietoa – lämmitys toimii tavallisesti
  ///
  /// In en, this message translates to:
  /// **'No price data – heating runs normally'**
  String get s452449f24c;

  /// fi: Lämpötila {p0} °C alle tavoitteen {p1} °C – lämmitetään
  ///
  /// In en, this message translates to:
  /// **'Temperature {p0} °C is below the setpoint {p1} °C – heating'**
  String sadbee991d6(String p0, String p1);

  /// fi: Tavoite {p0} °C saavutettu ({p1} °C)
  ///
  /// In en, this message translates to:
  /// **'Setpoint {p0} °C reached ({p1} °C)'**
  String s0e20e8780d(String p0, String p1);

  /// fi: Lämmitetään, kunnes {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Heating until {p0} °C'**
  String s3f74d751fe(String p0);

  /// fi: Pois, kunnes lämpötila laskee alle {p0} °C
  ///
  /// In en, this message translates to:
  /// **'Off until the temperature drops below {p0} °C'**
  String s91276ece64(String p0);

  /// fi: Anturi ei vastaa – lämmitys pidetään päällä
  ///
  /// In en, this message translates to:
  /// **'Sensor not answering – heating is kept on'**
  String get s4437d2666a;

  /// fi: Anturi ei vastaa – lämmitys pidetään pois
  ///
  /// In en, this message translates to:
  /// **'Sensor not answering – heating is kept off'**
  String get s127c973eb9;

  /// fi: Turvaraja: pois liian pitkään – lämmitetään tunti
  ///
  /// In en, this message translates to:
  /// **'Safety limit: off for too long – heating for an hour'**
  String get s7e2afd388e;

  /// fi: Pidetään päällä: vähimmäisaika ei ole täynnä
  ///
  /// In en, this message translates to:
  /// **'Kept on: the minimum on time is not over'**
  String get s630919f15c;

  /// fi: Pidetään pois: vähimmäisaika ei ole täynnä
  ///
  /// In en, this message translates to:
  /// **'Kept off: the minimum off time is not over'**
  String get sf5f33530ca;

  /// fi: Esilämmitys ennen kallista tai kylmää jaksoa
  ///
  /// In en, this message translates to:
  /// **'Pre-heating before an expensive or cold spell'**
  String get sd36f9bf75a;

  /// fi: Säästö kalliina aikana
  ///
  /// In en, this message translates to:
  /// **'Saving while expensive'**
  String get s8ea3994a9b;

  /// fi: Ei tietoa vielä
  ///
  /// In en, this message translates to:
  /// **'No information yet'**
  String get s8ec3c3bdb9;

  /// fi: Seuraava muutos riippuu lämpötilasta
  ///
  /// In en, this message translates to:
  /// **'The next change depends on the temperature'**
  String get sd80668c71a;

  /// fi: Automaattinen ohjaus jatkuu klo {p0}
  ///
  /// In en, this message translates to:
  /// **'Automatic control resumes at {p0}'**
  String s723147d2b2(String p0);

  /// fi: Seuraavaksi päälle klo {p0}
  ///
  /// In en, this message translates to:
  /// **'Next on at {p0}'**
  String sc2c736c508(String p0);

  /// fi: Seuraavaksi pois klo {p0}
  ///
  /// In en, this message translates to:
  /// **'Next off at {p0}'**
  String s2c7a2c7c84(String p0);

  /// fi: Lämpötilaohjaus ja turvarajat (jäätymissuoja, vähimmäislämpötila) eivät ole käytössä, ja {p0}.
  ///
  /// In en, this message translates to:
  /// **'Temperature control and the safety limits (frost protection, minimum temperature) are off, and {p0}.'**
  String s6ebbbbc4a0(String p0);

  /// fi: Turvarajat (jäätymissuoja, vähimmäislämpötila) eivät ole käytössä, ja lämmitys noudattaa hintaohjausta.
  ///
  /// In en, this message translates to:
  /// **'The safety limits (frost protection, minimum temperature) are off, and heating follows the price schedule.'**
  String get sdba1212edb;

  /// fi: Lämpöanturi ei vastaa.
  ///
  /// In en, this message translates to:
  /// **'The temperature sensor is not answering.'**
  String get sbf916076f9;

  /// fi: Tarkista anturin paristo ja verkkoyhteys tai valitse toinen anturi.
  ///
  /// In en, this message translates to:
  /// **'Check the sensor battery and network, or choose another sensor.'**
  String get s9fad63ec58;

  /// fi: Löytyy reitittimen laitelistasta tai valmistajan sovelluksesta (laitteen tiedot). Varaa laitteelle kiinteä IP.
  ///
  /// In en, this message translates to:
  /// **'Find it in your router\'\'s device list or the maker\'\'s app (device info). Reserve a fixed IP for it.'**
  String get s0a81072a1f;

  /// fi: Päälukemat
  ///
  /// In en, this message translates to:
  /// **'Main readings'**
  String get s7c6a740594;

  /// fi: Lisäruudut automaatioihin
  ///
  /// In en, this message translates to:
  /// **'Extra tiles for automations'**
  String get se74bcc1028;

  /// fi: Huawei SUN2000 (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Huawei SUN2000 (Modbus TCP, local)'**
  String get s87d0186621;

  /// fi: SUN2000-invertteri (myös LUNA2000-akku ja DTSU666-mittari) SDonglen kautta kotiverkossa, ilman pilveä.
  ///
  /// In en, this message translates to:
  /// **'SUN2000 inverter (incl. LUNA2000 battery and DTSU666 meter) via the SDongle on your network, no cloud.'**
  String get se7647d6762;

  /// fi: SDonglen IP-osoite. Ota ensin käyttöön FusionSolar-sovelluksessa: Laitekäyttöönotto → Dongle → Modbus TCP = "Ota käyttöö
  ///
  /// In en, this message translates to:
  /// **'The SDongle IP address. First enable it in the FusionSolar app: Device commissioning → Dongle → Modbus TCP = \"Enable (unrestricted)\". Without a dongle: the inverter\'\'s own Wi-Fi, address like 192.168.200.1:6607.'**
  String get sccb0c7d2d8;

  /// fi: Valinnainen: tuotanto FusionSolarin virallisen Northbound-rajapinnan kautta. Päivittyy noin 5 min välein.
  ///
  /// In en, this message translates to:
  /// **'Optional: production through the official FusionSolar Northbound API. Updates about every 5 minutes.'**
  String get sddc831ec16;

  /// fi: Northbound-API-käyttäjä (ei sovelluksen tavallinen tunnus). Asentaja tai pääkäyttäjä luo sen: Järjestelmä → Yritys → Nor
  ///
  /// In en, this message translates to:
  /// **'A Northbound API user (not your normal app login). The installer / admin creates it: System → Company → Northbound management.'**
  String get s4424767fdd;

  /// fi: Tallentuu vain tähän laitteeseen salattuna.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on this device only.'**
  String get s7a7ab0d238;

  /// fi: Selaimen osoiterivin palvelin kun kirjaudut FusionSolariin. Oletus eu5.
  ///
  /// In en, this message translates to:
  /// **'The host in your browser address bar when signed in to FusionSolar. Default eu5.'**
  String get sde3c79670a;

  /// fi: Symo, Primo, Gen24, Tauro – myös Smart Meter ja akku. Valmistajan avoin paikallinen rajapinta, ei pilveä.
  ///
  /// In en, this message translates to:
  /// **'Symo, Primo, Gen24, Tauro – incl. Smart Meter and battery. The maker\'\'s open local API, no cloud.'**
  String get se80d87723d;

  /// fi: {p0} Gen24: ota Solar API käyttöön invertterin web-sivulta (Viestintä → Solar API).
  ///
  /// In en, this message translates to:
  /// **' Gen24: enable the Solar API on the inverter web page (Communication → Solar API).'**
  String s1cb0924dc9(String p0);

  /// fi: SolarEdge-invertteri, mittari ja akku SunSpec Modbusilla kotiverkossa (portti 1502).
  ///
  /// In en, this message translates to:
  /// **'SolarEdge inverter, meter and battery over SunSpec Modbus on your network (port 1502).'**
  String get s1345214178;

  /// fi: {p0} Ota Modbus TCP käyttöön SetApp-sovelluksella: Käyttöönotto → Tiedonsiirto → Modbus TCP.
  ///
  /// In en, this message translates to:
  /// **' Enable Modbus TCP with the SetApp: Commissioning → Communication → Modbus TCP.'**
  String s1f7b006036(String p0);

  /// fi: Valinnainen: tuotanto ja energiavirrat SolarEdgen virallisen monitoring-rajapinnan kautta (päivittyy ~5 min).
  ///
  /// In en, this message translates to:
  /// **'Optional: production and power flow through the official SolarEdge monitoring API (updates ~5 min).'**
  String get s5d43115e7d;

  /// fi: monitoring.solaredge.com → Admin → Site Access → API Access: hyväksy ehdot ja kopioi avain.
  ///
  /// In en, this message translates to:
  /// **'monitoring.solaredge.com → Admin → Site Access → API Access: accept the terms and copy the key.'**
  String get sbe1a020a66;

  /// fi: Sunny Boy, Sunny Tripower, Sunny Boy Storage – SMA:n Modbus-rekisterit kotiverkossa (unit id 3).
  ///
  /// In en, this message translates to:
  /// **'Sunny Boy, Sunny Tripower, Sunny Boy Storage – SMA Modbus registers on your network (unit id 3).'**
  String get s9c5e673c38;

  /// fi: {p0} Ota Modbus käyttöön invertterin web-sivulta: Laitteen parametrit → Ulkoinen tiedonsiirto → Modbus TCP-palvelin.
  ///
  /// In en, this message translates to:
  /// **' Enable Modbus on the inverter web page: Device parameters → External communication → Modbus TCP server.'**
  String s4fad533521(String p0);

  /// fi: SMA Energy Meter / Home Manager (Speedwire, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'SMA Energy Meter / Home Manager (Speedwire, local)'**
  String get s528ecf3140;

  /// fi: Verkosta osto ja myynti suoraan mittarin Speedwire-lähetyksistä – ei kirjautumista eikä pilveä.
  ///
  /// In en, this message translates to:
  /// **'Grid import and export straight from the meter\'\'s Speedwire broadcasts – no login, no cloud.'**
  String get sa7e3cb3d48;

  /// fi: Mittari löytyy automaattisesti samasta kotiverkosta. Jos haku ei löydä sitä, kirjoita mittarin IP-osoite (luku tulee sil
  ///
  /// In en, this message translates to:
  /// **'The meter is found automatically on the same home network. If the search misses it, type the meter IP (readings still come from its broadcasts).'**
  String get s126a0713b8;

  /// fi: Growatt (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Growatt (Modbus TCP, local)'**
  String get sbdf4d24f64;

  /// fi: MIN/MOD/SPH-invertterit RS485→TCP-muuntimen (tai Modbus TCP:tä tukevan ShineLan-X:n) kautta. Tarkista lukemat.
  ///
  /// In en, this message translates to:
  /// **'MIN/MOD/SPH inverters via an RS485→TCP gateway (or a ShineLan-X with Modbus TCP). Verify the readings.'**
  String get s6c5156d740;

  /// fi: RS485→Modbus TCP -muuntimen IP-osoite (esim. Elfin EW11, Waveshare). Kytketään invertterin RS485/COM-liittimeen.
  ///
  /// In en, this message translates to:
  /// **'IP of the RS485→Modbus TCP gateway (e.g. Elfin EW11, Waveshare) wired to the inverter RS485/COM port.'**
  String get se351eda9ce;

  /// fi: Valinnainen: tuotanto Growattin OpenAPI:n kautta (ShinePhone/ShineServer-tili). Päivittyy ~5 min.
  ///
  /// In en, this message translates to:
  /// **'Optional: production through the Growatt OpenAPI (ShinePhone/ShineServer account). Updates ~5 min.'**
  String get s06257dd63c;

  /// fi: Pyydä token Growattin tuesta tai asentajalta (OpenAPI), tai ShineServerin asetuksista jos se näkyy.
  ///
  /// In en, this message translates to:
  /// **'Ask Growatt support or your installer for an OpenAPI token, or find it in ShineServer settings if shown.'**
  String get sbd8c9831bb;

  /// fi: Kostal, Fronius (Modbus), SMA (SunSpec), ABB/FIMER, Sungrow-mittarit… Mikä tahansa SunSpec-laite.
  ///
  /// In en, this message translates to:
  /// **'Kostal, Fronius (Modbus), SMA (SunSpec), ABB/FIMER… Any SunSpec device.'**
  String get s3c89bd3976;

  /// fi: {p0} Portti oletuksena 502 – muu portti muodossa 192.168.1.20:1502.
  ///
  /// In en, this message translates to:
  /// **' Port 502 by default – another port like 192.168.1.20:1502.'**
  String s183e57cdfd(String p0);

  /// fi: Huawei, Fronius, SolarEdge, SMA, Growatt – tuotanto, verkko ja akku. Paikallisesti, pilvi valinnainen.
  ///
  /// In en, this message translates to:
  /// **'Huawei, Fronius, SolarEdge, SMA, Growatt – production, grid and battery. Local, cloud optional.'**
  String get s984804da72;

  /// fi: Tiedot päivitetty
  ///
  /// In en, this message translates to:
  /// **'Data updated'**
  String get s5a9f34e4c2;

  /// fi: Tietohaku ei onnistunut
  ///
  /// In en, this message translates to:
  /// **'Data fetch failed'**
  String get s3acea7ff5a;

  /// fi: {p0} – yritetään uudelleen
  ///
  /// In en, this message translates to:
  /// **'{p0} – retrying'**
  String s0cfb3a816e(String p0);

  /// fi: OCPP 1.6J (paikallinen, mikä tahansa merkki)
  ///
  /// In en, this message translates to:
  /// **'OCPP 1.6J (local, any brand)'**
  String get s68e2e87750;

  /// fi: Easee (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Easee (cloud)'**
  String get s66fb236f0c;

  /// fi: Zaptec (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Zaptec (cloud)'**
  String get s3809be512f;

  /// fi: Wallbox (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Wallbox (cloud)'**
  String get s90c71e52fb;

  /// fi: Sähköauton laturi (oma integraatio)
  ///
  /// In en, this message translates to:
  /// **'EV charger (built-in integration)'**
  String get s7c3abc09fc;

  /// fi: OCPP toimii paikallisesti ilman pilveä (laturi ottaa yhteyden tähän sovellukseen tai siltaan).
  ///
  /// In en, this message translates to:
  /// **'OCPP works locally without a cloud (the charger connects to this app or the bridge).'**
  String get se6885155b4;

  /// fi: OCPP-portti
  ///
  /// In en, this message translates to:
  /// **'OCPP port'**
  String get sb14c49378c;

  /// fi: Portti, jota tämä laite kuuntelee. Laturin osoite: ws://<tämän laitteen IP>:9000/ocpp/
  ///
  /// In en, this message translates to:
  /// **'The port this device listens on. Charger URL: ws://<this device IP>:9000/ocpp/'**
  String get sa9346504d4;

  /// fi: Laturin tunnus (OCPP)
  ///
  /// In en, this message translates to:
  /// **'Charge point id (OCPP)'**
  String get sf94b2ba7f3;

  /// fi: Laturin OCPP-tunnus (charge point id). Tyhjä = ensimmäinen yhteyden ottanut.
  ///
  /// In en, this message translates to:
  /// **'The charger\'\'s OCPP charge point id. Empty = the first one that connects.'**
  String get s8ea8831ed0;

  /// fi: Tunniste (idTag) etäkäynnistykseen
  ///
  /// In en, this message translates to:
  /// **'idTag for remote start'**
  String get sa3b3822b75;

  /// fi: Lähetetään RemoteStartTransactionissa. Tyhjä = "molaplan".
  ///
  /// In en, this message translates to:
  /// **'Sent with RemoteStartTransaction. Empty = \"molaplan\".'**
  String get sf718534954;

  /// fi: Käyttäjätunnus / sähköposti (pilvi)
  ///
  /// In en, this message translates to:
  /// **'Username / e-mail (cloud)'**
  String get s540a178f7a;

  /// fi: Sama kuin valmistajan sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'Same as in the maker\'\'s app.'**
  String get s98c928f06c;

  /// fi: Pilvi: sovelluksen salasana. OCPP: valinnainen Basic auth -salasana. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'Cloud: the app password. OCPP: optional Basic auth password. Stored on this device only.'**
  String get sa6b5175654;

  /// fi: Mikä laturin lukema näytetään.
  ///
  /// In en, this message translates to:
  /// **'Which charger reading to show.'**
  String get sccb2892754;

  /// fi: Tila
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get s0e7115e10c;

  /// fi: Lataa (1/0)
  ///
  /// In en, this message translates to:
  /// **'Charging (1/0)'**
  String get s20cb072267;

  /// fi: Latausteho (W)
  ///
  /// In en, this message translates to:
  /// **'Charging power (W)'**
  String get se13ff56722;

  /// fi: Tämä lataus (kWh)
  ///
  /// In en, this message translates to:
  /// **'This session (kWh)'**
  String get sd3627e3a20;

  /// fi: Yhteensä (kWh)
  ///
  /// In en, this message translates to:
  /// **'Total (kWh)'**
  String get s19e058622f;

  /// fi: Virtaraja (A)
  ///
  /// In en, this message translates to:
  /// **'Current limit (A)'**
  String get s613785b80f;

  /// fi: Laturin tunnus
  ///
  /// In en, this message translates to:
  /// **'Charger id'**
  String get s60f4e2786f;

  /// fi: Tilin laturin tunnus; tyhjä = ainoa laturi.
  ///
  /// In en, this message translates to:
  /// **'Charger id in the account; empty = the only charger.'**
  String get sfbbd0943a8;

  /// fi: Aloita, lopeta tai aseta virtaraja.
  ///
  /// In en, this message translates to:
  /// **'Start, stop or set the current limit.'**
  String get s9617db1f3d;

  /// fi: Aloita lataus
  ///
  /// In en, this message translates to:
  /// **'Start charging'**
  String get sc110ab773a;

  /// fi: Lopeta / tauko
  ///
  /// In en, this message translates to:
  /// **'Stop / pause'**
  String get s44d11f741f;

  /// fi: Lataus päälle/pois
  ///
  /// In en, this message translates to:
  /// **'Charging on/off'**
  String get s4c68e739b0;

  /// fi: Aseta virtaraja (A)
  ///
  /// In en, this message translates to:
  /// **'Set current limit (A)'**
  String get s141fac7235;

  /// fi: Virtaraja ampeereina; {{value}} = liukusäätimen arvo.
  ///
  /// In en, this message translates to:
  /// **'\'Current limit in amps; {{value}} = the slider value.\''**
  String get s33f04bfedd;

  /// fi: Laturia "{p0}" ei löydy (ei yhteyttä tai poistettu tililtä)
  ///
  /// In en, this message translates to:
  /// **'Charger \"{p0}\" not found (offline or removed)'**
  String s610172c6f4(String p0);

  /// fi: Virtaraja puuttuu
  ///
  /// In en, this message translates to:
  /// **'Current limit missing'**
  String get sf51ef628f4;

  /// fi: Ei latureita
  ///
  /// In en, this message translates to:
  /// **'No chargers'**
  String get sd661432e07;

  /// fi: ladattu yhteensä
  ///
  /// In en, this message translates to:
  /// **'total charged'**
  String get s47aba73804;

  /// fi: lataus
  ///
  /// In en, this message translates to:
  /// **'charging'**
  String get sed9640f6b4;

  /// fi: latausteho
  ///
  /// In en, this message translates to:
  /// **'charging power'**
  String get sebaaf2a20f;

  /// fi: tämä lataus
  ///
  /// In en, this message translates to:
  /// **'this session'**
  String get s223d1336d5;

  /// fi: virtaraja
  ///
  /// In en, this message translates to:
  /// **'current limit'**
  String get sbea289dcc3;

  /// fi: OCPP-palvelinta ei voitu käynnistää porttiin {p0}: {p1}
  ///
  /// In en, this message translates to:
  /// **'Could not start the OCPP server on port {p0}: {p1}'**
  String s2d551049ff(String p0, String p1);

  /// fi: Laturi "{p0}" ei ole ottanut yhteyttä. Aseta laturin OCPP-osoitteeksi ws://<tämän laitteen IP>:{p1}/ocpp/
  ///
  /// In en, this message translates to:
  /// **'Charger \"{p0}\" has not connected. Set its OCPP URL to ws://<this device IP>:{p1}/ocpp/'**
  String s9a6813045a(String p0, String p1);

  /// fi: Laturi ei lataa nyt
  ///
  /// In en, this message translates to:
  /// **'The charger is not charging now'**
  String get sb33d4d8b62;

  /// fi: Ei autoa
  ///
  /// In en, this message translates to:
  /// **'No car'**
  String get sb75700bbba;

  /// fi: Auto kytketty
  ///
  /// In en, this message translates to:
  /// **'Car connected'**
  String get s5a3fcd56de;

  /// fi: Lataa
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get s23910a6fb5;

  /// fi: Tauolla
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get s22cd08064f;

  /// fi: Valmis
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get s5b8b3042ec;

  /// fi: Vika
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get s84df123d5a;

  /// fi: Wallbox, Alfen, ABB, go-e, Etrel, Easee/Zaptec (OCPP päälle)… Laturi ottaa yhteyden suoraan Molaplaniin – ei pilveä.
  ///
  /// In en, this message translates to:
  /// **'Wallbox, Alfen, ABB, go-e, Etrel, Easee/Zaptec (OCPP on)… The charger connects straight to Molaplan – no cloud.'**
  String get s12fa00013a;

  /// fi: Jos laturissa on asetettu Basic auth -salasana. Yleensä tyhjä.
  ///
  /// In en, this message translates to:
  /// **'If the charger has a Basic auth password set. Usually empty.'**
  String get s4bc8fc306b;

  /// fi: Easee Home / Charge / One Easee-tilin kautta: tila, aloitus/lopetus ja virtaraja.
  ///
  /// In en, this message translates to:
  /// **'Easee Home / Charge / One through your Easee account: status, start/stop and current limit.'**
  String get s8c376593cb;

  /// fi: Sama kuin Easee-sovelluksessa (puhelin muodossa +358…).
  ///
  /// In en, this message translates to:
  /// **'Same as in the Easee app (phone as +358…).'**
  String get s827730d443;

  /// fi: Zaptec Go / Home / Pro Zaptec-tilin kautta. Aloitus/tauko vaatii omistajan oikeudet.
  ///
  /// In en, this message translates to:
  /// **'Zaptec Go / Home / Pro through your Zaptec account. Start/pause needs owner rights.'**
  String get se1a5b725a4;

  /// fi: Pulsar, Commander, Copper myWallbox-tilin kautta. Paikallisesti: valitse OCPP.
  ///
  /// In en, this message translates to:
  /// **'Pulsar, Commander, Copper through your myWallbox account. Locally: pick OCPP.'**
  String get s72dc0a7687;

  /// fi: Easee, Zaptec, Wallbox – tai mikä tahansa OCPP-laturi paikallisesti. Lataus ylijäämällä tai halvalla.
  ///
  /// In en, this message translates to:
  /// **'Easee, Zaptec, Wallbox – or any OCPP charger locally. Charge on surplus or when cheap.'**
  String get s59ed724e14;

  /// fi: airCloud: kirjautuminen epäonnistui
  ///
  /// In en, this message translates to:
  /// **'airCloud: sign-in failed'**
  String get se62d52c336;

  /// fi: airCloud: laitetta ei löydy
  ///
  /// In en, this message translates to:
  /// **'airCloud: unit not found'**
  String get sc5f4490c42;

  /// fi: outo vastaus
  ///
  /// In en, this message translates to:
  /// **'odd answer'**
  String get s14e68f6852;

  /// fi: Toshiba: väärä käyttäjätunnus tai salasana
  ///
  /// In en, this message translates to:
  /// **'Toshiba: wrong username or password'**
  String get s8f016f0e29;

  /// fi: myUplink: väärä Client ID tai Secret
  ///
  /// In en, this message translates to:
  /// **'myUplink: wrong Client ID or Secret'**
  String get s4558be4f09;

  /// fi: Maalämpöpumpun tilaa ei vaihdeta täältä – vain asetusarvo.
  ///
  /// In en, this message translates to:
  /// **'The mode of a ground-source pump is not changed here – only the setpoint.'**
  String get s370bf1904d;

  /// fi: Midea: väärä token tai key
  ///
  /// In en, this message translates to:
  /// **'Midea: wrong token or key'**
  String get sb795949130;

  /// fi: yhteys aikakatkaistiin
  ///
  /// In en, this message translates to:
  /// **'connect timeout'**
  String get sd6b2f21f4a;

  /// fi: Midea V3 tarvitsee tokenin (128 merkkiä) ja keyn (64 merkkiä)
  ///
  /// In en, this message translates to:
  /// **'Midea V3 needs a token (128 hex characters) and a key (64 hex characters)'**
  String get s6831eae697;

  /// fi: Midea: laite ei hyväksynyt tokenia ja keytä (tarkista ne)
  ///
  /// In en, this message translates to:
  /// **'Midea: the device did not accept the token and key (check them)'**
  String get s22a358f420;

  /// fi: Midea: laite ei lähettänyt tilatietoa
  ///
  /// In en, this message translates to:
  /// **'Midea: the device sent no state'**
  String get s01f1dab4e3;

  /// fi: Löytyy reitittimen laitelistasta tai valmistajan sovelluksesta (laitteen tiedot).
  ///
  /// In en, this message translates to:
  /// **'Find it in your router\'\'s device list or the maker\'\'s app (device info).'**
  String get s6d21845355;

  /// fi: Tämä laite (V3) tarvitsee laitekohtaisen tokenin ja keyn. Syötä ne, tai syötä oma Midea NetHome Plus -tilisi (sähköposti
  ///
  /// In en, this message translates to:
  /// **'This unit (V3) needs a per-device token and key. Enter them, or enter your own Midea NetHome Plus account (e-mail and password) and Molaplan fetches them once from the Midea cloud. If the account was rejected, check the details. The token and key never go to Molaplan\'\'s servers.'**
  String get s2a9d28aac1;

  /// fi: Inventor ilmalämpöpumppu (INVmate II, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Inventor air conditioner (INVmate II, local)'**
  String get s0fa435dd3b;

  /// fi: Inventor-ilmalämpöpumput, joita ohjataan INVmate II -sovelluksella (wifi-moduuli EU-OSK105 tms.). Sama Midea LAN -protok
  ///
  /// In en, this message translates to:
  /// **'Inventor air conditioners controlled with the INVmate II app (Wi-Fi module EU-OSK105 or similar). The same Midea LAN protocol also works for Midea, Comfee and other Midea-built units. Local, no cloud.'**
  String get s355759f7fd;

  /// fi: Laitteen IP-osoite reitittimen laitelistasta (nimi usein "midea_ac_…"). Haku löytää sen yleensä itse.
  ///
  /// In en, this message translates to:
  /// **'The unit\'\'s IP from your router\'\'s device list (often named \"midea_ac_…\"). The search normally finds it by itself.'**
  String get sfe4d46ec2d;

  /// fi: Uudemmat laitteet (V3) tarvitsevat laitekohtaisen tokenin ja keyn. Jos et tiedä niitä, kirjoita alle oma Midea NetHome P
  ///
  /// In en, this message translates to:
  /// **'Newer units (V3) need a per-device token and key. If you do not have them, enter your own Midea NetHome Plus account below and they are fetched once.'**
  String get s08091212d0;

  /// fi: Tokenin pari.
  ///
  /// In en, this message translates to:
  /// **'The token\'\'s partner.'**
  String get s0866bdcde6;

  /// fi: Ilmainen tili NetHome Plus -sovelluksessa (Midea). Käytetään vain tokenin ja keyn hakuun kerran; salasanaa ei tallenneta
  ///
  /// In en, this message translates to:
  /// **'A free account in the NetHome Plus app (Midea). Used only to fetch the token and key once; the password is not stored.'**
  String get se0474ca270;

  /// fi: Vain avainten hakuun. Ei tallennu laitteen asetuksiin.
  ///
  /// In en, this message translates to:
  /// **'Only to fetch the keys. Not saved in the connection.'**
  String get sc69d2abc31;

  /// fi: Tarvitaan laitteen paikallinen avain (local key, 16 merkkiä) – kirjoita se, tai täytä oman ilmaisen Tuya-kehittäjäprojek
  ///
  /// In en, this message translates to:
  /// **'The unit\'\'s local key (16 characters) is needed – type it, or fill in the Access ID and Secret of your own free Tuya developer project and the key is fetched once. If the key was rejected, check it and the device id. The key never goes to Molaplan\'\'s servers.'**
  String get scea357a8db;

  /// fi: Inventor ilmalämpöpumppu (Inventor Control, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Inventor air conditioner (Inventor Control, local)'**
  String get s1737dca975;

  /// fi: Inventor-ilmalämpöpumput, joita ohjataan Inventor Control -sovelluksella (malleja mm. Leon, Legend, Comfort, Supreme, Ve
  ///
  /// In en, this message translates to:
  /// **'Inventor air conditioners controlled with the Inventor Control app (e.g. Leon, Legend, Comfort, Supreme, Vero). The app is Tuya-based; control on your home network without the cloud. Needs the unit\'\'s local key once.'**
  String get s568208217c;

  /// fi: Laitteen IP-osoite reitittimen laitelistasta. Haku löytää sen yleensä itse.
  ///
  /// In en, this message translates to:
  /// **'The unit\'\'s IP from your router\'\'s device list. The search normally finds it by itself.'**
  String get s0ef75068ac;

  /// fi: 16 merkin avain. Jos et tiedä sitä, täytä alla oma Tuya-kehittäjäprojektisi tunnukset, niin se haetaan kerran. Uusimmat
  ///
  /// In en, this message translates to:
  /// **'A 16-character key. If you do not have it, fill in your own Tuya developer project below and it is fetched once. The newest Inventor Control units cannot always be linked to the Tuya app – then the key has to be obtained another way (see docs/INVENTOR.md).'**
  String get s7455130634;

  /// fi: Täytetään automaattisesti, jos laite löytyi verkosta.
  ///
  /// In en, this message translates to:
  /// **'Filled in automatically when the unit was found on the network.'**
  String get s4b053856e0;

  /// fi: 3.3, 3.4 tai 3.5. Jos jätät tyhjäksi, kokeillaan kaikki.
  ///
  /// In en, this message translates to:
  /// **'3.3, 3.4 or 3.5. If left empty all are tried.'**
  String get s3761f46313;

  /// fi: Oma ilmainen Tuya-kehittäjäprojekti (iot.tuya.com → Cloud → Create Cloud Project → Devices → Link App Account). Sovelluk
  ///
  /// In en, this message translates to:
  /// **'Your own free Tuya developer project (iot.tuya.com → Cloud → Create Cloud Project → Devices → Link App Account). Use the Tuya Smart / Smart Life app the unit was added to.'**
  String get s5b0069af62;

  /// fi: Samalta projektin sivulta. Ei tallennu.
  ///
  /// In en, this message translates to:
  /// **'From the same project page. Not saved.'**
  String get s96dbe019ed;

  /// fi: Projektin data center, Euroopassa yleensä eu.
  ///
  /// In en, this message translates to:
  /// **'The project\'\'s data center, usually eu in Europe.'**
  String get s1573c32bab;

  /// fi: Pumppu ei vastannut oletusasetuksilla (portti 502, Modbus-osoite 1, sekä Modbus TCP että läpinäkyvä RTU). Tarkista muunt
  ///
  /// In en, this message translates to:
  /// **'The pump did not answer with the defaults (port 502, Modbus address 1, both Modbus TCP and transparent RTU). Check the converter\'\'s IP and type below the converter\'\'s port, the pump\'\'s Modbus address (DIP switches of the hydraulic module) and mode if they differ. RS-485: A/B to the wired controller\'\'s H1/H2 terminals, 9600 baud, 8 data bits, no parity, 1 stop bit.'**
  String get s18e2dce10d;

  /// fi: Inventor ilma-vesilämpöpumppu (Modbus RS-485)
  ///
  /// In en, this message translates to:
  /// **'Inventor air-to-water heat pump (Modbus RS-485)'**
  String get s3d0c432194;

  /// fi: Inventor-ilma-vesilämpöpumput (monoblock-sarjat ja hydromoduulit). Ohjaus pumpun langallisen ohjaimen RS-485-liitännän (
  ///
  /// In en, this message translates to:
  /// **'Inventor air-to-water heat pumps (monoblock series and hydro modules). Control through the RS-485 port (H1/H2) of the pump\'\'s wired controller with a cheap RS-485–Ethernet/Wi-Fi converter: mode, setpoint, hot water, water and outdoor temperature. Local, no cloud.'**
  String get s299d1b40fe;

  /// fi: RS-485–Modbus-muuntimen IP-osoite (esim. Waveshare, Elfin EW11, USR-TCP232). Sitä ei löydy haulla – kirjoita osoite.
  ///
  /// In en, this message translates to:
  /// **'IP of the RS-485–Modbus converter (e.g. Waveshare, Elfin EW11, USR-TCP232). It cannot be searched – type the address.'**
  String get s158de9d34a;

  /// fi: Muuntimen Modbus-portti, yleensä 502 (joillain 8899 tai 23).
  ///
  /// In en, this message translates to:
  /// **'The converter\'\'s Modbus port, usually 502 (some use 8899 or 23).'**
  String get sbe411b8e53;

  /// fi: Sama kuin hydromoduulin DIP-kytkimillä asetettu osoite, oletus 1.
  ///
  /// In en, this message translates to:
  /// **'The address set with the DIP switches of the hydraulic module, default 1.'**
  String get s1f7582a270;

  /// fi: Jätä tyhjäksi: kokeillaan sekä Modbus TCP että läpinäkyvä RTU. Muuntimen asetus 9600 baud, 8 databittiä, ei pariteettia,
  ///
  /// In en, this message translates to:
  /// **'Leave empty: both Modbus TCP and transparent RTU are tried. Set the converter to 9600 baud, 8 data bits, no parity, 1 stop bit.'**
  String get sa51903d6fa;

  /// fi: Daikin (wifi, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Daikin (Wi-Fi, local)'**
  String get s4a91d07711;

  /// fi: Daikin-ilmalämpöpumppu wifi-ohjaimella (BRP069, BRP072C, Airbase). Toimii ilman pilveä, haetaan verkosta.
  ///
  /// In en, this message translates to:
  /// **'Daikin with a Wi-Fi adapter (BRP069, BRP072C, Airbase). Works without the cloud; found on the network.'**
  String get s8e339844a9;

  /// fi: Uudemmissa BRP072C-ohjaimissa 13-numeroinen avain on ohjaimen tarrassa. Vanhemmat eivät tarvitse sitä.
  ///
  /// In en, this message translates to:
  /// **'Newer BRP072C adapters: the 13-digit key is on the adapter sticker. Older ones need none.'**
  String get sdb368f83d9;

  /// fi: Mitsubishi Heavy (Smart M-Air, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Mitsubishi Heavy (Smart M-Air, local)'**
  String get s2089a88d1f;

  /// fi: MHI-ilmalämpöpumppu WF-RAC-wifimoduulilla (Smart M-Air -sovellus). Paikallinen ohjaus ilman pilveä.
  ///
  /// In en, this message translates to:
  /// **'MHI heat pump with the WF-RAC Wi-Fi module (Smart M-Air app). Local control, no cloud.'**
  String get se19c918d2d;

  /// fi: Mitsubishi Electric (MELCloud)
  ///
  /// In en, this message translates to:
  /// **'Mitsubishi Electric (MELCloud)'**
  String get s050c379c67;

  /// fi: Ilmalämpöpumput ja Ecodan-ilma-vesipumput MELCloud-tilin kautta, mistä tahansa.
  ///
  /// In en, this message translates to:
  /// **'Air-to-air and Ecodan air-to-water pumps through your MELCloud account, from anywhere.'**
  String get sc24b0de42d;

  /// fi: Sama kuin MELCloud-sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'Same as in the MELCloud app.'**
  String get s41d69e699d;

  /// fi: Toshiba (Home AC Control)
  ///
  /// In en, this message translates to:
  /// **'Toshiba (Home AC Control)'**
  String get s339fd47e4a;

  /// fi: Toshiban wifi-ilmalämpöpumput Toshiba Home AC Control -tilin kautta.
  ///
  /// In en, this message translates to:
  /// **'Toshiba Wi-Fi heat pumps through your Toshiba Home AC Control account.'**
  String get sa8405bf705;

  /// fi: Sama kuin Toshiba Home AC Control -sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'Same as in the Toshiba app.'**
  String get s703279c03e;

  /// fi: Samsung (SmartThings)
  ///
  /// In en, this message translates to:
  /// **'Samsung (SmartThings)'**
  String get sf71a945a1d;

  /// fi: Samsungin wifi-ilmalämpöpumput SmartThingsin virallisen rajapinnan kautta.
  ///
  /// In en, this message translates to:
  /// **'Samsung Wi-Fi heat pumps through the official SmartThings API.'**
  String get se26b321a29;

  /// fi: Luo osoitteessa account.smartthings.com/tokens: valitse "Devices" (lue ja ohjaa). Huom: Samsung rajoittaa uudet tunnukse
  ///
  /// In en, this message translates to:
  /// **'Create one at account.smartthings.com/tokens with the Devices scopes. Note: Samsung limits new tokens to 24 hours.'**
  String get s550793ea4a;

  /// fi: Hitachi (airCloud Go)
  ///
  /// In en, this message translates to:
  /// **'Hitachi (airCloud Go)'**
  String get sf7aed9c9e0;

  /// fi: Hitachin ilmalämpöpumput airCloud Go -tilin kautta.
  ///
  /// In en, this message translates to:
  /// **'Hitachi heat pumps through your airCloud Go account.'**
  String get se2f1cb488d;

  /// fi: NIBE (myUplink-pilvi)
  ///
  /// In en, this message translates to:
  /// **'NIBE (myUplink cloud)'**
  String get sb33215fa8b;

  /// fi: NIBE-maalämpö- ja poistoilmapumput myUplinkin virallisen rajapinnan kautta (myös CTC, Høiax…).
  ///
  /// In en, this message translates to:
  /// **'NIBE ground-source and exhaust-air pumps through the official myUplink API (also CTC, Høiax…).'**
  String get s2e3665e309;

  /// fi: Kirjaudu dev.myuplink.com → Applications → Create (Callback URL voi olla esim. https://molaplan.com). Kopioi Client Iden
  ///
  /// In en, this message translates to:
  /// **'Sign in at dev.myuplink.com → Applications → Create. Copy the Client Identifier.'**
  String get sf2e635afad;

  /// fi: Samalta sivulta.
  ///
  /// In en, this message translates to:
  /// **'From the same page.'**
  String get s9db9eb22f8;

  /// fi: NIBE S-sarja (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'NIBE S-series (Modbus TCP, local)'**
  String get s412987475c;

  /// fi: S1155, S1255, SMO S40… Ota Modbus TCP käyttöön pumpun valikosta 7.5.9. Ei pilveä.
  ///
  /// In en, this message translates to:
  /// **'S1155, S1255, SMO S40… Enable Modbus TCP in the pump menu 7.5.9. No cloud.'**
  String get s3fc8f4ce0d;

  /// fi: Pumpun IP-osoite: valikko 3.1.13 (Yhteydet) tai reitittimen laitelista.
  ///
  /// In en, this message translates to:
  /// **'The pump\'\'s IP: menu 3.1.13 (Connections) or your router\'\'s device list.'**
  String get s9b15cf6f63;

  /// fi: NIBE F-sarja + MODBUS 40 (paikallinen)
  ///
  /// In en, this message translates to:
  /// **'NIBE F-series + MODBUS 40 (local)'**
  String get s29ed152759;

  /// fi: F1145/F1155/F1255/F750/SMO + MODBUS 40 -lisävaruste ja RS485→TCP-muunnin. Tarkista rekisterit.
  ///
  /// In en, this message translates to:
  /// **'F-series / SMO with the MODBUS 40 accessory and an RS485→TCP gateway. Verify the registers.'**
  String get sa723788d3c;

  /// fi: RS485→Modbus TCP -muuntimen IP-osoite.
  ///
  /// In en, this message translates to:
  /// **'IP address of the RS485→Modbus TCP gateway.'**
  String get sb001c51087;

  /// fi: Thermia (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Thermia (Modbus TCP, local)'**
  String get sde4b0f4525;

  /// fi: Thermia Atlas, Calibra, Diplomat Inverter, Mega (Genesis). Modbus TCP: Asetukset → BMS.
  ///
  /// In en, this message translates to:
  /// **'Thermia Atlas, Calibra, Diplomat Inverter, Mega (Genesis). Modbus TCP: Settings → BMS.'**
  String get s9280f807a6;

  /// fi: Pumpun IP-osoite (näytöltä tai reitittimestä).
  ///
  /// In en, this message translates to:
  /// **'The pump\'\'s IP address (display or router).'**
  String get scab35073e8;

  /// fi: Bosch / Buderus lämmitys (KM200-yhdyskäytävä, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Bosch / Buderus heating (KM200 gateway, local)'**
  String get s6ad1f33b9a;

  /// fi: Kaasu-/öljykattilat ja lämpöpumput, joissa on Logamatic web KM50/KM100/KM200/KM300 -yhdyskäytävä (Bosch, Buderus, Junker
  ///
  /// In en, this message translates to:
  /// **'Boilers and heat pumps with a Logamatic web KM50/KM100/KM200/KM300 gateway (Bosch, Buderus, Junkers, IVT). Local, no cloud, no fees.'**
  String get sd3415a288c;

  /// fi: KM-yhdyskäytävän IP-osoite reitittimen laitelistasta (nimi usein "KM200" tai sarjanumero).
  ///
  /// In en, this message translates to:
  /// **'The KM gateway\'\'s IP from your router\'\'s device list (often named \"KM200\" or its serial).'**
  String get s87ab70204b;

  /// fi: Yhdyskäytävän tarrassa tai lämmityslaitteen valikossa: Info → Internet → Kirjautumistiedot.
  ///
  /// In en, this message translates to:
  /// **'On the gateway sticker or in the boiler menu: Info → Internet → Login data.'**
  String get s85e666e6d0;

  /// fi: Salasana, jonka asetit valmistajan sovelluksessa (MyDevice, EasyControl tai Buderus-sovellus).
  ///
  /// In en, this message translates to:
  /// **'The password you set in the maker\'\'s app (MyDevice, EasyControl or the Buderus app).'**
  String get s7af1e0507c;

  /// fi: Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE, Thermia, Inventor – tai mikä tahansa IR-kaukosäätimellä.
  ///
  /// In en, this message translates to:
  /// **'Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE, Thermia, Inventor – or any with an IR remote.'**
  String get s6b99f7c0e5;

  /// fi: Ei laitteita
  ///
  /// In en, this message translates to:
  /// **'No units found'**
  String get s9622976fd3;

  /// fi: laitetta
  ///
  /// In en, this message translates to:
  /// **'unit(s)'**
  String get sa93876ac9d;

  /// fi: liian monta pyyntöä
  ///
  /// In en, this message translates to:
  /// **'too many requests'**
  String get sf3d77f10b9;

  /// fi: Tila "{p0}" ei ole käytössä tässä pumpussa
  ///
  /// In en, this message translates to:
  /// **'Mode \"{p0}\" is not available on this pump'**
  String s2c5094f4e4(String p0);

  /// fi: Ilma-vesipumpulla ei ole puhallinasetusta
  ///
  /// In en, this message translates to:
  /// **'An air-to-water pump has no fan setting'**
  String get sb6729e0077;

  /// fi: MELCloud: väärä sähköposti tai salasana
  ///
  /// In en, this message translates to:
  /// **'MELCloud: wrong e-mail or password'**
  String get s00c7f00681;

  /// fi: Tätä pumppua ei kytketä päälle/pois Modbusilla.
  ///
  /// In en, this message translates to:
  /// **'This pump is not switched on/off over Modbus.'**
  String get s4bd0e3110e;

  /// fi: Daikin hylkäsi pyynnön – tarkista avain (key) tarrasta.
  ///
  /// In en, this message translates to:
  /// **'Daikin refused – check the key on the sticker.'**
  String get sc2474a4b0b;

  /// fi: Daikin ei hyväksynyt avainta (key).
  ///
  /// In en, this message translates to:
  /// **'Daikin did not accept the key.'**
  String get s2f7a41de7a;

  /// fi: Daikin-ohjainta ei löytynyt osoitteesta {p0}
  ///
  /// In en, this message translates to:
  /// **'No Daikin adapter at {p0}'**
  String sc499fab53f(String p0);

  /// fi: Tämä malli ei tue puhaltimen automaattitilaa
  ///
  /// In en, this message translates to:
  /// **'This model has no automatic fan mode'**
  String get s642f888a5f;

  /// fi: Tämä ei näytä ilmastointilaitteelta (ei virta-datapistettä)
  ///
  /// In en, this message translates to:
  /// **'This does not look like an air conditioner (no power data point)'**
  String get s77890f9215;

  /// fi: Daikin (paikallinen wifi)
  ///
  /// In en, this message translates to:
  /// **'Daikin (local Wi-Fi)'**
  String get s4cfb5a36c9;

  /// fi: NIBE / Thermia (Modbus TCP, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'NIBE / Thermia (Modbus TCP, local)'**
  String get se9b4e55058;

  /// fi: Bosch / Buderus (KM200-yhdyskäytävä, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Bosch / Buderus (KM200 gateway, local)'**
  String get s16f7124e42;

  /// fi: Inventor INVmate II / Midea LAN (paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Inventor INVmate II / Midea LAN (local)'**
  String get sc207ec4ed9;

  /// fi: Inventor Control (Tuya, paikallinen)
  ///
  /// In en, this message translates to:
  /// **'Inventor Control (Tuya, local)'**
  String get sd0746c8b58;

  /// fi: Inventor ilma-vesi (Modbus)
  ///
  /// In en, this message translates to:
  /// **'Inventor air-to-water (Modbus)'**
  String get s49df2050fd;

  /// fi: Lämpöpumppu (oma integraatio)
  ///
  /// In en, this message translates to:
  /// **'Heat pump (built-in integration)'**
  String get sddd6b1d42e;

  /// fi: Valmistaja ja yhteystapa. Paikalliset toimivat ilman pilveä.
  ///
  /// In en, this message translates to:
  /// **'Maker and connection type. Local ones work without the cloud.'**
  String get s34a3681441;

  /// fi: Laitteen IP-osoite (paikalliset)
  ///
  /// In en, this message translates to:
  /// **'Device IP (local brands)'**
  String get s88688d2809;

  /// fi: Paikallisen laitteen IP-osoite (reitittimen laitelistasta).
  ///
  /// In en, this message translates to:
  /// **'IP address of a local unit (from your router\'\'s device list).'**
  String get s87e0a93996;

  /// fi: Sähköposti (pilvi)
  ///
  /// In en, this message translates to:
  /// **'E-mail (cloud)'**
  String get sc0bc183c3e;

  /// fi: Valmistajan sovelluksen kirjautumissähköposti (MELCloud, airCloud).
  ///
  /// In en, this message translates to:
  /// **'The e-mail you sign in to the maker\'\'s app with (MELCloud, airCloud).'**
  String get s0cc25259c7;

  /// fi: Käyttäjätunnus (Toshiba)
  ///
  /// In en, this message translates to:
  /// **'Username (Toshiba)'**
  String get s25f561c483;

  /// fi: Toshiba Home AC Control -sovelluksen käyttäjätunnus.
  ///
  /// In en, this message translates to:
  /// **'Your Toshiba Home AC Control username.'**
  String get s92e7ac8d3c;

  /// fi: Valmistajan sovelluksen salasana. Tallentuu vain tälle laitteelle / omaan holviisi.
  ///
  /// In en, this message translates to:
  /// **'The maker\'\'s app password. Stored only on this device / in your own vault.'**
  String get safde071183;

  /// fi: Tunnus (SmartThings token / Midea V3 token)
  ///
  /// In en, this message translates to:
  /// **'Token (SmartThings / Midea V3 token)'**
  String get sca7b0f8de6;

  /// fi: SmartThingsin henkilökohtainen token (account.smartthings.com/tokens), tai Midea V3 -laitteen token (128 heksamerkkiä).
  ///
  /// In en, this message translates to:
  /// **'SmartThings personal access token (account.smartthings.com/tokens), or the Midea V3 device token (128 hex characters).'**
  String get s0f1eaf350b;

  /// fi: Avain (Daikin BRP072C tarrasta / Midea V3 key)
  ///
  /// In en, this message translates to:
  /// **'Key (Daikin BRP072C sticker / Midea V3 key)'**
  String get se263eae5bc;

  /// fi: BRP072C-ohjaimen tarrassa oleva avain (key), tai Midea V3 -laitteen key (64 heksamerkkiä).
  ///
  /// In en, this message translates to:
  /// **'The key printed on the BRP072C adapter\'\'s sticker, or the Midea V3 device key (64 hex characters).'**
  String get s29ea4d7472;

  /// fi: Laitteen tunnus (Midea / Tuya)
  ///
  /// In en, this message translates to:
  /// **'Device id (Midea / Tuya)'**
  String get s5e51da0364;

  /// fi: Midea: laitteen numerotunnus (löytyy haussa). Tuya: Device ID (Tuya-sovelluksesta tai kehittäjäprojektista).
  ///
  /// In en, this message translates to:
  /// **'Midea: the numeric appliance id (found by the search). Tuya: the Device ID (from the Tuya app or developer project).'**
  String get se463b24b80;

  /// fi: Midea-protokolla (2 tai 3)
  ///
  /// In en, this message translates to:
  /// **'Midea protocol (2 or 3)'**
  String get s21214b52f5;

  /// fi: 2 = ei tunnuksia. 3 = uudempi laiteohjelmisto, tarvitsee tokenin ja keyn.
  ///
  /// In en, this message translates to:
  /// **'2 = no credentials. 3 = newer firmware, needs a token and key.'**
  String get sfd9749e4c3;

  /// fi: Paikallinen avain (Tuya local key)
  ///
  /// In en, this message translates to:
  /// **'Local key (Tuya)'**
  String get s7b9cbd8fc1;

  /// fi: 16 merkin Tuya-laitteen paikallinen avain.
  ///
  /// In en, this message translates to:
  /// **'The Tuya device\'\'s 16-character local key.'**
  String get sefa4614c28;

  /// fi: Tuya-protokollaversio
  ///
  /// In en, this message translates to:
  /// **'Tuya protocol version'**
  String get sb1d45b679e;

  /// fi: 3.3, 3.4 tai 3.5 (löytyy haussa).
  ///
  /// In en, this message translates to:
  /// **'3.3, 3.4 or 3.5 (found by the search).'**
  String get s2fb2791b81;

  /// fi: Modbus-kehystys (tcp / rtu)
  ///
  /// In en, this message translates to:
  /// **'Modbus framing (tcp / rtu)'**
  String get s284d1ca043;

  /// fi: RS-485-muuntimen tila: Modbus TCP tai läpinäkyvä RTU.
  ///
  /// In en, this message translates to:
  /// **'The RS-485 gateway\'\'s mode: Modbus TCP or transparent RTU.'**
  String get s8671c4de95;

  /// fi: RTU TCP:n yli (läpinäkyvä)
  ///
  /// In en, this message translates to:
  /// **'RTU over TCP (transparent)'**
  String get s797055e399;

  /// fi: Client ID (myUplink)
  ///
  /// In en, this message translates to:
  /// **'Client ID (myUplink)'**
  String get se67e3e0eb9;

  /// fi: Oman sovelluksen Client ID osoitteesta dev.myuplink.com.
  ///
  /// In en, this message translates to:
  /// **'Client ID of your own app at dev.myuplink.com.'**
  String get sc2d5225ae8;

  /// fi: Client Secret (myUplink)
  ///
  /// In en, this message translates to:
  /// **'Client Secret (myUplink)'**
  String get sa165e50f99;

  /// fi: Oman sovelluksen Client Secret osoitteesta dev.myuplink.com.
  ///
  /// In en, this message translates to:
  /// **'Client Secret of your own app at dev.myuplink.com.'**
  String get s332f9bc1a1;

  /// fi: Yhdyskäytävän salasana (KM200)
  ///
  /// In en, this message translates to:
  /// **'Gateway password (KM200)'**
  String get s911c662d27;

  /// fi: Bosch/Buderus KM-yhdyskäytävän tarrassa tai lämmityslaitteen valikossa (Info → Internet → Kirjautumistiedot).
  ///
  /// In en, this message translates to:
  /// **'On the Bosch/Buderus KM gateway sticker or in the boiler menu (Info → Internet → Login data).'**
  String get s52d4fcbe67;

  /// fi: Oma salasana (KM200)
  ///
  /// In en, this message translates to:
  /// **'Private password (KM200)'**
  String get se7829f1ac5;

  /// fi: Salasana, jonka asetit valmistajan sovelluksessa (MyDevice / EasyControl / Buderus).
  ///
  /// In en, this message translates to:
  /// **'The password you set in the maker\'\'s app (MyDevice / EasyControl / Buderus).'**
  String get sc6b9b9dafe;

  /// fi: Salaus-suola (KM200, vain jos valmistaja käyttää omaa)
  ///
  /// In en, this message translates to:
  /// **'Salt (KM200, only if the maker uses its own)'**
  String get s26eefc92ad;

  /// fi: Jätä tyhjäksi: käytetään Boschin/Buderuksen julkaistua oletusta.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use Bosch/Buderus\'\' published default.'**
  String get s333668bcad;

  /// fi: Rekisterikartta (Modbus)
  ///
  /// In en, this message translates to:
  /// **'Register map (Modbus)'**
  String get sd1d4b22fc6;

  /// fi: Pumpun mallisarja. 'Tuotu rekisterilista' = pumpun oma CSV-vienti.
  ///
  /// In en, this message translates to:
  /// **'The pump series. \'\'Imported register list\'\' = the pump\'\'s own CSV export.'**
  String get s5a9d485e7f;

  /// fi: NIBE S-sarja
  ///
  /// In en, this message translates to:
  /// **'NIBE S-series'**
  String get s7dc3b152a8;

  /// fi: NIBE F-sarja + MODBUS 40
  ///
  /// In en, this message translates to:
  /// **'NIBE F-series + MODBUS 40'**
  String get sad9fd728f9;

  /// fi: Thermia Genesis
  ///
  /// In en, this message translates to:
  /// **'Thermia Genesis'**
  String get seba6d1ba70;

  /// fi: Tuotu rekisterilista
  ///
  /// In en, this message translates to:
  /// **'Imported register list'**
  String get sfdc0bbf134;

  /// fi: Yleensä oletus (Modbus 502, MHI 51443).
  ///
  /// In en, this message translates to:
  /// **'Usually the default (Modbus 502, MHI 51443).'**
  String get scd35ffb8e9;

  /// fi: Modbus-laitteen osoite, yleensä 1.
  ///
  /// In en, this message translates to:
  /// **'Modbus unit address, usually 1.'**
  String get sab25ff8075;

  /// fi: Palvelimen osoite (vain testaukseen)
  ///
  /// In en, this message translates to:
  /// **'Server URL (testing only)'**
  String get sb064bec4c8;

  /// fi: Vain testaukseen: korvaa valmistajan palvelimen osoitteen.
  ///
  /// In en, this message translates to:
  /// **'Testing only: replaces the maker\'\'s server address.'**
  String get s67b2ac9328;

  /// fi: Mitä luetaan
  ///
  /// In en, this message translates to:
  /// **'What to read'**
  String get sabab3f2fae;

  /// fi: Koko tila (lämpöpumppuruutu) tai yksi lukema.
  ///
  /// In en, this message translates to:
  /// **'Full state (heat pump tile) or one reading.'**
  String get sf5e949d20c;

  /// fi: Koko tila
  ///
  /// In en, this message translates to:
  /// **'Full state'**
  String get s46ce82ef9c;

  /// fi: Yksi lukema
  ///
  /// In en, this message translates to:
  /// **'One reading'**
  String get s8cbd66456f;

  /// fi: Sisäyksikön tunnus
  ///
  /// In en, this message translates to:
  /// **'Unit id'**
  String get s6d1827b58e;

  /// fi: Sisäyksikön tunnus; yhden laitteen tileillä 'main'.
  ///
  /// In en, this message translates to:
  /// **'Indoor unit id; \'\'main\'\' for single-unit devices.'**
  String get s89308ddc6d;

  /// fi: Lukema (current, target, outdoor, power…)
  ///
  /// In en, this message translates to:
  /// **'Reading (current, target, outdoor, power…)'**
  String get sa643668bec;

  /// fi: Mikä lukema: current, target, outdoor, power, supply, hot_water…
  ///
  /// In en, this message translates to:
  /// **'Which reading: current, target, outdoor, power, supply, hot_water…'**
  String get s02d24152f0;

  /// fi: Aseta
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get se16e293d6b;

  /// fi: Mitä asetetaan
  ///
  /// In en, this message translates to:
  /// **'What to set'**
  String get s155de09d38;

  /// fi: Asetusarvo, virta, tila tai puhallin.
  ///
  /// In en, this message translates to:
  /// **'Setpoint, power, mode or fan.'**
  String get s94ecb845c8;

  /// fi: Muu asetus (key)
  ///
  /// In en, this message translates to:
  /// **'Other setting (key)'**
  String get s6ff46b02d2;

  /// fi: Asetusarvo
  ///
  /// In en, this message translates to:
  /// **'Setpoint'**
  String get sba2eb6d9b9;

  /// fi: Asetuksen tunnus (vain "Muu asetus")
  ///
  /// In en, this message translates to:
  /// **'Setting key (only \"Other setting\")'**
  String get sc8c47b547a;

  /// fi: Esim. dhw_set (käyttöveden lämpötila) tai dhw_power (käyttöveden lämmitys päälle/pois).
  ///
  /// In en, this message translates to:
  /// **'E.g. dhw_set (hot water setpoint) or dhw_power (hot water heating on/off).'**
  String get s679e5f90c2;

  /// fi: Lämpöpumppua "{p0}" ei löydy enää tililtä
  ///
  /// In en, this message translates to:
  /// **'Heat pump \"{p0}\" is no longer in the account'**
  String s6478b264c0(String p0);

  /// fi: Asetusarvo puuttuu
  ///
  /// In en, this message translates to:
  /// **'Setpoint missing'**
  String get s4937d259b8;

  /// fi: Asetuksen tunnus tai arvo puuttuu
  ///
  /// In en, this message translates to:
  /// **'Setting key or value missing'**
  String get sbd33d78695;

  /// fi: käyrän siirto
  ///
  /// In en, this message translates to:
  /// **'curve offset'**
  String get s10f42a9a20;

  /// fi: Käyttöveden tavoite
  ///
  /// In en, this message translates to:
  /// **'Hot water setpoint'**
  String get s3795df7c35;

  /// fi: Menoveden tavoite
  ///
  /// In en, this message translates to:
  /// **'Water setpoint'**
  String get sf5a30e3b51;

  /// fi: Käyttövesi päällä
  ///
  /// In en, this message translates to:
  /// **'Hot water on'**
  String get s8b6dbf3df6;

  /// fi: Menovesi
  ///
  /// In en, this message translates to:
  /// **'Supply'**
  String get s620c04d73e;

  /// fi: Paluuvesi
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get s922f77d2f1;

  /// fi: Käyttövesi
  ///
  /// In en, this message translates to:
  /// **'Hot water'**
  String get sbfee72daca;

  /// fi: Keruuliuos sisään
  ///
  /// In en, this message translates to:
  /// **'Brine in'**
  String get s0be9e35521;

  /// fi: Keruuliuos ulos
  ///
  /// In en, this message translates to:
  /// **'Brine out'**
  String get s3a0d796501;

  /// fi: Astetminuutit
  ///
  /// In en, this message translates to:
  /// **'Degree minutes'**
  String get s23bbe9b4ed;

  /// fi: Kompressori
  ///
  /// In en, this message translates to:
  /// **'Compressor'**
  String get s3ca74f3ef8;

  /// fi: Polttimen teho
  ///
  /// In en, this message translates to:
  /// **'Burner modulation'**
  String get s79f91561d9;

  /// fi: Vesivirtaus
  ///
  /// In en, this message translates to:
  /// **'Water flow'**
  String get s447ce92cd0;

  /// fi: Lämpöteho
  ///
  /// In en, this message translates to:
  /// **'Heating capacity'**
  String get s54fd87bce8;

  /// fi: Anna yhdyskäytävän salasana ja oma salasana
  ///
  /// In en, this message translates to:
  /// **'Enter the gateway password and your own password'**
  String get sc272460629;

  /// fi: Lämmityslaite vastasi, mutta tietoja ei saatu auki – tarkista molemmat salasanat.
  ///
  /// In en, this message translates to:
  /// **'The heating gateway answered but the data could not be decrypted – check both passwords.'**
  String get s684b127b9d;

  /// fi: Lämmityslaite ei salli tämän arvon muuttamista
  ///
  /// In en, this message translates to:
  /// **'The heating gateway does not allow changing this value'**
  String get sbe369d8548;

  /// fi: Lämmityspiiri
  ///
  /// In en, this message translates to:
  /// **'Heating circuit'**
  String get s1222da1433;

  /// fi: supply
  ///
  /// In en, this message translates to:
  /// **'/system/sensors/temperatures/supply_t1'**
  String get s131d0eb266;

  /// fi: return
  ///
  /// In en, this message translates to:
  /// **'/system/sensors/temperatures/return'**
  String get sac20961d10;

  /// fi: hot_water
  ///
  /// In en, this message translates to:
  /// **'/dhwCircuits/dhw1/actualTemp'**
  String get s2a35dc0822;

  /// fi: modulation
  ///
  /// In en, this message translates to:
  /// **'/heatSources/actualModulation'**
  String get s85a3e678f3;

  /// fi: lämmityspiiriä
  ///
  /// In en, this message translates to:
  /// **'heating circuit(s)'**
  String get s4159d585e2;

  /// fi: Ilmastointilaitteen käyttäjätaulukko on täynnä. Poista vanha puhelin Smart M-Air -sovelluksesta ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The unit\'\'s account table is full. Remove an old phone in the Smart M-Air app and try again.'**
  String get s31ec8d716e;

  /// fi: Laite on varattu (toinen sovellus ohjaa) – yritä minuutin päästä.
  ///
  /// In en, this message translates to:
  /// **'The unit is busy (another app) – try in a minute.'**
  String get sbaecc9fbed;

  /// fi: Ryhmän laitteet eivät vastaa
  ///
  /// In en, this message translates to:
  /// **'The group\'\'s devices are not answering'**
  String get s4cac4725b8;

  /// fi: Ohjattavaa laitetta ei löydy
  ///
  /// In en, this message translates to:
  /// **'The device to control is missing'**
  String get s13a91fe322;

  /// fi: Teho {p0}
  ///
  /// In en, this message translates to:
  /// **'Power {p0}'**
  String sb9964cfb3b(String p0);

  /// fi: Kanava {p0}
  ///
  /// In en, this message translates to:
  /// **'Channel {p0}'**
  String s08d04d58a9(String p0);

  /// fi: Home Assistant (esimerkki)
  ///
  /// In en, this message translates to:
  /// **'Home Assistant (example)'**
  String get s589eb1bcd3;

  /// fi: Kamera (esimerkki)
  ///
  /// In en, this message translates to:
  /// **'Camera (example)'**
  String get sc4fdb87cd7;

  /// fi: IV-kone (esimerkki)
  ///
  /// In en, this message translates to:
  /// **'Ventilation unit (example)'**
  String get sd50566a706;

  /// fi: Piha
  ///
  /// In en, this message translates to:
  /// **'Yard'**
  String get s4b4fd14aaf;

  /// fi: disarmed=Pois;armed_away=Päällä;armed_home=Kotona;triggered=HÄLYTYS
  ///
  /// In en, this message translates to:
  /// **''**
  String get s8ac16d45bc;

  /// fi: Olohuoneen valot
  ///
  /// In en, this message translates to:
  /// **'Living room lights'**
  String get sbde42d83a3;

  /// fi: Tuloilma
  ///
  /// In en, this message translates to:
  /// **'Supply air'**
  String get sb7c78c63b3;

  /// fi: IV-kone nopeus
  ///
  /// In en, this message translates to:
  /// **'Fan speed'**
  String get sbb2adef009;

  /// fi: 0=Pois;1=Poissa;2=Kotona;3=Tehostus;4=Max
  ///
  /// In en, this message translates to:
  /// **'0=Off;1=Away;2=Home;3=Boost;4=Max'**
  String get see46441329;

  /// fi: Lähden kotoa
  ///
  /// In en, this message translates to:
  /// **'Leaving home'**
  String get sb25aad3bc2;

  /// fi: Linkki poistettu käytöstä
  ///
  /// In en, this message translates to:
  /// **'Link revoked'**
  String get s047879732e;

  /// fi: Rauhallinen
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get s65320ede20;

  /// fi: Hyvää yötä
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get s7e5f6a29e3;

  /// fi: Hyvää huomenta
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get s253122823a;

  /// fi: Hyvää päivää
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get s640293f08f;

  /// fi: Hyvää iltaa
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get sd8c5bed7de;

  /// fi: iphone
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get s834e3e8c5d;

  /// fi: ipad
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get s11d8d321df;

  /// fi: macbook
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get sceefb34afd;

  /// fi: imac
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get s24a447c14c;

  /// fi: mac mini
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get s14418a4f88;

  /// fi: appletv
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get saab3e952a6;

  /// fi: apple tv
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get s7fbbfbf469;

  /// fi: galaxy
  ///
  /// In en, this message translates to:
  /// **'Samsung'**
  String get s045b27e316;

  /// fi: samsung
  ///
  /// In en, this message translates to:
  /// **'Samsung'**
  String get s2c0aede81e;

  /// fi: pixel
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get s7bd2005e15;

  /// fi: chromecast
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get sdcec96b503;

  /// fi: google
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get s49960d413e;

  /// fi: nest
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get s99e5776a78;

  /// fi: sonos
  ///
  /// In en, this message translates to:
  /// **'Sonos'**
  String get sea3c963b09;

  /// fi: synology
  ///
  /// In en, this message translates to:
  /// **'Synology'**
  String get s1e7b1fc81c;

  /// fi: diskstation
  ///
  /// In en, this message translates to:
  /// **'Synology'**
  String get s7dc8f4cf35;

  /// fi: qnap
  ///
  /// In en, this message translates to:
  /// **'QNAP'**
  String get s161d78d79c;

  /// fi: brother
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get s2512122220;

  /// fi: epson
  ///
  /// In en, this message translates to:
  /// **'Epson'**
  String get s127258a6f4;

  /// fi: canon
  ///
  /// In en, this message translates to:
  /// **'Canon'**
  String get s4e31401b4f;

  /// fi: hp
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get s933e21c819;

  /// fi: hewlett
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get sb309051c1f;

  /// fi: officejet
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get s6f339c5c37;

  /// fi: laserjet
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get s5f8734f6e4;

  /// fi: xiaomi
  ///
  /// In en, this message translates to:
  /// **'Xiaomi'**
  String get sceb247a904;

  /// fi: huawei
  ///
  /// In en, this message translates to:
  /// **'Huawei'**
  String get s10b7b68d6c;

  /// fi: lg
  ///
  /// In en, this message translates to:
  /// **'LG'**
  String get s3692c1d592;

  /// fi: webos
  ///
  /// In en, this message translates to:
  /// **'LG'**
  String get se7d945b970;

  /// fi: bravia
  ///
  /// In en, this message translates to:
  /// **'Sony'**
  String get s5a5044b5df;

  /// fi: sony
  ///
  /// In en, this message translates to:
  /// **'Sony'**
  String get sd92d7da7d5;

  /// fi: philips
  ///
  /// In en, this message translates to:
  /// **'Philips'**
  String get saa909391c3;

  /// fi: raspberry
  ///
  /// In en, this message translates to:
  /// **'Raspberry Pi'**
  String get se39b8c84ab;

  /// fi: fritz
  ///
  /// In en, this message translates to:
  /// **'AVM'**
  String get sec8808f414;

  /// fi: tp-link
  ///
  /// In en, this message translates to:
  /// **'TP-Link'**
  String get s0e225fb918;

  /// fi: asus
  ///
  /// In en, this message translates to:
  /// **'ASUS'**
  String get sb34f35dce5;

  /// fi: netgear
  ///
  /// In en, this message translates to:
  /// **'Netgear'**
  String get s7ea140809c;

  /// fi: ubiquiti
  ///
  /// In en, this message translates to:
  /// **'Ubiquiti'**
  String get s284be225b7;

  /// fi: unifi
  ///
  /// In en, this message translates to:
  /// **'Ubiquiti'**
  String get sfbaeb6a17e;

  /// fi: mikrotik
  ///
  /// In en, this message translates to:
  /// **'MikroTik'**
  String get sa24e9ce91d;

  /// fi: espressif
  ///
  /// In en, this message translates to:
  /// **'Espressif'**
  String get sa1b725d397;

  /// fi: amazon
  ///
  /// In en, this message translates to:
  /// **'Amazon'**
  String get sdf96423738;

  /// fi: echo
  ///
  /// In en, this message translates to:
  /// **'Amazon'**
  String get sf253859589;

  /// fi: roku
  ///
  /// In en, this message translates to:
  /// **'Roku'**
  String get sec4d80656d;

  /// fi: Osoite näyttää vajaalta. Muoto on neljä numeroa pisteillä, esim. 192.168.1.50.
  ///
  /// In en, this message translates to:
  /// **'The address looks incomplete. Use four numbers with dots, e.g. 192.168.1.50.'**
  String get sb662db81d8;

  /// fi:  Tarkoititko {p0}?
  ///
  /// In en, this message translates to:
  /// **' Did you mean {p0}?'**
  String s738ecfe2bc(String p0);

  /// fi: Tämä ei ole kotiverkon osoite (kotiverkon osoitteet alkavat yleensä 192.168.).{p0}
  ///
  /// In en, this message translates to:
  /// **'This is not a home network address (they usually start with 192.168.).{p0}'**
  String s06e738bf27(String p0);

  /// fi: Huom: tämä laite on verkossa {p0}.x – laite ei ehkä ole samassa wifissä.
  ///
  /// In en, this message translates to:
  /// **'Note: this device is on {p0}.x – the device may be on another Wi-Fi.'**
  String sbae99909c4(String p0);

  /// fi: Kuiva
  ///
  /// In en, this message translates to:
  /// **'VUOTO!'**
  String get se317f59de2;

  /// fi: Dry
  ///
  /// In en, this message translates to:
  /// **'LEAK!'**
  String get se4c4201882;

  /// fi: Kiinni
  ///
  /// In en, this message translates to:
  /// **'Auki'**
  String get sdbcf5515c1;

  /// fi: Closed
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sb0af7213b5;

  /// fi: Ei liikettä
  ///
  /// In en, this message translates to:
  /// **'Liikettä'**
  String get sa3477dac6e;

  /// fi: No motion
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get s280df88585;

  /// fi: OK
  ///
  /// In en, this message translates to:
  /// **'SAVUA!'**
  String get s064a959911;

  /// fi: OK
  ///
  /// In en, this message translates to:
  /// **'SMOKE!'**
  String get s50778e2eec;

  /// fi: Rauhallinen
  ///
  /// In en, this message translates to:
  /// **'Hälytys'**
  String get s1dfa5abe81;

  /// fi: Calm
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get s50c459fbff;

  /// fi: Bosch Smart Home -ohjain
  ///
  /// In en, this message translates to:
  /// **'Bosch Smart Home Controller'**
  String get s29c5b59ddb;

  /// fi: Ohjaimen IP-osoite
  ///
  /// In en, this message translates to:
  /// **'Controller IP address'**
  String get sfb05679ced;

  /// fi: Bosch Smart Home -ohjaimen osoite (sovellus: Lisää → Järjestelmä → Ohjain, tai reitittimen laitelista).
  ///
  /// In en, this message translates to:
  /// **'The controller\'\'s address (app: More → System → Controller, or your router\'\'s device list).'**
  String get sd65da878fe;

  /// fi: Asiakasvarmenne (PEM)
  ///
  /// In en, this message translates to:
  /// **'Client certificate (PEM)'**
  String get s6f7b5bb729;

  /// fi: Molaplan luo tämän parituksessa. Älä muuta.
  ///
  /// In en, this message translates to:
  /// **'Created by Molaplan when pairing. Do not change.'**
  String get sd21135f561;

  /// fi: Asiakasavain (PEM)
  ///
  /// In en, this message translates to:
  /// **'Client key (PEM)'**
  String get s2bc685129f;

  /// fi: Ohjaimen varmenteen sormenjälki
  ///
  /// In en, this message translates to:
  /// **'Controller certificate fingerprint'**
  String get sd5bfa709a3;

  /// fi: Tallennettu parituksessa: Molaplan puhuu vain tälle ohjaimelle. Tyhjä = hyväksy ensimmäinen.
  ///
  /// In en, this message translates to:
  /// **'Saved when pairing: Molaplan only talks to this controller. Empty = accept the first one.'**
  String get s8b133a2da5;

  /// fi: Bosch-laitteen tunnus (id).
  ///
  /// In en, this message translates to:
  /// **'The Bosch device id.'**
  String get s46f9aaf504;

  /// fi: Esim. TemperatureLevel, ShutterContact, PowerSwitch.
  ///
  /// In en, this message translates to:
  /// **'E.g. TemperatureLevel, ShutterContact, PowerSwitch.'**
  String get s84d11d45ce;

  /// fi: Kenttä
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get s4dabf0e462;

  /// fi: Kenttä palvelun tilasta, esim. temperature, value, switchState.
  ///
  /// In en, this message translates to:
  /// **'A field of the service state, e.g. temperature, value, switchState.'**
  String get s9a1eb4b849;

  /// fi: Polku (muut)
  ///
  /// In en, this message translates to:
  /// **'Path (other)'**
  String get se83f02e6bd;

  /// fi: Muu luettava polku, esim. /intrusion/states/system.
  ///
  /// In en, this message translates to:
  /// **'Another path to read, e.g. /intrusion/states/system.'**
  String get s3a985d4cc3;

  /// fi: PUT tilan muuttamiseen, POST toimintoihin.
  ///
  /// In en, this message translates to:
  /// **'PUT to change a state, POST for actions.'**
  String get s0d34dfcd38;

  /// fi: Polku /smarthome-osoitteen jälkeen.
  ///
  /// In en, this message translates to:
  /// **'Path after /smarthome.'**
  String get sf8c4f6beb9;

  /// fi: JSON, esim. {"@type":"powerSwitchState","switchState":"ON"}.
  ///
  /// In en, this message translates to:
  /// **'\'JSON, e.g. {\"@type\":\"powerSwitchState\",\"switchState\":\"ON\"}.\''**
  String get s5632684130;

  /// fi: Bosch-ohjain ei hyväksynyt yhteyttä (paritus puuttuu tai ohjain vaihtui) – lisää ohjain uudelleen. ({p0})
  ///
  /// In en, this message translates to:
  /// **'The Bosch controller refused the connection (not paired or a different controller) – add it again. ({p0})'**
  String s3addc3df37(String p0);

  /// fi: ✓ Bosch Smart Home -ohjain vastasi: {p0} laitetta. Komentoja ei lähetetty.
  ///
  /// In en, this message translates to:
  /// **'✓ The Bosch Smart Home Controller answered: {p0} devices. No commands were sent.'**
  String sc76c98702f(String p0);

  /// fi: Muut
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sd9b6de0a6a;

  /// fi: ei tavoitettavissa
  ///
  /// In en, this message translates to:
  /// **'unreachable'**
  String get s4dbb677293;

  /// fi: tavoitelämpö
  ///
  /// In en, this message translates to:
  /// **'target'**
  String get sd0368ed590;

  /// fi: venttiili
  ///
  /// In en, this message translates to:
  /// **'valve'**
  String get sec17dd81e8;

  /// fi: auki
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get s0b2f7d7c80;

  /// fi: kiinni
  ///
  /// In en, this message translates to:
  /// **'closed'**
  String get s7009587b85;

  /// fi: palovaroitin
  ///
  /// In en, this message translates to:
  /// **'smoke detector'**
  String get saf40fb40b3;

  /// fi: testi
  ///
  /// In en, this message translates to:
  /// **'test'**
  String get s4d85116fcb;

  /// fi: testaa hälytin
  ///
  /// In en, this message translates to:
  /// **'test alarm'**
  String get s54345410a1;

  /// fi: ilmanlaatu
  ///
  /// In en, this message translates to:
  /// **'air quality'**
  String get s67c7f22d99;

  /// fi: liiketunnistin
  ///
  /// In en, this message translates to:
  /// **'motion detector'**
  String get s4c3bb5ea0a;

  /// fi: vesivuoto
  ///
  /// In en, this message translates to:
  /// **'water leak'**
  String get sa6a56fa019;

  /// fi: kamera päällä
  ///
  /// In en, this message translates to:
  /// **'camera on'**
  String get s7c51d00219;

  /// fi: yksityisyystila
  ///
  /// In en, this message translates to:
  /// **'privacy mode'**
  String get s51cd662d6c;

  /// fi: ilmoitukset
  ///
  /// In en, this message translates to:
  /// **'notifications'**
  String get scdc860be9e;

  /// fi: valo
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get s45c8904016;

  /// fi: Murtohälytin
  ///
  /// In en, this message translates to:
  /// **'Intrusion alarm'**
  String get s416ac1459c;

  /// fi: Turvallisuus
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get s607339c984;

  /// fi: tila + valvonta päälle/pois + kuittaus
  ///
  /// In en, this message translates to:
  /// **'state + arm/disarm + mute'**
  String get sd1d17eca81;

  /// fi: Vesivuotohälytys
  ///
  /// In en, this message translates to:
  /// **'Water alarm'**
  String get s499d3aa6f1;

  /// fi: koko järjestelmä + kuittaus
  ///
  /// In en, this message translates to:
  /// **'whole system + mute'**
  String get se57c2c4920;

  /// fi: Skenaariot
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get s2eb00b7c28;

  /// fi: Kuittaa hälytys
  ///
  /// In en, this message translates to:
  /// **'Mute alarm'**
  String get s38df0b3b2b;

  /// fi: kuittaa
  ///
  /// In en, this message translates to:
  /// **'mute'**
  String get s1ff3dea39b;

  /// fi: GOOD=Hyvä;MEDIUM=Kohtalainen;BAD=Huono
  ///
  /// In en, this message translates to:
  /// **'GOOD=Good;MEDIUM=Medium;BAD=Bad'**
  String get s373ab1c97c;

  /// fi: ilman puhtaus
  ///
  /// In en, this message translates to:
  /// **'purity'**
  String get s129317999a;

  /// fi: asento (100 = auki)
  ///
  /// In en, this message translates to:
  /// **'position (100 = open)'**
  String get sd0807cf61e;

  /// fi: avaa
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get sdb34e99ef6;

  /// fi: sulje
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get s7fc017b0f0;

  /// fi: pysäytä
  ///
  /// In en, this message translates to:
  /// **'stop'**
  String get sb02c7ee226;

  /// fi: Läsnäolosimulaatio
  ///
  /// In en, this message translates to:
  /// **'Presence simulation'**
  String get sefdd3f7ade;

  /// fi: Bosch Smart Home
  ///
  /// In en, this message translates to:
  /// **'Bosch Smart Home'**
  String get s16bc9ff328;

  /// fi: Bosch Smart Home -ohjain (I tai II): termostaatit, patteriventtiilit, ikkuna-/ovianturit, palovaroittimet, pistorasiat,
  ///
  /// In en, this message translates to:
  /// **'Bosch Smart Home Controller (I or II): thermostats, radiator valves, window/door contacts, smoke detectors, plugs, lights, shutters, motion detectors, cameras and the intrusion alarm. Local, no cloud.'**
  String get sde61b8a8a4;

  /// fi: Bosch Smart Home -sovelluksessa: Lisää → Järjestelmä → Smart Home -ohjain → Verkkotiedot. Tai reitittimen laitelistasta
  ///
  /// In en, this message translates to:
  /// **'In the Bosch Smart Home app: More → System → Smart Home Controller → Network. Or your router\'\'s device list (\"shc…\").'**
  String get s3b276dcad6;

  /// fi: Kirjoita Bosch Smart Home -järjestelmän salasana (sama, jonka loit ohjainta asentaessa). Sitä ei tallenneta. Kun painat
  ///
  /// In en, this message translates to:
  /// **'Type the Bosch Smart Home system password (the one you created when setting up the controller). It is not saved. After tapping \"Connect\", press the button on the front of the controller.'**
  String get sc7c8ed347e;

  /// fi: Paina nyt ohjaimen etupainiketta: Smart Home Controller II – lyhyt painallus; vanha ohjain (I) – pidä pohjassa, kunnes v
  ///
  /// In en, this message translates to:
  /// **'Press the button on the front of the controller now: Controller II – a short press; the old controller (I) – hold until the lights flash. Wait here.'**
  String get s608bdcb257;

  /// fi: gk-200
  ///
  /// In en, this message translates to:
  /// **'sonoff'**
  String get s1a73b397a1;

  /// fi: ds-2
  ///
  /// In en, this message translates to:
  /// **'hikvision'**
  String get sb8a029d8b4;

  /// fi: tp-link
  ///
  /// In en, this message translates to:
  /// **'tapo'**
  String get s2e87289ebd;

  /// fi: Sonoff
  ///
  /// In en, this message translates to:
  /// **'Sonoff'**
  String get sd86b823895;

  /// fi: BASIC, MINI, POW, TH, 4CH… DIY-tilassa, Tasmotalla tai ESPHomella. Ruudut tehdään valmiiksi, etänä kotisillan kautta.
  ///
  /// In en, this message translates to:
  /// **'BASIC, MINI, POW, TH, 4CH… in DIY mode, with Tasmota or ESPHome. Tiles are made for you; remote use via the home bridge.'**
  String get s5f297ec9d8;

  /// fi: eWeLink-sovellus → laite → Asetukset näyttää IP-osoitteen, tai reitittimen laitelista. DIY-tilassa tarvitset myös laitte
  ///
  /// In en, this message translates to:
  /// **'eWeLink app → device → Settings shows the IP address, or your router\'\'s device list. In DIY mode you also need the Device ID (10 characters).'**
  String get s60e829b1b0;

  /// fi: DIY-tilan Sonoff vastaa vain, kun sille kerrotaan sen tunnus (Device ID). Se näkyy eWeLink-sovelluksessa: laite → Asetuk
  ///
  /// In en, this message translates to:
  /// **'A Sonoff in DIY mode only answers when told its Device ID. Find it in the eWeLink app: device → Settings → Device ID. Tasmota: the web password, if set.'**
  String get s6a46e8954d;

  /// fi: Vain DIY-tilassa, jos laitetta ei löytynyt haulla.
  ///
  /// In en, this message translates to:
  /// **'Only in DIY mode when the search did not find the device.'**
  String get sea057f1a02;

  /// fi: Teho
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get s4899323b9a;

  /// fi: Vaihe {p0}
  ///
  /// In en, this message translates to:
  /// **'Phase {p0}'**
  String sdaa374b331(String p0);

  /// fi: Vesivuotoanturi
  ///
  /// In en, this message translates to:
  /// **'Water leak sensor'**
  String get s4233362d60;

  /// fi: Shelly
  ///
  /// In en, this message translates to:
  /// **'Shelly'**
  String get sfcb44be1a0;

  /// fi: Releet, pistorasiat, himmentimet, verhot, energiamittarit (Pro 3EM) ja anturit. Löytyy automaattisesti, toimii ilman pil
  ///
  /// In en, this message translates to:
  /// **'Relays, plugs, dimmers, covers, energy meters (Pro 3EM) and sensors. Found automatically, works without the cloud.'**
  String get sc7df69ad6e;

  /// fi: Shelly-sovelluksessa: avaa laite → ratas (asetukset) → Laitetiedot → IP-osoite. Tai reitittimen laitelistasta: nimi alka
  ///
  /// In en, this message translates to:
  /// **'In the Shelly app: open the device → gear (settings) → Device information → IP address. Or in your router\'\'s device list: the name starts with \"shelly…\".'**
  String get sd7e123cd2f;

  /// fi: vuotoanturi · paristo
  ///
  /// In en, this message translates to:
  /// **'leak sensor · battery'**
  String get s9ad7b0076b;

  /// fi: Kontaktorin ohjaus
  ///
  /// In en, this message translates to:
  /// **'Contactor control'**
  String get s815bfa19dc;

  /// fi: lisää vain, jos rele on käytössä
  ///
  /// In en, this message translates to:
  /// **'add only if the relay is in use'**
  String get sb9209fee74;

  /// fi: nyt päällä
  ///
  /// In en, this message translates to:
  /// **'on now'**
  String get s5f2b2ca5f5;

  /// fi: nyt pois
  ///
  /// In en, this message translates to:
  /// **'off now'**
  String get s67f64cd925;

  /// fi: Mittaus
  ///
  /// In en, this message translates to:
  /// **'Metering'**
  String get s8b35cc884f;

  /// fi: kalibroi Shelly-sovelluksessa, niin saat liukusäätimen
  ///
  /// In en, this message translates to:
  /// **'calibrate in the Shelly app to get a slider'**
  String get sa58e7aab49;

  /// fi: paristolaite: päivittyy kun herää
  ///
  /// In en, this message translates to:
  /// **'battery device: updates when awake'**
  String get s78b6134b71;

  /// fi: Shelly Cloud (ilman kotisiltaa)
  ///
  /// In en, this message translates to:
  /// **'Shelly Cloud (no bridge)'**
  String get sd8dfb25d31;

  /// fi: Ohjaa Shellyjä Shellyn pilven kautta mistä tahansa. Tarvitset vain Shelly-sovelluksen avaimen.
  ///
  /// In en, this message translates to:
  /// **'Control Shellys through the Shelly cloud from anywhere. You only need the key from the Shelly app.'**
  String get s350215338a;

  /// fi: Shelly-sovellus → oma profiili (ylhäällä) → Käyttäjäasetukset → Authorization cloud key → Get key. Kopioi avain ja liitä
  ///
  /// In en, this message translates to:
  /// **'Shelly app → your profile → User settings → Authorization cloud key → Get key. Copy and paste it here.'**
  String get s64037991c2;

  /// fi: Näkyy samalla sivulla avaimen alla ("Server URI"), esim. shelly-103-eu.shelly.cloud.
  ///
  /// In en, this message translates to:
  /// **'Shown on the same page below the key (\"Server URI\").'**
  String get s062b21969d;

  /// fi: Yleensä ei tarvita – laitteet haetaan automaattisesti. Jos ei löydy: Shelly-sovellus → laite → asetukset → Laitetiedot →
  ///
  /// In en, this message translates to:
  /// **'Usually not needed. If nothing is found: Shelly app → device → settings → Device information → Device ID. Separate several with commas.'**
  String get sf30bb5d5e6;

  /// fi: Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Server URI.
  ///
  /// In en, this message translates to:
  /// **'Shelly app → User settings → Authorization cloud key → Server URI.'**
  String get s246c7a46ff;

  /// fi: Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Get key.
  ///
  /// In en, this message translates to:
  /// **'Shelly app → User settings → Authorization cloud key → Get key.'**
  String get s9d468f5c64;

  /// fi: Philips Hue
  ///
  /// In en, this message translates to:
  /// **'Philips Hue'**
  String get s0bf7cb1613;

  /// fi: Hue-silta ja sen valot (myös Zigbee-valot, jotka on liitetty Hue-siltaan). Paritus sillan painikkeella.
  ///
  /// In en, this message translates to:
  /// **'Hue Bridge and its lights (also Zigbee lights paired to it). Pair with the bridge button.'**
  String get se17d4e4197;

  /// fi: Hue-sovelluksessa: Asetukset → Hue-sillat → (i) → IP-osoite. Tai reitittimen laitelistasta: "Philips-hue".
  ///
  /// In en, this message translates to:
  /// **'In the Hue app: Settings → Hue Bridges → (i) → IP address. Or in your router\'\'s device list: \"Philips-hue\".'**
  String get sf83a145406;

  /// fi: Paina nyt Hue-sillan päällä olevaa isoa pyöreää painiketta. Odota tässä – yhteys syntyy itsestään.
  ///
  /// In en, this message translates to:
  /// **'Press the big round button on top of the Hue Bridge now. Wait here – it connects by itself.'**
  String get s80ee7a25a9;

  /// fi: himmennettävä
  ///
  /// In en, this message translates to:
  /// **'dimmable'**
  String get sf50732e8e8;

  /// fi: anturi
  ///
  /// In en, this message translates to:
  /// **'sensor'**
  String get s4082a34467;

  /// fi: koko huone ({p0} valoa)
  ///
  /// In en, this message translates to:
  /// **'whole room'**
  String s3832b8c729(String p0);

  /// fi: Tilanteet (scenet)
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get s2bb8fceaf7;

  /// fi: Phoscon / deCONZ (ConBee, RaspBee)
  ///
  /// In en, this message translates to:
  /// **'Phoscon / deCONZ (ConBee, RaspBee)'**
  String get s5a482978b7;

  /// fi: dresden elektronikin Phoscon-yhdyskäytävä: sen Zigbee-valot, -anturit, huoneet ja tilanteet kotiverkossa.
  ///
  /// In en, this message translates to:
  /// **'dresden elektronik Phoscon gateway: its Zigbee lights, sensors, rooms and scenes over the home network.'**
  String get s68dc51749b;

  /// fi: Phoscon-sovellus → Yhdyskäytävä → IP-osoite (portti usein 80 tai 8080, esim. 192.168.1.20:8080).
  ///
  /// In en, this message translates to:
  /// **'Phoscon app → Gateway → IP address (port is often 80 or 8080, e.g. 192.168.1.20:8080).'**
  String get se8773ef198;

  /// fi: Avaa Phoscon → Asetukset → Yhdyskäytävä → Lisäasetukset → "Todenna sovellus" (Authenticate app). Odota tässä.
  ///
  /// In en, this message translates to:
  /// **'Open Phoscon → Settings → Gateway → Advanced → \"Authenticate app\". Wait here.'**
  String get sa7f2076847;

  /// fi: provider
  ///
  /// In en, this message translates to:
  /// **'camera_'**
  String get sceabe202da;

  /// fi: Nuki Bridge (älylukot, Opener)
  ///
  /// In en, this message translates to:
  /// **'Nuki Bridge (smart locks, Opener)'**
  String get s7d714140d7;

  /// fi: Nuki-älylukot ja Opener Nuki Bridgen kautta kotiverkossa: lukitse, avaa, salpa auki, tila.
  ///
  /// In en, this message translates to:
  /// **'Nuki smart locks and Opener via the Nuki Bridge on the home network: lock, unlock, unlatch, state.'**
  String get s4de40f64d9;

  /// fi: Nuki-sovellus → Bridge → Hallitse → HTTP API päälle; näet samalla IP-osoitteen (portti 8080).
  ///
  /// In en, this message translates to:
  /// **'Nuki app → Bridge → Manage → enable the HTTP API; the IP address is shown there (port 8080).'**
  String get s482d16c3ce;

  /// fi: Paina nyt Nuki Bridgen painiketta lyhyesti (valo syttyy). Odota tässä.
  ///
  /// In en, this message translates to:
  /// **'Briefly press the button on the Nuki Bridge now (its light turns on). Wait here.'**
  String get sbd74055e48;

  /// fi: salpa auki
  ///
  /// In en, this message translates to:
  /// **'unlatch'**
  String get sf363d9cd29;

  /// fi: 1=Lukossa;3=Auki;5=Auki;6=Salpa auki;4=Lukitaan;2=Avataan
  ///
  /// In en, this message translates to:
  /// **'1=Locked;3=Unlocked;5=Unlocked;6=Unlatched;4=Locking;2=Unlocking'**
  String get sd37644b17a;

  /// fi: akku
  ///
  /// In en, this message translates to:
  /// **'battery'**
  String get s295b846c44;

  /// fi: 255=Lukossa;0=Auki
  ///
  /// In en, this message translates to:
  /// **'255=Locked;0=Unlocked'**
  String get s0e57291b85;

  /// fi: Z-Wave (Z-Wave JS)
  ///
  /// In en, this message translates to:
  /// **'Z-Wave (Z-Wave JS)'**
  String get s280313a20e;

  /// fi: Kaikki Z-Wave-laitteet Z-Wave JS UI:n kautta: Aeotec, FIBARO, Heatit, HELTUN, MCO Home, Philio, POPP, Sensative, Danaloc
  ///
  /// In en, this message translates to:
  /// **'Every Z-Wave device through Z-Wave JS UI: Aeotec, FIBARO, Heatit, HELTUN, MCO Home, Philio, POPP, Sensative, Danalock…'**
  String get sb8e26517e5;

  /// fi: Z-Wave JS UI:n kone (portti 3000). Z-Wave JS UI: Asetukset → Home Assistant → WS Server päälle.
  ///
  /// In en, this message translates to:
  /// **'The Z-Wave JS UI machine (port 3000). Z-Wave JS UI: Settings → Home Assistant → WS Server on.'**
  String get sa429a60008;

  /// fi: temperature
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get s1a4eab1f51;

  /// fi: humidity
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get s9e731440d8;

  /// fi: battery
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get s77c638e731;

  /// fi: contact
  ///
  /// In en, this message translates to:
  /// **''**
  String get s96abb7f975;

  /// fi: motion
  ///
  /// In en, this message translates to:
  /// **''**
  String get s91e5760e43;

  /// fi: bthome
  ///
  /// In en, this message translates to:
  /// **''**
  String get s2f76c2abd3;

  /// fi: Kytkimet ja releet
  ///
  /// In en, this message translates to:
  /// **'Switches and relays'**
  String get sc2b99541c7;

  /// fi: Valot ja himmentimet
  ///
  /// In en, this message translates to:
  /// **'Lights and dimmers'**
  String get sd85dbd8e5e;

  /// fi: Verhot ja rullakaihtimet
  ///
  /// In en, this message translates to:
  /// **'Covers and rollers'**
  String get s38935a3c66;

  /// fi: Energiamittarit
  ///
  /// In en, this message translates to:
  /// **'Energy meters'**
  String get s64c6ca7840;

  /// fi: Kytkin
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get s027fcbe1b6;

  /// fi: Rullakaihdin
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get s6814e463b1;

  /// fi: Kokonaisteho
  ///
  /// In en, this message translates to:
  /// **'Total power'**
  String get s477d8b2c95;

  /// fi: Valoisuus
  ///
  /// In en, this message translates to:
  /// **'Light level'**
  String get s32c88e5aa6;

  /// fi: Ovi / ikkuna
  ///
  /// In en, this message translates to:
  /// **'Door / window'**
  String get s57b4effa42;

  /// fi: Vesivuoto
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get s29045a726e;

  /// fi: liikettä
  ///
  /// In en, this message translates to:
  /// **'motion'**
  String get s3b35de231e;

  /// fi: nukkuu – viimeksi {p0}
  ///
  /// In en, this message translates to:
  /// **'asleep – last {p0}'**
  String se7520a3990(String p0);

  /// fi: ei yhteydessä pilveen
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get s3aaacf80d2;

  /// fi: true=Auki;false=Kiinni
  ///
  /// In en, this message translates to:
  /// **'true=Open;false=Closed'**
  String get s5d888c1384;

  /// fi: true=Liikettä;false=Ei liikettä
  ///
  /// In en, this message translates to:
  /// **'true=Motion;false=No motion'**
  String get sd74ad36c31;

  /// fi: true=VUOTO!;false=Kuiva
  ///
  /// In en, this message translates to:
  /// **'true=LEAK!;false=Dry'**
  String get sfa12d7fdd7;

  /// fi: true=SAVUA!;false=OK
  ///
  /// In en, this message translates to:
  /// **'true=SMOKE!;false=OK'**
  String get s1f18c0f400;

  /// fi: Nanoleaf
  ///
  /// In en, this message translates to:
  /// **'Nanoleaf'**
  String get s0f299d2e07;

  /// fi: Nanoleaf-valopaneelit (Shapes, Canvas, Lines, Elements): virta, kirkkaus ja tehosteet kotiverkossa.
  ///
  /// In en, this message translates to:
  /// **'Nanoleaf panels (Shapes, Canvas, Lines, Elements): power, brightness and effects over the home network.'**
  String get s55f2d35756;

  /// fi: Nanoleaf-sovellus → laite → Laitteen tiedot → IP-osoite, tai reitittimen laitelista.
  ///
  /// In en, this message translates to:
  /// **'Nanoleaf app → device → Device info → IP address, or your router\'\'s device list.'**
  String get s05b968ee5c;

  /// fi: Pidä Nanoleafin virtapainiketta pohjassa 5–7 sekuntia, kunnes valot vilkkuvat. Odota tässä.
  ///
  /// In en, this message translates to:
  /// **'Hold the Nanoleaf power button for 5–7 seconds until the lights flash. Wait here.'**
  String get s620e38e4d3;

  /// fi: WLED-ledinauhat (GLEDOPTO, Athom…)
  ///
  /// In en, this message translates to:
  /// **'WLED LED strips (GLEDOPTO, Athom…)'**
  String get s8f97e2baf8;

  /// fi: WLED-ohjaimet: virta, kirkkaus ja tallennetut esiasetukset kotiverkossa. Ei pilveä, ei paritusta.
  ///
  /// In en, this message translates to:
  /// **'WLED controllers: power, brightness and saved presets over the home network. No cloud, no pairing.'**
  String get se27117cf23;

  /// fi: WLED-sovellus tai reitittimen laitelista ("wled-…").
  ///
  /// In en, this message translates to:
  /// **'The WLED app or your router\'\'s device list (\"wled-…\").'**
  String get secd19de5a0;

  /// fi: %
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get s4819add77e;

  /// fi: hPa
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get s4117cb92a9;

  /// fi: W
  ///
  /// In en, this message translates to:
  /// **'bolt'**
  String get s4619bd31a8;

  /// fi: kWh
  ///
  /// In en, this message translates to:
  /// **'bolt'**
  String get s606cbaad36;

  /// fi: V
  ///
  /// In en, this message translates to:
  /// **'bolt'**
  String get s2687c0eee6;

  /// fi: A
  ///
  /// In en, this message translates to:
  /// **'bolt'**
  String get s31d19d826e;

  /// fi: µg/m³
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get se7d1f9f76e;

  /// fi: mg/m³
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get sd993224ef3;

  /// fi: LOCK=Lukossa;UNLOCK=Auki
  ///
  /// In en, this message translates to:
  /// **'LOCK=Locked;UNLOCK=Unlocked'**
  String get s6f53f8cea7;

  /// fi: Zigbee (Zigbee2MQTT)
  ///
  /// In en, this message translates to:
  /// **'Zigbee (Zigbee2MQTT)'**
  String get s264f553034;

  /// fi: Kaikki Zigbee2MQTT:n laitteet kerralla: Aqara, MOES, frient, Heiman, GLEDOPTO, SONOFF, Danfoss Ally, Salus, NOUS, IKEA…
  ///
  /// In en, this message translates to:
  /// **'Every Zigbee2MQTT device at once: Aqara, MOES, frient, Heiman, GLEDOPTO, SONOFF, Danfoss Ally, Salus, NOUS, IKEA… Needs Zigbee2MQTT and an MQTT broker.'**
  String get s1a57c524f8;

  /// fi: MQTT-välittäjän (esim. Mosquitto) osoite, jota Zigbee2MQTT käyttää.
  ///
  /// In en, this message translates to:
  /// **'The MQTT broker (e.g. Mosquitto) that Zigbee2MQTT uses.'**
  String get sb3557cace9;

  /// fi: Zigbee2MQTT:n asetus base_topic (oletus zigbee2mqtt).
  ///
  /// In en, this message translates to:
  /// **'Zigbee2MQTT setting base_topic (default zigbee2mqtt).'**
  String get s7f5f8e33cf;

  /// fi: YAML-tiedostoa ei voitu lukea: {p0}
  ///
  /// In en, this message translates to:
  /// **'Could not read the YAML: {p0}'**
  String sd63d34bfe9(String p0);

  /// fi: "{p0}" käyttää sarjaporttia (USB/RS485) – tarvitset RS485 → TCP -yhdyskäytävän.
  ///
  /// In en, this message translates to:
  /// **'\"{p0}\" uses a serial port (USB/RS485) – you need an RS485 → TCP gateway.'**
  String sc5c9e5e2fc(String p0);

  /// fi: 0=Pois;1=Päällä
  ///
  /// In en, this message translates to:
  /// **'0=Off;1=On'**
  String get s77bf3b424f;

  /// fi: {p0} – asetus
  ///
  /// In en, this message translates to:
  /// **'{p0} – target'**
  String s69135546c8(String p0);

  /// fi: "{p0}" ohitettiin – lisää ne käsin.
  ///
  /// In en, this message translates to:
  /// **'\"{p0}\" were skipped – add them by hand.'**
  String sd88c13e972(String p0);

  /// fi: YAML:sta ei löytynyt Modbus TCP -yhteyttä (modbus: … type: tcp, host: …).
  ///
  /// In en, this message translates to:
  /// **'No Modbus TCP hub found in the YAML (modbus: … type: tcp, host: …).'**
  String get sceebf690e3;

  /// fi: Inactive=Ei käytössä;Ready=Valmiina;DelayedStart=Ajastettu;Run=Käynnissä;Pause=Tauko;ActionRequired=Toimenpide tarvitaan
  ///
  /// In en, this message translates to:
  /// **'Inactive=Inactive;Ready=Ready;DelayedStart=Delayed start;Run=Running;Pause=Paused;ActionRequired=Action required;Finished=Finished;Error=Error;Aborting=Aborting;Offline=Offline'**
  String get s623040a63a;

  /// fi: Home Connect (Bosch, Siemens, Neff, Gaggenau)
  ///
  /// In en, this message translates to:
  /// **'Home Connect (Bosch, Siemens, Neff, Gaggenau)'**
  String get s417e8a2ba4;

  /// fi: Oman Home Connect -sovelluksesi Client ID (developer.home-connect.com → Applications).
  ///
  /// In en, this message translates to:
  /// **'Client ID of your own Home Connect application (developer.home-connect.com → Applications).'**
  String get sb98e3e97cd;

  /// fi: Client Secret (jos sovelluksella on)
  ///
  /// In en, this message translates to:
  /// **'Client Secret (if your app has one)'**
  String get s6e05e7371c;

  /// fi: Samalta sivulta. Device Flow -sovellus toimii yleensä ilmankin.
  ///
  /// In en, this message translates to:
  /// **'From the same page. A Device Flow app usually works without it.'**
  String get s8189ed86b7;

  /// fi: Kirjautumisavain
  ///
  /// In en, this message translates to:
  /// **'Sign-in token'**
  String get sda4f3457c2;

  /// fi: Saadaan kirjautumalla lisäysvelhossa. Älä muuta.
  ///
  /// In en, this message translates to:
  /// **'Comes from signing in in the add wizard. Do not change.'**
  String get sa134f8dd4c;

  /// fi: Simulaattori on kehittäjille (virtuaaliset laitteet).
  ///
  /// In en, this message translates to:
  /// **'The simulator is for developers (virtual appliances).'**
  String get s560a9b1bab;

  /// fi: Oikeat laitteet
  ///
  /// In en, this message translates to:
  /// **'Real appliances'**
  String get s5f614bf8c1;

  /// fi: Home Connect -simulaattori
  ///
  /// In en, this message translates to:
  /// **'Home Connect simulator'**
  String get s3a5c09be5b;

  /// fi: Vain testaukseen: korvaa Home Connectin osoitteen.
  ///
  /// In en, this message translates to:
  /// **'Testing only: replaces Home Connect\'\'s address.'**
  String get s6dcd74c435;

  /// fi: Laitteen tunnus (haId)
  ///
  /// In en, this message translates to:
  /// **'Appliance id (haId)'**
  String get s9de7817d1f;

  /// fi: Home Connect -laitteen haId.
  ///
  /// In en, this message translates to:
  /// **'The Home Connect haId.'**
  String get s1839d16bcc;

  /// fi: Avain
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get s6efa690ee3;

  /// fi: Tila- tai asetusavain, esim. BSH.Common.Status.DoorState.
  ///
  /// In en, this message translates to:
  /// **'Status or setting key, e.g. BSH.Common.Status.DoorState.'**
  String get sf69f72bbac;

  /// fi: Mitä laitteelle tehdään.
  ///
  /// In en, this message translates to:
  /// **'What to do on the appliance.'**
  String get s9d3115f45d;

  /// fi: Käynnistä valittu ohjelma
  ///
  /// In en, this message translates to:
  /// **'Start the selected program'**
  String get s07c53aa821;

  /// fi: Pysäytä ohjelma
  ///
  /// In en, this message translates to:
  /// **'Stop the program'**
  String get sf918a12f32;

  /// fi: Asetus
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get s9384bc6f7e;

  /// fi: Asetuksen avain
  ///
  /// In en, this message translates to:
  /// **'Setting key'**
  String get s6a395924ea;

  /// fi: Vain "Asetus": avain.
  ///
  /// In en, this message translates to:
  /// **'Only \"Setting\": the key.'**
  String get sc58b6af7f5;

  /// fi: Virta: On / Off / Standby. Asetus: arvo.
  ///
  /// In en, this message translates to:
  /// **'Power: On / Off / Standby. Setting: the value.'**
  String get s378202fe0b;

  /// fi: kirjaudu Home Connectiin uudelleen
  ///
  /// In en, this message translates to:
  /// **'sign in to Home Connect again'**
  String get sb1baaa4494;

  /// fi: kirjaudu uudelleen (Yhteydet → Home Connect)
  ///
  /// In en, this message translates to:
  /// **'sign in again (Connections → Home Connect)'**
  String get saa6e9765a0;

  /// fi: Home Connectin pyyntöraja täynnä, odota
  ///
  /// In en, this message translates to:
  /// **'Home Connect rate limit reached, wait'**
  String get s7af74cd31e;

  /// fi: Home Connectin pyyntöraja täynnä
  ///
  /// In en, this message translates to:
  /// **'Home Connect rate limit reached'**
  String get s3cdfd26282;

  /// fi: Valitse ensin ohjelma laitteesta
  ///
  /// In en, this message translates to:
  /// **'Select a program on the appliance first'**
  String get sf8050ebbd9;

  /// fi: Etäkäynnistys ei ole sallittu: kytke laitteesta "Etäkäynnistys" (Remote Start) päälle ja sulje luukku.
  ///
  /// In en, this message translates to:
  /// **'Remote start is not allowed: turn on \"Remote Start\" on the appliance and close the door.'**
  String get s4673002a7e;

  /// fi: ✓ Home Connect vastasi: {p0} laitetta. Komentoja ei lähetetty.
  ///
  /// In en, this message translates to:
  /// **'✓ Home Connect answered: {p0} appliances. No commands were sent.'**
  String scf29ca4038(String p0);

  /// fi: ei yhteyttä
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get see67742c70;

  /// fi: ohjelma
  ///
  /// In en, this message translates to:
  /// **'program'**
  String get s77140ea0df;

  /// fi: aikaa jäljellä
  ///
  /// In en, this message translates to:
  /// **'time left'**
  String get s09166e1ea6;

  /// fi: edistyminen
  ///
  /// In en, this message translates to:
  /// **'progress'**
  String get sfb70dcb933;

  /// fi: luukku
  ///
  /// In en, this message translates to:
  /// **'door'**
  String get sabadf329bd;

  /// fi: uunin lämpötila
  ///
  /// In en, this message translates to:
  /// **'oven temperature'**
  String get s7152ef5dbd;

  /// fi: jääkaapin lämpötila
  ///
  /// In en, this message translates to:
  /// **'fridge temperature'**
  String get s68d00964af;

  /// fi: pakastimen lämpötila
  ///
  /// In en, this message translates to:
  /// **'freezer temperature'**
  String get s824d365527;

  /// fi: ovihälytys
  ///
  /// In en, this message translates to:
  /// **'door alarm'**
  String get sfc4a054c1a;

  /// fi: käynnistä valittu ohjelma
  ///
  /// In en, this message translates to:
  /// **'start selected program'**
  String get s8253ea43e9;

  /// fi: Kodinkoneet Home Connect -tilin kautta: pesu- ja kuivauskoneet, astianpesukoneet, uunit, jääkaapit, kahvikoneet… Tila, j
  ///
  /// In en, this message translates to:
  /// **'Home appliances through your Home Connect account: washers, dryers, dishwashers, ovens, fridges, coffee machines… State, time left, door, start and stop. Free.'**
  String get s1462af9000;

  /// fi: Ilmainen, kerran: kirjaudu developer.home-connect.com (samalla sähköpostilla kuin Home Connect -sovellus) → Applications
  ///
  /// In en, this message translates to:
  /// **'Free, once: sign in at developer.home-connect.com (same e-mail as the Home Connect app) → Applications → Register application → OAuth Flow: \"Device Flow\", Home Connect User Account for Testing: your e-mail. Copy the Client ID here. A new application can take 15–30 min to start working.'**
  String get sdc0ed8435b;

  /// fi: Vain jos sovelluksesi sivulla on Client Secret.
  ///
  /// In en, this message translates to:
  /// **'Only if your application page shows a Client Secret.'**
  String get s625166a5a9;

  /// fi: Kameran käyttäjä (yleensä admin) ja salasana, jonka asetit kameran aktivoinnissa.
  ///
  /// In en, this message translates to:
  /// **'The camera user (usually admin) and the password you set when activating it.'**
  String get s0185672be7;

  /// fi: Käyttäjä admin. Imou: salasana on kameran tarrassa oleva "Safety code" tai laitesalasana.
  ///
  /// In en, this message translates to:
  /// **'User admin. Imou: the password is the \"Safety code\" on the camera label or the device password.'**
  String get s814f4633e3;

  /// fi: Reolink-sovelluksen kameran käyttäjä (yleensä admin) ja salasana.
  ///
  /// In en, this message translates to:
  /// **'The camera user in the Reolink app (usually admin) and its password.'**
  String get s4450807111;

  /// fi: Reolink-sovellus → kamera → Asetukset → Verkko → Lisäasetukset → Palvelinasetukset: laita HTTP ja RTSP päälle. Akkukamer
  ///
  /// In en, this message translates to:
  /// **'Reolink app → camera → Settings → Network → Advanced → Server settings: turn on HTTP and RTSP. Battery cameras (Argus) are not supported.'**
  String get s1095c54819;

  /// fi: Tapo-sovellus → kamera → Lisäasetukset → Kameran tili. Tee sinne käyttäjä ja salasana ja kirjoita ne tähän (ei Tapo-pilv
  ///
  /// In en, this message translates to:
  /// **'Tapo app → camera → Advanced settings → Camera account. Create a user and password there and type them here (not your Tapo cloud login).'**
  String get sc79a5fee2b;

  /// fi: Tee ensin kameran tili: Tapo-sovellus → kamera → Lisäasetukset → Kameran tili.
  ///
  /// In en, this message translates to:
  /// **'First create a camera account: Tapo app → camera → Advanced settings → Camera account.'**
  String get s174e06b97c;

  /// fi: Käyttäjä admin, salasana on kameran tarrassa oleva 6-kirjaiminen vahvistuskoodi (Verification code).
  ///
  /// In en, this message translates to:
  /// **'User admin; the password is the 6-letter verification code on the camera label.'**
  String get s21da6fb5dc;

  /// fi: Ezviz-sovellus → kamera → Asetukset → LAN Live View / RTSP: laita päälle (jos valinta on).
  ///
  /// In en, this message translates to:
  /// **'Ezviz app → camera → Settings → LAN Live View / RTSP: turn it on (if the option exists).'**
  String get s1866ef6dc8;

  /// fi: Käyttäjätunnus ja salasana, jotka eWeLink-sovelluksen kameran ONVIF/RTSP-sivu näyttää (Asetukset → Lisäasetukset → ONVIF
  ///
  /// In en, this message translates to:
  /// **'The username and password shown on the camera\'\'s ONVIF/RTSP page in the eWeLink app (Settings → More settings → ONVIF/RTSP). They are not your eWeLink account login. On a dual-lens model both lenses come from the same device.'**
  String get sceda303e37;

  /// fi: eWeLink-sovellus → kamera → Asetukset → Lisäasetukset → ONVIF/RTSP: laita päälle ja katso kameran IP-osoite, käyttäjätun
  ///
  /// In en, this message translates to:
  /// **'eWeLink app → camera → Settings → More settings → ONVIF/RTSP: turn it on and note the camera IP address, username and password.'**
  String get s9134959509;

  /// fi: Kameran käyttäjä (service, user tai live) ja salasana, jonka asetit Configuration Managerissa tai kameran web-sivulla.
  ///
  /// In en, this message translates to:
  /// **'The camera user (service, user or live) and the password you set in Configuration Manager or on the camera web page.'**
  String get s0ae408f9a0;

  /// fi: Bosch Smart Home -kamerat (Eyes, 360) eivät lähetä videota kotiverkkoon – lisää ne kohdasta "Bosch Smart Home" (yksityis
  ///
  /// In en, this message translates to:
  /// **'Bosch Smart Home cameras (Eyes, 360) do not stream video on the home network – add them with \"Bosch Smart Home\" (privacy mode, notifications, light).'**
  String get s61c9b76fa1;

  /// fi: Kameran käyttäjä ja salasana (usein admin). ONVIF pitää ehkä laittaa päälle kameran asetuksista. Tapo käyttää porttia 20
  ///
  /// In en, this message translates to:
  /// **'The camera user and password (often admin). ONVIF may need to be enabled in the camera settings. Tapo uses port 2020 and needs a Camera Account (Tapo app → camera → Advanced settings → Camera account), not your Tapo cloud login.'**
  String get s69d3885720;

  /// fi: Valvontakamera
  ///
  /// In en, this message translates to:
  /// **'Security camera'**
  String get s32270de47a;

  /// fi: Hikvision, Dahua, Reolink, Tapo, Ezviz, Sonoff tai muu ONVIF/RTSP-kamera. Kuva ruutuun, live-video kotona.
  ///
  /// In en, this message translates to:
  /// **'Hikvision, Dahua, Reolink, Tapo, Ezviz, Sonoff or any ONVIF/RTSP camera. Picture on a tile, live video at home.'**
  String get s652458eb87;

  /// fi: Kameran sovelluksesta (laitetiedot) tai reitittimen laitelistasta.
  ///
  /// In en, this message translates to:
  /// **'In the camera app (device info) or your router\'\'s device list.'**
  String get se8ea97c5eb;

  /// fi: Tyhjänä kokeillaan tavallisia portteja (80, 2020, 8000, 8080…). Tapo: 2020.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to try the usual ports (80, 2020, 8000, 8080…). Tapo: 2020.'**
  String get sf361b8971e;

  /// fi: kamera
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get s1577068729;

  /// fi: Kamera kertoo olevansa "{p0}", ei {p1}. Se on lisätty silti ONVIF-kamerana.
  ///
  /// In en, this message translates to:
  /// **'The camera says it is \"{p0}\", not {p1}. It was added anyway as an ONVIF camera.'**
  String sbfd6f856ef(String p0, String p1);

  /// fi: Videon osoitetta ei voitu varmistaa (kamera vastasi RTSP {p0}). Se on lisätty silti – jos kuva ei näy, tarkista tunnus j
  ///
  /// In en, this message translates to:
  /// **'The video address could not be verified (the camera answered RTSP {p0}). It was added anyway – if no picture shows, check the username and password.'**
  String s56ef345ef2(String p0);

  /// fi: Kuvavirta {p0}/{p1} (oma linssi tai kanava)
  ///
  /// In en, this message translates to:
  /// **'Stream {p0}/{p1} (own lens or channel)'**
  String s83d937ae6b(String p0, String p1);

  /// fi: Kuva ruutuun, live-video kotiverkossa
  ///
  /// In en, this message translates to:
  /// **'Picture on the tile, live video at home'**
  String get s136c6f0d2b;

  /// fi: Live-video kotiverkossa (ei kuvaa etänä)
  ///
  /// In en, this message translates to:
  /// **'Live video at home (no picture away)'**
  String get s2101774157;

  /// fi: PTZ-ohjaus
  ///
  /// In en, this message translates to:
  /// **'PTZ control'**
  String get s208a59a323;

  /// fi: Laitteen avain puuttuu
  ///
  /// In en, this message translates to:
  /// **'Device key missing'**
  String get sdd483f7f78;

  /// fi: Väärä laitteen avain (devicekey)
  ///
  /// In en, this message translates to:
  /// **'Wrong device key (devicekey)'**
  String get sfb72a207e0;

  /// fi: Sonoff eWeLink LAN (salattu)
  ///
  /// In en, this message translates to:
  /// **'Sonoff eWeLink LAN (encrypted)'**
  String get sc8b59edea5;

  /// fi: Laitteen tunnus (Device ID)
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get s823a139bb1;

  /// fi: eWeLink-sovellus → laite → Asetukset → Laitteen tunnus.
  ///
  /// In en, this message translates to:
  /// **'eWeLink app → device → Settings → Device ID.'**
  String get sc0c760d1b6;

  /// fi: Tyhjä = haetaan mDNS:llä joka kerta (suositus, jos osoite vaihtuu).
  ///
  /// In en, this message translates to:
  /// **'Empty = found with mDNS every time (recommended if the address changes).'**
  String get s39d7729e9f;

  /// fi: Laitteen avain (devicekey)
  ///
  /// In en, this message translates to:
  /// **'Device key (devicekey)'**
  String get s82e87d091b;

  /// fi: Salausavain. Tallentuu vain tälle laitteelle.
  ///
  /// In en, this message translates to:
  /// **'Encryption key. Stored on this device only.'**
  String get s93e0e8861a;

  /// fi: Kanava: lisää kenttä outlet (0, 1, …) monikanavaisille.
  ///
  /// In en, this message translates to:
  /// **'Channel: add an outlet field (0, 1, …) for multi-channel devices.'**
  String get se106001035;

  /// fi: Kytkin (1/0)
  ///
  /// In en, this message translates to:
  /// **'Switch (1/0)'**
  String get sd0c16a8638;

  /// fi: Teho (W)
  ///
  /// In en, this message translates to:
  /// **'Power (W)'**
  String get s4ba00d3333;

  /// fi: Jännite (V)
  ///
  /// In en, this message translates to:
  /// **'Voltage (V)'**
  String get sa510517ad6;

  /// fi: Virta (A)
  ///
  /// In en, this message translates to:
  /// **'Current (A)'**
  String get s348bd4e5f0;

  /// fi: Lämpötila (°C)
  ///
  /// In en, this message translates to:
  /// **'Temperature (°C)'**
  String get s32aa0dde33;

  /// fi: Kosteus (%)
  ///
  /// In en, this message translates to:
  /// **'Humidity (%)'**
  String get se516f09209;

  /// fi: Arvo 1/0 kytkimestä.
  ///
  /// In en, this message translates to:
  /// **'Value 1/0 from the toggle.'**
  String get sa7ce546ed1;

  /// fi: Kytkin päälle/pois (arvo 1/0)
  ///
  /// In en, this message translates to:
  /// **'Switch on/off (value 1/0)'**
  String get sb4b475b660;

  /// fi: Sonoff ei näy kotiverkossa (mDNS)
  ///
  /// In en, this message translates to:
  /// **'The Sonoff is not visible on the home network (mDNS)'**
  String get s4d2703ac9b;

  /// fi: Jos tiedät avaimen. Muuten täytä alla oman eWeLink-kehittäjäsovelluksesi tiedot – avain haetaan kerran ja ohjaus pysyy p
  ///
  /// In en, this message translates to:
  /// **'If you know the key. Otherwise fill in your own eWeLink developer app below – the key is fetched once and control stays local.'**
  String get s02e0a98408;

  /// fi: Sonoff (eWeLink LAN-tila)
  ///
  /// In en, this message translates to:
  /// **'Sonoff (eWeLink LAN mode)'**
  String get s2d442b23e2;

  /// fi: Tavallinen eWeLink-Sonoff ilman DIY-tilaa: ohjaus kotiverkossa salattuna. Tarvitaan laitteen avain kerran.
  ///
  /// In en, this message translates to:
  /// **'A regular eWeLink Sonoff without DIY mode: encrypted local control. Needs the device key once.'**
  String get sc977fcb4f5;

  /// fi: Laite löytyy yleensä itse (mDNS). eWeLink-sovelluksessa LAN-ohjauksen pitää olla sallittu (oletus).
  ///
  /// In en, this message translates to:
  /// **'Usually found automatically (mDNS). LAN control must be allowed in the eWeLink app (default).'**
  String get se287b905f6;

  /// fi: Avain (devicekey) on laitteen salausavain. Saat sen eWeLinkistä omalla kehittäjäsovelluksella (dev.ewelink.cc → oma sove
  ///
  /// In en, this message translates to:
  /// **'The devicekey is the device\'\'s encryption key. Get it from eWeLink with your own developer app (dev.ewelink.cc → your app → APPID and APP SECRET) – Molaplan asks once and never uses the cloud for control.'**
  String get s7c6206fa83;

  /// fi: dev.ewelink.cc → oma sovellus.
  ///
  /// In en, this message translates to:
  /// **'dev.ewelink.cc → your app.'**
  String get sccd5375513;

  /// fi: Käytetään vain avaimen hakuun, ei tallenneta.
  ///
  /// In en, this message translates to:
  /// **'Only used to fetch the key, not stored.'**
  String get sd190b6d70e;

  /// fi: Puhelin muodossa +358…
  ///
  /// In en, this message translates to:
  /// **'Phone as +358…'**
  String get sd936bbcc2d;

  /// fi: Valo{p0}
  ///
  /// In en, this message translates to:
  /// **'Light{p0}'**
  String s1a9acfbc67(String p0);

  /// fi: Verho{p0}
  ///
  /// In en, this message translates to:
  /// **'Cover{p0}'**
  String s5d0fb602f6(String p0);

  /// fi: Lämpötila{p0} (lisäosa)
  ///
  /// In en, this message translates to:
  /// **'Temperature{p0} (add-on)'**
  String s82ecc12a66(String p0);

  /// fi: valoisuus
  ///
  /// In en, this message translates to:
  /// **'illuminance'**
  String get s8b234e1a6f;

  /// fi: IKEA Dirigera
  ///
  /// In en, this message translates to:
  /// **'IKEA Dirigera'**
  String get sf34c97592f;

  /// fi: IKEAn älykeskus ja sen valot ja pistorasiat (Zigbee). Paritus keskuksen painikkeella.
  ///
  /// In en, this message translates to:
  /// **'IKEA smart hub and its lights and plugs (Zigbee). Pair with the button on the hub.'**
  String get sb38eac6a87;

  /// fi: IKEA Home smart -sovelluksessa: Asetukset → Keskus → IP-osoite. Tai reitittimen laitelistasta: "gw2-…" tai "dirigera".
  ///
  /// In en, this message translates to:
  /// **'In the IKEA Home smart app: Settings → Hub → IP address. Or in your router\'\'s device list: \"gw2-…\" or \"dirigera\".'**
  String get s4e92ab791e;

  /// fi: Paina nyt Dirigera-keskuksen pohjassa olevaa toimintopainiketta (pieni painike) kerran. Odota tässä.
  ///
  /// In en, this message translates to:
  /// **'Press the action button on the bottom of the Dirigera hub once now. Wait here.'**
  String get s73824fc3d0;

  /// fi: Sälekaihdin
  ///
  /// In en, this message translates to:
  /// **'Blind'**
  String get s92d24d0543;

  /// fi: Ilmanpuhdistin
  ///
  /// In en, this message translates to:
  /// **'Air purifier'**
  String get s7727759a28;

  /// fi: Pistorasia
  ///
  /// In en, this message translates to:
  /// **'Plug'**
  String get sda8d9bf1cd;

  /// fi: asento (100 = kiinni)
  ///
  /// In en, this message translates to:
  /// **'position (100 = closed)'**
  String get s06444f278d;

  /// fi: Laite toimii Molaplan-sovelluksessa.
  ///
  /// In en, this message translates to:
  /// **'The device works in the Molaplan app.'**
  String get s1882976d8c;

  /// fi: Selainversiossa piilotetaan ruudut, joihin ei saada yhteyttä tästä selaimesta, ja ruudut, jotka eivät ole vastanneet noin kymmeneen minuuttiin. Piilotetut saa näkyviin näkymän alareunasta. Koskee vain tätä selainta.
  ///
  /// In en, this message translates to:
  /// **'In the browser, tiles this browser cannot reach, and tiles that have not answered for about ten minutes, are hidden. Hidden tiles can be opened from the bottom of the view. This browser only.'**
  String get s25a2d52c2d;

  /// fi: Näytä aina
  ///
  /// In en, this message translates to:
  /// **'Always show'**
  String get s493a65113f;

  /// fi: Still-kuvaa ei saatu tehtyä videovirrasta selaimessa.
  ///
  /// In en, this message translates to:
  /// **'A still picture could not be made from the video stream in the browser.'**
  String get s5972cf4f3b;

  /// fi: Ruutu tulee näkyviin heti, kun laite vastaa.
  ///
  /// In en, this message translates to:
  /// **'The tile comes back as soon as the device answers.'**
  String get s70aa3dc5be;

  /// fi: Tätä laitetta ei voi käyttää selaimesta.
  ///
  /// In en, this message translates to:
  /// **'This device cannot be used from the browser.'**
  String get s786c05c9e1;

  /// fi: Laite ei ole vastannut tarpeeksi pitkään.
  ///
  /// In en, this message translates to:
  /// **'The device has not answered for a while.'**
  String get s98ffbf5518;

  /// fi: {p0} laitetta piilotettu – ei käytettävissä selaimessa
  ///
  /// In en, this message translates to:
  /// **'{p0} devices hidden – not available in the browser'**
  String sa59af4f48b(String p0);

  /// fi: Lisää kotisilta, niin tämä toimii myös selaimessa.
  ///
  /// In en, this message translates to:
  /// **'Add a home bridge so this also works in the browser.'**
  String get sb3a5e212e2;

  /// fi: Piilota automaattisesti
  ///
  /// In en, this message translates to:
  /// **'Hide automatically'**
  String get sbfd72f3328;

  /// fi: Asenna ffmpeg kotisillan tietokoneelle, tai käytä Molaplan-sovellusta kotisiltana.
  ///
  /// In en, this message translates to:
  /// **'Install ffmpeg on the home-bridge computer, or use the Molaplan app as the home bridge.'**
  String get scdf43305db;

  /// fi: Koskee vain tätä selainta. Muissa laitteissa ruutu pysyy paikallaan.
  ///
  /// In en, this message translates to:
  /// **'Applies only in this browser. On other devices the tile stays in place.'**
  String get se24b0e7f60;

  /// fi: Piilota selaimessa toimimattomat
  ///
  /// In en, this message translates to:
  /// **'Hide tiles that don\'\'t work in the browser'**
  String get se9702be418;

  /// fi: Selainnäkymä
  ///
  /// In en, this message translates to:
  /// **'Browser view'**
  String get sf328dcc536;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'et', 'fi', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'et':
      return AppLocalizationsEt();
    case 'fi':
      return AppLocalizationsFi();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
