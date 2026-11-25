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

  /// fi: Kotisilta ei ole päällä
  ///
  /// In en, this message translates to:
  /// **'The home bridge is off'**
  String get s7e11595f9e;

  /// fi: Etäyhteys kulkee kotona olevan sillan (tabletti tai PC) kautta. Tarkista että se on päällä, Molaplan on auki ja sillä on
  ///
  /// In en, this message translates to:
  /// **'Remote access goes through the bridge at home (tablet or PC). Check that it is on, Molaplan is open and it has internet.'**
  String get s2cd1df086e;

  /// fi: Ei nettiyhteyttä
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get sdfb639365a;

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

  /// fi: Jokin meni pieleen
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get s9dd2ff794f;

  /// fi: Tarkista asetukset ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Check the settings and try again.'**
  String get sbb62433c2c;

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

  /// fi: ei tavoitettavissa
  ///
  /// In en, this message translates to:
  /// **'unreachable'**
  String get s4dbb677293;

  /// fi: päällä
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get s609cb4c5f9;

  /// fi: pois
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get s356d822497;

  /// fi: himmennettävä
  ///
  /// In en, this message translates to:
  /// **'dimmable'**
  String get sf50732e8e8;

  /// fi: koko huone ({p0} valoa)
  ///
  /// In en, this message translates to:
  /// **'whole room'**
  String s3832b8c729(String p0);

  /// fi: kirkkaus
  ///
  /// In en, this message translates to:
  /// **'brightness'**
  String get see129fb410;

  /// fi: Kanava {p0}
  ///
  /// In en, this message translates to:
  /// **'Channel {p0}'**
  String s08d04d58a9(String p0);

  /// fi: teho
  ///
  /// In en, this message translates to:
  /// **'power'**
  String get se78754330c;

  /// fi: Shelly
  ///
  /// In en, this message translates to:
  /// **'Shelly'**
  String get sfcb44be1a0;

  /// fi: Releet ja pistorasiat: Pro 4PM, Plus 1PM, Plug S, 2.5… Löytyy automaattisesti, ruudut tehdään joka kanavalle.
  ///
  /// In en, this message translates to:
  /// **'Relays and plugs: Pro 4PM, Plus 1PM, Plug S, 2.5… Found automatically, tiles for every channel.'**
  String get sa6ff717527;

  /// fi: Shelly-sovelluksessa: avaa laite → ratas (asetukset) → Laitetiedot → IP-osoite. Tai reitittimen laitelistasta: nimi alka
  ///
  /// In en, this message translates to:
  /// **'In the Shelly app: open the device → gear (settings) → Device information → IP address. Or in your router\'\'s device list: the name starts with \"shelly…\".'**
  String get sd7e123cd2f;

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

  /// fi: ei yhteydessä pilveen
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get s3aaacf80d2;

  /// fi: Shelly Cloud
  ///
  /// In en, this message translates to:
  /// **'Shelly Cloud'**
  String get s252ebed5af;

  /// fi: Palvelin
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get s25399cd337;

  /// fi: Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Server URI.
  ///
  /// In en, this message translates to:
  /// **'Shelly app → User settings → Authorization cloud key → Server URI.'**
  String get s246c7a46ff;

  /// fi: Pilviavain
  ///
  /// In en, this message translates to:
  /// **'Cloud key'**
  String get s61a2d946a4;

  /// fi: Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Get key.
  ///
  /// In en, this message translates to:
  /// **'Shelly app → User settings → Authorization cloud key → Get key.'**
  String get s9d468f5c64;

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

  /// fi: Valo
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get sa376ec78ec;

  /// fi: Pistorasia
  ///
  /// In en, this message translates to:
  /// **'Plug'**
  String get sda8d9bf1cd;

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

  /// fi: Päivitä
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get sfbf490ec3f;

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

  /// fi: Peruuta
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get s809d0eb368;

  /// fi: Avaa asetukset
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get sa1bd8d2533;

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

  /// fi: Näytä
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get sb06bee9921;

  /// fi: Salasana ei täsmää. Kirjoita tilin salasana (sama jolla kirjauduit ensimmäisen kerran).
  ///
  /// In en, this message translates to:
  /// **'The password does not match. Type your account password.'**
  String get sf1b5d0ffa6;

  /// fi: Jokin meni pieleen: {p0}
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {p0}'**
  String s11ee4426b2(String p0);

  /// fi: Ei nettiyhteyttä. Tarkista wifi tai mobiilidata ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check Wi-Fi or mobile data and try again.'**
  String get sbf59e43c36;

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

  /// fi: Myös tällä laitteella on omia laitteita ja ruutuja. Mitä tehdään?
  ///
  /// In en, this message translates to:
  /// **'This device has its own devices and tiles too. What should we do?'**
  String get s43d6286f35;

  /// fi: Silloin samat kodit, laitteet ja ruudut näkyvät kaikilla laitteillasi, joilla kirjaudut tälle tilille.
  ///
  /// In en, this message translates to:
  /// **'Then the same homes, devices and tiles appear on every device signed in to this account.'**
  String get sd8a380a86d;

  /// fi: Peru ja kirjaudu ulos
  ///
  /// In en, this message translates to:
  /// **'Cancel and sign out'**
  String get sec25d10ff5;

  /// fi: Käytä tilin asetuksia
  ///
  /// In en, this message translates to:
  /// **'Use the account\'\'s setup'**
  String get sb7a13da58b;

  /// fi: Yhdistä molemmat (suositus)
  ///
  /// In en, this message translates to:
  /// **'Combine both (recommended)'**
  String get sf498dceefb;

  /// fi: Tallenna tiliin
  ///
  /// In en, this message translates to:
  /// **'Save to account'**
  String get s9542718c6f;

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

  /// fi: Kirjaudu sisään
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get se697487621;

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

  /// fi: Takaisin
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get scf7e14661c;

  /// fi: Kirjaudu koodilla
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get s22c960ff4f;

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

  /// fi: Tallenna
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get s162a85c6ef;

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

  /// fi: Opettele kaukosäädin
  ///
  /// In en, this message translates to:
  /// **'Learn remote'**
  String get s8e4e78e067;

  /// fi: Valmis
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get s2acab0eccd;

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

  /// fi: Kopioi
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get sd6f41faa1d;

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

  /// fi: Ilmalämpöpumppu (huoltoliitäntä/ESPHome)
  ///
  /// In en, this message translates to:
  /// **'Heat pump (service port/ESPHome)'**
  String get sbd2f94e7a4;

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

  /// fi: Lisää
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get s5a40f12b6a;

  /// fi: Lämmitys
  ///
  /// In en, this message translates to:
  /// **'Heating'**
  String get sa3a093e55e;

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

  /// fi: Pois
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get s33831dd49f;

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

  /// fi: Ei kotisiltaa: termostaatti ei ohjaa vielä. Ota etäyhteys käyttöön kodin tabletilla.
  ///
  /// In en, this message translates to:
  /// **'No home bridge: the thermostat is not controlling yet. Set up remote access on the home tablet.'**
  String get s4f1166fe24;

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

  /// fi: Ei mitään
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get se12fc46923;

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

  /// fi: Nimi
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sb1924acbe7;

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

  /// fi: Edistyneet
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sf4caddf894;

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

  /// fi: Vähimmäisaika päällä
  ///
  /// In en, this message translates to:
  /// **'Minimum on time'**
  String get s64540136ff;

  /// fi: Vähimmäisaika pois
  ///
  /// In en, this message translates to:
  /// **'Minimum off time'**
  String get s21713a2177;

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

  /// fi: Seuraava
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get s6c3e76828b;

  /// fi: Muokkaa
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get s187d328bb1;

  /// fi: Poista
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sc1845eb440;

  /// fi: Poistetaanko termostaatti?
  ///
  /// In en, this message translates to:
  /// **'Delete the thermostat?'**
  String get s87984716cb;

  /// fi: Nyt
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get s29fd8d5b5e;

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

  /// fi: Ota etäyhteys käyttöön kodin tabletilla (Asetukset → Etäyhteys). Siihen asti termostaatti ei ohjaa.
  ///
  /// In en, this message translates to:
  /// **'Set up remote access on the home tablet (Settings → Remote access). Until then it does not control anything.'**
  String get s9c1b5394df;

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

  /// fi: Älykäs lämmitys
  ///
  /// In en, this message translates to:
  /// **'Smart heating'**
  String get s798f7b2876;

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

  /// fi: Ei hintoja
  ///
  /// In en, this message translates to:
  /// **'No prices'**
  String get s306729fe62;

  /// fi: halvin
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get s723c887da6;

  /// fi: kallein
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get scaaff6345d;

  /// fi: huomenna mukana
  ///
  /// In en, this message translates to:
  /// **'incl. tomorrow'**
  String get s65982a11bc;

  /// fi: huominen klo 14 jälkeen
  ///
  /// In en, this message translates to:
  /// **'tomorrow after 14:00'**
  String get se79acaf837;

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

  /// fi: Osoitteesta vastasi laite, joka ei ole {p0}. Tarkista osoite ja kokeile uudelleen.
  ///
  /// In en, this message translates to:
  /// **'The device at that address is not {p0}. Check the address.'**
  String s5b7d02a301(String p0);

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

  /// fi: Tarkista että kotona oleva kotisilta (tabletti tai PC) on päällä, Molaplan on auki ja sillä on netti.
  ///
  /// In en, this message translates to:
  /// **'Check that the bridge at home is on, Molaplan is open and it has internet.'**
  String get scc1918f2dc;

  /// fi: Yritä uudelleen. Jos ongelma toistuu, käynnistä laite uudelleen.
  ///
  /// In en, this message translates to:
  /// **'Try again. If it keeps happening, restart the device.'**
  String get sce0949d6fc;

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

  /// fi: Täytä ensin
  ///
  /// In en, this message translates to:
  /// **'Fill in first'**
  String get s43370d968c;

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

  /// fi: Haku tehdään kotisillan kautta, joten tämä toimii myös kodin ulkopuolella.
  ///
  /// In en, this message translates to:
  /// **'Searching through the home bridge, so this works away from home too.'**
  String get sc788897ba0;

  /// fi: Etsin laitteita kodin wifistä. Napauta omaasi.
  ///
  /// In en, this message translates to:
  /// **'Looking on your home Wi-Fi. Tap yours.'**
  String get s0f7361f40c;

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

  /// fi: kotisillan kautta
  ///
  /// In en, this message translates to:
  /// **'via home bridge'**
  String get saae59a3865;

  /// fi: Laitteita ei löytynyt automaattisesti. Tarkista että {p0} on päällä ja samassa wifissä{p1}. Voit myös kirjoittaa osoitte
  ///
  /// In en, this message translates to:
  /// **'Nothing found automatically. Check that {p0} is on and on the same Wi-Fi. You can also type the address below.'**
  String s8eabd27f68(String p0, String p1);

  /// fi: Etsi uudelleen
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get s2fc39b0bd7;

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

  /// fi: IP-osoite
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get s178e07f06b;

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

  /// fi: Paina painiketta nyt
  ///
  /// In en, this message translates to:
  /// **'Press the button now'**
  String get s0a7134d0e3;

  /// fi: Aikaa jäljellä {p0} s
  ///
  /// In en, this message translates to:
  /// **'{p0} s left'**
  String s43118959d5(String p0);

  /// fi: Yhdistetään…
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get sba10f23f03;

  /// fi: Laitteen salasana
  ///
  /// In en, this message translates to:
  /// **'Device password'**
  String get se4095d7d95;

  /// fi: Yhdistä
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get sdbdf676485;

  /// fi: Yritä uudelleen
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get s200542b930;

  /// fi: Olen kodin ulkopuolella
  ///
  /// In en, this message translates to:
  /// **'I am away from home'**
  String get s8f610a3bb2;

  /// fi: Tekniset tiedot
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get sf77125583f;

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

  /// fi: Ota etäyhteys käyttöön
  ///
  /// In en, this message translates to:
  /// **'Set up remote access'**
  String get s856a422504;

  /// fi: Et ole kotona? Ota etäyhteys käyttöön
  ///
  /// In en, this message translates to:
  /// **'Not at home? Turn on remote access'**
  String get sd9923cda70;

  /// fi: Lisää laite
  ///
  /// In en, this message translates to:
  /// **'Add a device'**
  String get s876c7230a2;

  /// fi: Sulje
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get s1e593aeca2;

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
  /// **'IR is one-way: the heat pump does not confirm. Molaplan always sends the whole state and shows what it sent. Learn other remote buttons later: Connections → blaster → \"Learn remote\".'**
  String get s566585dc66;

  /// fi: Ohje ja automaattinen haku
  ///
  /// In en, this message translates to:
  /// **'Guide and automatic search'**
  String get s0dd21e026c;

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

  /// fi: Valitse kamerayhteys
  ///
  /// In en, this message translates to:
  /// **'Choose a camera connection'**
  String get s4529c1010a;

  /// fi: Virta päättyi
  ///
  /// In en, this message translates to:
  /// **'Stream ended'**
  String get sc95fb5440b;

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
  String get s4e35ba5321;

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

  /// fi: Ei päälläoloa seuraavan vuorokauden aikana (tai huomisen hinnat puuttuvat vielä).
  ///
  /// In en, this message translates to:
  /// **'No on-times in the next day (or tomorrow\'\'s prices are not out yet).'**
  String get s406e599999;

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

  /// fi: Hinta-alue {p0}. Hinnat: pörssisähkö (day-ahead), ALV {p1} %. Vaihda alue ja siirtohinta lisäämällä "Sähkön hinta" -lait
  ///
  /// In en, this message translates to:
  /// **'Price area {p0}. Day-ahead spot prices incl. VAT {p1} %. Add the \"Electricity price\" device to change area and fees.'**
  String sf87d92faf4(String p0, String p1);

  /// fi: Valitse yhteystyyppi
  ///
  /// In en, this message translates to:
  /// **'Choose connection type'**
  String get s2adc3a77ed;

  /// fi: Yhteydet
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get s78d94155f1;

  /// fi: Uusi yhteys
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get s776d8b06bf;

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

  /// fi: Ei yhteyttä
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get s1f8cf57b2c;

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

  /// fi: Etäyhteys
  ///
  /// In en, this message translates to:
  /// **'Remote access'**
  String get s370acd310d;

  /// fi: Ohjaa kotia myös kodin ulkopuolelta
  ///
  /// In en, this message translates to:
  /// **'Control your home from anywhere'**
  String get s0b57661c18;

  /// fi: Kotona Molaplan puhuu laitteille suoraan. Muualla yhteys kulkee salattuna kotisillan kautta – porttiohjauksia tai reitit
  ///
  /// In en, this message translates to:
  /// **'At home Molaplan talks to your devices directly. Elsewhere it goes encrypted through your home bridge – no port forwarding or router settings. The app picks the right path automatically.'**
  String get sb43ef4094c;

  /// fi: Yhdistetty kotiin
  ///
  /// In en, this message translates to:
  /// **'Connected to home'**
  String get s075e5a4864;

  /// fi: Kotona = suoraan laitteille. Etäyhteys = kotisillan kautta. Ei yhteyttä = kumpikaan ei vastaa.
  ///
  /// In en, this message translates to:
  /// **'At home = directly. Remote = through the home bridge. No connection = neither answers.'**
  String get sa7679488fb;

  /// fi: Testaa etäyhteys
  ///
  /// In en, this message translates to:
  /// **'Test remote access'**
  String get s19cec9667e;

  /// fi: Kopioi kodin näkymät
  ///
  /// In en, this message translates to:
  /// **'Copy home dashboards'**
  String get s86ad95fa48;

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

  /// fi: Poista
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get s9593939a4c;

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

  /// fi: Lisäasetukset
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get se7b8d659b5;

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

  /// fi: Pois päältä
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scc0cccf89d;

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

  /// fi: Avaa kotona olevalla kotisillalla (tabletti tai PC) Molaplan → Asetukset → Etäyhteys → Tee tästä laitteesta kotisilta.
  ///
  /// In en, this message translates to:
  /// **'On the home bridge (tablet or PC at home) open Molaplan → Settings → Remote access → Make this device the home bridge.'**
  String get s3a141e0c32;

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

  /// fi: Laite "{p0}" yhdistetty!
  ///
  /// In en, this message translates to:
  /// **'Device \"{p0}\" connected!'**
  String s7132345f20(String p0);

  /// fi: Kotisilta
  ///
  /// In en, this message translates to:
  /// **'Home bridge'**
  String get sb38b582dab;

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

  /// fi: Kodin nimi
  ///
  /// In en, this message translates to:
  /// **'Home name'**
  String get sc58a7d7121;

  /// fi: Skannaa puhelimella
  ///
  /// In en, this message translates to:
  /// **'Scan with the phone'**
  String get s9715416100;

  /// fi: Puhelimessa: Molaplan → Asetukset → Etäyhteys → Yhdistä tämä laite kotiin
  ///
  /// In en, this message translates to:
  /// **'On the phone: Molaplan → Settings → Remote access → Connect this device to home'**
  String get sf54c6d871c;

  /// fi: Voimassa
  ///
  /// In en, this message translates to:
  /// **'Valid for'**
  String get sf7fa9632f3;

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

  /// fi: Luettu arvo
  ///
  /// In en, this message translates to:
  /// **'Value read'**
  String get s76e7a995de;

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

  /// fi: Otsikko
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get s8a8673aafe;

  /// fi: Kuvake
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get scf37cbeda8;

  /// fi: Automaattinen
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get sa444aab286;

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

  /// fi: Yhteys
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get s5210a5ad23;

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

  /// fi: Värirajat (arvo ≥ raja → väri)
  ///
  /// In en, this message translates to:
  /// **'Color thresholds (value ≥ limit → color)'**
  String get sc0f5a14d2b;

  /// fi: Raja
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get scd65d31d4c;

  /// fi: Lisää raja
  ///
  /// In en, this message translates to:
  /// **'Add threshold'**
  String get s30a2c0f460;

  /// fi: Kumoa
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get s4226eb046f;

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

  /// fi: Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Molaplan löytää lämpöpumpun itse.
  ///
  /// In en, this message translates to:
  /// **'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Found automatically.'**
  String get sa35e37b4b4;

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

  /// fi: Lisää ruutu
  ///
  /// In en, this message translates to:
  /// **'Add tile'**
  String get scdfd80f963;

  /// fi: Lisää laite
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get s41c3cebc48;

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

  /// fi: Kulutus kirjataan, kun sovellus on auki (kodin tabletilla jatkuvasti).
  ///
  /// In en, this message translates to:
  /// **'Use is recorded while the app is open (all the time on the home tablet).'**
  String get sbbd89fbc05;

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

  /// fi: PIN-koodi
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get sdfc012fb4e;

  /// fi: PIN
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get s1df6e2eaa7;

  /// fi: Muista tällä laitteella
  ///
  /// In en, this message translates to:
  /// **'Remember on this device'**
  String get secab66c046;

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

  /// fi: Arvo
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get s38ac222392;

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

  /// fi: Päällä
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get s4cbe24240f;

  /// fi: Lisäasetukset
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get sdc398885dc;

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

  /// fi: Kirjaudu tai luo tili
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get s9bb545e9b3;

  /// fi: Näyttää tekniset asetukset: yhteydet (HTTP, MQTT, Modbus…), viestit, JSON-polut ja ruutujen lähteet. Useimmat eivät tarv
  ///
  /// In en, this message translates to:
  /// **'Shows technical settings: connections (HTTP, MQTT, Modbus…), payloads, JSON paths and tile sources. Most people don\'\'t need these.'**
  String get s21f870dbc2;

  /// fi: Ohjaa kotia myös kodin ulkopuolelta.
  ///
  /// In en, this message translates to:
  /// **'Control your home from outside too.'**
  String get saec69088a5;

  /// fi: Ohjeet: VPN, Nabu Casa, pilvi-MQTT
  ///
  /// In en, this message translates to:
  /// **'Guides: VPN, Nabu Casa, cloud MQTT'**
  String get scc3d01ee5e;

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

  /// fi: Lisää esimerkkinäkymä (kamera, hälytys, valot, IV-kone). Vaihda osoitteet omiksesi.
  ///
  /// In en, this message translates to:
  /// **'Add an example dashboard (camera, alarm, lights, ventilation). Replace the addresses with yours.'**
  String get s412c666544;

  /// fi: Lisää esimerkkinäkymä
  ///
  /// In en, this message translates to:
  /// **'Add example dashboard'**
  String get sec02c7c071;

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

  /// fi: Tervetuloa Molaplaniin
  ///
  /// In en, this message translates to:
  /// **'Welcome to Molaplan'**
  String get s907220900d;

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

  /// fi: WebSocket
  ///
  /// In en, this message translates to:
  /// **'WebSocket'**
  String get s3d43664fcc;

  /// fi: Osoite
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get sfcbb753f53;

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

  /// fi: Salli itse allekirjoitettu sertifikaatti
  ///
  /// In en, this message translates to:
  /// **'Allow self-signed certificate'**
  String get s2c4fd261e2;

  /// fi: Suodatin (viesti sisältää)
  ///
  /// In en, this message translates to:
  /// **'Filter (message contains)'**
  String get s4d089aab74;

  /// fi: JSON-polku
  ///
  /// In en, this message translates to:
  /// **'JSON path'**
  String get s55c951a8ad;

  /// fi: Regex (ryhmä 1)
  ///
  /// In en, this message translates to:
  /// **'Regex (group 1)'**
  String get s10813e25b3;

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

  /// fi: Kamera (MJPEG / JPEG)
  ///
  /// In en, this message translates to:
  /// **'Camera (MJPEG / JPEG)'**
  String get sad3975b3c1;

  /// fi: Kameran osoite
  ///
  /// In en, this message translates to:
  /// **'Camera base URL'**
  String get s1534821f4a;

  /// fi: Tila
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get se995a6862d;

  /// fi: Kuvan päivitysväli (s, snapshot)
  ///
  /// In en, this message translates to:
  /// **'Refresh (s, snapshot)'**
  String get s4f356d158a;

  /// fi: Sähkön hinta
  ///
  /// In en, this message translates to:
  /// **'Electricity price'**
  String get sca7e088857;

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

  /// fi: Mitä näytetään
  ///
  /// In en, this message translates to:
  /// **'What to show'**
  String get s271885dc8b;

  /// fi: now = hinta nyt, chart = kaavio tälle ja huomiselle päivälle.
  ///
  /// In en, this message translates to:
  /// **'now = current price, chart = today and tomorrow.'**
  String get s46282f452b;

  /// fi: Tämän päivän hintoja ei ole vielä saatavilla.
  ///
  /// In en, this message translates to:
  /// **'No prices for today yet.'**
  String get s2f754e8ab4;

  /// fi: huomenna
  ///
  /// In en, this message translates to:
  /// **'tomorrow '**
  String get sd575462da3;

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

  /// fi: Portti
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get s800d13debd;

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

  /// fi: Viesti ({{value}} = arvo)
  ///
  /// In en, this message translates to:
  /// **'\'Payload ({{value}} = value)\''**
  String get s120726c79a;

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

  /// fi: summary = koko tila tekstinä. room = lähettimen lämpöanturi (jos on). Muut = viimeksi lähetetty asetus.
  ///
  /// In en, this message translates to:
  /// **'summary = full state as text. room = the blaster\'\'s temperature sensor. Others = last sent setting.'**
  String get s8567c5faa6;

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

  /// fi: Puhallin
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get s018d2e08f4;

  /// fi: Modbus TCP
  ///
  /// In en, this message translates to:
  /// **'Modbus TCP'**
  String get s36fb6ba26f;

  /// fi: IP-osoite
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get sa70cc38354;

  /// fi: Laitteen osoite (unit id)
  ///
  /// In en, this message translates to:
  /// **'Unit id'**
  String get sdc5301b750;

  /// fi: Aikakatkaisu (ms)
  ///
  /// In en, this message translates to:
  /// **'Timeout (ms)'**
  String get s15e327bf8e;

  /// fi: Rekisterityyppi
  ///
  /// In en, this message translates to:
  /// **'Register table'**
  String get s943b8b6bf3;

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

  /// fi: Kerroin
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get see24ec5d84;

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

  /// fi: ntfy (viestikanava / komennot)
  ///
  /// In en, this message translates to:
  /// **'ntfy (message channel / commands)'**
  String get sefaea1b818;

  /// fi: Komentokanava (aihe tai koko osoite)
  ///
  /// In en, this message translates to:
  /// **'Command topic (name or full URL)'**
  String get s6a4516e0fe;

  /// fi: Aihe, johon komennot lähetetään. Voit liittää koko osoitteen, esim. https://ntfy.sh/oma-aihe – sama osoite jota iPhonen
  ///
  /// In en, this message translates to:
  /// **'Topic the commands are sent to. You can paste the full URL, e.g. https://ntfy.sh/my-topic – the same one your iPhone Shortcut uses. The topic name works like a password: keep it long and random.'**
  String get se003ecc10b;

  /// fi: Vastauskanava (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Reply topic (optional)'**
  String get s800cd08229;

  /// fi: Jos kotilaite vastaa eri aiheeseen, kirjoita se tähän. Jätä tyhjäksi, jos vastaus tulee samaan aiheeseen – silloin oma l
  ///
  /// In en, this message translates to:
  /// **'If the home device replies on another topic, type it here. Leave empty if the reply comes on the same topic – our own command is then ignored and the next message is shown as the reply.'**
  String get s2e3a66d384;

  /// fi: Käyttöoikeustunnus (vapaaehtoinen)
  ///
  /// In en, this message translates to:
  /// **'Access token (optional)'**
  String get s5bc736c04a;

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

  /// fi: Odota vastausta
  ///
  /// In en, this message translates to:
  /// **'Wait for the reply'**
  String get sfee393b70e;

  /// fi: Kuuntelee kotilaitteen vastausta ja näyttää sen tässä ruudussa (ja ilmoituksena, jos sovellus on taustalla).
  ///
  /// In en, this message translates to:
  /// **'Listens for the home device\'\'s reply and shows it in this tile (and as a notification when the app is in the background).'**
  String get sfff5bc52e5;

  /// fi: Vastauksen odotus (s)
  ///
  /// In en, this message translates to:
  /// **'Wait for reply (s)'**
  String get sbdcbe301b9;

  /// fi: Kuinka kauan vastausta odotetaan, ennen kuin kerrotaan ettei vastausta tullut.
  ///
  /// In en, this message translates to:
  /// **'How long to wait before saying that no reply came.'**
  String get s121542d6d7;

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

  /// fi: ntfy: liian monta viestiä lyhyessä ajassa (HTTP 429). Odota hetki ja yritä uudelleen.
  ///
  /// In en, this message translates to:
  /// **'ntfy: too many messages (HTTP 429). Wait a moment and try again.'**
  String get s72c37e530d;

  /// fi: ntfy: komentokanava puuttuu
  ///
  /// In en, this message translates to:
  /// **'ntfy: command topic missing'**
  String get s0870daf796;

  /// fi: ntfy: yhteys katkesi ennen vastausta
  ///
  /// In en, this message translates to:
  /// **'ntfy: connection closed before the reply'**
  String get s28dc7ea012;

  /// fi: Komento lähetettiin, mutta vastausta ei tullut {p0} sekunnissa. Tarkista, että kotilaite on päällä ja kuuntelee aihetta
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but no reply came within {p0} s. Check that the home device is on and listens to \"{p1}\".'**
  String sa4313864fe(String p0, String p1);

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

  /// fi: Home Assistant
  ///
  /// In en, this message translates to:
  /// **'Home Assistant'**
  String get sf0ef0140c3;

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

  /// fi: Koti
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get s5b44cbe9c0;

  /// fi: ESP32-kamera
  ///
  /// In en, this message translates to:
  /// **'ESP32 camera'**
  String get s804e935440;

  /// fi: IV-kone (Modbus)
  ///
  /// In en, this message translates to:
  /// **'Ventilation unit (Modbus)'**
  String get s478ddb6e1a;

  /// fi: Piha
  ///
  /// In en, this message translates to:
  /// **'Yard'**
  String get s4b4fd14aaf;

  /// fi: Hälytys
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get s8d06ee5308;

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

  /// fi: Malli
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get sdccd6e7f24;

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

  /// fi: Tasmota-laite
  ///
  /// In en, this message translates to:
  /// **'Tasmota device'**
  String get s702ca14235;

  /// fi: Tasmota-ohjelmistolla toimiva rele tai pistorasia.
  ///
  /// In en, this message translates to:
  /// **'Relay or plug running Tasmota firmware.'**
  String get sc130e073ba;

  /// fi: Vain energiamittauksella varustetuille.
  ///
  /// In en, this message translates to:
  /// **'Only for devices with energy metering.'**
  String get s16be1831d6;

  /// fi: Releen numero
  ///
  /// In en, this message translates to:
  /// **'Relay number'**
  String get s8890d26ef2;

  /// fi: Monireleisissä 1, 2, 3...
  ///
  /// In en, this message translates to:
  /// **'For multi-relay devices 1, 2, 3...'**
  String get s7e6d21d466;

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

  /// fi: ESPHome-laite
  ///
  /// In en, this message translates to:
  /// **'ESPHome device'**
  String get se0e5f715ad;

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

  /// fi: Valot, hälytys, anturit – kaikki mitä Home Assistantissa on.
  ///
  /// In en, this message translates to:
  /// **'Lights, alarm, sensors – anything in Home Assistant.'**
  String get s7f8e45ea74;

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

  /// fi: Valo (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Light (optional)'**
  String get s75a056cf4d;

  /// fi: Entiteetin tunnus, löytyy HA:sta Asetukset → Laitteet ja palvelut → Entiteetit.
  ///
  /// In en, this message translates to:
  /// **'Entity id from Settings → Devices → Entities.'**
  String get sdb9a90cb96;

  /// fi: Hälytys (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Alarm (optional)'**
  String get sa9681c1a9a;

  /// fi: Lämpötila-anturi (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Temperature sensor (optional)'**
  String get s64bd3ab3ff;

  /// fi: Kytkin / pistorasia (valinnainen)
  ///
  /// In en, this message translates to:
  /// **'Switch (optional)'**
  String get sa6504f5712;

  /// fi: disarmed=Pois;armed_away=Päällä;armed_home=Kotona;armed_night=Yö;triggered=HÄLYTYS;arming=Kytkeytyy
  ///
  /// In en, this message translates to:
  /// **'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming'**
  String get s64d4364336;

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

  /// fi: Lämpöpumppu
  ///
  /// In en, this message translates to:
  /// **'Heat pump'**
  String get sc7d02fbe84;

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

  /// fi: Tämän ja huomisen päivän pörssisähkön hinta kaaviona, 15 minuutin tarkkuudella. Hintaohjaus: paina laitteen ruutua pitkä
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s and tomorrow\'\'s spot price as a chart. Price control: long-press a device tile → Price control.'**
  String get se807a72c0a;

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

  /// fi: Sähkö nyt
  ///
  /// In en, this message translates to:
  /// **'Electricity now'**
  String get scf849c933b;

  /// fi: Halvin tunti
  ///
  /// In en, this message translates to:
  /// **'Cheapest hour'**
  String get s53a951507b;

  /// fi: Sähkön hinta tänään ja huomenna
  ///
  /// In en, this message translates to:
  /// **'Price today and tomorrow'**
  String get s3e99310fc0;

  /// fi: IV-kone (Modbus TCP)
  ///
  /// In en, this message translates to:
  /// **'Ventilation unit (Modbus TCP)'**
  String get s9af9526395;

  /// fi: Lämpötilat ja puhallinnopeus. Valmiit rekisterilistat esimerkkeinä – tarkista oman koneesi ohjeesta.
  ///
  /// In en, this message translates to:
  /// **'Temperatures and fan speed. Register presets are examples – verify with your manual.'**
  String get s29dc0baf55;

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

  /// fi: Liitä sama osoite, johon pikakomento lähettää komennot (esim. https://ntfy.sh/kv-cmd-…). Pelkkä aiheen nimi riittää myös
  ///
  /// In en, this message translates to:
  /// **'Paste the same URL your Shortcut posts commands to (e.g. https://ntfy.sh/kv-cmd-…). The topic name alone also works.'**
  String get sd82d127f05;

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

  /// fi: Komento
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get s5bed8bff00;

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

  /// fi: off=Pois;heat=Lämmitys;cool=Jäähdytys;auto=Auto;heat_cool=Auto;dry=Kuivaus;fan_only=Puhallus
  ///
  /// In en, this message translates to:
  /// **'off=Off;heat=Heat;cool=Cool;auto=Auto;heat_cool=Auto;dry=Dry;fan_only=Fan'**
  String get sdc84bf286f;

  /// fi: {p0} – lämpötila
  ///
  /// In en, this message translates to:
  /// **'{p0} – temperature'**
  String s3378eb2d0b(String p0);

  /// fi: Lähetetty tila (IR on yksisuuntainen)
  ///
  /// In en, this message translates to:
  /// **'Sent state (IR is one-way)'**
  String get saa437260b8;

  /// fi: Tila
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get sfffb54daf4;

  /// fi: Puhallin (0 = auto)
  ///
  /// In en, this message translates to:
  /// **'Fan (0 = auto)'**
  String get seab2c72485;

  /// fi: Suuntaus
  ///
  /// In en, this message translates to:
  /// **'Swing'**
  String get sfb0b971c01;

  /// fi: {p0} – huone
  ///
  /// In en, this message translates to:
  /// **'{p0} – room'**
  String s3a38b97f7b(String p0);
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
