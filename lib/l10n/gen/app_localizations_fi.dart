// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get s03c0a5192b => 'Osoitetta ei löydy';

  @override
  String get sb3ef01a6fa =>
      'Tarkista osoitteen kirjoitusasu. Kokeile IP-osoitetta (esim. 192.168.1.50) nimen sijaan.';

  @override
  String get s274a753ad6 => 'Laitetta ei löydy osoitteesta';

  @override
  String get s2b503695b6 =>
      'Tarkista että laite on päällä ja että puhelin tai PC on samassa wifissä. Tarkista myös IP-osoite – se voi vaihtua, joten varaa laitteelle kiinteä osoite reitittimestä.';

  @override
  String get sff9ca463e3 => 'Laite löytyi, mutta ei vastaa tähän porttiin';

  @override
  String get s1d4f4506de =>
      'Tarkista portin numero ja että palvelu (esim. web-käyttöliittymä, MQTT tai Modbus TCP) on laitteessa päällä.';

  @override
  String get s8523a9cfd0 => 'Suojattu yhteys (https) epäonnistui';

  @override
  String get sdfd499c1f1 =>
      'Kokeile osoitetta http:// -alkuisena, tai Lisäasetuksista \"Salli itse allekirjoitettu sertifikaatti\".';

  @override
  String get s3fabccc1cd => 'Tunnus, salasana tai token ei kelpaa';

  @override
  String get sdc2d65f8eb =>
      'Tarkista tunnukset. Home Assistantissa voit luoda uuden pitkäikäisen tunnuksen omasta profiilista.';

  @override
  String get se0a7cef6c4 => 'Laite vastasi, mutta kohdetta ei löytynyt';

  @override
  String get see02239a35 =>
      'Tarkista polku tai entiteetin nimi (esim. light.olohuone). Isot ja pienet kirjaimet ovat merkitseviä.';

  @override
  String get sdec83d1e90 => 'Laitteessa tapahtui virhe';

  @override
  String get s3de239ffc5 =>
      'Komento tai kysely ei kelvannut laitteelle. Tarkista polku ja lähetettävä sisältö.';

  @override
  String get s6121e8d8f1 => 'Laite ei tunne tätä rekisteriä';

  @override
  String get s3474aedf54 =>
      'Tarkista rekisterin numero laitteen Modbus-taulukosta. Jos taulukko alkaa 1:stä (esim. 40001), vähennä 1. Tarkista myös holding/input-valinta.';

  @override
  String get s2c303f6774 => 'Laite ei tue tätä rekisterityyppiä';

  @override
  String get s945685fcda =>
      'Kokeile toista rekisterityyppiä (holding ↔ input).';

  @override
  String get s07ffbc349a => 'Laite ei hyväksynyt arvoa';

  @override
  String get s76b95eef9f =>
      'Arvo on luultavasti sallitun alueen ulkopuolella. Tarkista myös kerroin.';

  @override
  String get sb66bc0e677 => 'Laite ei vastannut Modbus-kyselyyn';

  @override
  String get s6ef5539bc2 =>
      'Yhteys aukesi, mutta vastausta ei tullut. Tarkista laitteen osoite (unit id, usein 1) ja yhdyskäytävän sarjaportin asetukset.';

  @override
  String get s17ea4c52d5 => 'Laite ei vastannut';

  @override
  String get s50ecf9ba6f =>
      'Yhteys toimi, mutta vastausta ei tullut ajoissa. Tarkista lähetettävä viesti.';

  @override
  String get sf93db545a1 => 'Asetuksissa on virhe';

  @override
  String get sf19a9f0856 =>
      'Tarkista kentät, esim. että osoite alkaa http:// ja että numerot ovat numeroita.';

  @override
  String get s3976954bef => 'Ruudulta puuttuu laite';

  @override
  String get sc025e0a1f4 => 'Avaa muokkaus (kynä) ja valitse ruudulle laite.';

  @override
  String get s7e11595f9e => 'Kotisilta ei ole päällä';

  @override
  String get s2cd1df086e =>
      'Etäyhteys kulkee kotona olevan sillan (tabletti tai PC) kautta. Tarkista että se on päällä, Molaplan on auki ja sillä on netti.';

  @override
  String get sdfb639365a => 'Ei nettiyhteyttä';

  @override
  String get sdbf06d05d9 =>
      'Laitteesi ei saa yhteyttä Molaplanin etäpalveluun. Tarkista mobiilidata tai wifi.';

  @override
  String get s8b737f4026 => 'Etäyhteys on poistettu';

  @override
  String get s4b9e4ca079 =>
      'Tämä laite on poistettu kotisillalta. Yhdistä uudelleen: Asetukset → Etäyhteys.';

  @override
  String get s5b3116ed94 => 'Kotisilta ei vastannut ajoissa';

  @override
  String get se082095a34 =>
      'Yhteys voi olla hidas. Yritä hetken päästä uudelleen.';

  @override
  String get s688a4f4ccb => 'Koodi ei kelpaa';

  @override
  String get sfa0e226cd0 =>
      'Tarkista 6 numeroa kotisillan näytöltä. Koodi on voimassa 10 minuuttia ja kelpaa kerran – paina tarvittaessa sillalla \"Yhdistä puhelin\" uudelleen.';

  @override
  String get sfa5c1fb1ac => 'Kotisilta ei hyväksynyt laitetta';

  @override
  String get s9ad07ab36e =>
      'Kun yhdistät koodilla, sillan näytölle tulee kysymys – paina siellä \"Hyväksy\". Tai skannaa QR-koodi, silloin hyväksyntää ei tarvita.';

  @override
  String get sb5c271ae6a => 'Turvatarkistus epäonnistui';

  @override
  String get s3d7ca280db =>
      'Yhteyttä ei voitu varmistaa turvalliseksi, joten sitä ei otettu käyttöön. Yritä uudelleen QR-koodilla.';

  @override
  String get s0061b44673 => 'Kotisilta ei vastannut';

  @override
  String get sceb894b9b3 =>
      'Hyväksy laite sillan näytöllä 3 minuutin sisällä, tai skannaa QR-koodi.';

  @override
  String get s9dd2ff794f => 'Jokin meni pieleen';

  @override
  String get sbb62433c2c => 'Tarkista asetukset ja yritä uudelleen.';

  @override
  String get sc27533ae83 => 'Säästävä';

  @override
  String get sdbcb85509b =>
      'Lämpö saa vaihdella eniten (+1 / −2 °C). Suurin säästö.';

  @override
  String get s380b20be36 => 'Tasapainoinen';

  @override
  String get s66ea783264 => 'Pieni vaihtelu (+1 / −1 °C). Hyvä oletus.';

  @override
  String get see96226e44 => 'Mukavuus';

  @override
  String get sb403e00b3d =>
      'Lähes tasainen lämpö (+0,5 / −0,5 °C). Säästää vähän.';

  @override
  String get sd86b823895 => 'Sonoff';

  @override
  String get s5f297ec9d8 =>
      'BASIC, MINI, POW, TH, 4CH… DIY-tilassa, Tasmotalla tai ESPHomella. Ruudut tehdään valmiiksi, etänä kotisillan kautta.';

  @override
  String get s60e829b1b0 =>
      'eWeLink-sovellus → laite → Asetukset näyttää IP-osoitteen, tai reitittimen laitelista. DIY-tilassa tarvitset myös laitteen tunnuksen (Device ID, 10 merkkiä).';

  @override
  String get s6a46e8954d =>
      'DIY-tilan Sonoff vastaa vain, kun sille kerrotaan sen tunnus (Device ID). Se näkyy eWeLink-sovelluksessa: laite → Asetukset → Laitteen tunnus. Tasmota: web-salasana, jos asetettu.';

  @override
  String get sea057f1a02 =>
      'Vain DIY-tilassa, jos laitetta ei löytynyt haulla.';

  @override
  String s08d04d58a9(String p0) {
    return 'Kanava $p0';
  }

  @override
  String get s8653f173b6 => 'Lämpötila';

  @override
  String get s9cb8820285 => 'Kosteus';

  @override
  String get s4899323b9a => 'Teho';

  @override
  String get se78754330c => 'teho';

  @override
  String get s1a4eab1f51 => 'temperature';

  @override
  String get s9e731440d8 => 'humidity';

  @override
  String get s77c638e731 => 'battery';

  @override
  String get s96abb7f975 => 'contact';

  @override
  String get s91e5760e43 => 'motion';

  @override
  String get s2f76c2abd3 => 'bthome';

  @override
  String get sc2b99541c7 => 'Kytkimet ja releet';

  @override
  String get sd85dbd8e5e => 'Valot ja himmentimet';

  @override
  String get s38935a3c66 => 'Verhot ja rullakaihtimet';

  @override
  String get s64c6ca7840 => 'Energiamittarit';

  @override
  String get s662fecdc8d => 'Anturit';

  @override
  String get s027fcbe1b6 => 'Kytkin';

  @override
  String get sa376ec78ec => 'Valo';

  @override
  String get s6814e463b1 => 'Rullakaihdin';

  @override
  String get s477d8b2c95 => 'Kokonaisteho';

  @override
  String sdaa374b331(String p0) {
    return 'Vaihe $p0';
  }

  @override
  String get s32c88e5aa6 => 'Valoisuus';

  @override
  String get sbb26f2192c => 'Akku';

  @override
  String get s57b4effa42 => 'Ovi / ikkuna';

  @override
  String get s66350d8e7a => 'Liike';

  @override
  String get s29045a726e => 'Vesivuoto';

  @override
  String get s57c2113aee => 'Savu';

  @override
  String get se8422f063f => 'Anturi';

  @override
  String get s609cb4c5f9 => 'päällä';

  @override
  String get s356d822497 => 'pois';

  @override
  String get s0b2f7d7c80 => 'auki';

  @override
  String get s7009587b85 => 'kiinni';

  @override
  String get s3b35de231e => 'liikettä';

  @override
  String get s3dfa789b85 => 'HÄLYTYS';

  @override
  String get sd9b6de0a6a => 'Muut';

  @override
  String se7520a3990(String p0) {
    return 'nukkuu – viimeksi $p0';
  }

  @override
  String get s3aaacf80d2 => 'ei yhteydessä pilveen';

  @override
  String get see129fb410 => 'kirkkaus';

  @override
  String get s5d888c1384 => 'true=Auki;false=Kiinni';

  @override
  String get sd74ad36c31 => 'true=Liikettä;false=Ei liikettä';

  @override
  String get sfa12d7fdd7 => 'true=VUOTO!;false=Kuiva';

  @override
  String get s1f18c0f400 => 'true=SAVUA!;false=OK';

  @override
  String get s0bf7cb1613 => 'Philips Hue';

  @override
  String get se17d4e4197 =>
      'Hue-silta ja sen valot (myös Zigbee-valot, jotka on liitetty Hue-siltaan). Paritus sillan painikkeella.';

  @override
  String get sf83a145406 =>
      'Hue-sovelluksessa: Asetukset → Hue-sillat → (i) → IP-osoite. Tai reitittimen laitelistasta: \"Philips-hue\".';

  @override
  String get s80ee7a25a9 =>
      'Paina nyt Hue-sillan päällä olevaa isoa pyöreää painiketta. Odota tässä – yhteys syntyy itsestään.';

  @override
  String get s4dbb677293 => 'ei tavoitettavissa';

  @override
  String get sf50732e8e8 => 'himmennettävä';

  @override
  String s3832b8c729(String p0) {
    return 'koko huone ($p0 valoa)';
  }

  @override
  String get sceabe202da => 'provider';

  @override
  String get s834e3e8c5d => 'iphone';

  @override
  String get s11d8d321df => 'ipad';

  @override
  String get sceefb34afd => 'macbook';

  @override
  String get s24a447c14c => 'imac';

  @override
  String get s14418a4f88 => 'mac mini';

  @override
  String get saab3e952a6 => 'appletv';

  @override
  String get s7fbbfbf469 => 'apple tv';

  @override
  String get s045b27e316 => 'galaxy';

  @override
  String get s2c0aede81e => 'samsung';

  @override
  String get s7bd2005e15 => 'pixel';

  @override
  String get sdcec96b503 => 'chromecast';

  @override
  String get s49960d413e => 'google';

  @override
  String get s99e5776a78 => 'nest';

  @override
  String get sea3c963b09 => 'sonos';

  @override
  String get s1e7b1fc81c => 'synology';

  @override
  String get s7dc8f4cf35 => 'diskstation';

  @override
  String get s161d78d79c => 'qnap';

  @override
  String get s2512122220 => 'brother';

  @override
  String get s127258a6f4 => 'epson';

  @override
  String get s4e31401b4f => 'canon';

  @override
  String get s933e21c819 => 'hp ';

  @override
  String get sb309051c1f => 'hewlett';

  @override
  String get s6f339c5c37 => 'officejet';

  @override
  String get s5f8734f6e4 => 'laserjet';

  @override
  String get sceb247a904 => 'xiaomi';

  @override
  String get s10b7b68d6c => 'huawei';

  @override
  String get s3692c1d592 => 'lg ';

  @override
  String get se7d945b970 => 'webos';

  @override
  String get s5a5044b5df => 'bravia';

  @override
  String get sd92d7da7d5 => 'sony';

  @override
  String get saa909391c3 => 'philips';

  @override
  String get se39b8c84ab => 'raspberry';

  @override
  String get sec8808f414 => 'fritz';

  @override
  String get s0e225fb918 => 'tp-link';

  @override
  String get sb34f35dce5 => 'asus';

  @override
  String get s7ea140809c => 'netgear';

  @override
  String get s284be225b7 => 'ubiquiti';

  @override
  String get sfbaeb6a17e => 'unifi';

  @override
  String get sa24e9ce91d => 'mikrotik';

  @override
  String get sa1b725d397 => 'espressif';

  @override
  String get sdf96423738 => 'amazon';

  @override
  String get sf253859589 => 'echo';

  @override
  String get sec4d80656d => 'roku';

  @override
  String sb9964cfb3b(String p0) {
    return 'Teho $p0';
  }

  @override
  String get sfcb44be1a0 => 'Shelly';

  @override
  String get sa6ff717527 =>
      'Releet ja pistorasiat: Pro 4PM, Plus 1PM, Plug S, 2.5… Löytyy automaattisesti, ruudut tehdään joka kanavalle.';

  @override
  String get sd7e123cd2f =>
      'Shelly-sovelluksessa: avaa laite → ratas (asetukset) → Laitetiedot → IP-osoite. Tai reitittimen laitelistasta: nimi alkaa \"shelly…\", esim. shellypro4pm-….';

  @override
  String get s5f2b2ca5f5 => 'nyt päällä';

  @override
  String get s67f64cd925 => 'nyt pois';

  @override
  String get sd8dfb25d31 => 'Shelly Cloud (ilman kotisiltaa)';

  @override
  String get s350215338a =>
      'Ohjaa Shellyjä Shellyn pilven kautta mistä tahansa. Tarvitset vain Shelly-sovelluksen avaimen.';

  @override
  String get s64037991c2 =>
      'Shelly-sovellus → oma profiili (ylhäällä) → Käyttäjäasetukset → Authorization cloud key → Get key. Kopioi avain ja liitä tähän.';

  @override
  String get s062b21969d =>
      'Näkyy samalla sivulla avaimen alla (\"Server URI\"), esim. shelly-103-eu.shelly.cloud.';

  @override
  String get sf30bb5d5e6 =>
      'Yleensä ei tarvita – laitteet haetaan automaattisesti. Jos ei löydy: Shelly-sovellus → laite → asetukset → Laitetiedot → Device ID. Useita pilkulla eroteltuna.';

  @override
  String get s252ebed5af => 'Shelly Cloud';

  @override
  String get s25399cd337 => 'Palvelin';

  @override
  String get s246c7a46ff =>
      'Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Server URI.';

  @override
  String get s61a2d946a4 => 'Pilviavain';

  @override
  String get s9d468f5c64 =>
      'Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Get key.';

  @override
  String get sf34c97592f => 'IKEA Dirigera';

  @override
  String get sb38eac6a87 =>
      'IKEAn älykeskus ja sen valot ja pistorasiat (Zigbee). Paritus keskuksen painikkeella.';

  @override
  String get s4e92ab791e =>
      'IKEA Home smart -sovelluksessa: Asetukset → Keskus → IP-osoite. Tai reitittimen laitelistasta: \"gw2-…\" tai \"dirigera\".';

  @override
  String get s73824fc3d0 =>
      'Paina nyt Dirigera-keskuksen pohjassa olevaa toimintopainiketta (pieni painike) kerran. Odota tässä.';

  @override
  String get sda8d9bf1cd => 'Pistorasia';

  @override
  String get s0185672be7 =>
      'Kameran käyttäjä (yleensä admin) ja salasana, jonka asetit kameran aktivoinnissa.';

  @override
  String get s814f4633e3 =>
      'Käyttäjä admin. Imou: salasana on kameran tarrassa oleva \"Safety code\" tai laitesalasana.';

  @override
  String get s4450807111 =>
      'Reolink-sovelluksen kameran käyttäjä (yleensä admin) ja salasana.';

  @override
  String get s1095c54819 =>
      'Reolink-sovellus → kamera → Asetukset → Verkko → Lisäasetukset → Palvelinasetukset: laita HTTP ja RTSP päälle. Akkukamerat (Argus) eivät tue tätä.';

  @override
  String get sc79a5fee2b =>
      'Tapo-sovellus → kamera → Lisäasetukset → Kameran tili. Tee sinne käyttäjä ja salasana ja kirjoita ne tähän (ei Tapo-pilvitunnuksesi).';

  @override
  String get s174e06b97c =>
      'Tee ensin kameran tili: Tapo-sovellus → kamera → Lisäasetukset → Kameran tili.';

  @override
  String get s21da6fb5dc =>
      'Käyttäjä admin, salasana on kameran tarrassa oleva 6-kirjaiminen vahvistuskoodi (Verification code).';

  @override
  String get s1866ef6dc8 =>
      'Ezviz-sovellus → kamera → Asetukset → LAN Live View / RTSP: laita päälle (jos valinta on).';

  @override
  String get s1c2786e15f =>
      'Kameran käyttäjä ja salasana (usein admin). ONVIF pitää ehkä laittaa päälle kameran asetuksista.';

  @override
  String get s32270de47a => 'Valvontakamera';

  @override
  String get s4d3ff251d6 =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz tai muu ONVIF-kamera. Kuva ruutuun, live-video kotona.';

  @override
  String get se8ea97c5eb =>
      'Kameran sovelluksesta (laitetiedot) tai reitittimen laitelistasta.';

  @override
  String get s1577068729 => 'kamera';

  @override
  String get seeb6c38c8e => 'Kamera';

  @override
  String get s136c6f0d2b => 'Kuva ruutuun, live-video kotiverkossa';

  @override
  String get s2101774157 => 'Live-video kotiverkossa (ei kuvaa etänä)';

  @override
  String get sb662db81d8 =>
      'Osoite näyttää vajaalta. Muoto on neljä numeroa pisteillä, esim. 192.168.1.50.';

  @override
  String s738ecfe2bc(String p0) {
    return ' Tarkoititko $p0?';
  }

  @override
  String s06e738bf27(String p0) {
    return 'Tämä ei ole kotiverkon osoite (kotiverkon osoitteet alkavat yleensä 192.168.).$p0';
  }

  @override
  String sbae99909c4(String p0) {
    return 'Huom: tämä laite on verkossa $p0.x – laite ei ehkä ole samassa wifissä.';
  }

  @override
  String get s5b44cbe9c0 => 'Koti';

  @override
  String get s5a40f12b6a => 'Lisää';

  @override
  String get s58aaa6dade => 'Näkymä on lukittu';

  @override
  String get sdf1af3409c => 'Avaa lukitus';

  @override
  String get s4629a1695c => 'Valikko';

  @override
  String get s41c3cebc48 => 'Lisää laite';

  @override
  String get scd04aa5d9e => 'Muokkaa näkymää';

  @override
  String get s49de879696 => 'Energia';

  @override
  String get s1da81fd6c3 => 'Asetukset';

  @override
  String get s365492a7d0 => 'Lukitse näkymä';

  @override
  String get sb2f38410ee =>
      'Laitteita voi edelleen ohjata, mutta muokkaus, asetukset ja laitteiden lisäys piilotetaan. Avaa lukitus rataskuvakkeesta.';

  @override
  String get se497d27174 => 'PIN-koodi (valinnainen)';

  @override
  String get sd21180a166 =>
      'Ilman PIN-koodia lukitus avataan yhdellä napautuksella.';

  @override
  String get s809d0eb368 => 'Peruuta';

  @override
  String get sd86ff8e28a => 'Lukitse';

  @override
  String get s872f93a062 => 'Avaa lukitus?';

  @override
  String get s0cd88e27f4 => 'Muokkaus ja asetukset tulevat taas näkyviin.';

  @override
  String get sa5283191be => 'Avaa';

  @override
  String get sdfc012fb4e => 'PIN-koodi';

  @override
  String get sca710b76b5 => 'Väärä PIN-koodi';

  @override
  String sa0c07ccd04(String p0) {
    return 'Sinulla on uusin versio ($p0).';
  }

  @override
  String get sa118d84538 =>
      'Päivityksiä ei voitu tarkistaa juuri nyt. Tarkista nettiyhteys ja yritä myöhemmin.';

  @override
  String s9f2b092d8c(String p0) {
    return 'Uusi versio $p0 on saatavilla';
  }

  @override
  String sa5133b2c4a(String p0) {
    return 'Sinulla on nyt versio $p0.';
  }

  @override
  String get se099b5797e => 'Mitä uutta:';

  @override
  String get s9315c3df42 => 'Ohita tämä versio';

  @override
  String get sdd5c8f0a9d => 'Myöhemmin';

  @override
  String get sfbf490ec3f => 'Päivitä';

  @override
  String get s5a94ef2af1 => 'Lataus oli viallinen';

  @override
  String get s81e4325573 => 'Lataus ei onnistunut';

  @override
  String get s4b1d3df588 =>
      'Tiedoston tarkistussumma ei täsmännyt, joten mitään ei asennettu. Yritä hetken päästä uudelleen.';

  @override
  String get s0c463c7069 =>
      'Tarkista nettiyhteys ja yritä uudelleen. Voit myös ladata päivityksen julkaisusivulta.';

  @override
  String get s5dd4c9671f => 'Avaa julkaisusivu';

  @override
  String get s49ddc3c3b6 => 'Päivitys ladattu';

  @override
  String s04a05bb8fc(String p0) {
    return 'Tiedosto on tarkistettu ja tallennettu:\n$p0\n\nNäin otat sen käyttöön:\n1. Sulje Molaplan.\n2. Pura zip-tiedosto vanhan Molaplan-kansion päälle (tai uuteen kansioon).\n3. Käynnistä molaplan.exe. Asetuksesi säilyvät.';
  }

  @override
  String get s1dd246ec69 => 'Julkaisusivu';

  @override
  String get s0f07b20d45 => 'Avaa zip';

  @override
  String get s6e1ebc8baa => 'Avaa kansio';

  @override
  String get sa065e7f650 => 'Salli päivitysten asennus';

  @override
  String get sdc3bf71baf =>
      'Android kysyy kerran luvan, jotta Molaplan saa asentaa omat päivityksensä.\n\n1. Paina \"Avaa asetukset\".\n2. Kytke päälle \"Salli tästä lähteestä\".\n3. Palaa takaisin ja paina \"Päivitä\" uudelleen.';

  @override
  String get sa1bd8d2533 => 'Avaa asetukset';

  @override
  String get s441683b7a8 => 'Tarkistetaan…';

  @override
  String get se83b7fb2ac => 'Ladataan päivitystä…';

  @override
  String s0b68f81d82(String p0) {
    return 'Molaplan $p0 on saatavilla. Silta toimii normaalisti.';
  }

  @override
  String get sb06bee9921 => 'Näytä';

  @override
  String get sf1b5d0ffa6 =>
      'Salasana ei täsmää. Kirjoita tilin salasana (sama jolla kirjauduit ensimmäisen kerran).';

  @override
  String s11ee4426b2(String p0) {
    return 'Jokin meni pieleen: $p0';
  }

  @override
  String get sbf59e43c36 =>
      'Ei nettiyhteyttä. Tarkista wifi tai mobiilidata ja yritä uudelleen.';

  @override
  String get s9ba7e7a8e6 =>
      'Sähköposti tai salasana on väärin. Tarkista kirjoitusasu, tai paina \"Unohdin salasanan\".';

  @override
  String get se899b438b5 =>
      'Sähköpostia ei ole vielä vahvistettu. Katso sähköpostistasi koodi.';

  @override
  String get s3fb651ebf3 =>
      'Tällä sähköpostilla on jo tili. Paina \"Minulla on jo tili\" ja kirjaudu.';

  @override
  String get s1eddf46047 => 'Salasanan pitää olla vähintään 8 merkkiä.';

  @override
  String get sca19a10c02 =>
      'Sähköpostiosoite ei näytä oikealta (esim. nimi@esimerkki.fi).';

  @override
  String get s736463f0d2 =>
      'Koodi on väärä tai vanhentunut. Tarkista koodi tai pyydä uusi.';

  @override
  String get s4800010fa4 =>
      'Liian monta yritystä. Odota hetki (noin minuutti) ja yritä uudelleen.';

  @override
  String get sf1a6e42ab0 => 'Kirjautuminen on vanhentunut. Kirjaudu uudelleen.';

  @override
  String get sf597621fdd =>
      'Toinen laite muutti asetuksia samaan aikaan. Yritä uudelleen.';

  @override
  String get se16eef219e =>
      'Tilipalvelu ei vastannut oikein. Yritä hetken päästä uudelleen.';

  @override
  String get s2ab0ff38c1 => 'Tililläsi on jo kotinäkymä';

  @override
  String get s3ce644ca86 => 'Tallennetaanko tämän laitteen kotinäkymä tiliisi?';

  @override
  String get s43d6286f35 =>
      'Myös tällä laitteella on omia laitteita ja ruutuja. Mitä tehdään?';

  @override
  String get sd8a380a86d =>
      'Silloin samat kodit, laitteet ja ruudut näkyvät kaikilla laitteillasi, joilla kirjaudut tälle tilille.';

  @override
  String get sec25d10ff5 => 'Peru ja kirjaudu ulos';

  @override
  String get sb7a13da58b => 'Käytä tilin asetuksia';

  @override
  String get sf498dceefb => 'Yhdistä molemmat (suositus)';

  @override
  String get s9542718c6f => 'Tallenna tiliin';

  @override
  String get sa711c4833e =>
      'Kirjoita sähköpostiosoitteesi (esim. nimi@esimerkki.fi).';

  @override
  String get s933dc9caef => 'Salasanan pitää olla vähintään 8 merkkiä.';

  @override
  String get sb3cec3f199 => 'Molaplan-tili';

  @override
  String get sb24f053a48 => 'Sähköposti';

  @override
  String get s976a9f2980 => 'Salasana';

  @override
  String get sc0f9642fb2 => 'Näytä salasana';

  @override
  String get s4d212254bc => 'Koodi sähköpostista';

  @override
  String get s3b86a618be =>
      'Koodi tulee muutamassa minuutissa. Katso myös roskapostikansio.';

  @override
  String get sb35c5ba0fc =>
      'Tilin avulla kotisi, laitteesi ja ruudut ovat samat kaikilla laitteillasi – PC:llä, tabletilla ja puhelimella. Kotiyhteys siirtyy uudelle laitteelle ilman QR-koodia.\n\nTili on vapaaehtoinen: ilman tiliä Molaplan toimii kuten ennenkin, ja asetukset pysyvät vain tällä laitteella.';

  @override
  String get se697487621 => 'Kirjaudu sisään';

  @override
  String get sec4d25a98e => 'Minulla ei ole tiliä – luo uusi';

  @override
  String get s860d0269e0 => 'Kirjaudu sähköpostiin tulevalla koodilla';

  @override
  String get s755639049e => 'Unohdin salasanan';

  @override
  String get s4a1671a2cc => 'Luo Molaplan-tili';

  @override
  String get s75c960f1e5 => 'Keksi salasana (vähintään 8 merkkiä)';

  @override
  String get sea446a95e5 =>
      'Salasana myös suojaa laitteidesi salasanat ja pilviavaimet: ne salataan tällä laitteella ennen tallennusta. Pidä salasana tallessa.';

  @override
  String get s4508b6c2e0 => 'Luo tili';

  @override
  String s0ca1377846(String p0) {
    return 'Lähetimme koodin osoitteeseen $p0. Kirjoita se alle.';
  }

  @override
  String get s07e981c940 => 'Minulla on jo tili – kirjaudu';

  @override
  String get s2e793f899b => 'Vahvista sähköposti';

  @override
  String get s87b6699e12 => 'Vahvista';

  @override
  String get s824a7408ab => 'Uusi koodi lähetetty.';

  @override
  String get s317ad443fb => 'Koodi ei tullut – lähetä uusi';

  @override
  String get scf7e14661c => 'Takaisin';

  @override
  String get s7d43ee2d5a => 'Luo tili tai kirjaudu';

  @override
  String get s22c960ff4f => 'Kirjaudu koodilla';

  @override
  String get scb167ce8b1 =>
      'Kirjoita sähköpostiosoitteesi, niin lähetämme koodin. Salasanaa ei tarvita. Jos tiliä ei vielä ole, se luodaan, ja tämän laitteen asetukset siirtyvät siihen.';

  @override
  String get s7d29d1dfbd =>
      'Lähetämme sähköpostiisi koodin. Salasanaa ei tarvita kirjautumiseen.';

  @override
  String get sc350da6f19 => 'Lähetä koodi';

  @override
  String s23cda12342(String p0) {
    return 'Koodi lähetetty osoitteeseen $p0.';
  }

  @override
  String get s14d85b9e32 => 'Kirjaudu';

  @override
  String get saa1e3d1f13 => 'Lähetä uusi koodi';

  @override
  String get se1be2ec8e5 => 'Kirjaudu salasanalla';

  @override
  String get s8c48f847f6 => 'Vaihda salasana';

  @override
  String get safd591d9b6 =>
      'Lähetämme sähköpostiisi koodin. Sen jälkeen voit keksiä uuden salasanan.';

  @override
  String get s6807ac704e => 'Uusi salasana (vähintään 8 merkkiä)';

  @override
  String get sa9b5a0b2df => 'Vaihda salasana ja kirjaudu';

  @override
  String get se10ce6962a => 'Synkronoidaan…';

  @override
  String get s94d5ea139c =>
      'Ajan tasalla – samat asetukset kaikilla laitteillasi';

  @override
  String get sc6f1932436 => 'Ei nettiä – muutokset siirtyvät, kun yhteys palaa';

  @override
  String get s16ab688a9b => 'Synkronointi epäonnistui – yritetään uudelleen';

  @override
  String get s97d4aa9c1a => 'Ei synkronoitu vielä';

  @override
  String get s40ea946050 => 'Kirjautunut';

  @override
  String get s456721b668 => 'Synkronoi nyt';

  @override
  String get sa9df24980f =>
      'Laitteiden salasanat ja pilviavaimet ovat tilillä lukittuina. Kirjoita tilin salasana avataksesi ne tällä laitteella.';

  @override
  String get sd1723cc065 => 'Tilin salasana';

  @override
  String get s9e9a059c2f => 'Avaa salasanat';

  @override
  String get s8b2b8fdc77 => 'En muista salasanaa – aloita salasanat alusta';

  @override
  String get s5ec8009dfd =>
      'Mitä tilille tallennetaan: kodit, laitteet, ruudut ja niiden järjestys sekä kotiyhteys. Laitteiden salasanat, pilviavaimet ja kotiyhteyden avaimet salataan tällä laitteella tilisi salasanalla ennen lähettämistä – palvelin ei näe niitä.';

  @override
  String get s2ea6f9de12 => 'Vaihda salasana';

  @override
  String get s7ebd89c416 => 'Kirjaudu ulos?';

  @override
  String get s6c6165d662 =>
      'Kodit ja ruudut jäävät tälle laitteelle, mutta muutokset eivät enää siirry muille laitteillesi.';

  @override
  String get s643325053b => 'Kirjaudu ulos';

  @override
  String get sfd6f965e64 => 'Tilin poistaminen';

  @override
  String get s37bf90cffe =>
      'Poistaa tilin ja kaikki palvelimelle tallennetut tiedot pysyvästi. Tämän laitteen kotinäkymä jää laitteelle.';

  @override
  String get sc523d0f28e => 'Poista tili';

  @override
  String get s84fda3e17f => 'Peru';

  @override
  String get s162a85c6ef => 'Tallenna';

  @override
  String get s02c3403918 => 'Keksi uusi salasana tilillesi.';

  @override
  String get s04ab058029 => 'Salasana vaihdettu.';

  @override
  String get s7c23534562 => 'Aloita salasanat alusta';

  @override
  String get s5ea3703a0a =>
      'Tilille tallennetut laitteiden salasanat ja pilviavaimet katoavat, ja ne pitää kirjoittaa uudelleen. Kodit ja ruudut säilyvät. Kirjautumissalasana vaihtuu tähän uuteen.';

  @override
  String get s321912ef77 => 'Poistetaanko tili pysyvästi?';

  @override
  String s3b0ea9bbc7(String p0) {
    return 'Tili $p0 ja kaikki palvelimelle tallennetut kodit, laitteet, ruudut ja salatut salasanat poistetaan. Tätä ei voi perua.\n\nTämä laite jatkaa toimintaa ilman tiliä. Muilla laitteillasi kirjautuminen päättyy.';
  }

  @override
  String get s139d2075b8 => 'Tili poistettu. Molaplan toimii nyt ilman tiliä.';

  @override
  String get sfb4df77773 => 'Anna napille nimi, esim. \"Turbo\".';

  @override
  String get s986eb41068 =>
      'Tallenna ESPHome-koodi Pronto-muodossa: lisää remote_receiver-kohtaan dump: pronto.';

  @override
  String s0d353281af(String p0) {
    return 'Nappi \"$p0\" lisättiin kotinäkymään.';
  }

  @override
  String get s8e4e78e067 => 'Opettele kaukosäädin';

  @override
  String get s2acab0eccd => 'Valmis';

  @override
  String get s608a56ad4b =>
      'Tallenna kaukosäätimen nappeja Molaplaniin, esim. \"Turbo\" tai \"Hiljainen\". Tarvitset IR-lähettimen, jossa on myös vastaanotin.';

  @override
  String get sa1aed8855e => 'IR-kaukosäädin';

  @override
  String get sded7fb8520 => 'RF433-kaukosäädin';

  @override
  String get sc8e312a953 =>
      'RF433 = radiokaukosäätimet (esim. pistorasiat, markiisit, autotallin ovet, kattotuulettimet). IR = infrapuna (lämpöpumput, TV:t).';

  @override
  String get s63c57060b6 => 'Paina \"Aloita kuuntelu\".';

  @override
  String get s439f6f3869 =>
      'Osoita kaukosäätimellä lähetintä alle metrin päästä ja paina haluamaasi nappia kerran.';

  @override
  String get sd8667596c3 => 'Anna napille nimi ja paina \"Tallenna napiksi\".';

  @override
  String get sd5f1a45865 =>
      'IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan näyttää vain, mitä se lähetti. Opettelu toimii kotiverkossa.';

  @override
  String get s628dc92a8d => 'Kuunnellaan… paina kaukosäätimen nappia';

  @override
  String get s1313eb829d => 'Aloita kuuntelu';

  @override
  String get s619fdf8b5c => 'Koodi vastaanotettu';

  @override
  String get s6264a40ec6 => 'Napin nimi';

  @override
  String get sc630994fba => 'Näkyy ruudun otsikkona.';

  @override
  String get s09feac6b28 =>
      'ESPHome ei voi vastaanottaa uusia koodeja verkon yli. Lisää tämä laitteen YAML-asetuksiin, asenna päivitys ESPHomesta ja tallenna sitten nappi:';

  @override
  String get sd6f41faa1d => 'Kopioi';

  @override
  String get s0a7c7a151a => 'Tallenna napiksi';

  @override
  String get s29adc71f1c =>
      'Sisäyksikön piirilevyn CN105-liitin (5-napainen). ESPHome: \"esphome-mitsubishiheatpump\" (SwiCago-kirjasto). Valmiita ohjaimia myydään myös kytkettävinä.';

  @override
  String get s1d17c9fc6e =>
      'S21 (useimmat seinämallit) tai X50A (uudemmat). Faikin-ohjain kytketään suoraan liittimeen; ESPHome: \"esphome-daikin-s21\".';

  @override
  String get s07767f6a03 =>
      'CN-CNT-liitin sisäyksikössä (sama kuin Panasonicin oma WLAN-adapteri). ESPHome: \"esphome-panasonic-ac\".';

  @override
  String get s659b742754 =>
      'Toshiban sisäyksikön huoltoliitin (TCC-Link/AB-väylä). ESPHome: \"esphome-toshiba_ac\".';

  @override
  String get s7c3bf9542b => 'Kirjoita ESPHome-laitteen IP-osoite.';

  @override
  String sdfa6aedae8(String p0, String p1) {
    return '\"$p0\" ja $p1 ruutua lisätty.';
  }

  @override
  String get sbd2f94e7a4 => 'Ilmalämpöpumppu (huoltoliitäntä/ESPHome)';

  @override
  String get s49b479c566 =>
      'Paras tapa ohjata ilmalämpöpumppua: pieni ESP32-ohjain kytketään sisäyksikön huoltoliitäntään. Toisin kuin IR, se on kaksisuuntainen – näet todellisen tilan ja huonelämmön, ja komennot varmistuvat.';

  @override
  String get sc95a59f7c6 =>
      'Turvallisuus: katkaise lämpöpumpun virta pääkytkimestä ennen kuin avaat sisäyksikön. Liitäntä voi vaikuttaa takuuseen. Jos et ole varma, pyydä asentajaa.';

  @override
  String get s7b7121b71e => 'Liitäntä merkeittäin';

  @override
  String get s67c1a8a6a3 => 'Näin otat käyttöön';

  @override
  String get s2f9c5f3130 =>
      'Hanki merkkiisi sopiva ESP32-ohjain ja liitäntäkaapeli (linkit yllä).';

  @override
  String get s2675e49423 =>
      'Asenna siihen ESPHome-asetukset projektin ohjeen mukaan. Lisää mukaan rivi \"web_server:\" – Molaplan käyttää sitä.';

  @override
  String get scd70d27319 =>
      'Kytke ohjain huoltoliitäntään virrat pois päältä ja kiinnitä kansi.';

  @override
  String get s56b0cb63ea =>
      'Kirjoita alle ohjaimen IP-osoite ja paina \"Etsi lämpöpumput\". Molaplan löytää ilmastoinnin itse.';

  @override
  String get sdd1cd7bdd5 => 'ESPHome-ohjaimen IP-osoite';

  @override
  String get sa1e21d236a =>
      'Löytyy reitittimen laitelistasta tai ESPHome-hallinnasta.';

  @override
  String get s1bef32afe0 => 'Etsi lämpöpumput';

  @override
  String get s9aa9bc9679 =>
      'Laite vastasi, mutta siinä ei ole ilmastointia (climate). Tarkista ESPHome-asetukset.';

  @override
  String get s3a5c21004e => 'Ei yhteyttä';

  @override
  String get sbc7a87e591 => 'Hintoja ei saatu – yritetään uudelleen';

  @override
  String get s3f0837ec84 => 'Säätietoja ei saatu – yritetään uudelleen';

  @override
  String get s68cbe596f8 => 'Kirjautuminen vanhentunut';

  @override
  String get s156aa7eeb3 => 'Laite ei vastaa';

  @override
  String get s7abcbf1107 => 'Palvelinta ei löydy';

  @override
  String get sca533b6f25 => 'Kotisilta ei vastaa';

  @override
  String get s96ad0dc252 => 'Tietoa ei löydy laitteesta';

  @override
  String get s61cdd7287b => 'Asetus puuttuu';

  @override
  String get s57d0940253 => 'Suojausvirhe';

  @override
  String get sfec025279e => 'Laite ei ole verkossa';

  @override
  String get sa7d212f047 => 'Kotiverkon laitteet toimivat silti Wi-Fin kautta.';

  @override
  String get s24ccd151f2 => 'Yritä';

  @override
  String get sc5f54cf3c8 => 'Täytä avain ja palvelin.';

  @override
  String get sb26dad8f73 => 'Pilvessä ei ole laitteita tällä avaimella.';

  @override
  String s2c6ce95ec2(String p0) {
    return '$p0 toimii nyt Shelly Cloudin kautta.';
  }

  @override
  String s5629901cc4(String p0) {
    return 'Ohjaa $p0 kodin ulkopuolelta';
  }

  @override
  String get s064abc90af =>
      'Laite vaihdetaan käyttämään Shelly Cloudia. Kaikki sen kanavat, nimet ja ruudut säilyvät. Avain: Shelly-sovellus → oma profiili → Käyttäjäasetukset → Authorization cloud key.';

  @override
  String get sf16961256b => 'Palvelin (Server URI)';

  @override
  String s28e10c6870(String p0) {
    return 'Mikä näistä on $p0?';
  }

  @override
  String get s09f5da65e0 => 'Vaihda Shelly Cloudiin';

  @override
  String get sa3a093e55e => 'Lämmitys';

  @override
  String get s8efb99df1d => 'Jäähdytys';

  @override
  String get s0b98d62330 => 'Lämmitys ja jäähdytys';

  @override
  String get s33831dd49f => 'Pois';

  @override
  String get sa61efb9866 => 'lämmittää';

  @override
  String get s9a47ee3e3c => 'jäähdyttää';

  @override
  String get s156712ac0c => 'odottaa';

  @override
  String get s8a1f52a37b => 'Termostaatti poistettu';

  @override
  String get s28dc9bc46a => 'Lämpötilaa ei saada';

  @override
  String get s4f1166fe24 =>
      'Ei kotisiltaa: termostaatti ei ohjaa vielä. Ota etäyhteys käyttöön kodin tabletilla.';

  @override
  String get s29fd8d5b5e => 'Nyt';

  @override
  String get see9111ba68 => 'Rele tai kytkin (päälle/pois)';

  @override
  String get seaed91ad78 => 'Lämpöpumppu tai ilmastointi (asetusarvo)';

  @override
  String get sb757921c13 => 'Lämmittää';

  @override
  String get s7407864734 => 'Jäähdyttää';

  @override
  String get s272aa3f1da => 'Molemmat';

  @override
  String get sdadb6e3501 => 'Varalämmitin';

  @override
  String get se4e381334d =>
      'Käynnistyy vain, kun lämpö on selvästi alle tavoitteen.';

  @override
  String get s17c79c5f4e => 'Virta päälle/pois (valinnainen)';

  @override
  String get s92d88612de => 'Lämmitystilan painike (valinnainen)';

  @override
  String get s75ac845bab => 'Jäähdytystilan painike (valinnainen)';

  @override
  String get se12fc46923 => 'Ei mitään';

  @override
  String get sc590a09db9 => 'Mikä lämmittää tai jäähdyttää?';

  @override
  String get sa15ffe53d4 =>
      'Valitse yksi tai useampi. Esim. lämpöpumppu ja varalämmitin.';

  @override
  String get sd47a7615a7 => 'Ei sopivia laitteita vielä';

  @override
  String get s3c7649a7f0 =>
      'Lisää ensin rele (esim. Shelly) tai lämpöpumppu (IR tai huoltoportti) ja palaa sitten tähän.';

  @override
  String get see513572ea => 'Mistä lämpötila luetaan?';

  @override
  String get s5155522e83 =>
      'Valitse lämpömittari. Useampi = varalla tai keskiarvo.';

  @override
  String get s581fa290f3 =>
      'Ei pakollinen: lämpöpumppu mittaa itse. Valitse mittari, jos haluat nähdä lämpötilan.';

  @override
  String get s7e4d8d60a0 => 'Ei lämpömittaria';

  @override
  String get s0787d80876 => 'Lisää ensin laite, joka näyttää lämpötilan.';

  @override
  String get s89661203b7 => 'Ensimmäinen toimiva';

  @override
  String get s0da3005956 => 'Keskiarvo';

  @override
  String get s0c6a008ffd => 'Nimi ja tila';

  @override
  String get sb1924acbe7 => 'Nimi';

  @override
  String get s1790a71e85 => 'esim. Olohuone';

  @override
  String get sd5f46903a1 => 'Tavoitelämpötila';

  @override
  String get s6de95e582f => 'Jos lämpötilaa ei saada';

  @override
  String get s8ff25225b4 => 'Sammuta lämmitys/jäähdytys (turvallisin)';

  @override
  String get s17cb86f49e => 'Pidä ennallaan';

  @override
  String get sf4caddf894 => 'Edistyneet';

  @override
  String get s9624f070ee => 'Hystereesi';

  @override
  String get sf070be2c1e => 'Kuollut alue (lämmitys/jäähdytys)';

  @override
  String get s64540136ff => 'Vähimmäisaika päällä';

  @override
  String get s21713a2177 => 'Vähimmäisaika pois';

  @override
  String get s8f7c8eb7d0 => 'Varalämmitin, kun alle tavoitteen';

  @override
  String get sf1eb3b2d34 => 'Mittari kadonnut, kun ei lukemaa';

  @override
  String get s0ab1430151 => 'Uusi termostaatti';

  @override
  String get sbbc98d573d => 'Muokkaa termostaattia';

  @override
  String get s6c3e76828b => 'Seuraava';

  @override
  String get s187d328bb1 => 'Muokkaa';

  @override
  String get sc1845eb440 => 'Poista';

  @override
  String get s87984716cb => 'Poistetaanko termostaatti?';

  @override
  String get s79786b9f7d => 'Tavoite';

  @override
  String get sdd309c0a63 => 'Termostaatti toimii kotisillalla';

  @override
  String get s9c1b5394df =>
      'Ota etäyhteys käyttöön kodin tabletilla (Asetukset → Etäyhteys). Siihen asti termostaatti ei ohjaa.';

  @override
  String get s06cda8c0de => 'Ohjaus toimii tällä laitteella (kotisilta).';

  @override
  String get s2342536aea => 'Ohjaus toimii kotisillalla.';

  @override
  String get s798f7b2876 => 'Älykäs lämmitys';

  @override
  String get s2c5993c1fd =>
      'Lämmittää etukäteen ennen kallista sähköä ja pakkasta, ja antaa lämmön laskea hieman kalliina tunteina.';

  @override
  String get s81c4abc1a5 => 'Ylilämpö +';

  @override
  String get sdea18b2b40 => 'Alilämpö −';

  @override
  String get s523214c8db =>
      'Viiva = tavoitelämpötila, palkit = sähkön hinta, katkoviiva = ulkolämpötila.';

  @override
  String get s94b8f63aa7 => 'Lisää kodin sijainti säätä varten';

  @override
  String get s941fbb47fe => 'Suunnitelmaa lasketaan…';

  @override
  String get s702ca14235 => 'Tasmota-laite';

  @override
  String get se0e5f715ad => 'ESPHome-laite';

  @override
  String get s63b6e55469 => 'HomeKit-laite';

  @override
  String get s13e301a66e => 'Tuntematon laite';

  @override
  String get sddb2c2cb2b => 'Puhelin';

  @override
  String get s16cd267576 => 'Tabletti';

  @override
  String get sec4679ec39 => 'Tietokone';

  @override
  String get s798f9a0558 => 'Tulostin';

  @override
  String get s06109b8e5c => 'TV / mediatoistin';

  @override
  String get sc4655d321e => 'Kaiutin';

  @override
  String get sa9f2f85b3e => 'Reititin';

  @override
  String get sf8360dcd74 => 'Verkkolevy';

  @override
  String get s8e21b6f258 => 'Älylaite';

  @override
  String get sb38b582dab => 'Kotisilta';

  @override
  String get sdf66171e91 => 'Tämä laite';

  @override
  String get s76a76a654e => 'iPhonen hotspot';

  @override
  String get s15d4ca1672 => 'Puhelimen hotspot';

  @override
  String get sd54522fe39 => 'Reititin / hotspot';

  @override
  String get s23f4820db7 => 'ei vielä ohjattavissa';

  @override
  String get saae59a3865 => 'kotisillan kautta';

  @override
  String get sdccd6e7f24 => 'Malli';

  @override
  String get s891a4b434e => 'MAC';

  @override
  String get s43aba09687 => 'Portit';

  @override
  String get scee3511db6 => 'Lähteet';

  @override
  String get sbc46a05125 => 'Nimeä laite';

  @override
  String get s1d5ed84aed => 'Nimi muistetaan tällä laitteella.';

  @override
  String get s59622d792b => 'Nimeä';

  @override
  String get s1169d2d093 => 'Etsi laitteet';

  @override
  String get s55b85f29a6 => 'Etsitään kotiverkosta…';

  @override
  String get se9c923ff0b =>
      'Molaplan etsii kotiverkosta laitteet, jotka se tunnistaa.';

  @override
  String get s3ff2220816 =>
      'Tunnettuja laitteita ei löytynyt. Valitse merkki alta.';

  @override
  String s2a9142dc3e(String p0) {
    return 'Löytyi $p0. Lisää napauttamalla.';
  }

  @override
  String get s2fc39b0bd7 => 'Etsi uudelleen';

  @override
  String get s0a9acb5af1 => 'Etsi';

  @override
  String get s9a018b8166 =>
      'Et ole kotona: kotisilta etsi laitteet kotiverkosta.';

  @override
  String sf16a25c313(String p0) {
    return 'Muut laitteet verkossa ($p0)';
  }

  @override
  String get s9e8430c37b =>
      'Näitä Molaplan ei ohjaa. iPhonet näkyvät nimellä vain hereillä ollessaan.';

  @override
  String get s3c98732a8c => 'Mittari';

  @override
  String get s6f29aeb685 => 'Trendi';

  @override
  String get s3298699c1a => 'Mittari + trendi';

  @override
  String get sed593f53ed => 'Luku';

  @override
  String get s9027c88cb7 => 'Kerätään dataa…';

  @override
  String get se38a9bb2ed => 'Viimeksi';

  @override
  String get s049d71f971 => 'viimeksi';

  @override
  String get s55d52c5ae1 => 'Tämä laite ei ole yhteydessä wifiin';

  @override
  String s9a4dece965(String p0) {
    return 'Yhdistä tämä laite kodin wifiin (samaan, jossa $p0 on). Tai jos olet kodin ulkopuolella, ota käyttöön kotisilta – silloin haku tehdään kotona olevan laitteen kautta.';
  }

  @override
  String get s3972820cd6 => 'Laitetta ei tavoitettu';

  @override
  String s0f480abb4a(String p0) {
    return 'Laitetta ei tavoitettu osoitteesta $p0';
  }

  @override
  String sa82143ee02(String p0, String p1) {
    return '1. Tarkista että $p0 on päällä (valo palaa).\n2. Tämän laitteen (tai kotisillan) pitää olla samassa wifissä kuin $p1.\n3. Tarkista osoite – se voi vaihtua. Paina \"Takaisin\" ja hae uudelleen.';
  }

  @override
  String get sd4d7ad1bab => 'Osoitteessa on jokin muu laite';

  @override
  String s5b7d02a301(String p0) {
    return 'Osoitteesta vastasi laite, joka ei ole $p0. Tarkista osoite ja kokeile uudelleen.';
  }

  @override
  String get sdac5622fa8 => 'Laite pyytää salasanaa';

  @override
  String get sbf9ee8aaec =>
      'Olet asettanut laitteeseen salasanan. Kirjoita se alle ja paina \"Yhdistä\".';

  @override
  String get s9e22388413 => 'Tarvitaan vielä yksi tieto';

  @override
  String sc8702d4da2(String p0) {
    return '$p0 ei kerro tätä itse. Kirjoita se alle ja paina \"Yhdistä\".';
  }

  @override
  String get s83f57c7c24 => 'Salasana ei kelpaa';

  @override
  String get s32e85a0ba2 =>
      'Tarkista salasana (isot ja pienet kirjaimet). Sen voi vaihtaa laitteen omasta sovelluksesta.';

  @override
  String get sb1d36bfdd3 => 'Painiketta ei painettu ajoissa';

  @override
  String get sc994f6ec6e =>
      'Paina \"Yritä uudelleen\" ja paina sitten painiketta heti.';

  @override
  String get s663202243e => 'Laitteelta ei löytynyt ohjattavaa';

  @override
  String get sb03997d94b =>
      'Laite vastasi, mutta siinä ei ollut kytkimiä tai valoja. Jos käytät pilveä, kirjoita laitteen tunnus (Device ID) käsin.';

  @override
  String get s869571042f => 'Pilviavain tai palvelin ei kelpaa';

  @override
  String get sab1763c592 =>
      'Kopioi avain ja palvelimen osoite uudelleen Shelly-sovelluksesta (Käyttäjäasetukset → Authorization cloud key).';

  @override
  String get s855ffbfd24 => 'Pilveen ei saatu yhteyttä';

  @override
  String get s739d569a9c => 'Tarkista nettiyhteys ja yritä uudelleen.';

  @override
  String get sc96a3502b5 => 'Liian monta pyyntöä';

  @override
  String get sed917dc2a2 =>
      'Pilvi rajoittaa pyyntöjä. Odota hetki ja yritä uudelleen.';

  @override
  String get s516dbdd784 => 'Kotisilta on vanha versio';

  @override
  String get s70089507bf =>
      'Päivitä kotisillan Molaplan (Asetukset → Tarkista päivitykset) ja yritä uudelleen.';

  @override
  String get scc1918f2dc =>
      'Tarkista että kotona oleva kotisilta (tabletti tai PC) on päällä, Molaplan on auki ja sillä on netti.';

  @override
  String get sce0949d6fc =>
      'Yritä uudelleen. Jos ongelma toistuu, käynnistä laite uudelleen.';

  @override
  String get sce6d01c270 => 'Kirjoita ensin osoite';

  @override
  String get s65bbf3cab4 => 'Tarkista osoite';

  @override
  String sb711cc1ce2(String p0, String p1) {
    return '$p0 ei ole kotiverkon osoite. Kotiverkon osoitteet alkavat yleensä 192.168. – katso osoite uudelleen $p1-sovelluksesta.';
  }

  @override
  String se60794c266(String p0) {
    return 'Tarkoititko $p0?';
  }

  @override
  String get s264fda2dee => 'Korjaan itse';

  @override
  String get s0a6098ac78 => 'Kokeile silti';

  @override
  String sc1039f5cf6(String p0) {
    return 'Käytä $p0';
  }

  @override
  String get s20f777bfef => 'Osoite on eri verkossa';

  @override
  String sbb1730fa00(String p0, String p1, String p2, String p3) {
    return 'Osoite $p0 ei ole samassa verkossa kuin tämä laite ($p1.x). Yleensä se tarkoittaa, että tämä laite on eri wifissä kuin $p2.\n\nYhdistä tämä laite samaan wifiin kuin $p3, tai ota kotisilta käyttöön.';
  }

  @override
  String get s43370d968c => 'Täytä ensin';

  @override
  String get s915c9a0db3 => 'Valitse vähintään yksi';

  @override
  String sb160156a36(String p0) {
    return 'Lisää: $p0';
  }

  @override
  String get s43d448a950 => 'Lisää kotinäkymään';

  @override
  String get sd890121a57 => 'Näytä kotinäkymä';

  @override
  String get sb1717cc67c => 'A) Ilman kotisiltaa';

  @override
  String get s2082568a23 => 'Käytä Shelly Cloudia (ei kotisiltaa)';

  @override
  String get s5080d486b8 =>
      'Paras, jos mikään laite ei ole aina kotona – esim. kun tabletti kulkee mukanasi. Ohjaus kulkee Shellyn oman pilven kautta. Tarvitset avaimen Shelly-sovelluksesta (näytämme mistä).';

  @override
  String get s82985d5078 => 'B) Kotisillan kautta';

  @override
  String get s78aec2034d => 'Miten ohjaat kotia muualta?';

  @override
  String s03b3c3b3c8(String p0) {
    return 'Kotisilta on laite, joka on AINA kotona, päällä ja samassa wifissä kuin $p0 – esim. vanha puhelin, tabletti tai PC. Muut laitteesi ottavat siihen yhteyden netin yli (salattu, ei porttiohjauksia). Jos laite lähtee mukaasi, se ei sovi kotisillaksi.';
  }

  @override
  String get s688d1308d7 =>
      'Koska olet kirjautunut, kotiyhteys siirtyy kaikille laitteillesi automaattisesti.';

  @override
  String get s96feb2f60a => 'Tämä laite jää aina kotiin – tee siitä kotisilta';

  @override
  String get sb2a33a1ec4 =>
      'Pidä laite laturissa ja Molaplan auki. Muut laitteet yhdistetään siihen QR-koodilla tai kirjautumalla samalle tilille.';

  @override
  String get s1b9f4ae6d5 =>
      'Kotisilta on jo toisella laitteella – yhdistä siihen';

  @override
  String get s13d739b710 =>
      'Skannaa kotisillan QR-koodi. Sen jälkeen laitteet haetaan kotisillan kautta, vaikka olisit muualla.';

  @override
  String get sda6a1e50e9 =>
      'Ohita nyt – lisään laitteen kotiverkossa (etäyhteyden voi ottaa käyttöön myöhemmin)';

  @override
  String s6f326a48f9(String p0) {
    return 'Etsitään: $p0';
  }

  @override
  String get sc788897ba0 =>
      'Haku tehdään kotisillan kautta, joten tämä toimii myös kodin ulkopuolella.';

  @override
  String get s0f7361f40c => 'Etsin laitteita kodin wifistä. Napauta omaasi.';

  @override
  String get sda2b4c9721 => 'Avaa wifi-asetukset';

  @override
  String get sc93d9cc14b => 'Yhdistin – etsi uudelleen';

  @override
  String get s13f0596b74 => 'Etsitään… (noin 5 sekuntia)';

  @override
  String s8eabd27f68(String p0, String p1) {
    return 'Laitteita ei löytynyt automaattisesti. Tarkista että $p0 on päällä ja samassa wifissä$p1. Voit myös kirjoittaa osoitteen alle.';
  }

  @override
  String get sa616ab181e => 'Kirjoita osoite itse';

  @override
  String get sb439b8abc3 => 'Tai kirjoita osoite itse';

  @override
  String get s178e07f06b => 'IP-osoite';

  @override
  String get scf487a3699 => 'Mistä löydän sen?';

  @override
  String get s9b9b0d01a2 => ' (vapaaehtoinen)';

  @override
  String get s0a7134d0e3 => 'Paina painiketta nyt';

  @override
  String s43118959d5(String p0) {
    return 'Aikaa jäljellä $p0 s';
  }

  @override
  String get sba10f23f03 => 'Yhdistetään…';

  @override
  String get s46c87a553f => 'Kirjaudu kameraan';

  @override
  String get se4095d7d95 => 'Laitteen salasana';

  @override
  String get sdbdf676485 => 'Yhdistä';

  @override
  String get s200542b930 => 'Yritä uudelleen';

  @override
  String get s8f610a3bb2 => 'Olen kodin ulkopuolella';

  @override
  String get sf77125583f => 'Tekniset tiedot';

  @override
  String s77ec7b376b(String p0) {
    return 'Löytyi: $p0';
  }

  @override
  String get sac4debdb9c =>
      'Valitse mitkä tulevat kotinäkymään ja anna niille nimet (esim. Lämmitys, Ulkovalot).';

  @override
  String get sfe5661e401 => 'Poista valinnat';

  @override
  String s2618555da0(String p0) {
    return 'Valitse kaikki ($p0)';
  }

  @override
  String get s86c3f92546 => 'Lisää myös kirkkaus / teho';

  @override
  String get s91571486e4 => 'Näytä myös teho (W)';

  @override
  String sf86536db42(String p0) {
    return 'Valmis! $p0 ruutua lisätty';
  }

  @override
  String get sbfaea66122 =>
      'Ruudut toimivat kotona ja kodin ulkopuolella pilven kautta – mitään muuta ei tarvitse tehdä.';

  @override
  String get se7c68b3bed =>
      'Ruudut toimivat kotona ja kodin ulkopuolella kotisillan kautta – mitään muuta ei tarvitse tehdä.';

  @override
  String get sbc8469cce1 =>
      'Ruudut toimivat nyt kotiverkossa. Jotta voit ohjata kotia mistä tahansa, ota kotisilta käyttöön.';

  @override
  String get s856a422504 => 'Ota etäyhteys käyttöön';

  @override
  String get sd9923cda70 => 'Et ole kotona? Ota etäyhteys käyttöön';

  @override
  String get s876c7230a2 => 'Lisää laite';

  @override
  String get s1e593aeca2 => 'Sulje';

  @override
  String get s3d00dee1a9 => 'Käytä';

  @override
  String get sa252f06bff =>
      'Valitse laitteesi merkki. Molaplan etsii sen ja tekee ruudut valmiiksi.';

  @override
  String get s5b3b5e5a24 =>
      'Hae merkkiä tai laitetta (esim. Shelly, Hue, IKEA)';

  @override
  String get sa427be10c9 => 'Löydä ja yhdistä automaattisesti';

  @override
  String get s6f4cc0844f => 'Tulossa – näin käytät nyt';

  @override
  String get s846ee3bc67 => 'Muut laitteet';

  @override
  String get sdeadd78d47 => 'Termostaatti lämmitys jäähdytys';

  @override
  String get s48264cfe32 => 'Termostaatti';

  @override
  String get s641a848754 =>
      'Pitää lämmön halutussa: ohjaa releitä tai lämpöpumppua lämpömittarin mukaan. Voi säästää pörssisähköllä.';

  @override
  String get s94493d01ca => 'Sääennuste sää lämpötila sade tuuli';

  @override
  String get s262f9527aa => 'Sääennuste';

  @override
  String get scb3570338f =>
      'Sää nyt ja tunneittain: lämpötila, sade ja tuuli kotisi sijainnista. Ei vaadi laitetta.';

  @override
  String get s2a9b6fedd9 => 'Etkö löydä merkkiäsi?';

  @override
  String get scfc7244d06 =>
      'Husqvarna, Zigbee, Tuya, Netatmo, lämpöpumput… katso miten ne toimivat jo nyt.';

  @override
  String get sf7b77783e5 => 'Muu laite (oma asetus)';

  @override
  String get sc168355ee6 => 'Muu laite (edistynyt)';

  @override
  String get s3022f72ece =>
      'Kaikki yhteystyypit: HTTP, MQTT, Modbus, WebSocket, TCP, UDP.';

  @override
  String get s2d1d488d6d =>
      'Teknisille käyttäjille. Vaatii edistyneet asetukset.';

  @override
  String get s6f1c11270c => 'Sisältää esimerkkiasetuksia';

  @override
  String get s8f4c0baf1a =>
      'Laitteita ei löytynyt automaattisesti. Kirjoita osoite itse – sen löydät reitittimen laitelistasta tai laitteen omasta sovelluksesta.';

  @override
  String get s104238f11e => 'Löydetyt laitteet – valitse omasi:';

  @override
  String get sd5f9dce947 => 'Haku ei ole käytettävissä tässä verkossa.';

  @override
  String get s26abc57d91 => 'Opetetaanko kaukosäätimen napit?';

  @override
  String get sc709f38633 =>
      'Perusohjaus (virta, lämpö, tila) toimii jo. Voit lisäksi opettaa kaukosäätimen muita nappeja, esim. \"Turbo\" tai \"Hiljainen\".';

  @override
  String get s6cac83dd5e => 'Ei nyt';

  @override
  String get s97ea2eeb11 => 'Opeta nyt';

  @override
  String get s09cfb7b2a1 => 'Laite lisätty';

  @override
  String sda9574390f(String p0) {
    return 'Laite ja $p0 ruutua lisätty';
  }

  @override
  String get sd51ee1ec8d =>
      'Valmiit asetukset ovat esimerkkejä. Tarkista ne laitteesi ohjeesta ennen kuin luotat arvoihin.';

  @override
  String get s566585dc66 =>
      'IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan lähettää aina koko tilan (virta, tila, lämpö, puhallin, suuntaus) kerralla ja näyttää, mitä se lähetti. Kaukosäätimen muita nappeja voit opettaa myöhemmin: Yhteydet → lähetin → \"Opettele kaukosäädin\".';

  @override
  String get s0dd21e026c => 'Ohje ja automaattinen haku';

  @override
  String get s695a011cc1 => 'Etsitään…';

  @override
  String get s47d409fddd => 'Etsi verkosta';

  @override
  String get s7196b72140 =>
      '⚠ Tässä koneessa ei ole Modbus TCP:tä – tarvitset RS485 → Modbus TCP -muuntimen.';

  @override
  String get s2e8ba44677 => 'Lähde';

  @override
  String get sceb8e47d07 => 'Testaa yhteys';

  @override
  String get s02ce5f4a01 => 'Toimii!';

  @override
  String get sb9e9e55164 => 'Nämä ruudut luodaan';

  @override
  String get s1cb2891ef2 =>
      'Täytä tähdellä (*) merkityt kentät, niin näet ruudut.';

  @override
  String get s504861ee78 =>
      'Ei valmiita ruutuja – voit lisätä ne myöhemmin kynä-painikkeesta.';

  @override
  String get s1094266d4c => 'Näyttää arvon';

  @override
  String get sf6ae3f3323 => 'Kytkin päälle/pois';

  @override
  String get s20dad69675 => 'Painike';

  @override
  String get s0e9f94df05 => 'Säädin';

  @override
  String get s109b454866 => 'Kamerakuva';

  @override
  String get s37153e0e80 => 'Edistyneet asetukset';

  @override
  String get s0ca55a9cae =>
      'Muu laite liitetään teknisillä asetuksilla (HTTP, MQTT, Modbus…). Jos laitteesi merkki löytyy listasta, käytä sitä – se on helpompaa.\n\nOtetaanko edistyneet asetukset käyttöön? Voit poistaa ne Asetuksista.';

  @override
  String get s9630135746 => 'Ota käyttöön';

  @override
  String get sbcdff8f72a => 'Mikä kamera sinulla on?';

  @override
  String get s67bf18fb6f => 'Muu kamera (ONVIF)';

  @override
  String get s772c158a57 => 'rtsp-transport';

  @override
  String get sea00017814 => 'profile';

  @override
  String get s2d65587b87 => 'network-timeout';

  @override
  String get s2ad22696ca => 'Kieli';

  @override
  String get s7efc5653d2 => 'Laitteen kieli';

  @override
  String get s4529c1010a => 'Valitse kamerayhteys';

  @override
  String get s98bf81bba3 => 'Live-video ei toimi tällä laitteella';

  @override
  String get seb2bb5cbce =>
      'Live-video näkyy vain kotiverkossa. Tällä kameralla ei ole still-kuvaa etäkäyttöön.';

  @override
  String get sc95fb5440b => 'Virta päättyi';

  @override
  String get sd55dd196f6 =>
      'Live-videota ei saatu. Tarkista, että olet kotiverkossa ja kameran RTSP on päällä.';

  @override
  String get s8e574c3313 => 'Virta';

  @override
  String get sa9360bdda1 => 'Tuuletin';

  @override
  String get sc7d02fbe84 => 'Lämpöpumppu';

  @override
  String get s8d06ee5308 => 'Hälytys';

  @override
  String get sfb63e3c23f => 'Lukko';

  @override
  String get s2f42d90475 => 'Vesi';

  @override
  String get sf2d10dd213 => 'Sähkö / teho';

  @override
  String get s291ca127d6 => 'Autotalli';

  @override
  String get sb543af1c63 => 'Ovi';

  @override
  String get s60b1079d6c => 'Ikkuna';

  @override
  String get s66ce56ca38 => 'Käynnistä';

  @override
  String get s0ab3a44562 => 'Ajastin';

  @override
  String get s3044a10005 => 'Verkko';

  @override
  String get s1f67139f55 => 'Sauna / lämmitys';

  @override
  String get sf21fd72396 => 'Pistorasia';

  @override
  String get s7783fe5fca => 'Suosikki';

  @override
  String get sb2fa876c32 => 'Kirkkaus';

  @override
  String get s912ea5d2ec => 'Lähetä';

  @override
  String get se223375393 => 'Lista';

  @override
  String get sfb0b971c01 => 'Suuntaus';

  @override
  String get see42f2d999 => 'Kaukosäädin';

  @override
  String get s9126bf24a0 => 'Aurinko';

  @override
  String get s306729fe62 => 'Ei hintoja';

  @override
  String get s80c4ecec94 => 'c/t';

  @override
  String get sbfe79d1f5f => 'Päivitetty';

  @override
  String get sb68e905fc4 => 'Kulutus (kWh)';

  @override
  String get s5fc5085143 => 'Kustannus';

  @override
  String get s2b2118a93b => 'Vanha tieto';

  @override
  String get sb730159a01 => 'Hinta nyt';

  @override
  String get s68fcfcfed1 => 'Halvin tunti tänään';

  @override
  String get s86ff059f5e => 'Tänään keskihinta';

  @override
  String get s7b911d48c6 => 'Kallein tunti tänään';

  @override
  String get s29dbf49d92 => 'Hetkellinen kustannus';

  @override
  String get s723c887da6 => 'halvin';

  @override
  String get s3b36524e04 => 'ka';

  @override
  String get scaaff6345d => 'kallein';

  @override
  String get s5f131c3ec4 => 'Kulutus';

  @override
  String get s039bb374fe => 'Luvut tuntikeskiarvoina';

  @override
  String get sa5e6b1e0e3 => 'Huominen n. klo 14 jälkeen';

  @override
  String get s62cfd94468 => 'Halvimmat tunnit yöllä';

  @override
  String get s7995dff292 =>
      'Päällä yön (22–07) halvimpina tunteina. Sopii varaajalle ja sähköauton lataukseen.';

  @override
  String get sf92675687a => 'Halvimmat tunnit vuorokaudessa';

  @override
  String get sf71a753c59 => 'Päällä vuorokauden halvimpina tunteina.';

  @override
  String get s6c070f7367 => 'Pois, kun sähkö on kallis';

  @override
  String get s214f034099 =>
      'Sammuu, kun hinta ylittää rajan, ja palaa päälle, kun hinta laskee.';

  @override
  String get s3939cfc37e => 'Päälle, kun sähkö on halpa';

  @override
  String get scecc366bc4 => 'Päällä vain, kun hinta on rajan alla.';

  @override
  String get s6e700ae773 => 'Hintaohjaus poistettu';

  @override
  String get s5aa3400a7a => 'Hintaohjaus tallennettu';

  @override
  String get s2f5410429b =>
      'Sääntö toimii tällä laitteella (kotisilta). Pidä laite kotona päällä ja verkossa.';

  @override
  String sb86a43361f(String p0) {
    return 'Sääntö toimii kotisillalla$p0 – puhelimen ei tarvitse olla päällä.';
  }

  @override
  String get s4e35ba5321 =>
      'Kotisiltaa ei ole. Sääntö tallentuu, mutta alkaa toimia vasta kun kotona on aina päällä oleva tabletti tai PC kotisiltana (Asetukset → Etäyhteys).';

  @override
  String s1a9e9bead3(String p0) {
    return 'Hintaohjaus: $p0';
  }

  @override
  String get s6b609c3376 => 'Milloin laite on päällä?';

  @override
  String get s93e5435cf4 => 'Ei hintaohjausta';

  @override
  String get s55e5c3a177 => 'Montako tuntia päällä';

  @override
  String get s52ef5e0b45 => 'Hintaraja';

  @override
  String get s993193d056 => 'Tulevat päälläoloajat';

  @override
  String get s2f7c00a89e =>
      'Hintoja ei saatu juuri nyt. Sääntö toimii, kun hinnat saadaan.';

  @override
  String get s406e599999 =>
      'Ei päälläoloa seuraavan vuorokauden aikana (tai huomisen hinnat puuttuvat vielä).';

  @override
  String get s140acccb81 => 'Tänään';

  @override
  String get s0de6e75a52 => 'Huomenna';

  @override
  String sf87d92faf4(String p0, String p1) {
    return 'Hinta-alue $p0. Hinnat: pörssisähkö (day-ahead), ALV $p1 %. Vaihda alue ja siirtohinta lisäämällä \"Sähkön hinta\" -laite.';
  }

  @override
  String get s2adc3a77ed => 'Valitse yhteystyyppi';

  @override
  String get s78d94155f1 => 'Yhteydet';

  @override
  String get s776d8b06bf => 'Uusi yhteys';

  @override
  String get sc6d89693a5 =>
      'Ei yhteyksiä vielä. Lisää laite tai palvelu, esim. IV-kone (Modbus), Home Assistant tai kamera.';

  @override
  String get s07c82cb0af => 'Pakollinen kenttä';

  @override
  String get sf702cf0ac6 => 'Poistetaanko yhteys?';

  @override
  String s6b83de0ab9(String p0) {
    return '$p0 ruutua käyttää tätä yhteyttä, ne lakkaavat toimimasta.';
  }

  @override
  String get sccd1325381 => 'Yhteys poistetaan tältä laitteelta.';

  @override
  String get s837e0fc5e6 =>
      'IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Ruuduissa näkyy viimeksi lähetetty tila.';

  @override
  String get s09737988fd => 'Yhteys toimii!';

  @override
  String get s0a972aa85e =>
      'Salasanat ja tokenit tallennetaan laitteen suojattuun tallennustilaan.';

  @override
  String get sc51b1e0dc0 => 'Mitä lisätään?';

  @override
  String get s67584c9abf => 'Laite';

  @override
  String get s38f5b2ef26 =>
      'Shelly, Sonoff, Hue, kamera, lämpöpumppu… Etsii kotiverkosta automaattisesti.';

  @override
  String get s3b56b2cb8d => 'Ruutu';

  @override
  String get sfc846c4cc5 =>
      'Sähkön hinta, sää, kamera, mittari, ilmoitus tai komento – ei vaadi uutta laitetta.';

  @override
  String get s147f47be4c => 'Lisää ruutu';

  @override
  String get s229f981388 => 'Kotisilta päällä';

  @override
  String get sfc2dc8fc36 => 'Kotisilta: ei yhteyttä';

  @override
  String get sdedbb30a67 => 'Kotona';

  @override
  String get s9d64d4c166 => 'Etäyhteys';

  @override
  String get s1f8cf57b2c => 'Ei yhteyttä';

  @override
  String get s678a751265 => 'Yhdistä tämä laite kotiin';

  @override
  String get sdae0305965 =>
      'Kotona on jo kotisilta (tabletti tai PC). Skannaa sen QR-koodi tai kirjoita 6 numeroa.';

  @override
  String get s5f8284b98f => 'Tee tästä laitteesta kotisilta';

  @override
  String get s6a95f7843b =>
      'Tämä laite jää kotiin aina päälle (laturiin ja wifiin) ja välittää etänä annetut komennot kodin laitteille.';

  @override
  String get s2c3ae5833b => 'Muut tavat: VPN, Nabu Casa, pilvi-MQTT';

  @override
  String get s807e3a32f3 =>
      'Selkeät ohjeet, jos käytät jo Tailscalea, WireGuardia, Home Assistant Cloudia tai pilvi-MQTT:tä.';

  @override
  String get sa3e78d5c4e => 'Kotisilta vastaa – etäyhteys toimii.';

  @override
  String get s370acd310d => 'Etäyhteys';

  @override
  String get s0b57661c18 => 'Ohjaa kotia myös kodin ulkopuolelta';

  @override
  String get sb43ef4094c =>
      'Kotona Molaplan puhuu laitteille suoraan. Muualla yhteys kulkee salattuna kotisillan kautta – porttiohjauksia tai reititinasetuksia ei tarvita. Sovellus valitsee automaattisesti nopeimman tien.';

  @override
  String get s075e5a4864 => 'Yhdistetty kotiin';

  @override
  String get sa7679488fb =>
      'Kotona = suoraan laitteille. Etäyhteys = kotisillan kautta. Ei yhteyttä = kumpikaan ei vastaa.';

  @override
  String get s19cec9667e => 'Testaa etäyhteys';

  @override
  String get s86ad95fa48 => 'Kopioi kodin näkymät';

  @override
  String get sfaa5185b74 => 'Poistetaanko etäyhteys?';

  @override
  String get sbc44ce6993 =>
      'Tämä laite ei sen jälkeen saa yhteyttä kotiin kodin ulkopuolelta. Voit yhdistää uudelleen milloin vain.';

  @override
  String get s9593939a4c => 'Poista';

  @override
  String get s3563cb1635 => 'Poista etäyhteys';

  @override
  String get s528c4f3a4c => 'Tämä laite on kotisilta';

  @override
  String get se7b8d659b5 => 'Lisäasetukset';

  @override
  String get sfd263f3e04 => 'Kamerakuvan päivitys etänä';

  @override
  String s99249ddf24(String p0) {
    return 'Etänä kamera näyttää kuvan $p0 s välein (säästää dataa).';
  }

  @override
  String get s451ea613dd => 'Välityspalvelin';

  @override
  String get s72da730a42 => 'Yhteys etäpalveluun: kunnossa';

  @override
  String get s421f161f5b => 'Yhdistetään etäpalveluun…';

  @override
  String get s88e2b1dad5 =>
      'Ei yhteyttä etäpalveluun – yritetään uudelleen automaattisesti. Tarkista nettiyhteys.';

  @override
  String get scc0cccf89d => 'Pois päältä';

  @override
  String get sa1d085d92c => 'Kotisillalla ei ole näkymiä kopioitavaksi.';

  @override
  String sa13ef6f8d9(String p0) {
    return 'Kopioitu: $p0 näkymää';
  }

  @override
  String sab5e7202f5(String p0) {
    return 'Yhdistetty kotiin \"$p0\"!';
  }

  @override
  String get s30f06b7fb0 =>
      'Nyt voit ohjata kotia myös kodin ulkopuolelta. Haluatko kopioida kotisillan näkymät ja laitteet myös tähän laitteeseen?';

  @override
  String get s641263ce18 => 'Ei kiitos';

  @override
  String get sa7a6c0fc2d => 'ei Molaplan-koodi';

  @override
  String get se2ecf1935a => 'Yhdistä kotiin';

  @override
  String get s410655fd47 => 'Näin yhdistät';

  @override
  String get s3a141e0c32 =>
      'Avaa kotona olevalla kotisillalla (tabletti tai PC) Molaplan → Asetukset → Etäyhteys → Tee tästä laitteesta kotisilta.';

  @override
  String get sc7c83b2f58 =>
      'Paina siellä \"Yhdistä puhelin\". Näytölle tulee QR-koodi ja 6 numeroa.';

  @override
  String get s35284509d4 => 'Skannaa QR-koodi tai kirjoita numerot alle.';

  @override
  String get s66bb65d8e8 => 'Skannaa QR-koodi';

  @override
  String get se97cc157ef => 'tai kirjoita koodi';

  @override
  String get s643434044c =>
      'Koodilla yhdistettäessä paina vielä kotisillalla \"Hyväksy\".';

  @override
  String get s9753766742 => 'Paina kotisillan näytöllä \"Hyväksy\"…';

  @override
  String get s50e49dd1df => 'Osoita kameralla QR-koodia';

  @override
  String s5d717bb2c5(String p0) {
    return 'Kameraa ei voi käyttää ($p0). Salli kameran käyttö tai kirjoita koodi käsin.';
  }

  @override
  String s7132345f20(String p0) {
    return 'Laite \"$p0\" yhdistetty!';
  }

  @override
  String get se2e2af02ac =>
      'Kotisilta on kotona aina päällä oleva laite, esimerkiksi vanha tabletti tai PC. Kun olet poissa, puhelimesi komennot kulkevat salattuina sen kautta kodin laitteille.';

  @override
  String get sd64f52490d => 'Pidä laite laturissa ja kodin wifissä.';

  @override
  String get sbb23f25581 =>
      'Pidä Molaplan auki. Näyttö pysyy päällä, kun silta on käytössä.';

  @override
  String get sbfed096278 => 'Käytä tätä laitetta kotisiltana';

  @override
  String get s13995350ed => 'Yhdistä puhelin';

  @override
  String get s6a74454a98 => 'Yhdistetyt laitteet';

  @override
  String get s1e4fc2e7fe => 'Ei vielä yhtään. Paina \"Yhdistä puhelin\".';

  @override
  String get s7ea55c5834 => 'Lisätty';

  @override
  String sfd8d693d04(String p0) {
    return 'Poistetaanko \"$p0\"?';
  }

  @override
  String get s84572f642e =>
      'Laite ei sen jälkeen pääse kotiin etänä. Sen voi yhdistää uudelleen.';

  @override
  String get sc58a7d7121 => 'Kodin nimi';

  @override
  String get s9715416100 => 'Skannaa puhelimella';

  @override
  String get sf54c6d871c =>
      'Puhelimessa: Molaplan → Asetukset → Etäyhteys → Yhdistä tämä laite kotiin';

  @override
  String get sf7fa9632f3 => 'Voimassa';

  @override
  String get s5378bb3f05 => 'Hyväksytäänkö laite?';

  @override
  String s1d8bb7b0a6(String p0) {
    return '\"$p0\" haluaa ohjata kotia etänä. Hyväksy vain, jos se on oma tai perheenjäsenen laite, jolla juuri syötit koodin.';
  }

  @override
  String get sa04c218f82 => 'Hylkää';

  @override
  String get sdfaf8c242b => 'Hyväksy';

  @override
  String get s1cf33c1fbc => 'Tila / arvo';

  @override
  String get s86029171be => 'Kytkin';

  @override
  String get s4ddce888df => 'Painike / pikakomento';

  @override
  String get s357fc9c3fe => 'Liukusäädin / asetusarvo';

  @override
  String get s14da6beba5 => 'Näyttää lukeman, esim. lämpötilan tai tehon.';

  @override
  String get se4b1d203df => 'Päälle/pois, esim. valo tai hälytys.';

  @override
  String get sc2197ab417 => 'Yksi painallus tekee yhden tai monta asiaa.';

  @override
  String get sd611704caf => 'Säädä arvoa, esim. lämpötilaa tai puhallinta.';

  @override
  String get sacfc0c0b41 => 'Näyttää kameran kuvan.';

  @override
  String get s7172c54c2c => 'Pitää lämpötilan halutussa arvossa.';

  @override
  String get s76e7a995de => 'Luettu arvo';

  @override
  String get sc5edd6d3d1 => 'Uusi ruutu';

  @override
  String get sa684fd0716 => 'Muokkaa ruutua';

  @override
  String get s8a8673aafe => 'Otsikko';

  @override
  String get scf37cbeda8 => 'Kuvake';

  @override
  String get sfeab9bd26f => 'Leveys';

  @override
  String get s58be670598 => 'Korkeus';

  @override
  String get sd7314e8237 => 'Näyttötapa';

  @override
  String get s1c72b8c56a => 'Trendin pituus';

  @override
  String get s6bb0c0c7e3 => 'Mittarin minimi';

  @override
  String get sa444aab286 => 'Automaattinen';

  @override
  String get sbf29caff87 => 'Mittarin maksimi';

  @override
  String get sea30815e6a =>
      'Ruudun tekniset asetukset (mistä tila luetaan, mitä komento lähettää) näkyvät, kun otat Asetuksista käyttöön \"Edistyneet\".';

  @override
  String get s382afc832f => 'Tilan luku';

  @override
  String get s581aee3e96 => 'Valinnainen: mistä nykyinen tila luetaan.';

  @override
  String get se6b18b17d9 => 'Päivitysväli (s, 0 = ei kyselyä)';

  @override
  String get s01f2b1ee0c =>
      'MQTT, Home Assistant ja WebSocket päivittyvät reaaliajassa ilman kyselyä.';

  @override
  String get s937448ecf5 => 'Testaa luku';

  @override
  String get s5cbdea7f7e => 'Näyttö';

  @override
  String get se6af4b33df => 'Yksikkö';

  @override
  String get sd5498697da => 'Desimaalit';

  @override
  String get s4f7007db78 => 'Arvojen nimet';

  @override
  String get s4aae179c52 => '0=Pois;1=Kotona;2=Poissa';

  @override
  String get s0c12fda7ca => 'Kytkimen komennot';

  @override
  String get s3a9d9e16ef => '\"Päällä\"-arvot (pilkuin, tyhjä = automaattinen)';

  @override
  String get s1509c5a2a6 => 'PÄÄLLE-komento';

  @override
  String get s2a1e131afd => 'POIS-komento';

  @override
  String get s0201de52c0 => 'Komennossa {{value}} korvataan säätimen arvolla.';

  @override
  String get sc30c9a7e51 => 'Askel';

  @override
  String get s4d6451a63a => 'Asetuskomento';

  @override
  String get sa4082e1a79 => 'Komennot (suoritetaan järjestyksessä)';

  @override
  String get s467488e572 =>
      'Pikakomento voi ohjata useaa laitetta peräkkäin, viiveillä.';

  @override
  String get sad43973fb3 => 'Lisää komento';

  @override
  String get sdaef43c622 => 'Kysy vahvistus ennen komentoa';

  @override
  String get s5210a5ad23 => 'Yhteys';

  @override
  String get s96705fc3df => 'Komento lähetetty';

  @override
  String get sb41db1e809 => 'Kokeile';

  @override
  String get s77d2309fd5 => 'Viive ennen (ms)';

  @override
  String get sc0f5a14d2b => 'Värirajat (arvo ≥ raja → väri)';

  @override
  String get scd65d31d4c => 'Raja';

  @override
  String get s30a2c0f460 => 'Lisää raja';

  @override
  String get s4226eb046f => 'Kumoa';

  @override
  String get sd5cb601286 => 'Tailscale (helppo VPN)';

  @override
  String get s0aa851cfb4 =>
      'Ilmainen henkilökäyttöön. Puhelin ja koti ovat kuin samassa verkossa – Molaplan toimii samoilla osoitteilla kuin kotona.';

  @override
  String get s444ca5d58f =>
      'Sopii, jos sinulla on kotona aina päällä PC, Raspberry Pi tai Home Assistant.';

  @override
  String get sec7b4d1d7a =>
      'Tee Tailscale-tili osoitteessa tailscale.com (Google-, Microsoft- tai Apple-tunnuksella).';

  @override
  String get s178c57446d =>
      'Asenna Tailscale kotona aina päällä olevaan laitteeseen. Home Assistantissa: Asetukset → Lisäosat → Tailscale.';

  @override
  String get s4faf83aa13 =>
      'Ota siinä käyttöön \"subnet router\" ja kerro kotiverkkosi, esim. 192.168.1.0/24. Silloin kaikki kodin laitteet näkyvät.';

  @override
  String get s721719c0e1 =>
      'Hyväksy reitti Tailscalen hallintasivulla (Machines → laite → Edit route settings).';

  @override
  String get s921f981bda =>
      'Asenna Tailscale-sovellus puhelimeen ja kirjaudu samalla tilillä. Laita VPN päälle.';

  @override
  String get s8ae7e7b2a4 =>
      'Valmis! Molaplan käyttää samoja osoitteita kuin kotona. Etäyhteyttä ei tarvitse muuttaa.';

  @override
  String get se92301ff0a => 'tailscale.com/download';

  @override
  String get sf6270ae66c => 'Subnet router -ohje / guide';

  @override
  String get s57f0b61334 => 'WireGuard (reitittimen VPN)';

  @override
  String get sb9bb49ab92 =>
      'Jos reitittimesi tukee WireGuardia (esim. ASUS, FRITZ!Box, UniFi, OpenWrt), puhelin liittyy kotiverkkoon suoraan.';

  @override
  String get s986d264604 =>
      'Sopii, jos reitittimessä on WireGuard ja liittymässä julkinen IP-osoite.';

  @override
  String get sf24b16dc12 =>
      'Avaa reitittimen asetukset ja etsi \"VPN-palvelin\" → \"WireGuard\".';

  @override
  String get s1e5d1eb832 =>
      'Ota palvelin käyttöön ja lisää uusi laite (peer) puhelimelle.';

  @override
  String get s8e0252a2b4 =>
      'Reititin näyttää QR-koodin. Asenna puhelimeen WireGuard-sovellus ja skannaa koodi.';

  @override
  String get s4b3740b727 =>
      'Tarkista että \"Allowed IPs\" sisältää kotiverkon (esim. 192.168.1.0/24).';

  @override
  String get sd2e8523b28 =>
      'Laita VPN päälle puhelimessa – Molaplan toimii kuten kotona.';

  @override
  String get saa17c5a456 => 'wireguard.com/install';

  @override
  String get se5960424ea =>
      'Monissa mobiililaajakaistoissa (4G/5G-kotinetti) ei ole julkista IP-osoitetta (CGNAT), eikä WireGuard silloin toimi ulkoa. Käytä silloin Molaplan-etäyhteyttä tai Tailscalea.';

  @override
  String get sab2dfe387b => 'Home Assistant Cloud (Nabu Casa)';

  @override
  String get s2e0586b37e =>
      'Maksullinen kuukausitilaus Home Assistantin tekijöiltä. Antaa turvallisen etäosoitteen Home Assistantiin.';

  @override
  String get s534e7ec95e => 'Sopii, jos laitteesi ovat jo Home Assistantissa.';

  @override
  String get s0f7533967d =>
      'Home Assistantissa: Asetukset → Home Assistant Cloud → aloita kokeilu tai kirjaudu.';

  @override
  String get s2e60dd8178 => 'Ota \"Remote control / Etäohjaus\" päälle.';

  @override
  String get s7a73024451 =>
      'Kopioi etäosoite, joka näyttää tältä: https://abcd1234.ui.nabu.casa';

  @override
  String get sd4873612f7 =>
      'Molaplanissa: Yhteydet → Home Assistant → vaihda osoitteeksi tuo etäosoite. Token pysyy samana.';

  @override
  String get s15223b0e32 =>
      'Valmis! Home Assistant -ruudut toimivat nyt kaikkialla.';

  @override
  String get s9b3201b1fa => 'nabucasa.com';

  @override
  String get s60e7067815 =>
      'Tämä koskee vain Home Assistantin kautta ohjattavia laitteita. Muille (Modbus, kamerat suoraan) käytä Molaplan-etäyhteyttä tai VPN:ää.';

  @override
  String get s8e0d0a2d4e => 'Pilvi-MQTT (esim. HiveMQ Cloud)';

  @override
  String get sd0fff65292 =>
      'Laitteet ja Molaplan puhuvat saman pilvipalvelimen kautta. HiveMQ Cloudissa on ilmainen taso, joka riittää kotikäyttöön.';

  @override
  String get s7350b9f98b =>
      'Sopii MQTT-laitteille: Tasmota, ESPHome, Shelly, Zigbee2MQTT, omat ESP-laitteet.';

  @override
  String get s59b3c7d246 =>
      'Tee ilmainen tili osoitteessa console.hivemq.cloud ja luo ilmainen klusteri (Free/Serverless).';

  @override
  String get s04fe436d1e =>
      'Kohdassa \"Access Management\" luo käyttäjätunnus ja salasana.';

  @override
  String get sdf0075eab5 =>
      'Kopioi palvelimen osoite (esim. abcd.s1.eu.hivemq.cloud). Portti on 8883 ja TLS on päällä.';

  @override
  String get s9e9be6fc33 =>
      'Vaihda laitteidesi MQTT-asetuksiin tämä palvelin, tunnus ja salasana (TLS päälle).';

  @override
  String get s90f1cb151b =>
      'Molaplanissa: Yhteydet → MQTT → osoite, portti 8883, TLS päälle, tunnus ja salasana. Valmis – toimii kaikkialla.';

  @override
  String get s77bf29f2f5 => 'console.hivemq.cloud';

  @override
  String get safd2cd2b7b =>
      'Valitse vahva salasana: kuka tahansa salasanan tietävä voi ohjata laitteitasi.';

  @override
  String get s9557c0ef28 => 'Etäkäytön ohjeet';

  @override
  String get sf4d7957b78 => 'Helpoin: Molaplan-etäyhteys';

  @override
  String get s8032085166 =>
      'Ei tilejä, ei reititinasetuksia. Tarvitset vain kotona aina päällä olevan tabletin tai PC:n.';

  @override
  String get sd9b48e01fc => 'Muut tavat';

  @override
  String get sfe551fd431 => 'Laiteohjeet';

  @override
  String get sa35e37b4b4 =>
      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Molaplan löytää lämpöpumpun itse.';

  @override
  String get scb28b11e70 => 'Uusi näkymä';

  @override
  String get s1f9799af4e => 'esim. Mökki';

  @override
  String get s3a13f9d077 => 'Nimeä näkymä';

  @override
  String get sa5bf37213b => 'Poistetaanko näkymä?';

  @override
  String s10671afc00(String p0, String p1) {
    return '\"$p0\" ja sen $p1 ruutua poistetaan.';
  }

  @override
  String s897761b5f4(String p0) {
    return 'Näkymä \"$p0\" poistettu';
  }

  @override
  String get scc5cf9957d => 'Valitse ruudun tyyppi';

  @override
  String get s7cf6340503 => 'Uusi laite valmiilla ruuduilla';

  @override
  String get se6ca707cf3 =>
      'Helpoin tapa: Shelly, ESP32-CAM, Home Assistant, IV-kone…';

  @override
  String get s0789f5f14f => 'NÄKYMÄT';

  @override
  String get sfb3e3c456c => 'Poista näkymä';

  @override
  String get scdfd80f963 => 'Lisää ruutu';

  @override
  String get s71af34b8e9 => 'Tyhjä näkymä';

  @override
  String get s6a210970eb =>
      'Täällä näkyvät laitteidesi ruudut: lämpötilat, kytkimet, kamerat ja pikakomennot. Aloita lisäämällä laite.';

  @override
  String get s4229fb4103 => 'Lisää ensimmäinen laite';

  @override
  String get sf67e0d5752 => 'Poistetaanko ruutu?';

  @override
  String s97f46743e0(String p0) {
    return 'Ruutu \"$p0\" poistettu';
  }

  @override
  String get sda9203de80 => 'Ei tiliä – asetukset vain tällä laitteella. ';

  @override
  String get s8b3e63da21 => 'Luo tili ›';

  @override
  String get s887c293cad => 'Laite lisätty! 🎉';

  @override
  String get s84a087a679 =>
      'Luo tili, niin asetukset säilyvät ja siirtyvät muille laitteille. Se käy sähköpostikoodilla, salasanaa ei tarvita.';

  @override
  String get s907220900d => 'Tervetuloa Molaplaniin';

  @override
  String get s845ec6276f => 'Asetukset kaikilla laitteillasi';

  @override
  String get s9dfa93453b => 'Mitään ei katoa, vaikka puhelin vaihtuu';

  @override
  String get s6aa51b28a5 => 'Laitteiden salasanat salataan';

  @override
  String get sc6f02b69d3 => 'Luo tili / Kirjaudu';

  @override
  String get sc777bde66f => 'Sähköpostikoodilla – ei salasanaa.';

  @override
  String get se2e5ff2c8a => 'Jatka ilman tiliä';

  @override
  String get sb8934a5835 => 'Sähkönkulutus';

  @override
  String get s5409dc748f => 'Ei mukana';

  @override
  String get sf0bbcc217b => 'Koko kohde';

  @override
  String get s0ad1897b28 => 'Laitteen mittaus';

  @override
  String get s99268b5a6c =>
      'Koko kohde = pääsähkömittari. Laitteen mittaus = yksi laite (näytetään osana kokonaisuutta, ei lasketa kahteen kertaan).';

  @override
  String get se1174af557 => 'Osa mittaria (valinnainen)';

  @override
  String get s9773c92c92 => 'Energia ja kustannukset';

  @override
  String get s43dead6994 => 'Sähkösopimus';

  @override
  String get sef4d24cdd4 => 'Päivä';

  @override
  String get sa62dd794ce => 'Kuukausi';

  @override
  String get s6b2ebe5aca => 'Valitse ensin mittarit';

  @override
  String get sde41f2fac9 =>
      'Merkitse alta, mikä mittari mittaa koko kohdetta ja mitkä yksittäisiä laitteita.';

  @override
  String get s4ad000d885 => 'sis. ALV';

  @override
  String get s9e214b6e88 => 'ilman ALV';

  @override
  String get s73771d252c => 'Mitatut laitteet yhteensä';

  @override
  String get s22d03356a9 => 'Muu kulutus';

  @override
  String get s48b08c5f5a => 'Perusmaksut (energia + siirto)';

  @override
  String get s286e1cfb54 => 'Yhteensä';

  @override
  String get s2e8700e0cf =>
      'Osalle kulutuksesta ei ollut hintaa (pörssihinta puuttui).';

  @override
  String get sbbd89fbc05 =>
      'Kulutus kirjataan, kun sovellus on auki (kodin tabletilla jatkuvasti).';

  @override
  String get s64382718ff => 'Mittarit';

  @override
  String get s9a3a0d414e =>
      'Ei teho- tai energiaruutuja (W, kW, Wh, kWh). Lisää esim. Shelly-mittari.';

  @override
  String get sdb0484d728 => 'Tallennettu';

  @override
  String get se80021e22a =>
      'Katso hinnat sähkölaskusta. Voit kirjoittaa ne verollisina tai verottomina – kustannukset näytetään molempina.';

  @override
  String get sfb62156afe => 'Hinta-alue';

  @override
  String get s1762fb70a7 => 'Sähköenergia';

  @override
  String get s2ed3e3cf28 => 'Pörssisähkö';

  @override
  String get s5d1dd0f675 => 'Kiinteä';

  @override
  String get sedb38796fb => 'Yö/päivä';

  @override
  String get s0774cea15a => 'Marginaali';

  @override
  String get s63370fe61a => 'Energian hinta';

  @override
  String get s50a7dd89c6 => 'Päiväenergia';

  @override
  String get sdeaa5ad900 => 'Yöenergia';

  @override
  String get se93c7bcd86 => 'Perusmaksu (energia)';

  @override
  String get sb7937e4b91 => 'Siirto';

  @override
  String get s0f89840226 => 'Yleissiirto';

  @override
  String get sa768f1b352 => 'Siirtohinta';

  @override
  String get s9e5dde22cb => 'Päiväsiirto';

  @override
  String get sdf7a4fd2e3 => 'Yösiirto';

  @override
  String get s4df0aee067 => 'Perusmaksu (siirto)';

  @override
  String get s4c59c90975 => 'Yö alkaa';

  @override
  String get s84decd042b => 'Yö päättyy';

  @override
  String get s90c26f1e37 => 'Verot';

  @override
  String get s222cb348a0 => 'Sähkövero';

  @override
  String get sbe412dcaa6 => 'ALV';

  @override
  String get s43b55c13c5 => 'Haku ei onnistunut. Tarkista verkkoyhteys.';

  @override
  String get s171834ca33 => 'Kodin sijainti';

  @override
  String get s6f6c2fe37a =>
      'Sääennuste (Open-Meteo) auttaa lämmittämään etukäteen ennen pakkasta. Paikkakunta riittää.';

  @override
  String get s5f663978d6 => 'Paikkakunta';

  @override
  String get s7be6460c54 => 'esim. Tampere';

  @override
  String get s1576b70590 => 'Sähkönkulutus, kustannukset, sopimus ja sää.';

  @override
  String get sa6212aaeb4 => 'Sijainti';

  @override
  String get s12c2f8e6e4 => 'Vain kotiverkossa';

  @override
  String s5f7c464e6d(String p0) {
    return 'klo $p0';
  }

  @override
  String s21b64ae0a7(String p0) {
    return '$p0 toimii vain kotiverkossa. Ruutu palaa normaaliksi itsestään, kun olet taas kotona.';
  }

  @override
  String get s6b1a8249de => 'Viimeisin tila';

  @override
  String get s56650a18d5 => 'Tee etäkäyttöiseksi ›';

  @override
  String get sa0d8c62e5a => 'Komentoa ei ole määritetty';

  @override
  String get s1e5d696a26 => 'Suoritetaanko komento?';

  @override
  String get s1df6e2eaa7 => 'PIN';

  @override
  String get secab66c046 => 'Muista tällä laitteella';

  @override
  String get s10bf4eab8e =>
      'Tallennetaan suojattuna vain tähän laitteeseen. Oletuksena PIN-koodia ei tallenneta.';

  @override
  String get s856418521a => 'Komentoja ei ole määritetty';

  @override
  String sdfa66ee201(String p0) {
    return '$p0: lähetetty';
  }

  @override
  String get s12fc3810a5 => 'Lähetetty – odotetaan vastausta…';

  @override
  String get sd1c7d49360 => 'Vastaus klo';

  @override
  String get s38ac222392 => 'Arvo';

  @override
  String get s29fae6a0e8 => 'Hintaohjaus käytössä';

  @override
  String get s59d55f8882 => 'Nimeä uudelleen';

  @override
  String get s25580038cb => 'Tallennettu PIN poistettu';

  @override
  String get sf50c488b24 => 'Unohda tallennettu PIN';

  @override
  String get safe0429a90 => 'Hintaohjaus';

  @override
  String get sf3d644dd4c => 'Opettele kaukosäätimen nappi';

  @override
  String get sfb1a18d11f => 'Päivitä';

  @override
  String get s4cbe24240f => 'Päällä';

  @override
  String get s72a2328ddd => 'Valot';

  @override
  String get sca12be80ca => 'Kytkimet';

  @override
  String get sa4c0eeea02 => 'Lämpöpumput ja ilmastointi';

  @override
  String get sa8dbf04ad3 => 'Tila-anturit';

  @override
  String get sa7690acf57 => 'Verhot ja ovet';

  @override
  String get s487bf00fc7 => 'Lukot';

  @override
  String get s88ac47e6d1 => 'Kamerat';

  @override
  String get sbe76826428 => 'Puhaltimet';

  @override
  String get s6b7c1c52da => 'Tilannekuvat';

  @override
  String get s9f1334d4e2 => 'Skriptit';

  @override
  String get s4b53bcaaf0 => 'Painikkeet';

  @override
  String get s5c92d42edd => 'Säätimet';

  @override
  String get s3c2ed0c522 => 'Apukytkimet';

  @override
  String get se9ca7cb470 => 'Automaatiot';

  @override
  String get sea20d169a3 => 'Mediasoittimet';

  @override
  String get sbcb95e1e78 =>
      'Tunnus (token) ei kelpaa. Luo uusi Home Assistantissa.';

  @override
  String get s0b80dc2642 =>
      'Home Assistantiin ei saatu yhteyttä. Tarkista osoite.';

  @override
  String get sf32b7f15d8 => 'kamerat';

  @override
  String s095ca83913(String p0) {
    return '$p0 ruutua lisätty';
  }

  @override
  String get sa7a829cefb => 'Valitse Home Assistantin laitteet';

  @override
  String get sefdf8e3316 => 'Haetaan laitteita…';

  @override
  String get s26583a1933 => 'Huoneittain omiin näkymiin';

  @override
  String sf1319d04d0(String p0) {
    return 'Lisää $p0';
  }

  @override
  String get sb3e6b54bce => 'Hae nimellä tai tunnuksella';

  @override
  String get safedc10c48 => 'Kaikki huoneet';

  @override
  String get s407f3f7a0c => 'Ei huonetta';

  @override
  String get sedb7b77645 => 'Kaikki';

  @override
  String get sa765c9294a => 'Näytä kaikki';

  @override
  String sdb088f47a8(String p0) {
    return '$p0 teknistä kohdetta piilotettu (diagnostiikka, asetukset, päivitykset)';
  }

  @override
  String get s3ee8d0a5e3 =>
      'Huoneita ei saatu luettua – näytetään laitteet ilman huoneita.';

  @override
  String get sf55fca7a32 => 'Ei osumia';

  @override
  String get s78cdce874e => 'jo lisätty';

  @override
  String get sdc398885dc => 'Lisäasetukset';

  @override
  String get s5d477f3cd8 => 'Yleensä näihin ei tarvitse koskea';

  @override
  String get s2315e0e739 => 'esim.';

  @override
  String get sc1c47d2474 => 'Valitse taustakuva';

  @override
  String sa8ce5112ee(String p0) {
    return 'Enintään $p0 taustakuvaa. Poista jokin ensin.';
  }

  @override
  String get sceafe9ce2a => 'Tiedosto ei ole kuva';

  @override
  String get s12a7d631af => 'Ulkoasu';

  @override
  String get s0d83798030 => 'Koko';

  @override
  String get s64c916e299 => 'Pieni';

  @override
  String get s5e3097232a => 'Leveä';

  @override
  String get s8971788287 => 'Iso';

  @override
  String get s7400a53ab2 => 'Väri';

  @override
  String get s254a1d8e12 => 'Taustakuva (valinnainen)';

  @override
  String get sc48f5f9bcf => 'Valitse kuva';

  @override
  String get sf55eee73b8 => 'Vaihda kuva';

  @override
  String get sf6723451b9 => 'Ota kuva';

  @override
  String get sdd957ccc1b => 'Poista kuva';

  @override
  String get s7ba9d453ed => 'Himmennä kun laite on pois päältä';

  @override
  String get s016ae7b580 =>
      'Kuva pienennetään (≤ 200 kt) ja synkronoidaan tiliisi.';

  @override
  String get sabb10f8cb2 =>
      'Kuva pienennetään (≤ 200 kt) ja tallennetaan vain tälle laitteelle.';

  @override
  String get s4dab2d409b => 'Vie asetukset';

  @override
  String get s149c1e54d6 => 'Asetukset viety';

  @override
  String get s35f445793b => 'Tuo asetukset';

  @override
  String get sd55be829e3 => 'Korvataanko nykyiset asetukset?';

  @override
  String get s852dd1795e =>
      'Kaikki nykyiset yhteydet ja näkymät korvataan tiedoston sisällöllä.';

  @override
  String get s580678cb10 => 'Tuo';

  @override
  String get s5f2ec17730 => 'Asetukset tuotu';

  @override
  String get sa87fff54f3 => 'Tuonti epäonnistui';

  @override
  String get s2fd2bfedb8 => 'Tili';

  @override
  String get s4c0ff416ab => 'Samat kodit ja ruudut kaikilla laitteillasi.';

  @override
  String get scc7e418ee3 =>
      'Kirjaudu, niin kodit, laitteet ja ruudut ovat samat PC:llä, tabletilla ja puhelimella. Vapaaehtoinen.';

  @override
  String get s9bb545e9b3 => 'Kirjaudu tai luo tili';

  @override
  String get s0625d54b38 => 'Laattakoko';

  @override
  String get s8382da3467 => 'Normaali';

  @override
  String get s7c1cd8314e => 'Piilota etänä toimimattomat';

  @override
  String get sa0cbbafb4e =>
      'Kotiverkon ulkopuolella vain kotiverkossa toimivat ruudut piilotetaan. Oletuksena ne näkyvät harmaina paikallaan.';

  @override
  String get s21f870dbc2 =>
      'Näyttää tekniset asetukset: yhteydet (HTTP, MQTT, Modbus…), viestit, JSON-polut ja ruutujen lähteet. Useimmat eivät tarvitse näitä.';

  @override
  String get sca4c8b88b7 => 'Home Assistant: lisää laitteita';

  @override
  String get saec69088a5 => 'Ohjaa kotia myös kodin ulkopuolelta.';

  @override
  String get scc3d01ee5e => 'Ohjeet: VPN, Nabu Casa, pilvi-MQTT';

  @override
  String get s90ba544719 => 'Ohjeet';

  @override
  String get sb915c42792 => 'Näytä aloitusopas';

  @override
  String get sd337a7ddd5 => 'Varmuuskopio ja siirto';

  @override
  String get s07c1048b4f =>
      'Vie asetukset JSON-tiedostoon ja tuo ne toiselle laitteelle (esim. PC → puhelin).';

  @override
  String get s2f797098e7 => 'Sisällytä salasanat ja tokenit';

  @override
  String get s26f72949e3 =>
      'Tiedosto on silloin salaamaton – säilytä se turvassa.';

  @override
  String get sdb12678e52 => 'Vie';

  @override
  String get s34686ffb09 => 'Esimerkki';

  @override
  String get s412c666544 =>
      'Lisää esimerkkinäkymä (kamera, hälytys, valot, IV-kone). Vaihda osoitteet omiksesi.';

  @override
  String get sec02c7c071 => 'Lisää esimerkkinäkymä';

  @override
  String get s522d6584c5 => 'Tarkista päivitykset';

  @override
  String get sd178a1d809 =>
      'Oma ohjauspääte: HTTP, MQTT, Modbus TCP, Home Assistant, kamerat, WebSocket, TCP ja UDP. Ilman tiliä kaikki asetukset pysyvät tällä laitteella.';

  @override
  String get se455dc672b => 'Vaihe';

  @override
  String get s3ddd2678bf => 'Ohita opas';

  @override
  String get s171ac59e67 =>
      'Valitse laitteesi alta. Täytät vain sen osoitteen – loput tehdään puolestasi.';

  @override
  String get se722dfcec9 =>
      'Molaplan on kotisi oma ohjauspaneeli. Kokoat siihen itse ne laitteet ja napit, joita tarvitset.';

  @override
  String get scbac938ead => 'Näe tilanne yhdellä silmäyksellä';

  @override
  String get se25f930e31 =>
      'Lämpötilat, valot, hälytys ja kamerakuva samassa näkymässä.';

  @override
  String get s3e450dba98 => 'Ohjaa yhdellä napautuksella';

  @override
  String get sdda6a3f06e =>
      'Valot päälle, IV-kone tehostukselle tai \"Lähden kotoa\" -painike, joka tekee monta asiaa kerralla.';

  @override
  String get sbcac0cd35a => 'Sama koti kaikilla laitteilla';

  @override
  String get sd43d517cc7 =>
      'Halutessasi kirjaudu tilillä, niin PC, tabletti ja puhelin näyttävät saman kodin. Salasanat salataan laitteellasi. Tili ei ole pakollinen.';

  @override
  String get s70fff97e97 => 'Minulla on jo Molaplan-tili – kirjaudu';

  @override
  String get sd6561a08ca => 'Aloitetaan';

  @override
  String get se5be2a8386 => 'Ruudut ovat valmiina';

  @override
  String get s8162694dbe => 'Lisää ensimmäinen ruutu';

  @override
  String get s7b2a30b77c =>
      'Laitteellesi tehtiin nämä ruudut. Voit muuttaa ja järjestää niitä myöhemmin.';

  @override
  String get s39e163fa49 =>
      'Ruutu näyttää tiedon tai ohjaa laitetta. Valitse millainen ruutu tehdään:';

  @override
  String get s4bfb026e45 => 'Teen tämän myöhemmin';

  @override
  String get s3f0351473c => 'Haluatko ohjata kotia myös kodin ulkopuolelta?';

  @override
  String get s6fe6fe631f =>
      'Kotona kaikki toimii jo. Kodin ulkopuolelta tarvitaan kotiin yksi aina päällä oleva laite (vanha tabletti tai PC) – ei reititinasetuksia, ei tilejä.';

  @override
  String get sb599b7432f => 'Etäyhteys on käytössä.';

  @override
  String get s33a294d472 => 'Tämä laite on kotisilta.';

  @override
  String get s4aa8cce504 => 'Ei nyt – vain kotona';

  @override
  String get sd3c370ca52 => 'Valmista!';

  @override
  String get s1359035b73 => 'Napauta ruutua';

  @override
  String get sfd26c8e50b =>
      'Kytkin vaihtuu päälle/pois, painike suorittaa komennon.';

  @override
  String get s416c8184a7 => 'Kynä-painike ylhäällä';

  @override
  String get s2ba275defe =>
      'Muokkaa, lisää, poista ja järjestä ruutuja vetämällä.';

  @override
  String get se872eeb0f5 => 'Paina ruutua pitkään';

  @override
  String get s63496941fc =>
      'Näet lisätiedot ja selityksen, jos jokin ei toimi.';

  @override
  String get s080be778d5 =>
      'Sieltä löydät tämän oppaan, etäyhteyden ja varmuuskopioinnin.';

  @override
  String get sae0fae7127 => 'Siirry omaan näkymään';

  @override
  String get s64f4d1e11a => 'Aseta kodin sijainti';

  @override
  String get sbf7cc3de9a => 'Yritä nyt';

  @override
  String get s1becc05ea1 => 'locked=Lukossa;unlocked=Auki;jammed=JUMISSA';

  @override
  String get s259de02f33 =>
      'open=Auki;closed=Kiinni;opening=Aukeaa;closing=Sulkeutuu';

  @override
  String get s64d4364336 =>
      'disarmed=Pois;armed_away=Päällä;armed_home=Kotona;armed_night=Yö;triggered=HÄLYTYS;arming=Kytkeytyy';

  @override
  String get s5b1e227dc4 => 'on=Päällä;off=Pois';

  @override
  String get s3d43664fcc => 'WebSocket';

  @override
  String get sfcbb753f53 => 'Osoite';

  @override
  String get s81479e1555 => 'Otsakkeet (Nimi: arvo / rivi)';

  @override
  String get s5811b38d7b => 'Token (Authorization: Bearer)';

  @override
  String get sd512dbbfc7 => 'Viesti yhdistettäessä';

  @override
  String get s2c4fd261e2 => 'Salli itse allekirjoitettu sertifikaatti';

  @override
  String get s4d089aab74 => 'Suodatin (viesti sisältää)';

  @override
  String get s55c951a8ad => 'JSON-polku';

  @override
  String get s10813e25b3 => 'Regex (ryhmä 1)';

  @override
  String get s4a282cd247 => 'Kyselyviesti (lähetetään luettaessa)';

  @override
  String get sbeef545d37 => 'Viesti ({{value}} = arvo)';

  @override
  String get s0477f24b6b => 'HTTP / REST';

  @override
  String get s3102ae3a16 => 'Perusosoite';

  @override
  String get s38d0517a8d => 'Tunnistus';

  @override
  String get sed995f57b8 => 'Käyttäjätunnus';

  @override
  String get s65e35b7cc4 => 'Token';

  @override
  String get s51510ae27a => 'Lisäotsakkeet (Nimi: arvo / rivi)';

  @override
  String get s361419c448 => 'Aikakatkaisu (s)';

  @override
  String get sf235ce5ec0 => 'Metodi';

  @override
  String get s484291707c => 'Polku';

  @override
  String get s54c8aed8bc => 'Runko';

  @override
  String get s5c5e9b662c => 'Runko ({{value}} = arvo)';

  @override
  String get s8e82ca13cf => 'Content-Type';

  @override
  String s3c045f21ee(String p0, String p1, String p2) {
    return 'Testattiin: GET $p0 (perusosoite, $p1 tavua, $p2 ms).';
  }

  @override
  String get s7797602869 =>
      'Komentoja ei lähetetty eikä ruutujen polkuja testattu.';

  @override
  String sbf349dfcbd(String p0, String p1) {
    return 'HTTP $p0: laite vastasi, mutta ei hyväksynyt kirjautumista. Tarkista käyttäjätunnus, salasana tai token. $p1';
  }

  @override
  String s3bd10f0ae2(String p0, String p1) {
    return 'HTTP $p0: laite vastasi virheellä (palvelinvirhe). $p1';
  }

  @override
  String s2a7fa26dd6(String p0, String p1) {
    return '✓ Laite vastasi osoitteessa $p0 (HTTP 404: perusosoitteessa ei ole sivua – se on normaalia monille laitteille). Yhteys toimii. $p1';
  }

  @override
  String sb2821916bc(String p0, String p1, String p2) {
    return '✓ Yhteys toimii: HTTP $p0. $p1 $p2';
  }

  @override
  String get s58648dc3fc => 'Kamera (MJPEG / JPEG / RTSP)';

  @override
  String get s1534821f4a => 'Kameran osoite';

  @override
  String get s95533426a3 => 'RTSP-osoite (live-kuva kotiverkossa)';

  @override
  String get sa1115d4b0b => 'RTSP-osoite, kevyt (ruutu)';

  @override
  String get se995a6862d => 'Tila';

  @override
  String get s4f356d158a => 'Kuvan päivitysväli (s, snapshot)';

  @override
  String get sca7e088857 => 'Sähkön hinta';

  @override
  String get s2525f9a4f5 =>
      'Suomi on yksi alue (FI). Ruotsissa ja Norjassa alue riippuu asuinpaikasta.';

  @override
  String get s8f4a683abf => 'ALV %';

  @override
  String get s1c7d76a774 => 'Suomessa 25,5 %.';

  @override
  String get se49d0fba92 => 'Myyjän marginaali (c/kWh)';

  @override
  String get s20a5e2936a =>
      'Pörssisähkösopimuksen marginaali ilman ALV:tä, esim. 0,5.';

  @override
  String get s923f9739de => 'Siirto + sähkövero (c/kWh)';

  @override
  String get s2a3498fb0f =>
      'Laskun mukaan ALV:n kanssa. Jätä 0, jos haluat nähdä pelkän energian hinnan.';

  @override
  String get s515da3a9dd => 'Hintapalvelin';

  @override
  String get s98cc9f1c14 =>
      'Molaplanin oma palvelin hakee hinnat avoimista lähteistä.';

  @override
  String get s271885dc8b => 'Mitä näytetään';

  @override
  String get s46282f452b =>
      'now = hinta nyt, chart = kaavio tälle ja huomiselle päivälle.';

  @override
  String get s2f754e8ab4 => 'Tämän päivän hintoja ei ole vielä saatavilla.';

  @override
  String get sd575462da3 => 'huomenna ';

  @override
  String get s18faad19ed => 'Hintaa ei ole tälle hetkelle.';

  @override
  String get s29178b43f4 => 'Sähkön hinta on vain luettava.';

  @override
  String get s1a707f2788 => 'Huominen: kyllä.';

  @override
  String get sb85af981c1 => 'Huominen: ei vielä (julkaistaan n. klo 14).';

  @override
  String s6270faf138(String p0, String p1, String p2, String p3) {
    return '✓ Hinnat haettu alueelle $p0 ($p1 jaksoa, $p2 min, lähde $p3).';
  }

  @override
  String get se1bd60873c => 'MQTT';

  @override
  String get s85b9781bb7 => 'Välittäjän osoite';

  @override
  String get s800d13debd => 'Portti';

  @override
  String get s49fa57061a => 'TLS';

  @override
  String get s0fcef98aad => 'WebSocket-yhteys (ws:// tai wss://)';

  @override
  String get s5089c65c1f => 'Client ID (tyhjä = automaattinen)';

  @override
  String get s9372a6f755 => 'Keep alive (s)';

  @override
  String get sd373a99107 => 'Tilan aihe (topic)';

  @override
  String get s518c8aa712 => 'Komennon aihe (topic)';

  @override
  String get s120726c79a => 'Viesti ({{value}} = arvo)';

  @override
  String get s3660228d11 => 'QoS';

  @override
  String get s1b07c9ba3d => 'Retain';

  @override
  String s91c3d72d1e(String p0) {
    return 'puhallin $p0';
  }

  @override
  String get s40032ddea9 => ', suuntaus';

  @override
  String get s7068e8892e =>
      'Koodia ei tunnistettu eikä raakadataa tullut. Ota Tasmotassa käyttöön raakadata (SetOption58 1) ja yritä uudelleen.';

  @override
  String get s6207a45bff => 'IR-lähetin (ilmalämpöpumppu)';

  @override
  String get s859c2e7734 => 'Lähettimen ohjelmisto';

  @override
  String get s3f8d3fb444 =>
      'tasmota_http = Tasmota (tasmota-ir) suoraan IP-osoitteella. tasmota_mqtt = Tasmota MQTT-välittäjän kautta. esphome = ESPHome climate_ir. http/mqtt = muu lähetin omilla osoitteilla.';

  @override
  String get s38471ae691 => 'Lähettimen osoite';

  @override
  String get sda91fafa54 =>
      'IR-lähettimen IP-osoite (Tasmota tai ESPHome). Löytyy reitittimen laitelistasta.';

  @override
  String get sf9220a3e4d => 'Merkin IR-protokolla';

  @override
  String get s423f2576c4 =>
      'Tasmotan IRhvac-valmistajanimi, esim. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. Jos laite ei reagoi, kokeile saman merkin toista protokollaa.';

  @override
  String get s74ff2fd8a8 => 'Malli (valinnainen)';

  @override
  String get sef4c0e5d90 =>
      'IRhvac Model -numero joillekin merkeille (esim. Panasonic). Jätä tyhjäksi, jos et tiedä.';

  @override
  String get s8e7962c184 => 'Tasmotan aihe (topic)';

  @override
  String get s5ae4cc50db =>
      'Vain MQTT: Tasmotan asetuksista (Configuration → MQTT → Topic). Komennot menevät aiheeseen cmnd/<aihe>/IRhvac.';

  @override
  String get sed30580f59 => 'MQTT-välittäjän osoite';

  @override
  String get s744ce256bb =>
      'Vain MQTT: kone, jolla Mosquitto pyörii (usein Home Assistant -kone).';

  @override
  String get se6754df705 => 'MQTT-portti';

  @override
  String get sbfc8ee6c86 => 'Tunnus';

  @override
  String get s711670d91a => 'MQTT-tunnus tai Tasmotan web-tunnus (admin).';

  @override
  String get s3bbd70773d => 'Jätä tyhjäksi, jos ei tarvita.';

  @override
  String get s443fe6f350 => 'ESPHome-ilmastoinnin tunnus';

  @override
  String get s62feae1a9f =>
      'Vain ESPHome: climate-entiteetin nimi pienillä kirjaimilla ja alaviivoilla (esim. \"Ilmalämpöpumppu\" → ilmalampopumppu).';

  @override
  String get se0efd6dfb3 => 'Komennon osoite (muu lähetin)';

  @override
  String get s5366cbd4df =>
      'Vain http: osoite, johon koko tila lähetetään. Paikkamerkit: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.';

  @override
  String get sce533db7c1 => 'Viestin pohja (muu lähetin)';

  @override
  String get s0fa691e7c7 =>
      'http (POST-runko) tai mqtt (viesti). Tyhjä = IRhvac-JSON ({{json}}).';

  @override
  String get s8567c5faa6 =>
      'summary = koko tila tekstinä. room = lähettimen lämpöanturi (jos on). Muut = viimeksi lähetetty asetus.';

  @override
  String get sdd8cd8132c => 'Mitä muutetaan';

  @override
  String get s2e8b846390 =>
      'Koko tila lähetetään aina kerralla (IR toimii niin). Arvo tulee ruudusta tai kentästä \"Arvo\".';

  @override
  String get sb517d97868 =>
      'Esim. heat, cool, auto, dry, fan (tila) tai on/off. Tyhjä = ruudun arvo.';

  @override
  String get sda4a1b2eee => 'Opeteltu koodi';

  @override
  String get s0cfc723aa2 =>
      'Täyttyy itse, kun tallennat opetellun kaukosäätimen napin. Lähetetään Tasmotan IRsend-komennolla.';

  @override
  String get s3f26cb7602 => 'ESPHome-painike';

  @override
  String get sc71964f422 =>
      'Vain ESPHome: painikkeen tunnus, jonka teit opetellulle koodille.';

  @override
  String get s852a166240 => 'Lähettimen osoite puuttuu.';

  @override
  String get s75ce01c354 =>
      'Tasmota pyytää salasanaa – lisää web-salasana yhteyden asetuksiin.';

  @override
  String sf9d84ad23c(String p0) {
    return 'Tasmota ei tunne komentoa $p0. Asenna lähettimeen tasmota-ir-versio (sisältää ilmalämpöpumppujen protokollat).';
  }

  @override
  String sff167aa9a6(String p0) {
    return 'Tasmota hylkäsi komennon: $p0';
  }

  @override
  String s385c6a9a2d(String p0) {
    return 'Tasmota ei tunne merkin protokollaa \"$p0\". Valitse toinen merkki/protokolla.';
  }

  @override
  String sb4ea2389cb(String p0) {
    return 'ESPHome ei löytänyt ilmastointia \"$p0\". Tarkista tunnus (web_server-sivulta).';
  }

  @override
  String get s34deda2c72 => 'Komennon osoite puuttuu.';

  @override
  String get s04e4777aea => 'Lämpötila puuttuu.';

  @override
  String get sfce1a094cb =>
      'Lähettimessä ei ole lämpöanturia (Status 8 ei kertonut lämpötilaa).';

  @override
  String s4536eb33dd(String p0) {
    return 'Lämpötilaa ei tullut (tele/$p0/SENSOR).';
  }

  @override
  String get s9b5bbfa2c6 => 'Huonelämpö vain Tasmota/ESPHome-lähettimistä.';

  @override
  String get s5acc16dafb => 'RF433-koodeja voi lähettää vain Tasmotalla.';

  @override
  String get s8478662ad1 => 'Opeteltuja koodeja voi lähettää vain Tasmotalla.';

  @override
  String s9f8263b5a0(String p0, String p1) {
    return 'ESPHome-painiketta \"$p0\" ei löytynyt (HTTP $p1).';
  }

  @override
  String s3296e8d7e7(String p0) {
    return 'Koodia ei tullut $p0 sekunnissa. Osoita kaukosäätimellä suoraan lähettimeen (alle 1 m) ja paina nappia uudelleen. Tarkista, että lähettimessä on IR-vastaanotin.';
  }

  @override
  String get s1e73ba395d => 'RF433-opettelu toimii Tasmotalla.';

  @override
  String get scc47b4b225 => 'Opettelu toimii Tasmota- ja ESPHome-lähettimillä.';

  @override
  String s96adaaf2b6(String p0, String p1, String p2) {
    return '✓ Tasmota vastasi (versio $p0). Testattiin: Status 0 osoitteessa $p1. $p2 Lämpöpumpulle ei lähetetty mitään.';
  }

  @override
  String sfce5c770f1(String p0) {
    return 'MQTT-välittäjä toimii, mutta Tasmota \"$p0\" ei vastannut. Tarkista aihe.';
  }

  @override
  String s2c3b95a054(String p0) {
    return '✓ Tasmota \"$p0\" vastasi MQTT:n kautta. Lämpöpumpulle ei lähetetty mitään.';
  }

  @override
  String scf9ead3297(String p0, String p1, String p2, String p3) {
    return '✓ ESPHome-ilmastointi \"$p0\" löytyi (tila $p1). Testattiin: GET $p2/climate/$p3. Mitään ei lähetetty.';
  }

  @override
  String get s8ad50358b9 =>
      'Muulle lähettimelle ei ole testiä: IR on yksisuuntainen. Paina virtaruutua ja katso, reagoiko lämpöpumppu.';

  @override
  String s3b476099a2(String p0) {
    return 'Laite vastasi HTTP $p0. Onko ESPHome-asetuksissa web_server päällä?';
  }

  @override
  String sd44aec7380(String p0) {
    return 'Laite ei vastannut osoitteessa $p0.';
  }

  @override
  String s120026628c(String p0) {
    return 'Laitetta ei tavoitettu osoitteessa $p0. Tarkista IP-osoite.';
  }

  @override
  String get s43c9b88580 => 'Automaatti';

  @override
  String get sa3e8beed42 => 'Lämmitys';

  @override
  String get s6c9668fbd9 => 'Jäähdytys';

  @override
  String get s9db8aefc43 => 'Kuivaus';

  @override
  String get s018d2e08f4 => 'Puhallin';

  @override
  String get s36fb6ba26f => 'Modbus TCP';

  @override
  String get sa70cc38354 => 'IP-osoite';

  @override
  String get sdc5301b750 => 'Laitteen osoite (unit id)';

  @override
  String get s15e327bf8e => 'Aikakatkaisu (ms)';

  @override
  String get s943b8b6bf3 => 'Rekisterityyppi';

  @override
  String get sf51ad986eb => 'Osoite (0-pohjainen)';

  @override
  String get s601f118ac0 => 'Tietotyyppi';

  @override
  String get sddd62d21b0 => 'Sanajärjestys käänteinen (CDAB)';

  @override
  String get see24ec5d84 => 'Kerroin';

  @override
  String get s0a239b832b => 'Siirtymä';

  @override
  String get s5f374d3643 => 'Unit id (tyhjä = yhteyden)';

  @override
  String get sef11962984 => 'Kirjoitettava';

  @override
  String get s779b59ba4b => 'Arvo ({{value}} = liukusäädin/kytkin)';

  @override
  String get sefaea1b818 => 'ntfy (viestikanava / komennot)';

  @override
  String get s6a4516e0fe => 'Komentokanava (aihe tai koko osoite)';

  @override
  String get se003ecc10b =>
      'Aihe, johon komennot lähetetään. Voit liittää koko osoitteen, esim. https://ntfy.sh/oma-aihe – sama osoite jota iPhonen pikakomento käyttää. Aiheen nimi on kuin salasana: pidä se pitkänä ja satunnaisena.';

  @override
  String get s800cd08229 => 'Vastauskanava (vapaaehtoinen)';

  @override
  String get s2e3a66d384 =>
      'Jos kotilaite vastaa eri aiheeseen, kirjoita se tähän. Jätä tyhjäksi, jos vastaus tulee samaan aiheeseen – silloin oma lähetetty komento ohitetaan ja seuraava viesti näytetään vastauksena.';

  @override
  String get s5bc736c04a => 'Käyttöoikeustunnus (vapaaehtoinen)';

  @override
  String get s77feae14f5 =>
      'Tarvitaan vain, jos aihe on suojattu (ntfy-tili → Access tokens). Julkiseen aiheeseen jätä tyhjäksi.';

  @override
  String get seca0d75969 =>
      'Oletus on julkinen ntfy.sh. Vaihda vain, jos käytät omaa ntfy-palvelinta. Jos liitit yllä koko osoitteen, palvelin luetaan siitä.';

  @override
  String get sddbea594a4 =>
      'latest = viimeisin viesti, log = useita viimeisimpiä viestejä allekkain (uusin ylimpänä).';

  @override
  String get s2bd0e69d44 => 'Aihe (vapaaehtoinen)';

  @override
  String get s4eb1e8ac15 =>
      'Mistä aiheesta viestit luetaan. Tyhjä = yhteyden vastauskanava (tai komentokanava, jos vastauskanavaa ei ole).';

  @override
  String get s09fa5c0332 => 'Viestien määrä (log)';

  @override
  String get s17fda9fb06 =>
      'Montako viimeisintä viestiä näytetään log-tilassa.';

  @override
  String get s78f2f0d783 => 'Kuinka kaukaa';

  @override
  String get s79bdbfd820 =>
      'Esim. 30m, 12h tai 2d. Julkinen ntfy.sh säilyttää viestejä noin 12 tuntia.';

  @override
  String get sfe357edcec => 'Komento (lähetettävä teksti)';

  @override
  String get s48e102023d =>
      'Teksti joka lähetetään, esim. \"päivitä\". Jos PIN kysytään, se lisätään perään välilyönnillä: \"päivitä 1234\".';

  @override
  String get saf2ebedf61 => 'Kysy PIN painettaessa';

  @override
  String get sfcb5608064 =>
      'Kysyy PIN-koodin (piilotettuna) joka painalluksella ja lisää sen komennon perään. PIN-koodia ei tallenneta, ellet itse valitse \"Muista tällä laitteella\".';

  @override
  String get sfee393b70e => 'Odota vastausta';

  @override
  String get sfff5bc52e5 =>
      'Kuuntelee kotilaitteen vastausta ja näyttää sen tässä ruudussa (ja ilmoituksena, jos sovellus on taustalla).';

  @override
  String get sbdcbe301b9 => 'Vastauksen odotus (s)';

  @override
  String get s121542d6d7 =>
      'Kuinka kauan vastausta odotetaan, ennen kuin kerrotaan ettei vastausta tullut.';

  @override
  String get sa53638cfea => 'Vastaus näkyy ruudussa (s)';

  @override
  String get se6d21484a8 =>
      'Kuinka kauan vastaus näkyy ruudussa. 0 = kunnes painat uudelleen.';

  @override
  String get s74d68a98d6 => 'Viestin otsikko (vapaaehtoinen)';

  @override
  String get sc2492ac3ab =>
      'ntfy-viestin otsikko. Yleensä tyhjä – jätä tyhjäksi, ellei kotilaite sitä vaadi.';

  @override
  String s54ea45f27f(String p0, String p1) {
    return 'ntfy: aihe \"$p0\" on suojattu (HTTP $p1). Lisää käyttöoikeustunnus (tk_…) yhteyden asetuksiin.';
  }

  @override
  String get s72c37e530d =>
      'ntfy: liian monta viestiä lyhyessä ajassa (HTTP 429). Odota hetki ja yritä uudelleen.';

  @override
  String get s0870daf796 => 'ntfy: komentokanava puuttuu';

  @override
  String get s28dc7ea012 => 'ntfy: yhteys katkesi ennen vastausta';

  @override
  String sa4313864fe(String p0, String p1) {
    return 'Komento lähetettiin, mutta vastausta ei tullut $p0 sekunnissa. Tarkista, että kotilaite on päällä ja kuuntelee aihetta \"$p1\".';
  }

  @override
  String get s85a1947a44 => '(ei viestejä)';

  @override
  String get s7069b18b7d => 'ntfy: komennon teksti puuttuu';

  @override
  String s43de3fd299(String p0) {
    return ' Vastauskanava: $p0.';
  }

  @override
  String s9ed9eb7f92(String p0, String p1, String p2, String p3) {
    return '✓ ntfy-palvelin $p0 vastasi ja aihe \"$p1\" on luettavissa ($p2 viestiä viimeisen tunnin aikana).$p3 Testi ei lähettänyt komentoa – paina ruutua kokeillaksesi.';
  }

  @override
  String get sf0ef0140c3 => 'Home Assistant';

  @override
  String get s1f90ee6992 => 'Pitkäikäinen käyttöoikeustunnus';

  @override
  String get sccb0cca8e3 => 'Reaaliaikaiset päivitykset (websocket)';

  @override
  String get s8f8e1cfad3 => 'Entiteetti';

  @override
  String get s382111aebc => 'Attribuutti (tyhjä = tila)';

  @override
  String get sf500d0ad67 => 'Palvelu';

  @override
  String get s7286715019 => 'Lisädata JSON ({{value}} = arvo)';

  @override
  String get s1b5b0421c0 => 'Viesti heksana';

  @override
  String get s44ab1d33df => 'Odota vastausta';

  @override
  String get s341bf61e36 => 'Vastaus heksana';

  @override
  String get se7cff2d61e => 'TCP (raaka)';

  @override
  String get s1dfeacd9f6 => 'UDP';

  @override
  String get s804e935440 => 'ESP32-kamera';

  @override
  String get s478ddb6e1a => 'IV-kone (Modbus)';

  @override
  String get s4b4fd14aaf => 'Piha';

  @override
  String get s8ac16d45bc =>
      'disarmed=Pois;armed_away=Päällä;armed_home=Kotona;triggered=HÄLYTYS';

  @override
  String get sbde42d83a3 => 'Olohuoneen valot';

  @override
  String get sb7c78c63b3 => 'Tuloilma';

  @override
  String get sbb2adef009 => 'IV-kone nopeus';

  @override
  String get see46441329 => '0=Pois;1=Poissa;2=Kotona;3=Tehostus;4=Max';

  @override
  String get sb25aad3bc2 => 'Lähden kotoa';

  @override
  String get s7e461faf91 =>
      'Löytyy reitittimen laitelistasta tai laitteen sovelluksesta. Voit myös painaa \"Etsi verkosta\".';

  @override
  String get saf4b222a68 => 'Laitteen IP-osoite';

  @override
  String get s1bbea216af => 'ESP32-CAM-kamera';

  @override
  String get saaaeccd0cc => 'Edullinen wifi-kamera. Näyttää liikkuvan kuvan.';

  @override
  String get saaea39b2de => 'Kameran IP-osoite';

  @override
  String get s6ef2a3f197 =>
      'Näkyy kameran sarjamonitorissa käynnistyessä tai reitittimen laitelistassa.';

  @override
  String get sae199413a2 => 'Esim. Piha, Eteinen, Autotalli.';

  @override
  String get s2dd165b39f => 'Kuvan tyyppi';

  @override
  String get sb66b153f36 =>
      'mjpeg = liikkuva kuva (suositus). snapshot = still-kuva muutaman sekunnin välein, kevyempi.';

  @override
  String get sf81257929d => 'Shelly-rele / pistorasia';

  @override
  String get s2b8ab6defc =>
      'Ohjaa valoa tai laitetta päälle/pois ja näyttää tehon.';

  @override
  String get s7fcea114f0 => 'Mitä se ohjaa?';

  @override
  String get s864ba0233b =>
      'Uudemmat (Shelly Plus, Pro, Gen3) = Plus / Pro / Gen2+. Vanhat Shelly 1, 2.5, Plug S = Gen1.';

  @override
  String get s92f97cd95e => 'Näytä teho (W)';

  @override
  String get s54c71d86aa =>
      'Vain malleille, joissa on tehomittaus (esim. Plus 1PM, Plug S).';

  @override
  String get s49671fc56f => 'Kanava';

  @override
  String get s06f8a27d8a =>
      'Monikanavaisissa (esim. Shelly 2PM) 0 = ensimmäinen, 1 = toinen.';

  @override
  String get s259e46c59a =>
      'Vain jos olet asettanut Shellyyn salasanan (Gen1: admin).';

  @override
  String get sc130e073ba =>
      'Tasmota-ohjelmistolla toimiva rele tai pistorasia.';

  @override
  String get s16be1831d6 => 'Vain energiamittauksella varustetuille.';

  @override
  String get s8890d26ef2 => 'Releen numero';

  @override
  String get s7e6d21d466 => 'Monireleisissä 1, 2, 3...';

  @override
  String get s5f1e4a036e => 'Web-salasana';

  @override
  String get s397e83233d =>
      'Vain jos Tasmotaan on asetettu web-salasana (käyttäjä admin).';

  @override
  String get sa0efcdf688 =>
      'Oma ESP32/ESP8266-laite ESPHome-ohjelmistolla (web_server päällä).';

  @override
  String get s631420589f => 'Laitteen nimi';

  @override
  String get s1db899640b => 'Kytkimen tunnus (valinnainen)';

  @override
  String get sb2e87033fc =>
      'YAML-tiedoston switch-nimi pienillä kirjaimilla, välilyönnit alaviivoiksi. Esim. \"Sauna rele\" → sauna_rele.';

  @override
  String get s978ae8f1d6 => 'Anturin tunnus (valinnainen)';

  @override
  String get s4ba12c5866 =>
      'Sensorin nimi samalla tavalla. Esim. \"Lämpötila\" → l_mp_tila tai lampotila (katso laitteen web-sivulta).';

  @override
  String get s945273ef29 => 'Anturin yksikkö';

  @override
  String get s5ca2e25792 =>
      'Vain jos web_serverille on asetettu tunnus (auth).';

  @override
  String get sb847f22473 => 'Web-tunnus';

  @override
  String get s76f6067b0f =>
      'Valot, hälytys, anturit – valitse listasta, mitkä haluat ruuduiksi.';

  @override
  String get s9f70681d3f => 'Home Assistantin osoite';

  @override
  String get s123502628e =>
      'Sama osoite, jolla avaat Home Assistantin selaimessa.';

  @override
  String get s92e3c4cd40 => 'Pitkäikäinen tunnus (token)';

  @override
  String get s4e3f2052b2 =>
      'Home Assistant → klikkaa omaa nimeäsi vasemmalla alhaalla → Turvallisuus → Pitkäikäiset käyttöoikeustunnukset → Luo tunnus. Kopioi ja liitä tähän.';

  @override
  String get s54e063bd9c => 'Lämpöpumppu (Home Assistant)';

  @override
  String get s2afe650320 =>
      'Ilmalämpöpumppu, joka näkyy Home Assistantissa ilmastointilaitteena (climate).';

  @override
  String get s48fdd98530 =>
      'Jos Home Assistant on jo lisätty, sama yhteys otetaan käyttöön.';

  @override
  String get sfe5ad3202f =>
      'HA → oma profiili → Turvallisuus → Luo tunnus. Ei tarvita, jos HA on jo lisätty.';

  @override
  String get sce069d8d1a => 'Lämpöpumpun entiteetti';

  @override
  String get s05e2aaa15c =>
      'Alkaa sanalla climate. Löytyy HA:sta Asetukset → Entiteetit.';

  @override
  String get se699281c85 => 'Lämpöpumppu (MQTT)';

  @override
  String get s8643040b95 =>
      'Esim. mitsubishi2mqtt- tai vastaava ESP-ohjain. Aiheet ovat esimerkkejä – tarkista omasi.';

  @override
  String get s2a1148ee77 => 'MQTT-välittäjän IP-osoite';

  @override
  String get s53e472c976 =>
      'Kone, jolla Mosquitto tai muu MQTT-välittäjä pyörii (usein Home Assistant -kone).';

  @override
  String get s29aff3d2a0 => 'MQTT-tunnus';

  @override
  String get s37e57de4b9 => 'Jätä tyhjäksi, jos välittäjä ei vaadi.';

  @override
  String get sffe00ea1b3 => 'MQTT-salasana';

  @override
  String get s407d4a5e56 => 'Perusaihe';

  @override
  String get sc1af622c0a =>
      'Ohjaimen asetuksista. Tila luetaan aiheesta <perusaihe>/state ja komennot lähetetään aiheeseen <perusaihe>/set.';

  @override
  String get s9783a8fd53 => 'huone';

  @override
  String get sbc996a7d25 => 'asetus';

  @override
  String get sa69c0e1ca3 => 'Ilmalämpöpumppu (IR)';

  @override
  String get s025e7bf04d =>
      'Ohjaa mitä tahansa kaukosäätimellä toimivaa ilmalämpöpumppua IR-lähettimellä (Tasmota tai ESPHome). IR on yksisuuntainen: Molaplan näyttää, mitä se viimeksi lähetti.';

  @override
  String get sb5d4127728 => 'IR-lähetin';

  @override
  String get sc899cf95db =>
      'Useimmat valmiit IR-lähettimet (esim. Athom, Moes) toimivat Tasmotalla. Asenna niihin tasmota-ir-versio. ESPHome = oma ESPHome-laite, jossa climate_ir.';

  @override
  String get sc096a735fd =>
      'IR-lähettimen IP-osoite. Jos valitsit MQTT:n, kirjoita tähän MQTT-välittäjän osoite.';

  @override
  String get safc7f1325c => 'Lämpöpumpun merkki';

  @override
  String get s7675ec1754 =>
      'Valitse ulkoyksikön tai kaukosäätimen merkki. Jos lämpöpumppu ei reagoi, kokeile \"Muu\" ja jotain saman merkin vaihtoehtoista protokollaa.';

  @override
  String get s9702830f91 => 'Protokolla (vain \"Muu\")';

  @override
  String get s6df0837908 =>
      'Tasmotan IRhvac-valmistajanimi, esim. DAIKIN2, LG2, COOLIX. Täytä vain, jos merkki on \"Muu\" tai haluat kokeilla toista.';

  @override
  String get saa49bfdb90 => 'Näkyy ruutujen otsikossa.';

  @override
  String get sf1971ac29b => 'Tasmotan aihe (vain MQTT)';

  @override
  String get s65529d5877 =>
      'Tasmota → Configuration → MQTT → Topic. Muu MQTT-lähetin: aihe, johon komento lähetetään.';

  @override
  String get s321c1677e2 => 'ESPHome-ilmastoinnin tunnus (vain ESPHome)';

  @override
  String get s4c07dec7b5 =>
      'climate_ir-entiteetin nimi pienillä kirjaimilla ja alaviivoilla. Näkyy ESPHome-laitteen web-sivulla.';

  @override
  String get s2229e548f3 =>
      'MQTT-tunnus tai Tasmotan web-tunnus (yleensä admin). Jätä tyhjäksi, jos ei tarvita.';

  @override
  String get s06cff48000 => 'Komennon osoite (vain Muu HTTP)';

  @override
  String get s5b41e244d6 =>
      'Paikkamerkit: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.';

  @override
  String get s9a60c2026e => 'Tilanapit (lämmitys, jäähdytys…)';

  @override
  String get sd119ce3382 =>
      'Omat napit lämmitykselle, jäähdytykselle, automaatille, kuivaukselle ja puhallukselle.';

  @override
  String get s9b8dd7076a => 'Puhallinnopeus';

  @override
  String get s9597aa1ae9 => 'Liukusäädin 0–5 (0 = automaatti).';

  @override
  String get secae50c5dd => 'Suuntaus (swing)';

  @override
  String get s8bcb8433f9 => 'Puhallussuunnan heilutus päälle/pois.';

  @override
  String get s78a5e5fa61 => 'Huonelämpö lähettimen anturista';

  @override
  String get s2dd6395602 =>
      'Vain jos lähettimessä on lämpöanturi (Tasmota: näkyy Status 8:ssa; ESPHome: climate_ir:n sensor).';

  @override
  String get s4ff78f06ab => 'Ilmalämpöpumppu (huoltoliitäntä / ESPHome)';

  @override
  String get s6cc7b6b499 =>
      'Lämpöpumpun sisäyksikön huoltoliitäntään kytketty ESPHome-ohjain (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba). Kaksisuuntainen: näet todellisen tilan ja huonelämmön.';

  @override
  String get s647e86e5e5 => 'Ilmastoinnin tunnus';

  @override
  String get sbeb6af1e1c =>
      'ESPHome-laitteen climate-entiteetti. Ohjeet-sivun \"Etsi lämpöpumput\" löytää sen itse.';

  @override
  String get sbf36d139cb => 'Vain jos ESPHome web_serverissä on tunnus.';

  @override
  String get s54d4fdbba4 => 'Vain jos ESPHome web_serverissä on salasana.';

  @override
  String get s84cd6a5180 => 'RF433-kaukosäädin (Athom IR & RF)';

  @override
  String get s4105198757 =>
      'Ohjaa radiokaukosäätimellä toimivia laitteita (pistorasiat, markiisit, autotallin ovet) Athom \"Tasmota IR & RF433 Controller\" -laitteella. Opetat napit kaukosäätimestä heti lisäämisen jälkeen.';

  @override
  String get sbc2bf08889 =>
      'Athom-ohjaimen IP-osoite (reitittimen laitelistasta).';

  @override
  String get sc34430eec0 => 'Esim. huone tai laite, jota ohjaat.';

  @override
  String get s12447972e0 => 'Vain jos Tasmotaan on asetettu web-salasana.';

  @override
  String get s6385f1487e => 'Sähkön hinta (pörssisähkö)';

  @override
  String get se807a72c0a =>
      'Tämän ja huomisen päivän pörssisähkön hinta kaaviona, 15 minuutin tarkkuudella. Hintaohjaus: paina laitteen ruutua pitkään → Hintaohjaus.';

  @override
  String get sef8d24c969 => 'Maa / hinta-alue';

  @override
  String get sef4f509f9f =>
      'Suomessa FI. Ruotsissa ja Norjassa valitse alue, jolla asut.';

  @override
  String get sf3a8631d14 =>
      'Laskustasi ALV:n kanssa. 0 = näytä pelkkä energian hinta.';

  @override
  String get sf3be8aac1c => 'Sopimuksesi marginaali ilman ALV:tä.';

  @override
  String s49dfca65a3(String p0) {
    return 'Sähkön hinta $p0';
  }

  @override
  String get s9af9526395 => 'IV-kone (Modbus TCP)';

  @override
  String get s29dc0baf55 =>
      'Lämpötilat ja puhallinnopeus. Valmiit rekisterilistat esimerkkeinä – tarkista oman koneesi ohjeesta.';

  @override
  String get sb75966bb58 => 'IV-koneen tai yhdyskäytävän IP-osoite';

  @override
  String get s751331a84a =>
      'Jos koneessa on vain RS485-väylä, tarvitset RS485 → Modbus TCP -muuntimen (esim. Waveshare). Syötä sen IP.';

  @override
  String get s658cdb6ff8 => 'Koneen merkki';

  @override
  String get s785c0c264c =>
      'Valitse merkki, niin rekisterit täytetään valmiiksi esimerkkinä. \"—\" = tyhjä, lisäät ruudut itse.';

  @override
  String get s7e9c785c20 => 'Usein 1. Katso koneen Modbus-asetuksista.';

  @override
  String get s0591744c19 => 'Lähes aina 502.';

  @override
  String get s5ccb7405cf => 'IV-kone';

  @override
  String get se7dfa3594e => 'MQTT-laite';

  @override
  String get s12ab103795 =>
      'Mikä tahansa laite, joka puhuu MQTT:tä (Zigbee2MQTT, oma ESP, ...).';

  @override
  String get sffcfefd91c =>
      'Kone, jolla MQTT-välittäjä (esim. Mosquitto) pyörii.';

  @override
  String get s6ac05d979c => 'Mikä laite on?';

  @override
  String get s460d48d0cc =>
      'switch = kytkin (päälle/pois), sensor = mittari (näyttää arvon).';

  @override
  String get s850c7e1194 => 'Tilan aihe';

  @override
  String get s49b7311a1e => 'Aihe, johon laite kertoo tilansa.';

  @override
  String get s579969e7e4 => 'Komentoaihe (kytkimelle)';

  @override
  String get s137db4076a => 'Aihe, johon päälle/pois-komento lähetetään.';

  @override
  String get s4c95226869 => 'Päälle-viesti';

  @override
  String get s70f2ea8532 => 'Pois-viesti';

  @override
  String get sdc234849ac => 'JSON-kenttä';

  @override
  String get sd3f60d4a71 =>
      'Jos viesti on JSONia, esim. {\"temperature\": 21}, kirjoita temperature.';

  @override
  String get s6cee917658 => 'Yksikkö (mittarille)';

  @override
  String get s3cd541d271 => 'Muu wifi-laite (HTTP)';

  @override
  String get s69885630aa =>
      'Laite, jolla on web-rajapinta. Näyttää yhden arvon, lisää muut ruudut myöhemmin.';

  @override
  String get s200320e245 => 'Tilan osoite (polku)';

  @override
  String get sc5872d2e30 =>
      'Mistä osoitteesta laite kertoo tilansa. Katso laitteen ohjeesta. Tyhjä = ei ruutua nyt.';

  @override
  String get s5564de12b2 => 'Näytettävä kenttä';

  @override
  String get s377942beb7 =>
      'Vastauksen kentän nimi, esim. temperature tai data.temp.';

  @override
  String get sbaf1a279c2 => 'Komento ja vastaus (ntfy)';

  @override
  String get se0fb2c7eea =>
      'Lähetä komento ntfy-viestinä (esim. \"päivitä\" + PIN) ja näe kotilaitteen vastaus samassa ruudussa. Sama kanava kuin iPhonen pikakomennossa.';

  @override
  String get s8231329360 => 'Komentokanavan osoite';

  @override
  String get sd82d127f05 =>
      'Liitä sama osoite, johon pikakomento lähettää komennot (esim. https://ntfy.sh/kv-cmd-…). Pelkkä aiheen nimi riittää myös.';

  @override
  String get s1b3bbae234 =>
      'Täytä vain, jos kotilaite vastaa eri aiheeseen. Tyhjä = vastaus tulee samaan aiheeseen, ja oma komento ohitetaan.';

  @override
  String get s1b08aa4646 =>
      'Teksti, joka näkyy ruudussa, esim. \"Päivitä\" tai \"Tila\".';

  @override
  String get s5bed8bff00 => 'Komento';

  @override
  String get se2a81ae67d =>
      'Lähetettävä teksti. PIN lisätään perään välilyönnillä, esim. \"päivitä 1234\".';

  @override
  String get s1477964f04 => 'Kysy PIN joka painalluksella';

  @override
  String get s62672283f6 =>
      'PIN kysytään piilotettuna eikä sitä tallenneta, ellet valitse \"Muista tällä laitteella\".';

  @override
  String get sb5e914eaf7 =>
      'Vain suojatulle aiheelle (ntfy-tili → Access tokens). Julkiseen aiheeseen jätä tyhjäksi.';

  @override
  String get s1a98a7e424 => 'Lisää myös viestiloki-ruutu';

  @override
  String get s5ab6348524 =>
      'Näyttää aiheen viimeisimmät viestit (esim. kotilaitteen ilmoitukset) omassa ruudussaan.';

  @override
  String get s57e684ac9e => 'Viestit';

  @override
  String get sdc84bf286f =>
      'off=Pois;heat=Lämmitys;cool=Jäähdytys;auto=Auto;heat_cool=Auto;dry=Kuivaus;fan_only=Puhallus';

  @override
  String s3378eb2d0b(String p0) {
    return '$p0 – lämpötila';
  }

  @override
  String get saa437260b8 => 'Lähetetty tila (IR on yksisuuntainen)';

  @override
  String get sfffb54daf4 => 'Tila';

  @override
  String get seab2c72485 => 'Puhallin (0 = auto)';

  @override
  String s3a38b97f7b(String p0) {
    return '$p0 – huone';
  }
}
