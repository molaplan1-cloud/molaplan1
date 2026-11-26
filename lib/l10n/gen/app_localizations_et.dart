// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppLocalizationsEt extends AppLocalizations {
  AppLocalizationsEt([String locale = 'et']) : super(locale);

  @override
  String get sc1e35d5171 => 'Hinnateenus';

  @override
  String get s8b22e8d330 => 'Ilmateenus';

  @override
  String get s252ebed5af => 'Shelly Cloud';

  @override
  String get s10edebf3fa => 'Ntfy server';

  @override
  String get sc08176420f => 'Airthingsi pilv';

  @override
  String get sd3d9c263ed => 'Teenus';

  @override
  String get sdfb639365a => 'Internetiühendus puudub';

  @override
  String s390dd51af3(String p0) {
    return '$p0 on internetis ja seda ei ole võimalik kasutada. Kontrolli seadme internetiühendust. Kui see on saadaval, näidatakse uusimaid andmeid.';
  }

  @override
  String sbb750bf9d6(String p0) {
    return '$p0 ei vasta, proovime varuallikat';
  }

  @override
  String s4284ebac1e(String p0) {
    return '$p0 ei vasta';
  }

  @override
  String get s828d009fa6 =>
      'Ka varukoopia allikad ei vastanud praegu. Probleem on kõige tõenäolisemalt teenustes, mitte sinu koduvõrgus. Proovimine toimub automaatselt.';

  @override
  String get se21c801ba6 =>
      'Teenusel on probleem, kõige tõenäolisemalt teenuses, mitte teie koduvõrgus. Proovitakse automaatselt uuesti.';

  @override
  String get s35e0766add => 'Teenuse sisselogimine nurjus';

  @override
  String sa4d255e53c(String p0) {
    return 'Kontrolli kontot, võtit või märki $p0 jaoks.';
  }

  @override
  String get sd0a2130950 =>
      'Oodatud seade ei vasta sellel aadressil – kontrolli seda (http või https?)';

  @override
  String get sdd5742468b =>
      'Midagi vastab, aga mitte ootuspäraselt. Proovi ette https:// või http:// ja kontrolli porti.';

  @override
  String get s03c0a5192b => 'Aadressi ei leitud';

  @override
  String get sb3ef01a6fa =>
      'Kontrolli õigekirja. Proovi nime asemel IP- aadressi (nt 192. 168. 1. 50).';

  @override
  String get s274a753ad6 => 'Seadet ei leitud sellel aadressil';

  @override
  String get s2b503695b6 =>
      'Kontrollige, kas seade on sisse lülitatud ja kas teie telefon või arvuti on samas WiFi-ühenduses. Kontrollige ka IP- aadressi – see võib muutuda, nii et reserveerige ruuteris kindel aadress.';

  @override
  String get sff9ca463e3 => 'Seade leiti, kuid port on suletud';

  @override
  String get s1d4f4506de =>
      'Kontrollige pordi numbrit ja kas teenus (veebi UI, MQTT või Modbus TCP) on seadmes lubatud.';

  @override
  String get s8523a9cfd0 => 'Turvaline ühendus (https) nurjus';

  @override
  String get sdfd499c1f1 =>
      'Proovige selle asemel http:// või lubage \"Luba ise allkirjastatud sertifikaat\" jaotises Advanced.';

  @override
  String get s3fabccc1cd => 'Sisselogimine, parool või token lükati tagasi';

  @override
  String get sdc2d65f8eb =>
      'Kontrolli parooli. Koduabilisega saad luua uue pikaealise märgi oma profiilis.';

  @override
  String get se0a7cef6c4 => 'Seade vastas, kuid elementi ei leitud';

  @override
  String get see02239a35 =>
      'Kontrollige asukohta või olemi nime (nt light.living_room).';

  @override
  String get sdec83d1e90 => 'Seade teatas veast';

  @override
  String get s3de239ffc5 => 'Kontrollige teed ja lasti.';

  @override
  String get s6121e8d8f1 => 'Tundmatu register seadmes';

  @override
  String get s3474aedf54 =>
      'Kontrollige registrinumbrit. Kui tabel algab 1- st (nt 40001), lahutage 1. Kontrollige ka hoidmist vs sisendit.';

  @override
  String get s2c303f6774 => 'Registritüüp pole toetatud';

  @override
  String get s945685fcda => 'Proovi teist registritüüpi (sisend ↔).';

  @override
  String get s07ffbc349a => 'Seadme poolt tagasi lükatud väärtus';

  @override
  String get s76b95eef9f =>
      'Väärtus on ilmselt väljaspool lubatud piire. Kontrolli ka skaalat.';

  @override
  String get s7746921882 => 'Seade leiti, kuid Modbus TCP on välja lülitatud';

  @override
  String get s7e552bd146 =>
      'Sellel aadressil on olemas seade, kuid see ei aktsepteeri Modbusi selles pordis. Lülita sisse Modbus TCP seadme seadistustes (sageli võrgu / Modbusi / kaugjuhtimise all) ja kontrolli pordi (tavaliselt 502). Samuti võid puudutada nuppu \"Skaneeri Modbus\". Kui seade töötab Home Assistantis, võib sellel juba olla ühendus (paljud lubavad ainult ühe) – loe väärtusi HA kaudu.';

  @override
  String s0ebc613f20(String p0) {
    return 'Seade on lukus, proovib uuesti $p0';
  }

  @override
  String get s317b2b59af =>
      'Seade ei vastanud, nii et see jääb mõneks ajaks üksi – paljud seadmed lukustavad kliente, kes küsitlusi liiga sageli teevad. Paus kasvab 30 sekundilt 5 minutini. Kui seadmel on juba ühendus (nt koduabiline), loe väärtused läbi HA. Lugemisintervall ja pausid on ühenduse all Muud.';

  @override
  String get s33e09089b2 => 'Seadme aadress puudub';

  @override
  String get s6180bd540e =>
      'Avage ühendus ja sisestage seadme IP-aadress või puudutage \"Scan Modbus\", et leida seade võrgus.';

  @override
  String get sd73581c910 => 'Seadmel võib juba olla ühendus';

  @override
  String get scee8d982a2 =>
      'Seade kukutas kohe Modbusi ühenduse. Paljud seadmed lubavad korraga ainult ühte Modbus TCP ühendust. Kui seade on juba Home Assistantis (nt modbus.yaml), loe väärtusi HA kaudu.';

  @override
  String get s6ca672a111 => 'Sellel aadressil pole midagi';

  @override
  String get sf7a98e1c70 =>
      'Sellele IP- aadressile ei vastatud midagi. Kontrolli, kas seade on sisse lülitatud ja samas võrgus ning kas IP on õige (see võib muutuda – reserveerida ruuteris kindla aadressi). \"Skaneeri Modbus\" leiab võrgust seadmeid.';

  @override
  String get scb0cba44ea => 'Modbusi seade ei vastanud õigel ajal';

  @override
  String get sc03ae7e1c5 =>
      'Porti avamine nurjus. Kõige sagedasemad põhjused: vale IP, seade on teises võrgus (külalise Wi-Fi), Modbus TCP on välja lülitatud või tulemüür blokeerib pordi. Kontrolli aadressi ja porti või puuduta \"Scan Modbus\".';

  @override
  String get sefba540275 => 'Värav ei jõua seadmeni selle seadme ID- ga';

  @override
  String get s6e4ed361f3 =>
      'Modbusi värav vastas, kuid selle taga ei ole ühtegi seadet selle ühiku ID- ga. Kontrolli seadme Modbusi aadressi (sageli 1) ning seeriakiirust ja pariteeti. \"Skaneeri Modbus\" proovib aadresse 1– 247.';

  @override
  String get sb66bc0e677 => 'Modbusi vastust ei ole';

  @override
  String get s6ef5539bc2 =>
      'Ühendatud, kuid ei vasta. Kontrolli ühiku ID- d (sageli 1) ja lüüsi jadaseadistusi.';

  @override
  String get s17ea4c52d5 => 'Seadmelt vastust ei ole';

  @override
  String get s50ecf9ba6f =>
      'Ühendatud, kuid ei vasta õigel ajal. Kontrolli teadet.';

  @override
  String get sf93db545a1 => 'Seadistustes on viga';

  @override
  String get sf19a9f0856 =>
      'Kontrollige väljasid, nt et aadress algab http://-ga ja numbrid on numbrid.';

  @override
  String get s3976954bef => 'Sellel plaadil pole seadet';

  @override
  String get sc025e0a1f4 =>
      'Avage redigeerimisrežiim (pliiats) ja valige plaatide seade.';

  @override
  String get s7e11595f9e => 'Kodusild on maas';

  @override
  String get s2cd1df086e =>
      'Kaugjuurdepääs käib läbi koduse silla (tahvel või arvuti). Kontrolli, kas see on sisse lülitatud, Molaplan on avatud ja sellel on internet.';

  @override
  String get sdbf06d05d9 =>
      'Sinu seade ei pääse ligi Molaplani kaugteenusele. Kontrolli mobiilseid andmeid või Wi-Fi- d.';

  @override
  String get s8b737f4026 => 'Kaugjuurdepääs eemaldati';

  @override
  String get s4b9e4ca079 =>
      'See seade eemaldati kodusillalt. Paar uuesti: Seadistused → Kaugjuurdepääs.';

  @override
  String get s5b3116ed94 => 'Kodusild ei vastanud õigel ajal';

  @override
  String get se082095a34 =>
      'Ühendus võib olla aeglane. Proovi hetke pärast uuesti.';

  @override
  String get s688a4f4ccb => 'Kood ei ole kehtiv';

  @override
  String get sfa0e226cd0 =>
      'Kontrolli 6 numbrit sillaekraanil. Kood kehtib 10 minutit ja töötab üks kord – vajadusel vajuta sillal uuesti \"Pane telefon\".';

  @override
  String get sfa5c1fb1ac => 'Sild ei aktsepteerinud seda seadet';

  @override
  String get s9ad07ab36e =>
      'Koodiga sidumisel palub sild kinnitust – vajuta seal \"Nõustuge\". Või skaneerige QR-kood, siis pole kinnitust vaja.';

  @override
  String get sb5c271ae6a => 'Turvakontroll nurjus';

  @override
  String get s3d7ca280db =>
      'Ühendust ei olnud võimalik kontrollida turvalisena, mistõttu seda ei kasutatud. Proovi uuesti QR- koodiga.';

  @override
  String get s0061b44673 => 'Sild ei vastanud';

  @override
  String get sceb894b9b3 =>
      'Aktsepteerige seade silla ekraanil 3 minuti jooksul või skaneerige QR-kood.';

  @override
  String get s700b0ef4de => 'Ühendus ei töötanud';

  @override
  String get s53a891e670 =>
      'Kontrolli aadressi ja seadeid ning proovi uuesti. Tehnilised üksikasjad näitavad täpset põhjust.';

  @override
  String get s02480e4c13 => 'Mõõtmised';

  @override
  String get sd1c778324e => 'Kontrollid';

  @override
  String get s88ac47e6d1 => 'Kaamerad';

  @override
  String get sdd5e97b1e2 => 'Selge';

  @override
  String get sad990c999d => 'Vahelduv pilvisus';

  @override
  String get s80bfe8f9ad => 'Pilves';

  @override
  String get s46f3db8514 => 'Udu';

  @override
  String get sbd81101eb4 => 'Uduvihm';

  @override
  String get s960a265544 => 'Vihm';

  @override
  String get seab38c2b45 => 'Lumesadu';

  @override
  String get sfc65eafa12 => 'Äike';

  @override
  String get sc27533ae83 => 'Säästlik';

  @override
  String get sdbcb85509b =>
      'Temperatuur võib kõikuda kõige rohkem (+1 / −2 °C). Suurim sääst.';

  @override
  String get s380b20be36 => 'Tasakaalus';

  @override
  String get s66ea783264 => 'Väike kõikumine (+1 / −1 °C). Hea vaikevalik.';

  @override
  String get see96226e44 => 'Mugavus';

  @override
  String get sb403e00b3d =>
      'Peaaegu ühtlane temperatuur (+0,5 / −0,5 °C). Säästab veidi.';

  @override
  String get sd86b823895 => 'Sonoff';

  @override
  String get s5f297ec9d8 =>
      'BASIC, MINI, POW, TH, 4CH... DIY režiimis koos Tasmota või ESPHome\' iga. Kaardid on loodud sinu eest; kaugkasutamine kodusilla kaudu.';

  @override
  String get s60e829b1b0 =>
      'eWeLink app → device → Seadistused näitavad IP- aadressi või ruuteri seadmete nimekirja. DIY režiimis on vaja ka Seadme ID- d (10 märki).';

  @override
  String get s6a46e8954d =>
      'Sonoff DIY režiimis vastab ainult siis, kui talle öeldakse selle seadme ID. Leia see rakendusest eWeLink: seade → Seadistused → Seadme ID. Tasmota: veebi parool, kui see on määratud.';

  @override
  String get sea057f1a02 =>
      'Ainult DIY-režiimis, kui otsing seadet ei leidnud.';

  @override
  String s08d04d58a9(String p0) {
    return 'Kanal $p0';
  }

  @override
  String get s8653f173b6 => 'Õhutemperatuur';

  @override
  String get s9cb8820285 => 'Niiskus';

  @override
  String get s4899323b9a => 'Võimsus';

  @override
  String get se78754330c => 'võimsus';

  @override
  String get se317f59de2 => 'VUOTO!';

  @override
  String get se4c4201882 => 'Lekk!';

  @override
  String get sdbcf5515c1 => 'Auki';

  @override
  String get sb0af7213b5 => 'Avage';

  @override
  String get sa3477dac6e => 'Liikettä';

  @override
  String get s280df88585 => 'Liikumine';

  @override
  String get s064a959911 => 'SAVUA!';

  @override
  String get s50778e2eec => 'Suitsu!';

  @override
  String get s1dfa5abe81 => 'Hälytys';

  @override
  String get s50c459fbff => 'Häire';

  @override
  String get s1a4eab1f51 => '°C';

  @override
  String get s9e731440d8 => '%';

  @override
  String get s77c638e731 => '%';

  @override
  String get s96abb7f975 => '';

  @override
  String get s91e5760e43 => '';

  @override
  String get s2f76c2abd3 => '';

  @override
  String get sc2b99541c7 => 'Lülitid ja releed';

  @override
  String get sd85dbd8e5e => 'Valgustid ja hämardid';

  @override
  String get s38935a3c66 => 'Kardinad ja rulood';

  @override
  String get s64c6ca7840 => 'Energiaarvestid';

  @override
  String get s662fecdc8d => 'Andurid';

  @override
  String get s027fcbe1b6 => 'Lülita';

  @override
  String get sa376ec78ec => 'Valgusti';

  @override
  String get s6814e463b1 => 'Katkesta';

  @override
  String get s477d8b2c95 => 'Koguvõimsus';

  @override
  String sdaa374b331(String p0) {
    return 'Faas $p0';
  }

  @override
  String get s32c88e5aa6 => 'Valgustase';

  @override
  String get sbb26f2192c => 'Aku';

  @override
  String get s57b4effa42 => 'Uks / aken';

  @override
  String get s66350d8e7a => 'Liikumine';

  @override
  String get s29045a726e => 'Veeleke';

  @override
  String get s57c2113aee => 'Suits';

  @override
  String get se8422f063f => 'Sens';

  @override
  String get s609cb4c5f9 => 'sees';

  @override
  String get s356d822497 => 'väljas';

  @override
  String get s0b2f7d7c80 => 'avatud';

  @override
  String get s7009587b85 => 'suletud';

  @override
  String get s3b35de231e => 'liikumise';

  @override
  String get s3dfa789b85 => 'ALARM';

  @override
  String get sd9b6de0a6a => 'Teised';

  @override
  String se7520a3990(String p0) {
    return 'uinumine – viimati $p0';
  }

  @override
  String get s3aaacf80d2 => 'võrguühenduseta';

  @override
  String get see129fb410 => 'heledus';

  @override
  String get s5d888c1384 => 'true=Open;false=Closed';

  @override
  String get sd74ad36c31 => 'true=Motion;false=No motion';

  @override
  String get sfa12d7fdd7 => 'true=LEAK!;false=Dry';

  @override
  String get s1f18c0f400 => 'true=SMOKE!;false=OK';

  @override
  String get s0bf7cb1613 => 'Philips Hue';

  @override
  String get se17d4e4197 =>
      'Hue sild ja selle tuled (ka Zigbee tuled paaris). Paari sillanupuga.';

  @override
  String get sf83a145406 =>
      'Hue rakenduses: Seadistused → Hue Bridges → (i) → IP- aadress. Või ruuteri seadmete loendis: \"Philips-hue\".';

  @override
  String get s80ee7a25a9 =>
      'Klõpsa kohe Hue silla peal asuvale suurele ümmargusele nupule. Oota siin – see ühendub iseenesest.';

  @override
  String get s4dbb677293 => 'kättesaamatu';

  @override
  String get sf50732e8e8 => 'hämardada';

  @override
  String get s68e711123b => 'temperatuur';

  @override
  String get s4082a34467 => 'sensor';

  @override
  String s3832b8c729(String p0) {
    return 'kogu tuba';
  }

  @override
  String get sceabe202da => 'camera_';

  @override
  String get s1a73b397a1 => 'sonoff';

  @override
  String get sb8a029d8b4 => 'Hikvision';

  @override
  String get s2e87289ebd => 'tapo';

  @override
  String get s834e3e8c5d => 'Apple';

  @override
  String get s11d8d321df => 'Apple';

  @override
  String get sceefb34afd => 'Apple';

  @override
  String get s24a447c14c => 'Apple';

  @override
  String get s14418a4f88 => 'Apple';

  @override
  String get saab3e952a6 => 'Apple';

  @override
  String get s7fbbfbf469 => 'Apple';

  @override
  String get s045b27e316 => 'Samsung';

  @override
  String get s2c0aede81e => 'Samsung';

  @override
  String get s7bd2005e15 => 'Google';

  @override
  String get sdcec96b503 => 'Google';

  @override
  String get s49960d413e => 'Google';

  @override
  String get s99e5776a78 => 'Google';

  @override
  String get sea3c963b09 => 'Sonos';

  @override
  String get s1e7b1fc81c => 'Synology';

  @override
  String get s7dc8f4cf35 => 'Sünoloogia';

  @override
  String get s161d78d79c => 'QNAP';

  @override
  String get s2512122220 => 'Vend';

  @override
  String get s127258a6f4 => 'Epson';

  @override
  String get s4e31401b4f => 'Canon';

  @override
  String get s933e21c819 => 'HP';

  @override
  String get sb309051c1f => 'HP';

  @override
  String get s6f339c5c37 => 'HP';

  @override
  String get s5f8734f6e4 => 'HP';

  @override
  String get sceb247a904 => 'Xiaomi';

  @override
  String get s10b7b68d6c => 'Huawei';

  @override
  String get s3692c1d592 => 'LG';

  @override
  String get se7d945b970 => 'LG';

  @override
  String get s5a5044b5df => 'Sony';

  @override
  String get sd92d7da7d5 => 'Sony';

  @override
  String get saa909391c3 => 'Philips';

  @override
  String get se39b8c84ab => 'Raspberry Pi';

  @override
  String get sec8808f414 => 'AVM';

  @override
  String get s0e225fb918 => 'See ei ole võimalik';

  @override
  String get sb34f35dce5 => 'ASUS';

  @override
  String get s7ea140809c => 'Netgear';

  @override
  String get s284be225b7 => 'Ubiquiti';

  @override
  String get sfbaeb6a17e => 'Ubiquiti';

  @override
  String get sa24e9ce91d => 'MikroTik';

  @override
  String get sa1b725d397 => 'Espressif';

  @override
  String get sdf96423738 => 'Amazon';

  @override
  String get sf253859589 => 'Amazon';

  @override
  String get sec4d80656d => 'Roku';

  @override
  String get s286e1cfb54 => 'Kokku';

  @override
  String sb9964cfb3b(String p0) {
    return 'Võimsus $p0';
  }

  @override
  String get s4233362d60 => 'Veelekke andur';

  @override
  String get sfcb44be1a0 => 'Shelly';

  @override
  String get sa6ff717527 =>
      'Releed ja pistikud: Pro 4PM, Plus 1PM, Plug S, 2.5... Leiti automaatselt, plaadid igale kanalile.';

  @override
  String get sd7e123cd2f =>
      'Shelly rakenduses: open the device → gear (settings) → Device information → IP- aadress. Või ruuteri seadmete nimekirjas: nimi algab sõnaga \"shelly...\".';

  @override
  String get s9ad7b0076b => 'lekkeandur · aku';

  @override
  String get s815bfa19dc => 'Kontakteri juhtseadis';

  @override
  String get sb9209fee74 => 'Lisa ainult siis, kui relee on kasutusel';

  @override
  String get s5f2b2ca5f5 => 'praegu sees';

  @override
  String get s67f64cd925 => 'praegu väljas';

  @override
  String get s8b35cc884f => 'Mõõtmine';

  @override
  String get sd8dfb25d31 => 'Shelly Cloud (sillata)';

  @override
  String get s350215338a =>
      'Juhtige Shellyt kõikjalt läbi Shelly pilve. Selleks on vaja ainult Shelly rakenduse võtit.';

  @override
  String get s64037991c2 =>
      'Shelly rakendus → sinu profiil → Kasutaja seaded → Autoriseerimispilve võti → Hangi võti. Kopeeri ja aseta siia.';

  @override
  String get s062b21969d =>
      'Näidatakse samal lehel võtme all (\"Server URI\").';

  @override
  String get sf30bb5d5e6 =>
      'Tavaliselt ei ole vaja. Kui midagi ei leita: Shelly app → device → settings → Device information → Device ID. Eralda mitu komadega.';

  @override
  String get s25399cd337 => 'Server';

  @override
  String get s246c7a46ff =>
      'Shelly app → Kasutaja seaded → Autoriseerimispilve võti → Server URI.';

  @override
  String get s61a2d946a4 => 'Pilvevõti';

  @override
  String get s9d468f5c64 =>
      'Shelly app → Kasutaja seaded → Autoriseerimispilve võti → Hangi võti.';

  @override
  String get sf34c97592f => 'IKEA Dirigera';

  @override
  String get sb38eac6a87 =>
      'IKEA nutisõlm ja selle tuled ja pistikud (Zigbee) Paari rummuga.';

  @override
  String get s4e92ab791e =>
      'IKEA Home nutirakenduses: Seadistused → Hub → IP- aadress. Või ruuteri seadmete loendis: \"gw2-...\" või \"dirigera\".';

  @override
  String get s73824fc3d0 =>
      'Vajuta kord Dirigera rummu allosas asuvat tegevusnuppu. Oota siin.';

  @override
  String get sda8d9bf1cd => 'Pistikupesa';

  @override
  String get s0185672be7 =>
      'Kaamera kasutaja (tavaliselt admin) ja selle aktiveerimisel määratud parool.';

  @override
  String get s814f4633e3 =>
      'Kasutaja administraator. Imou: parool on \"Ohutuskood\" kaamera sildil või seadme parool.';

  @override
  String get s4450807111 =>
      'Kaamera kasutaja Reolink rakenduses (tavaliselt admin) ja selle parool.';

  @override
  String get s1095c54819 =>
      'Reolink app → camera → Settings → Network → Advanced → Serveri seaded: lülita sisse HTTP ja RTSP. Akukaamerad (Argus) ei ole toetatud.';

  @override
  String get sc79a5fee2b =>
      'Tapo rakendus → camera → Muud seadistused → Kaamerakonto. Loo sinna kasutaja ja parool ning kirjuta need siia (mitte oma Tapo pilve sisselogimine).';

  @override
  String get s174e06b97c =>
      'Esmalt looge kaamera konto: Tapo app → camera → Advanced settings → Camera konto.';

  @override
  String get s21da6fb5dc =>
      'Kasutaja admin; parool on 6-täheline kontrollkood kaamera sildil.';

  @override
  String get s1866ef6dc8 =>
      'Ezviz app → camera → Settings → LAN Live View / RTSP: lülita see sisse (kui see on olemas).';

  @override
  String get s70625d8bbe =>
      'Kasutaja ja parool, mis on määratud kaamerale rakenduses eWeLink (RTSP/ONVIF). Kahe objektiiviga mudelil pärinevad mõlemad objektiivid samast seadmest.';

  @override
  String get s1a3c354399 =>
      'eWeLink app → camera → Seaded: lülitage RTSP/ONVIF sisse ja määrake sellele kasutaja ja parool (kui see on olemas).';

  @override
  String get s1c2786e15f =>
      'Kaamera kasutaja ja parool (sageli admin). Kaamera seadistustes võib olla vajalik sisse lülitada ONVIF.';

  @override
  String get s32270de47a => 'Turvakaamera';

  @override
  String get s652458eb87 =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz, Sonoff või ükskõik milline ONVIF/RTSP kaamera. Pilt kaardil, live video kodus.';

  @override
  String get se8ea97c5eb =>
      'Kaamera rakenduses (seadme info) või ruuteri seadmete loendis.';

  @override
  String get s1577068729 => 'kaamera';

  @override
  String get seeb6c38c8e => 'Kaamera';

  @override
  String s83d937ae6b(String p0, String p1) {
    return 'Stream $p0/$p1 (oma objektiiv või kanal)';
  }

  @override
  String get s136c6f0d2b => 'Pilt kaardil, live video kodus';

  @override
  String get s2101774157 => 'Video kodus (ilma pildita)';

  @override
  String sd63d34bfe9(String p0) {
    return 'YAML- i lugemine nurjus: $p0';
  }

  @override
  String sc5c9e5e2fc(String p0) {
    return '\"$p0\" kasutab jadaporti (USB/RS485) – vajate RS485 → TCP väravat.';
  }

  @override
  String get s77bf3b424f => '0=Off;1=On';

  @override
  String get s4cbe24240f => 'Sees';

  @override
  String get s33831dd49f => 'Väljas';

  @override
  String s69135546c8(String p0) {
    return '$p0 - sihtmärk';
  }

  @override
  String sd88c13e972(String p0) {
    return '\"$p0\" jäeti vahele - lisage need käsitsi.';
  }

  @override
  String get sceebf690e3 =>
      'YAML-is ei leitud Modbus TCP-jaoturit (modbus: ... tüüp: tcp, host: ...).';

  @override
  String get sb662db81d8 =>
      'Aadress näib olevat ebatäielik. Kasuta nelja numbrit koos punktidega, nt 192.168.1. 50.';

  @override
  String s738ecfe2bc(String p0) {
    return ' Kas sa mõtlesid $p0?';
  }

  @override
  String s06e738bf27(String p0) {
    return 'See ei ole koduvõrgu aadress (need algavad tavaliselt 192.168.). $p0';
  }

  @override
  String sbae99909c4(String p0) {
    return 'Märkus: see seade on sisse lülitatud $p0.x - seade võib olla teisel Wi-Fi-l.';
  }

  @override
  String get s5b44cbe9c0 => 'Kodu';

  @override
  String get s5a40f12b6a => 'Lisa';

  @override
  String get s58aaa6dade => 'Vaade on lukus';

  @override
  String get sdf1af3409c => 'Vabastage';

  @override
  String get s4629a1695c => 'Menüü';

  @override
  String get s41c3cebc48 => 'Lisa seade';

  @override
  String get scd04aa5d9e => 'Muuda vaadet';

  @override
  String get se9ca7cb470 => 'Automatiseerimine';

  @override
  String get sf98121cd3d => 'Toafoto';

  @override
  String get s49de879696 => 'Energia';

  @override
  String get s1da81fd6c3 => 'Seaded';

  @override
  String get s365492a7d0 => 'Lukusta vaade';

  @override
  String get sb2f38410ee =>
      'Seadmeid saab veel juhtida, kuid redigeerimis-, seadistus- ja lisamisseadmed on peidetud. Käigu ikoonilt ava lukustus.';

  @override
  String get se497d27174 => 'PIN-kood (valikuline)';

  @override
  String get sd21180a166 => 'Ilma PIN-koodita avaneb üks kraan.';

  @override
  String get s809d0eb368 => 'Tühista';

  @override
  String get sd86ff8e28a => 'Lukusta';

  @override
  String get s872f93a062 => 'Avage uks?';

  @override
  String get s0cd88e27f4 =>
      'Seadistused ja redigeerimine muutuvad taas nähtavaks.';

  @override
  String get sa5283191be => 'Vabastage';

  @override
  String get sdfc012fb4e => 'PIN-kood';

  @override
  String get sca710b76b5 => 'Vale PIN-kood';

  @override
  String sa0c07ccd04(String p0) {
    return 'Teil on kõige uuem versioon ($p0).';
  }

  @override
  String get sa118d84538 =>
      'Uuenduste kontrollimine pole praegu võimalik. Kontrolli internetiühendust ja proovi hiljem uuesti.';

  @override
  String s9f2b092d8c(String p0) {
    return 'Versioon $p0 on saadaval';
  }

  @override
  String sa5133b2c4a(String p0) {
    return 'Sul on versioon $p0.';
  }

  @override
  String get se099b5797e => 'Mis on uus:';

  @override
  String get s9315c3df42 => 'Jäta see versioon vahele';

  @override
  String get sdd5c8f0a9d => 'Hiljem';

  @override
  String get sfbf490ec3f => 'Uuenda';

  @override
  String get s5a94ef2af1 => 'Allalaadimine oli rikutud';

  @override
  String get s81e4325573 => 'Allalaadimine nurjus';

  @override
  String get s4b1d3df588 =>
      'Faili kontrollsumma ei sobinud, nii et midagi ei paigaldatud. Palun proovi hetke pärast uuesti.';

  @override
  String get s0c463c7069 =>
      'Kontrolli internetiühendust ja proovi uuesti. Uuenduse võib alla laadida ka väljalaskeleheküljelt.';

  @override
  String get s5dd4c9671f => 'Avamislehekülg';

  @override
  String get s49ddc3c3b6 => 'Allalaaditud uuendamine';

  @override
  String s04a05bb8fc(String p0) {
    return 'Faili kontrollitakse ja salvestatakse:\n$p0\n\nEt seda kasutada:\n1. Sulge Molaplan.\n2. Tõmmake zip üle vana Molaplani kausta (või uude kausta).\n3. Käivita molaplan.exe. Seadistused säilitatakse.';
  }

  @override
  String get s1dd246ec69 => 'Vabasta leht';

  @override
  String get s0f07b20d45 => 'Ava zip';

  @override
  String get s6e1ebc8baa => 'Ava kataloog';

  @override
  String get sa065e7f650 => 'Värskenduste paigaldamise lubamine';

  @override
  String get sdc3bf71baf =>
      'Android küsib luba, et Molaplan saaks oma värskendused installida.\n\n1. Puudutus \"Avatud seaded\".\n2. Lülita sisse \"Luba sellest allikast\".\n3. Tule tagasi ja puuduta uuesti \"Uuenda\".';

  @override
  String get sa1bd8d2533 => 'Ava seaded';

  @override
  String get s441683b7a8 => 'Kontrollin...';

  @override
  String get se83b7fb2ac => 'Uuenduse allalaadimine...';

  @override
  String s0b68f81d82(String p0) {
    return 'Molaplan $p0 on saadaval. Sild töötab edasi.';
  }

  @override
  String get sb06bee9921 => 'Näita';

  @override
  String get sf1b5d0ffa6 => 'Parool ei sobi. Kirjuta oma konto parool.';

  @override
  String sd0219ce512(String p0) {
    return 'Ühendus ei töötanud: $p0';
  }

  @override
  String get sbf59e43c36 =>
      'Internetiühendus puudub. Kontrolli Wi-Fi või mobiilseid andmeid ja proovi uuesti.';

  @override
  String get s9ba7e7a8e6 =>
      'Vale e- kiri või parool. Kontrolli neid või klõpsa nupule \"Unusta parool\".';

  @override
  String get se899b438b5 =>
      'E- kiri ei ole veel kinnitatud. Otsi koodi oma e- kirjast.';

  @override
  String get s3fb651ebf3 =>
      'Sellel kirjal on juba konto. Selle asemel logi sisse.';

  @override
  String get s1eddf46047 => 'Parool peab olema vähemalt 8 tähemärki.';

  @override
  String get sca19a10c02 => 'See ei näe välja nagu e-posti aadress.';

  @override
  String get s736463f0d2 =>
      'Kood on vale või aegunud. Kontrolli seda või küsi uut.';

  @override
  String get s4800010fa4 =>
      'Liiga palju katseid, oota üks hetk ja proovi uuesti.';

  @override
  String get sf1a6e42ab0 =>
      'Teie sisselogimine aegus, palun kirjutage uuesti sisse.';

  @override
  String get sf597621fdd =>
      'Teine seade muutis samal ajal seadistust. Proovi uuesti.';

  @override
  String get se16eef219e =>
      'Kontoteenus ei vastanud korralikult. Proovige varsti uuesti.';

  @override
  String get s2ab0ff38c1 => 'Teie konto on juba seadistatud';

  @override
  String get s3ce644ca86 => 'Salvesta seadme seadistus oma kontole?';

  @override
  String get s43d6286f35 =>
      'Sellel seadmel on ka oma seadmed ja plaadid. Mida me peaksime tegema?';

  @override
  String get sd8a380a86d =>
      'Seejärel ilmuvad samad kodud, seadmed ja plaadid igale sellele kontole sisse logitud seadmele.';

  @override
  String get sec25d10ff5 => 'Tühistage ja logige sisse';

  @override
  String get sb7a13da58b => 'Konto seadistuse kasutamine';

  @override
  String get sf498dceefb => 'Mõlema kombineerimine (soovitatav)';

  @override
  String get s9542718c6f => 'Salvesta kontole';

  @override
  String get sa711c4833e => 'Kirjuta oma e-posti aadress.';

  @override
  String get s933dc9caef => 'Vähemalt 8 tähemärki.';

  @override
  String get sb3cec3f199 => 'Molaplani konto';

  @override
  String get sb24f053a48 => 'E-post';

  @override
  String get s976a9f2980 => 'Parool';

  @override
  String get sc0f9642fb2 => 'Näita parooli';

  @override
  String get s4d212254bc => 'E- posti kood';

  @override
  String get s3b86a618be =>
      'Kood saabub mõne minuti pärast. Kontrolli ka rämpsposti kausta.';

  @override
  String get sb35c5ba0fc =>
      'Kontoga on sinu kodud, seadmed ja plaadid kõigis seadmetes – arvutis, tahvelarvutis ja telefonis – ühesugused. Koduühendus liigub uude seadmesse ilma QR-koodita.\n\nKonto on vabatahtlik: ilma ühe Molaplanita töötab nagu varem ja seadistus jääb sellesse seadmesse.';

  @override
  String get se697487621 => 'Logi sisse';

  @override
  String get sec4d25a98e => 'Mul ei ole kontot - loo üks';

  @override
  String get s860d0269e0 => 'Logige sisse koodiga, mis saadetakse e-posti teel';

  @override
  String get s755639049e => 'Unustasin parooli';

  @override
  String get s4a1671a2cc => 'Molaplani konto loomine';

  @override
  String get s75c960f1e5 => 'Vali parool (8+ märki)';

  @override
  String get sea446a95e5 =>
      'Parool kaitseb ka sinu seadme paroole ja pilvevõtmeid: need krüptitakse enne salvestamist selles seadmes. Hoidke seda turvaliselt.';

  @override
  String get s4508b6c2e0 => 'Loo konto';

  @override
  String s0ca1377846(String p0) {
    return 'Saatsime koodi aadressile $p0. Kirjuta see allpool.';
  }

  @override
  String get s07e981c940 => 'Mul on juba konto olemas – logi sisse';

  @override
  String get s2e793f899b => 'E- posti kinnitamine';

  @override
  String get s87b6699e12 => 'Kinnita';

  @override
  String get s824a7408ab => 'Saati uus kood.';

  @override
  String get s317ad443fb => 'Kood puudub – saada uus';

  @override
  String get scf7e14661c => 'Tagasi';

  @override
  String get s7d43ee2d5a => 'Konto või sisselogimise loomine';

  @override
  String get s22c960ff4f => 'Sisselogimine koodiga';

  @override
  String get scb167ce8b1 =>
      'Kirjuta oma kiri ja me saadame sulle koodi. Paroolisuper bullshit reconciliation. Kui sul pole veel kontot, luuakse see ja selle seadme seadistused liiguvad sinna sisse.';

  @override
  String get s7d29d1dfbd =>
      'Me saadame sulle koodi, sisselogimiseks pole vaja parooli.';

  @override
  String get sc350da6f19 => 'Saada kood';

  @override
  String s23cda12342(String p0) {
    return 'Kood saadetakse aadressile $p0.';
  }

  @override
  String get s14d85b9e32 => 'Logi sisse';

  @override
  String get saa1e3d1f13 => 'Saada uus kood';

  @override
  String get se1be2ec8e5 => 'Sisselogimine parooliga';

  @override
  String get s8c48f847f6 => 'Parool lähtestatakse';

  @override
  String get safd591d9b6 =>
      'Me saadame teile koodi, seejärel valite uue parooli.';

  @override
  String get s6807ac704e => 'Uus parool (8+ märki)';

  @override
  String get sa9b5a0b2df => 'Parooli muutmine ja sisselogimine';

  @override
  String get se10ce6962a => 'Sünkroonin…';

  @override
  String get s94d5ea139c => 'Ajakohastatud kõigis oma seadmetes';

  @override
  String get sc6f1932436 =>
      'Offline - muudatused sünkroonis, kui tagasi võrgus';

  @override
  String get s16ab688a9b => 'Sünkroniseerimine nurjus - proovitakse uuesti';

  @override
  String get s97d4aa9c1a => 'Pole veel sünkroniseeritud';

  @override
  String get s40ea946050 => 'Sisse logitud';

  @override
  String get s456721b668 => 'Sünkrooni kohe';

  @override
  String get sa9df24980f =>
      'Seadme paroolid ja pilveklahvid on lukustatud. Kirjuta oma konto parool, et avada need selles seadmes.';

  @override
  String get sd1723cc065 => 'Konto parool';

  @override
  String get s9e9a059c2f => 'Vabastage';

  @override
  String get s8b2b8fdc77 => 'Ma unustasin selle - alustage paroolide üle';

  @override
  String get s5ec8009dfd =>
      'Salvestatud kontole: kodud, seadmed, plaadid ja nende järjekord ning koduühendus. Seadme paroolid, pilveklahvid ja koduühenduse võtmed krüptitakse selles seadmes enne üleslaadimist sinu konto parooliga – server ei saa neid lugeda.';

  @override
  String get s2ea6f9de12 => 'Muuda parooli';

  @override
  String get s7ebd89c416 => 'Kirjutage alla?';

  @override
  String get s6c6165d662 =>
      'Kodud ja plaadid jäävad sellesse seadmesse, kuid muudatused ei jõua enam teie teistesse seadmetesse.';

  @override
  String get s643325053b => 'Logi välja';

  @override
  String get sfd6f965e64 => 'Kustuta konto';

  @override
  String get s37bf90cffe =>
      'Kustutab jäädavalt konto ja kõik serverisse salvestatud. See seade säilitab oma seadistused.';

  @override
  String get sc523d0f28e => 'Kustuta konto';

  @override
  String get s84fda3e17f => 'Tühista';

  @override
  String get s162a85c6ef => 'Salvesta';

  @override
  String get s02c3403918 => 'Vali uus parool.';

  @override
  String get s04ab058029 => 'Parool on muutunud.';

  @override
  String get s7c23534562 => 'Paroolide käivitamine';

  @override
  String get s5ea3703a0a =>
      'Salvestatud seadme paroolid ja pilveklahvid lähevad kaotsi ning need tuleb uuesti sisestada. Kodud ja plaadid jäävad alles. Sisselogimise parool muutub uueks.';

  @override
  String get s321912ef77 => 'Kas kustutada konto jäädavalt?';

  @override
  String s3b0ea9bbc7(String p0) {
    return 'Konto $p0 ja kõik serveris salvestatud kustutatakse. Seda ei saa tagasi võtta.\n\nSee seade töötab ilma kontota.';
  }

  @override
  String get s139d2075b8 => 'Konto kustutatud.';

  @override
  String get sfb4df77773 => 'Anna nupule nimi.';

  @override
  String get s986eb41068 =>
      'Pronto kasutamine: lisa dump: pronto kaugvastuvõtjale.';

  @override
  String s0d353281af(String p0) {
    return 'Nupp \"$p0\" lisatud.';
  }

  @override
  String get s8e4e78e067 => 'Õpeta pult';

  @override
  String get s2acab0eccd => 'Valmis';

  @override
  String get s608a56ad4b =>
      'Salvestab Molaplanile kaugnupud, nt \"Turbo\". Lõhkeaine vajab infrapunavastuvõtjat.';

  @override
  String get sa1aed8855e => 'IR-i pult';

  @override
  String get sded7fb8520 => 'RF433 pult';

  @override
  String get sc8e312a953 =>
      'RF433 = raadio kaugjuhtimispuldid (pesad, varikatused, garaažiuksed, ventilaatorid). IR = infrapunane (soojuspumbad, telerid).';

  @override
  String get s63c57060b6 => 'Puuduta \"Alusta kuulamist\".';

  @override
  String get s439f6f3869 =>
      'Suuna pult lõhkaja juurde (alla 1 m) ja vajuta nuppu üks kord.';

  @override
  String get sd8667596c3 => 'Nimetage see ja koputage \"Salvesta kui nupp\".';

  @override
  String get sd5f1a45865 =>
      'IR on ühesuunaline: soojuspump ei kinnita seda. Molaplan näitab ainult seda, mida ta saatis. Õppimine töötab koduvõrgus.';

  @override
  String get s628dc92a8d => 'Kuulamine... vajuta puldi nuppu';

  @override
  String get s1313eb829d => 'Alusta kuulamist';

  @override
  String get s619fdf8b5c => 'Kood vastu võetud';

  @override
  String get s6264a40ec6 => 'Nupu nimi';

  @override
  String get sc630994fba => 'Näidatud kui plaadi tiitel.';

  @override
  String get s09feac6b28 =>
      'ESPHome ei saa võtta uusi koode üle võrgu. Lisa see seadmesse YAML, paigalda see ja salvesta nupp:';

  @override
  String get sd6f41faa1d => 'Kopeeri';

  @override
  String get s0a7c7a151a => 'Salvesta nupuna';

  @override
  String get s29adc71f1c =>
      'CN105 pistik siselaual. ESPHome: esfome-mitsubishiheatpump.';

  @override
  String get s1d17c9fc6e =>
      'S21 (enamik seinaplokke) või X50A. Faikin pistikud otse sisse; ESPHome: esphome-daikin-s21.';

  @override
  String get s07767f6a03 =>
      'CN-CNT-pistik (kus läheb Panasonicu WLAN-i adapter). ESPHome: esfome- panasonic-ac.';

  @override
  String get s659b742754 =>
      'Toshiba siseteenindusport. ESPHome: esphome- toshiba_ac.';

  @override
  String get s7c3bf9542b => 'Kirjuta seadme IP.';

  @override
  String sdfa6aedae8(String p0, String p1) {
    return '\"$p0\" lisatud.';
  }

  @override
  String get sbd2f94e7a4 => 'Soojuspump (teenindussadam/ESPHome)';

  @override
  String get s49b479c566 =>
      'Parim viis: väike ESP32 siseseadme teeninduspordis. Erinevalt IR-ist on see kahesuunaline – reaalne olek ja toatemperatuur.';

  @override
  String get sc95a59f7c6 =>
      'Ohutus: soojuspump lülitatakse vooluvõrgust välja enne siseseadme avamist. See võib mõjutada garantiid.';

  @override
  String get s7b7121b71e => 'Sadam kaubamärgi järgi';

  @override
  String get s67c1a8a6a3 => 'Sammud';

  @override
  String get s2f9c5f3130 => 'Hankige ESP32 kontroller ja kaabel.';

  @override
  String get s2675e49423 =>
      'Flash ESPHome vastavalt projekti juhendile. Kaasa \"web_ server:\" – Molaplan kasutab seda.';

  @override
  String get scd70d27319 => 'Ühenda see väljalülitatud vooluga.';

  @override
  String get s56b0cb63ea =>
      'Kirjutage selle IP allpool ja puudutage \"Leia soojuspumbad\".';

  @override
  String get sdd1cd7bdd5 => 'ESPHome kontrolleri IP';

  @override
  String get sa1e21d236a =>
      'Ruuteri seadmete loendist või ESPHome armatuurlauast.';

  @override
  String get s1bef32afe0 => 'Soojuspumpade leidmine';

  @override
  String get s9aa9bc9679 => 'Seade vastas, kuid sellel ei ole kliimaüksust.';

  @override
  String get sec88246e24 => 'Vali toafoto';

  @override
  String get s252b8e1289 => 'Millise toa foto?';

  @override
  String get sa27e5362de =>
      'Vali sisseehitatud toa pilt või oma foto. Seda näidatakse päisena või kogu vaate taga.';

  @override
  String get s84ef77e1ca => 'Vali oma pilt';

  @override
  String get sf55eee73b8 => 'Muuda pilti';

  @override
  String get sf6723451b9 => 'Pildista';

  @override
  String get s0bec34cd24 => 'Päisepilt';

  @override
  String get s7b1e22fca7 => 'Kogu vaate taust';

  @override
  String get s229e29f9ee => 'Tumendus';

  @override
  String get s38285117e6 => 'Hägusus';

  @override
  String get sdd957ccc1b => 'Eemalda pilt';

  @override
  String s6c487e340b(String p0) {
    return 'Kõige rohkem $p0 pilte. Eemalda üks enne.';
  }

  @override
  String get sceafe9ce2a => 'Fail ei ole pilt';

  @override
  String get s3a5c21004e => 'Võrguühenduseta';

  @override
  String get sbc7a87e591 => 'Hindade hankimine nurjus – uuesti proovimine';

  @override
  String get s3f0837ec84 => 'Ilm ei õnnestunud - uuesti proovimine';

  @override
  String get s68cbe596f8 => 'Sisselogimine aegus';

  @override
  String get s599357f47b => 'Internetti pole';

  @override
  String get s74fa2d56aa => 'Modbus on väljas';

  @override
  String get s156aa7eeb3 => 'Seade ei vasta';

  @override
  String get sbf2cfbb102 => 'Vale üksuse ID?';

  @override
  String get s9be06479ff => 'Lukustus';

  @override
  String get s613938b0b3 => 'Aadressi pole';

  @override
  String get s252d8628c7 => 'Hõivatud (HA?)';

  @override
  String get s0e3a6bafbf => 'Teenistus ei vasta';

  @override
  String get s7abcbf1107 => 'Serverit ei leitud';

  @override
  String get sca533b6f25 => 'Kodusild ei vasta';

  @override
  String get s96ad0dc252 => 'Väärtust seadmes ei leitud';

  @override
  String get s61cdd7287b => 'Seade puudub';

  @override
  String get s57d0940253 => 'Turvaviga';

  @override
  String get sfec025279e => 'Seade ei ole võrgus';

  @override
  String get sa7d212f047 => 'Kodu Wi-Fi seadmed töötavad endiselt.';

  @override
  String get s24ccd151f2 => 'Proovi uuesti';

  @override
  String get sc26c52235c =>
      'Sa oled ära ja kodusild ei vasta. Koduvõrgu seadmeid ei saa praegu juhtida.';

  @override
  String get s0fc1c9f296 =>
      'Koduvõrgu seadmed töötavad eemalt ainult läbi kodusilla.';

  @override
  String get se50ed56454 => 'Kaugjuurdepääs';

  @override
  String get sc5f54cf3c8 => 'Täida võti ja server.';

  @override
  String get sb26dad8f73 => 'Selle võtmega ei ole pilves ühtegi seadet.';

  @override
  String s2c6ce95ec2(String p0) {
    return '$p0 töötab nüüd läbi Shelly Cloudi.';
  }

  @override
  String s5629901cc4(String p0) {
    return 'Kontroll $p0 kodust eemal';
  }

  @override
  String get s064abc90af =>
      'Seade lülitatakse Shelly Cloudile. Kõik selle kanalid, nimed ja kaardid jäävad alles. Võti: Shelly rakendus → sinu profiil → Kasutaja seaded → Autoriseerimispilve võti.';

  @override
  String get sf16961256b => 'Server (Server URI)';

  @override
  String s28e10c6870(String p0) {
    return 'Milline neist on $p0?';
  }

  @override
  String get s09f5da65e0 => 'Lülita Shelly Cloudile';

  @override
  String get sa846059775 => 'Home Assistant juba loeb seda seadet';

  @override
  String get s18a1844439 =>
      'Seadmel võib juba olla ühendus (nt Home Assistant) – lugeda väärtusi HA kaudu. Paljud seadmed lubavad ainult ühte Modbus TCP ühendust.';

  @override
  String sa29df4fc6b(String p0) {
    return '$p0 Koduabis leiduvad Modbusi väärtused. Paljud seadmed lubavad ainult ühte Modbusi TCP ühendust, seega on kõige ohutum lugeda läbi HA.';
  }

  @override
  String get sb8c40d2c20 => 'Kasutamine koduabilise kaudu';

  @override
  String get s810014ca02 => 'Koduabilise modbus.yamli import';

  @override
  String get sfbf34ee532 =>
      'Aseta modbus. yaml (või modbus: osa konfiguratsioonist. yaml). Ühendus ja kaardid kasutavad samu registreid ja ajastust.';

  @override
  String s2d4fbaade1(String p0, String p1) {
    return '$p0 ühendus(ed), $p1 kaardid';
  }

  @override
  String get s580678cb10 => 'Impordi';

  @override
  String get s108e078c0c => 'Koduabilisest imporditud Modbusi seade';

  @override
  String get sa3a093e55e => 'Kütab';

  @override
  String get s8efb99df1d => 'Jahutab';

  @override
  String get s0b98d62330 => 'Küte ja jahutus';

  @override
  String get sa61efb9866 => 'kütab';

  @override
  String get s9a47ee3e3c => 'jahutab';

  @override
  String get s156712ac0c => 'ootel';

  @override
  String get s8a1f52a37b => 'Termostaat eemaldatud';

  @override
  String get s28dc9bc46a => 'Temperatuurinäit puudub';

  @override
  String get s4f1166fe24 =>
      'Kodusild puudub: termostaat ei kontrolli veel. Seadke kaugjuurdepääs kodutahvlile.';

  @override
  String get s29fd8d5b5e => 'Praegu';

  @override
  String get see9111ba68 => 'Relee või lüliti (sees/väljas)';

  @override
  String get seaed91ad78 => 'Soojuspump või konditsioneer (seadeväärtus)';

  @override
  String get sb757921c13 => 'Kütab';

  @override
  String get s7407864734 => 'Jahutab';

  @override
  String get s272aa3f1da => 'Mõlemad';

  @override
  String get sdadb6e3501 => 'Varuküttekeha';

  @override
  String get se4e381334d =>
      'Alustatakse ainult siis, kui see on selgelt allpool eesmärki.';

  @override
  String get s17c79c5f4e => 'Sisse/väljalülitatud (valikuline)';

  @override
  String get s92d88612de => 'Soojusrežiimi nupp (ei ole kohustuslik)';

  @override
  String get s75ac845bab => 'Jahutusrežiimi nupp (ei ole kohustuslik)';

  @override
  String get se12fc46923 => 'Puudub';

  @override
  String get sc590a09db9 => 'Mis kütab või jahutab?';

  @override
  String get sa15ffe53d4 =>
      'Valige üks või mitu, nt soojuspump ja varukütteseade.';

  @override
  String get sd47a7615a7 => 'Sobivaid seadmeid veel pole';

  @override
  String get s3c7649a7f0 =>
      'Esmalt lisa relee (nt Shelly) või soojuspump (IR või teenindusport), seejärel tule tagasi.';

  @override
  String get see513572ea => 'Kust temperatuuri loetakse?';

  @override
  String get s5155522e83 =>
      'Vali termomeeter. Mitu = varuvariant või keskmine.';

  @override
  String get s581fa290f3 =>
      'Valikuline: soojuspump mõõdab ise. Vali temperatuuri nägemiseks andur.';

  @override
  String get s7e4d8d60a0 => 'Termomeetrit pole';

  @override
  String get s0787d80876 => 'Kõigepealt lisage seade, mis näitab temperatuuri.';

  @override
  String get s89661203b7 => 'Esimene töötav';

  @override
  String get s0da3005956 => 'Keskmine';

  @override
  String get s0c6a008ffd => 'Nimi ja režiim';

  @override
  String get sb1924acbe7 => 'Nimi';

  @override
  String get s1790a71e85 => 'nt Elutuba';

  @override
  String get sd5f46903a1 => 'Sihttemperatuur';

  @override
  String get s6de95e582f => 'Kui temperatuur kaob';

  @override
  String get s8ff25225b4 => 'Lülita küte/jahutus välja (kõige ohutum)';

  @override
  String get s17cb86f49e => 'Jäta nagu on';

  @override
  String get sf4caddf894 => 'Täpsem';

  @override
  String get s9624f070ee => 'Hüsterees';

  @override
  String get sf070be2c1e => 'Surnud tsoon (küte/jahutus)';

  @override
  String get s64540136ff => 'Minimaalne sees-aeg';

  @override
  String get s21713a2177 => 'Minimaalne väljas-aeg';

  @override
  String get s8f7c8eb7d0 => 'Varukütteseade, kui see on allpool sihtmärki';

  @override
  String get sf1eb3b2d34 => 'Sensor kadus pärast lugemist';

  @override
  String get s0ab1430151 => 'Uus termostaat';

  @override
  String get sbbc98d573d => 'Muuda termostaati';

  @override
  String get s6c3e76828b => 'Edasi';

  @override
  String get s187d328bb1 => 'Muuda';

  @override
  String get sc1845eb440 => 'Kustuta';

  @override
  String get s87984716cb => 'Kustutada termostaat?';

  @override
  String get s79786b9f7d => 'Siht';

  @override
  String get sdd309c0a63 => 'Termostaat töötab kodusillal';

  @override
  String get s2a7e9fe291 =>
      'Võrguühenduse loomine kodutahvlil (Seaded → Kaugjuurdepääs). Kuni selle ajani ei kontrolli see midagi.';

  @override
  String get s06cda8c0de => 'Töötab selles seadmes (kodusild).';

  @override
  String get s2342536aea => 'Töötab kodusillal.';

  @override
  String get s798f7b2876 => 'Nutikas küte';

  @override
  String get s2c5993c1fd =>
      'Soojeneb enne kallist elektrit ja külma ilma ning laseb kallitel tundidel temperatuuri veidi langeda.';

  @override
  String get s81c4abc1a5 => 'Ülekuumutus +';

  @override
  String get sdea18b2b40 => 'Alakuumutus −';

  @override
  String get s523214c8db =>
      'Rida = sihttemperatuur, baarid = elektrihind, kriipsutatud = välistemperatuur.';

  @override
  String get s94b8f63aa7 => 'Kodu asukoha lisamine ilmale';

  @override
  String get s941fbb47fe => 'Plaani arvutatakse…';

  @override
  String get s702ca14235 => 'Tasmota seade';

  @override
  String get se0e5f715ad => 'ESPHome seade';

  @override
  String get s63b6e55469 => 'HomeKiti seade';

  @override
  String get s13e301a66e => 'Tundmatu seade';

  @override
  String get sddb2c2cb2b => 'Telefon';

  @override
  String get s16cd267576 => 'Tahvelarvuti';

  @override
  String get sec4679ec39 => 'Arvuti';

  @override
  String get s798f9a0558 => 'Printer';

  @override
  String get s06109b8e5c => 'Teler / meediamängija';

  @override
  String get sc4655d321e => 'Kõlar';

  @override
  String get sa9f2f85b3e => 'Ruuter';

  @override
  String get sf8360dcd74 => 'Võrgusalvesti';

  @override
  String get s8e21b6f258 => 'Nutiseade';

  @override
  String get sb38b582dab => 'Kodusild';

  @override
  String get sdf66171e91 => 'See seade';

  @override
  String get s76a76a654e => 'iPhone\'i kuumkoht';

  @override
  String get s15d4ca1672 => 'Telefoni kuumkoht';

  @override
  String get sd54522fe39 => 'Ruuter / kuumkoht';

  @override
  String get s23f4820db7 => 'ei ole veel kontrollitav';

  @override
  String get sdeeabebed9 => 'Airthings: lisa pilve või Bluetoothi kaudu';

  @override
  String get saae59a3865 => 'kodusilla kaudu';

  @override
  String get sdccd6e7f24 => 'Mudel';

  @override
  String get s891a4b434e => ')\'}';

  @override
  String get s43aba09687 => 'Sadamad';

  @override
  String get scee3511db6 => 'Allikad';

  @override
  String get sbc46a05125 => 'Nimeta seade';

  @override
  String get s1d5ed84aed => 'Jäetakse selles seadmes meelde.';

  @override
  String get s59622d792b => 'Nimeta ümber';

  @override
  String get s1169d2d093 => 'Leia seadmed';

  @override
  String get s55b85f29a6 => 'Koduvõrgu otsimine...';

  @override
  String get se9c923ff0b =>
      'Molaplan otsib seadmeid, mida ta tunneb teie koduvõrgus.';

  @override
  String get s3ff2220816 =>
      'Teadaolevaid seadmeid ei leitud. Vali allpool kaubamärk.';

  @override
  String s2a9142dc3e(String p0) {
    return 'Leiti $p0. Lisatav kaart.';
  }

  @override
  String get s2fc39b0bd7 => 'Otsi uuesti';

  @override
  String get s0a9acb5af1 => 'Otsi';

  @override
  String get se3ef5a5658 => 'Skanni Modbus';

  @override
  String get s9a018b8166 => 'Sa oled ära: kodusild otsis läbi sinu koduvõrgu.';

  @override
  String sf16a25c313(String p0) {
    return 'Muud seadmed võrgus ($p0)';
  }

  @override
  String get s9e8430c37b => 'See tähendab, et see ei ole Mistahes ammunition.';

  @override
  String s095ca83913(String p0) {
    return '$p0 kaardid lisatud';
  }

  @override
  String get sd53b0c4edc => 'Õhuelementide monitorid';

  @override
  String sc401e05b53(String p0) {
    return 'Lisa $p0 kaardid';
  }

  @override
  String get s212e35a61b => 'Seadmete nimekiri nurjus';

  @override
  String get s039683f4a5 =>
      'Sinu kontol ei ole monitore. Lisa üks kõigepealt rakenduse Airthings.';

  @override
  String get sdfff64e4c3 => 'Hubi kaudu';

  @override
  String get s7f308d40c8 => 'Kütab';

  @override
  String get s41de361b3e => 'Jahutab';

  @override
  String get s4f7ccb7138 => 'Kuivatab';

  @override
  String get s9b2398228e => 'Ventilaator';

  @override
  String get s533177c689 => 'Ootel';

  @override
  String get sa3e8beed42 => 'Küte';

  @override
  String get s6c9668fbd9 => 'Jahutus';

  @override
  String get sd032c3efec => 'Auto';

  @override
  String get s9db8aefc43 => 'Kuivatus';

  @override
  String get s0117dea8bc => 'Ventilaator';

  @override
  String get s11a7c24b38 => 'Näit puudub';

  @override
  String get s28b7c227f0 => 'seade';

  @override
  String get s81e0c3084b =>
      'Valgusti olekut ei saanud lugeda – juhtimine võib siiski toimida.';

  @override
  String get s7400a53ab2 => 'Värv';

  @override
  String get s09aec1d642 => 'Valge';

  @override
  String get s16ff3849c9 => 'Värvitemperatuur';

  @override
  String get sf117c88d83 => 'Soe';

  @override
  String get secb1232aad => 'Jahutus';

  @override
  String get sb2fa876c32 => 'Heledus';

  @override
  String get s34cc93ca61 => 'Lemmikud';

  @override
  String get sdc485831ad => 'Eemaldamiseks vajuta pikalt';

  @override
  String get s3c98732a8c => 'Näidik';

  @override
  String get s6f29aeb685 => 'Trend';

  @override
  String get s3298699c1a => 'Näidik + trend';

  @override
  String get sed593f53ed => 'Väärtus';

  @override
  String get s9027c88cb7 => 'Andmete kogumine...';

  @override
  String get sf05d2a09f1 => '7 d';

  @override
  String get se38a9bb2ed => 'Viimane';

  @override
  String get s049d71f971 => 'viimase';

  @override
  String get s3ec9d77947 => 'tmrw';

  @override
  String get sed9b5e52f6 => 'praegu';

  @override
  String get s1b85ad9e38 =>
      'Otsib seadmeid, mille Modbus TCP on sees (pordid 502, 503 ja 5020) ning proovib ühiku ID- d. See võtab aega umbes pool minutit.';

  @override
  String get seb1f4357ea => 'Oma sadam (vabatahtlik)';

  @override
  String get s06760a6970 => 'Skaneeri uuesti';

  @override
  String get s23d146db23 => 'Skaneeri';

  @override
  String get s18e7ad553e => 'Skaneerin...';

  @override
  String get s721647a6cd => 'Sa oled ära: kodusild skaneeritud.';

  @override
  String get s08e57d2d85 => 'Skaneerimine nurjus';

  @override
  String get s4cf60b9350 =>
      'Modbusi seadmeid ei leitud. Kontrolli, kas Modbus TCP on seadme seadistustes sisse lülitatud ja kas see on samas võrgus (mitte külaliste Wi-Fi).';

  @override
  String get sbd8ee8a14f => 'Modbusi seade';

  @override
  String get sf0462b25ac => 'väravate';

  @override
  String s28d9c4c7dc(String p0) {
    return '$p0 eelseadistus';
  }

  @override
  String get sc6cde0d476 => 'leiti oma teadaandest';

  @override
  String get s166da70285 => 'Seade ei aktsepteeri ühendust';

  @override
  String get sbe97262d91 =>
      'Seadmel võib juba olla ühendus (nt Home Assistant) – lugeda väärtusi HA kaudu. Paljud seadmed lubavad ainult ühte Modbus TCP ühendust.';

  @override
  String get s24e5139123 => 'Port avatud, Modbusi vastust ei ole';

  @override
  String get s9041c140be =>
      'Kontrolli ühiku ID ja Modbusi seadistusi. Selle aadressi kasutamiseks klõpsa nupule.';

  @override
  String get s55d52c5ae1 => 'See seade ei ole Wi-Fi-s';

  @override
  String s9a4dece965(String p0) {
    return 'Ühenda see seade oma kodu Wi-Fi- ga (see, mida $p0 kasutab). Või kui oled eemal, seadista kodusild nii, et otsing käiks koduses seadmes.';
  }

  @override
  String get s3972820cd6 => 'Seadmeni jõudmine nurjus';

  @override
  String s0f480abb4a(String p0) {
    return 'Seadme jõudmine asukohta $p0 nurjus';
  }

  @override
  String sa82143ee02(String p0, String p1) {
    return '1. Kontrolli, kas $p0 on sisse lülitatud.\n2. See seade (või kodusild) peab olema samal Wi-Fi-l.\n3. Kontrolli aadressi – see võib muutuda. Kliki \"Tagasi\" ja otsi uuesti.';
  }

  @override
  String get sd4d7ad1bab => 'Vastas teine seade';

  @override
  String s5b7d02a301(String p0) {
    return 'Seade sellel aadressil ei ole $p0. Kontrolli aadressi.';
  }

  @override
  String get sdac5622fa8 => 'Seade küsib parooli';

  @override
  String get sbf9ee8aaec =>
      'Seadmele on määratud parool. Kirjuta see alla ja klõpsa nupule \"Ühenda\".';

  @override
  String get s9e22388413 => 'Vaja on veel üht detaili';

  @override
  String sc8702d4da2(String p0) {
    return '$p0 ei ütle seda ise. Kirjuta see alla ja puuduta \"Ühenda\".';
  }

  @override
  String get s83f57c7c24 => 'Vale parool';

  @override
  String get s32e85a0ba2 =>
      'Kontrolli parooli (juhtumiküsimused). Seda saab muuta seadme rakenduses.';

  @override
  String get sb1d36bfdd3 => 'Nuppu ei vajutatud õigel ajal';

  @override
  String get sc994f6ec6e =>
      'Puudutage \"Proovige uuesti\" ja seejärel vajutage nuppu kohe.';

  @override
  String get s663202243e => 'Midagi, mida kontrollida, ei leitud';

  @override
  String get sb03997d94b =>
      'Seade vastas, kuid sellel ei ole lüliteid ega tulesid. Pilve jaoks kirjuta seadme ID.';

  @override
  String get se6e01118ac => 'Kaamera leiti, kuid mitte selle video aadress';

  @override
  String get sca994210fb =>
      'Kaamera vastas, kuid ei öelnud oma videoaadressi ning ükski tavaline RTSP aadress ei töötanud selle sisselogimisega. Kontrolli, kas RTSP/ONVIF on kaamerarakenduses sisse lülitatud, või vali allpool olev kaubamärk ja puuduta \"Ühenda\".';

  @override
  String get s869571042f => 'Pilvevõti või server ei ole aktsepteeritud';

  @override
  String get sab1763c592 =>
      'Kopeeri võti ja server uuesti Shelly rakendusest (Kasutaja seaded → Autoriseerimispilve võti).';

  @override
  String get s855ffbfd24 => 'Pilveni jõudmine nurjus';

  @override
  String get s739d569a9c => 'Kontrolli internetiühendust.';

  @override
  String get sc96a3502b5 => 'Liiga palju taotlusi';

  @override
  String get sed917dc2a2 => 'Pilvepiirangud nõuavad, oota korraks.';

  @override
  String get s516dbdd784 => 'Kodusild on aegunud';

  @override
  String get s70089507bf =>
      'Uuenda Molaplan sillal (Seaded → Kontrolli värskendusi).';

  @override
  String get scc1918f2dc =>
      'Kontrollige, kas sild kodus on sisse lülitatud, Molaplan on avatud ja sellel on internet.';

  @override
  String get se11f9b5084 => 'Seadmega ei õnnestunud ühendust luua';

  @override
  String get s979376dca6 =>
      'Kontrolli aadressi ja seda, kas seade on sisse lülitatud, ning proovi uuesti. Tehnilised üksikasjad näitavad täpset põhjust.';

  @override
  String get sce6d01c270 => 'Kirjuta aadress esimesena';

  @override
  String get s65bbf3cab4 => 'Kontrolli aadressi';

  @override
  String sb711cc1ce2(String p0, String p1) {
    return '$p0 ei ole koduvõrgu aadress. Tavaliselt algavad need 192. 168- ga – kontrolli seda uuesti rakenduses $p1.';
  }

  @override
  String se60794c266(String p0) {
    return 'Kas sa mõtlesid $p0?';
  }

  @override
  String get s264fda2dee => 'Ma teen selle korda';

  @override
  String get s0a6098ac78 => 'Proovige';

  @override
  String sc1039f5cf6(String p0) {
    return 'Kasuta $p0';
  }

  @override
  String get s20f777bfef => 'Aadress on teises võrgus';

  @override
  String sbb1730fa00(String p0, String p1, String p2, String p3) {
    return 'Aadress $p0 ei ole selle seadmega samas võrgus ($p1. x). Tavaliselt on see seade erineval Wi-Fi- l kui $p2.\n\nLiituge sama Wi-Fi-ga või seadistage kodu sild.';
  }

  @override
  String get s43370d968c => 'Täitke esimesena';

  @override
  String get s915c9a0db3 => 'Vali vähemalt üks';

  @override
  String sb160156a36(String p0) {
    return 'Lisa: $p0';
  }

  @override
  String get s43d448a950 => 'Lisa kodu vaatesse';

  @override
  String get sd890121a57 => 'Koduvaate näitamine';

  @override
  String get sb1717cc67c => 'A. Ilma kodusillata';

  @override
  String get s2082568a23 => 'Shelly Cloudi kasutamine (sillata)';

  @override
  String get s5080d486b8 =>
      'Parim, kui ükski seade ei jää alati koju – nt tahvelarvuti liigub koos sinuga. Juhtimine käib Shelly enda pilve kaudu. Sul on vaja Shelly rakenduse võtit (me näitame, kus).';

  @override
  String get s82985d5078 => 'B. Läbi kodusilla';

  @override
  String get s78aec2034d =>
      'Kuidas sa kontrollid oma kodu, kui oled kodust eemal?';

  @override
  String s03b3c3b3c8(String p0) {
    return 'Kodusild on seade, mis ALATI jääb koju, on sisse ja sisse lülitatud samasse Wi-Fisse nagu $p0 – nt vana telefon, tahvelarvuti või arvuti. Teie muud seadmed jõuavad selleni interneti kaudu (krüptitud, porti ei edastata). Seade, mida te kannate, ei ole hea sild.';
  }

  @override
  String get s688d1308d7 =>
      'Kui olete sisse logitud, jõuab koduühendus automaatselt kõigisse teie seadmetesse.';

  @override
  String get s96feb2f60a => 'See seade jääb alati koju - tee sellest sild';

  @override
  String get sb2a33a1ec4 =>
      'Hoidke selle laadimine Molaplaniga lahti. Teised seadmed ühenduvad QR-koodiga või logivad sisse samale kontole.';

  @override
  String get s1b9f4ae6d5 => 'Sild on teisel seadmel - ühendage see sellega';

  @override
  String get s13d739b710 =>
      'Silla QR- koodi skaneerimine. Seadmed leitakse siis läbi silla isegi siis, kui oled eemal.';

  @override
  String get sda6a1e50e9 =>
      'Jäta kohe vahele – lisa koduvõrku (kaugjuurdepääsu saab seadistada hiljem)';

  @override
  String s6f326a48f9(String p0) {
    return 'Leidmine: $p0';
  }

  @override
  String get sc788897ba0 =>
      'Otsides läbi kodu silla, töötab see ka kodust eemal.';

  @override
  String get s0f7361f40c => 'Vaatan sinu kodu Wi-Fi-d.';

  @override
  String get sda2b4c9721 => 'Ava Wi-Fi seadistused';

  @override
  String get sc93d9cc14b => 'Ühendatud - otsi uuesti';

  @override
  String get s13f0596b74 => 'Otsimine... (umbes 5 sekundit)';

  @override
  String s8eabd27f68(String p0, String p1) {
    return 'Automaatselt ei leitud midagi. Kontrolli, kas $p0 on samal Wi-Fi- l. Allpool saab kirjutada ka aadressi.';
  }

  @override
  String get sa616ab181e => 'Kirjuta aadress';

  @override
  String get sb439b8abc3 => 'Või sisestage aadress';

  @override
  String get s178e07f06b => 'IP-aadress';

  @override
  String get scf487a3699 => 'Kust ma selle leian?';

  @override
  String get s9b9b0d01a2 => ' (valikuline)';

  @override
  String get s0a7134d0e3 => 'Vajuta nüüd nuppu';

  @override
  String s43118959d5(String p0) {
    return '$p0';
  }

  @override
  String get sba10f23f03 => 'Ühendan…';

  @override
  String get s46c87a553f => 'Registreeru kaamerasse';

  @override
  String get se4095d7d95 => 'Seadme parool';

  @override
  String get sdbdf676485 => 'Ühenda';

  @override
  String get s200542b930 => 'Proovi uuesti';

  @override
  String get s8f610a3bb2 => 'Ma olen kodust eemal';

  @override
  String get sf77125583f => 'Tehnilised üksikasjad';

  @override
  String get sb629592b4b => 'Kaameramark';

  @override
  String get se3aa0f7164 => 'RTSP aadress';

  @override
  String get s722ac06c6d =>
      'Ilma sisselogimiseta – kasutaja ja parool lisatakse automaatselt.';

  @override
  String s77ec7b376b(String p0) {
    return 'Leitud: $p0';
  }

  @override
  String get sac4debdb9c => 'Valige, mis toimub koduvaates ja nimetage need.';

  @override
  String get sfe5661e401 => 'Tühista valikud';

  @override
  String s2618555da0(String p0) {
    return 'Vali kõik ($p0)';
  }

  @override
  String get s86c3f92546 => 'Lisa ka heledust/võimsust';

  @override
  String get s91571486e4 => 'Näidatakse ka võimsust (W)';

  @override
  String sf86536db42(String p0) {
    return 'Valmis! $p0 kaarti lisatud';
  }

  @override
  String get sbfaea66122 =>
      'Plaadid töötavad kodus ja eemal pilve kaudu - midagi muud ei ole teha.';

  @override
  String get se7c68b3bed =>
      'Plaadid töötavad kodus ja eemal läbi kodusilla - midagi muud ei ole teha.';

  @override
  String get sbc8469cce1 =>
      'Plaadid töötavad sinu koduvõrgus, et juhtida ükskõik kust, pane kodusild valmis.';

  @override
  String get s417eb9a875 => 'Kaugjuurdepääsu seadistamine';

  @override
  String get sc3abd09cd9 => 'Kohandatud värv';

  @override
  String get s10e7cef8c1 => 'Hue';

  @override
  String get s59b65e3322 => 'Küllastus';

  @override
  String get s750ed8d878 => 'Heledus';

  @override
  String get sa39e78050c => 'Vali';

  @override
  String get sd9923cda70 => 'Lülitage kaugjuurdepääs sisse';

  @override
  String get sba1684ff6c => 'veel mitte';

  @override
  String get sef20071510 => 'Käivita ajalugu';

  @override
  String get s9f1334d4e2 => 'Skriptid';

  @override
  String get s6b7c1c52da => 'Stseenid';

  @override
  String get s8613961a5a => 'Teated';

  @override
  String get s4f745952b8 =>
      'Töötab sellel kodusillal, ka siis, kui rakendus on suletud.';

  @override
  String get s99cbed55fd =>
      'Kodusillal töötamine - töötab isegi siis, kui rakendus on suletud.';

  @override
  String get s0247948956 =>
      'Kodusild on vana versioon: uuenda seda, nii et rakenduse sulgemise ajal käivituvad ka automatiseerimised. Praegu töötab see rakendus.';

  @override
  String get s21fae60578 =>
      'Selles rakenduses töötab, kui see on avatud. Kodusild käivitab need, kui rakendus on suletud.';

  @override
  String get s66c54e2286 =>
      'Automatiseerimine on selles seadmes välja lülitatud.';

  @override
  String get s57f6ce1c7f => 'Mis on kodusild?';

  @override
  String get s4057f67774 => 'Mon Tue Wed Thu Fri Sat Sun';

  @override
  String get s456d234874 => '(seade puudub)';

  @override
  String get sf3779b50c6 => 'sees';

  @override
  String get s7c3e905972 => 'At';

  @override
  String get s61637a44e4 => 'Sunrise';

  @override
  String get sa0d5958b56 => 'Sunset';

  @override
  String s467fd3c653(String p0) {
    return '$p0 odavaim tööaeg';
  }

  @override
  String s65660a4b23(String p0) {
    return 'Hind üle $p0 c/kWh';
  }

  @override
  String sba8fa4af37(String p0) {
    return 'Hind alla $p0 c/kWh';
  }

  @override
  String get s3324b26519 => 'Õues';

  @override
  String sf3c2cf0323(String p0, String p1) {
    return '$p0 offline $p1 min';
  }

  @override
  String get s1b359d69e2 => 'Automatiseerimise loomine';

  @override
  String get s835865fd04 => 'Mallid';

  @override
  String s73d042449b(String p0, String p1) {
    return 'Automaatikat veel ei ole. Alustatakse mallist, nt \"$p0\" või \"$p1\".';
  }

  @override
  String get s8039add5ed => 'Pealkirjata';

  @override
  String get s5506524eac => 'Millal';

  @override
  String get sf2d3a43ee8 => 'Jooksu veel pole.';

  @override
  String get s5c7338ab38 => 'Valmis automatiseerimine';

  @override
  String get s354eb362d8 => 'Seadme valimine';

  @override
  String get s73a65d7dff => 'Seadmete valimine';

  @override
  String get s6bc0df13b3 => 'Seadmeid veel pole.';

  @override
  String get s90db0cb9e0 => 'Uus automatiseerimine';

  @override
  String get s3aeb373060 => 'Muuda automatiseerimist';

  @override
  String get sac3c555554 => 'Kustuta automaatika?';

  @override
  String get s53879bce24 => 'Millest algab automatiseerimine';

  @override
  String get s179f389617 => 'Ainult juhul (vabatahtlik)';

  @override
  String get s803ff4f73b => 'Kõik tingimused peavad vastama';

  @override
  String get sd930bdad70 => 'Lisa tingimus';

  @override
  String get s6f21edea24 => 'Tee';

  @override
  String get scbe17b6bf8 => 'Nõuetekohased hagid';

  @override
  String get secee53bdd2 => 'Veel rohkem';

  @override
  String get scb62f41105 => 'Jooksudevaheline minimaalne minutite arv';

  @override
  String get s643b680e89 =>
      'Peatab näiteks lehvitusanduri kümnete teadete saatmise.';

  @override
  String get s4c4ab28899 => 'Testi nüüd';

  @override
  String s7956c29b83(String p0) {
    return 'Jooksus: $p0';
  }

  @override
  String get s6e85ff5983 => '(Ilma seadmeteta)';

  @override
  String get sa627de5699 => '>';

  @override
  String get s24801cdec0 => '<';

  @override
  String get sef6eef049e => '≥';

  @override
  String get s5d759b1fd0 => '≤';

  @override
  String get sc67c2076cc => '=';

  @override
  String get sf69ef2bd3e => '≠';

  @override
  String get sc300fc12e3 => 'Seadme väärtus';

  @override
  String get sbab0e0dc9d => 'Seadme olek (sisse/välja lülitatud, andur)';

  @override
  String get s76de9025a1 => 'Kellaaeg';

  @override
  String get s04c0bcdd51 => 'Päikesetõus / päikeseloojang';

  @override
  String get sca7e088857 => 'Elektri hind';

  @override
  String get s869f0d57af => 'Ilm (välistemperatuur)';

  @override
  String get sa4261f6e35 => 'Seade ei vasta';

  @override
  String get s67584c9abf => 'Seade';

  @override
  String get se0a362c060 => 'Tüüp';

  @override
  String get s38ac222392 => 'Väärtus';

  @override
  String get s4f62fd1f09 => 'Kui see pöördub';

  @override
  String get sab64be3b87 => 'alarmis';

  @override
  String get sbfd08915bd => 'maha / rahulik';

  @override
  String get s0aaa16b331 => 'Aeg (TT:MM)';

  @override
  String get s9b4b2b3129 => 'Sündmus';

  @override
  String get s8c6de5d661 => 'Tasandus minutites (−60...60)';

  @override
  String get s59b3e665bf => 'Millal';

  @override
  String get s6a23c4a83f => 'Hind allpool';

  @override
  String get s49083cabf7 => 'Hinnatõus';

  @override
  String get s411924155f => 'Odavaimad tunnid päevas';

  @override
  String get s04dc35851a => 'Tundide arv';

  @override
  String get s6f22fd8c19 => 'Protokollid';

  @override
  String get s32fa6270c8 => 'Puudub valitud = iga päev';

  @override
  String get s966e223f86 => 'Ajaaken';

  @override
  String get s45aae9c551 => 'Nädalapäevad';

  @override
  String get sf05bf9c751 => 'Seadme olek / väärtus';

  @override
  String get sb74370fc1e => 'Välistemperatuur';

  @override
  String get s585b4c519f => 'Tume/valgus';

  @override
  String get s6019108a01 => 'Seisund';

  @override
  String get s9593939a4c => 'Eemalda';

  @override
  String get sc26d444f90 => 'Alates';

  @override
  String get s796739363a => 'To';

  @override
  String get s39d9f766c6 => 'Võrdle';

  @override
  String get sa56aea2cf9 => 'Olek on sisse/välja lülitatud';

  @override
  String get sc2521b6b15 => 'Number';

  @override
  String get sfffb54daf4 => 'Olek';

  @override
  String get se2b3e45118 => 'tume';

  @override
  String get s709da04ca2 => 'valgus';

  @override
  String get s723d015dc1 => 'Lisage toiming';

  @override
  String get sae3489a6c9 => 'Seadme juhtimine';

  @override
  String get s1f6962ba39 => 'Käivita stseen';

  @override
  String get s02df6d430a => 'Skripti käivitamine';

  @override
  String get sed67c16508 => 'Saatke teade';

  @override
  String get s654489bb29 => 'Oota';

  @override
  String get sf216517af2 => 'Oota';

  @override
  String get sde1657b024 => 'Kui / muidu';

  @override
  String get sbc8e165fbf => 'Action';

  @override
  String get s4cd3d92d4c => 'Sees';

  @override
  String get s750f16460c => 'Sisse/välja';

  @override
  String get s7a544fe304 => 'Määra väärtus';

  @override
  String get s929344a68b => 'Pressi';

  @override
  String get s02cfe06e04 => 'Stseen';

  @override
  String get sdb235c3ced => '(Pole stseene)';

  @override
  String get sdced476aeb => 'Skript';

  @override
  String get s4f330bfcfb => '(Skripte pole)';

  @override
  String get s8a8673aafe => 'Pealkiri';

  @override
  String get s34900f9d58 => 'Tekst';

  @override
  String get s3c2ee8fe0d => '{Kokkuvõte} = ilm, hind ja koduriik';

  @override
  String get sd84d87d156 => 'Prioriteet';

  @override
  String get sb55a08c07c => '1 – vaikiv';

  @override
  String get s423418208e => '2 – madal';

  @override
  String get sbad27a6b89 => '3 – normaalne';

  @override
  String get s8c17000b91 => '4 – kõrge';

  @override
  String get sa0738def3a => '5 – kiireloomuline (ka vaiksetel tundidel)';

  @override
  String get sb33001c92e => 'Kraan avaneb';

  @override
  String get s07d7410408 => 'äpp';

  @override
  String get sfb10dd528e => 'Sekundeid';

  @override
  String get sd7ab969914 => 'Kõige rohkem sekundeid';

  @override
  String get sccfe5a0d41 => 'Siis';

  @override
  String get s2d983e951b => 'Else';

  @override
  String get sf936d0b01d => 'Üles';

  @override
  String get s2c7a2bbac1 => 'Uus käsikiri';

  @override
  String get s5b2dd17cbc =>
      'Skript on sammude loend: juhtige seadet, oodake, teavitage, kui / muidu ... käivitage see nupust, automatiseerimisest või kaugjuhtimisest (iPhone\'i kiirklahv).';

  @override
  String get s6fe2320f3d => 'Lõpeta';

  @override
  String get se9ee46a9c8 => 'Jookse';

  @override
  String get sfd2d047cb2 => 'Täpsem';

  @override
  String s766b50721b(String p0) {
    return '$p0 samme';
  }

  @override
  String get s061d1b874b => 'kaugjuhtimispult';

  @override
  String get sb886978015 => 'Skripti redigeerimine';

  @override
  String get scc2c1e2508 => 'Käivita logi';

  @override
  String get sacf2fbc495 => 'Kustuta skript?';

  @override
  String get s01de653429 => 'Sammud';

  @override
  String get s01d3c353e2 => 'Kood';

  @override
  String get s637ae4dbf4 => 'Molaplani skript';

  @override
  String get sea09cb0d3b =>
      'Funktsioonid: lülita välja lülitamine ootamine teatamine stseeni hind odavaim temp aeg tunnis tööpäeva logi. Faili või võrgu kasutamine puudub; 10 min ajapiirang.';

  @override
  String get s420f3ec828 => 'Väline käivitamine (valikuline)';

  @override
  String get sb3cef805ee =>
      'Skripti nupp töötab ilma selleta: see käivitab rakenduses skripti ja eemalviibimisel automaatselt kaugjuurdepääsu. Seda on vaja ainult skripti käivitamiseks väljastpoolt Molaplanit, nt iPhone\'i kiirklahvid.';

  @override
  String get sb6e92eacba => 'Sisselülitamise lubamine väljastpoolt (PIN)';

  @override
  String get sa1692aa719 =>
      'Teade ntfy aadressile või iPhone\'i otsetee käivitab skripti PIN-koodiga.';

  @override
  String get s0a5410ea4f => 'Kaugjuhitav PIN (vähemalt 4 märki)';

  @override
  String sceba001122(String p0, String p1, String p2, String p3) {
    return 'Saada \"run $p0 <PIN>\" aadressile $p1\niPhone\'i kiirklahvid: \"Get Contents of URL\" → $p1, meetod POST, body: run $p0 <PIN>';
  }

  @override
  String get seff0aac16e => 'Kopeeri URL';

  @override
  String get sff9b69c6ca => 'Valmis';

  @override
  String get sf1ed05f7de => 'Nupp vaateväljas';

  @override
  String sf1541ca978(String p0) {
    return 'Nupp lisatud $p0';
  }

  @override
  String get s09f745552a => 'Salvesta aktiivne olek';

  @override
  String get s44367fdec5 => 'Tühi';

  @override
  String get sc41824585d =>
      'Stseen seab korraga mitu seadet, nt \"Movie Night\" või \"All off\".';

  @override
  String s7e7b0848fb(String p0) {
    return '$p0 tegevused';
  }

  @override
  String get s7cdee3dc7d => 'Millised seadmed sündmuskohal käivad?';

  @override
  String get sde0d544a4c => 'Stseen';

  @override
  String get scff2a13871 => 'Nt filmiõhtu';

  @override
  String get se3ba6a13bb => 'Uus stseen';

  @override
  String get s020a1af0d8 => 'Muuda stseeni';

  @override
  String get s4dbd6f62bf => 'Kustuta stseen?';

  @override
  String get se250251ff0 => 'Vajuta teateid';

  @override
  String get s91a8948ad7 => 'Läbi ntfy (Google\'i kontot pole vaja)';

  @override
  String get sbdd6c9bad2 => 'Näita seda seadet';

  @override
  String get se1e0d398d7 =>
      'Rakendus kuulab töötamise ajal teateid (aknas ka salvest).';

  @override
  String get s6993f32ed2 => 'Automaatika käivitamine selles rakenduses';

  @override
  String get sc0f6ea8ebe =>
      'Kui kodusilla ei ole. Kodusild töötab alati, ka siis, kui rakendus on suletud.';

  @override
  String get sb35519f8e9 => 'Salvi lähedal';

  @override
  String get s49ca9b6082 =>
      'Akna sulgemine hoiab Molaplani kella kõrval, nii et teated saabuvad.';

  @override
  String get sc6d6d4016e => 'Telefon, kui Molaplan on suletud';

  @override
  String get sb460bbf010 =>
      'Paigaldab ntfy rakenduse (Android: Google Play / F- Droid, iPhone: App Store) ja tellib selle teema. Teated saabuvad ka siis, kui Molaplan on suletud.';

  @override
  String get saa54f34e98 => 'Kopeeri tellimise link';

  @override
  String get s8f19ff1e21 => 'Vaiksed tunnid';

  @override
  String get s1cc7f7a75f => 'Ainult kiire (5) tuleb läbi.';

  @override
  String get s973f30f5e8 => '(HH:MM)';

  @override
  String get sb13eeff3cd => '(HH:MM)';

  @override
  String get s2f7a5f57b1 => 'Tumm';

  @override
  String get sa81c1da011 => '1 tund';

  @override
  String get s0ca30924bd => '8 tundi';

  @override
  String get s38bb718aaf => '24 tundi';

  @override
  String s36ef8a86e1(String p0) {
    return 'Muttetu (kuni $p0)';
  }

  @override
  String get s0183ae0a12 => 'Saada testteatis';

  @override
  String get sd95091858f => 'Molaplani teated töötavad';

  @override
  String get s58a8bfdd9f => 'Test saadeti';

  @override
  String get s5c380d76b6 => 'Viimane';

  @override
  String get s9d75942e41 => 'Valmis automatiseerimine';

  @override
  String get s70860413a1 =>
      'Päikeseloojangu tuled, veeleke → alarm, odavad tunnid...';

  @override
  String get s8b5be90c1e => 'Sinu enda automatiseerimine';

  @override
  String get sa9402c105a => 'Millal / Kui / Do';

  @override
  String get s4102c7e085 => 'Stseen praegusest olekust';

  @override
  String get s21ee7e78ee => 'Paljud seadmed ühe nupuga';

  @override
  String get s5afa6e08f2 => 'Sammud järjekorras, ootavad, kui/muu';

  @override
  String get s8070a25da8 => 'Grupp';

  @override
  String get sf5f1ae9c9e => 'Nt kõik elutoa tuled ühe kaardina';

  @override
  String get s73f89f4de7 => 'Millised seadmed grupis käivad?';

  @override
  String get s5b68340d84 => 'Grupi nimi';

  @override
  String s1b087cdbbd(String p0) {
    return 'Kõik: $p0';
  }

  @override
  String get s876c7230a2 => 'Lisa seade';

  @override
  String get s1e593aeca2 => 'Sulge';

  @override
  String get s3d00dee1a9 => 'Kasuta';

  @override
  String get sa252f06bff =>
      'Vali oma seadme kaubamärk, Molaplan leiab selle ja loob plaadid.';

  @override
  String get s5b3b5e5a24 =>
      'Otsingu kaubamärk või seade (nt Shelly, Hue, IKEA)';

  @override
  String get sa427be10c9 => 'Otsi ja ühendu automaatselt';

  @override
  String get s6f4cc0844f => 'Tulemas – kuidas seda täna kasutada';

  @override
  String get s846ee3bc67 => 'Muud seadmed';

  @override
  String get sdeadd78d47 => 'Termostaadi kütmise jahutus';

  @override
  String get s48264cfe32 => 'Termostaat';

  @override
  String get s641a848754 =>
      'Säilitab soovitud temperatuuri: juhib releed või soojuspumpa termomeetrilt. Säästab hetkehindadega.';

  @override
  String get s94493d01ca => 'Ilmaprognoos, temperatuur, vihmatuul';

  @override
  String get s262f9527aa => 'Ilmaennustus';

  @override
  String get scb3570338f =>
      'Ilm praegu ja tunniti: temperatuur, sademed ja tuul sinu kodus. Seadet pole vaja.';

  @override
  String get s2a9b6fedd9 => 'Ei leia oma kaubamärki?';

  @override
  String get scfc7244d06 =>
      'Husqvarna, Zigbee, Tuya, soojuspumbad... vaata, kuidas neid täna kasutada.';

  @override
  String get sf7b77783e5 => 'Muu (käsitsi seadistus)';

  @override
  String get sc168355ee6 => 'Muu seade (täpsem)';

  @override
  String get s3022f72ece => 'Kõik ühenduse tüübid.';

  @override
  String get s2d1d488d6d => 'Tehnilistele kasutajatele.';

  @override
  String get s6f1c11270c => 'Sisaldab näiteseadistusi';

  @override
  String s4f55f417b1(String p0) {
    return 'Seadmel on $p0 releed';
  }

  @override
  String get sab3ebba17a => 'Seadmel on 1 relee';

  @override
  String get sfa48c40832 => 'energiamõõtmine';

  @override
  String get sc8d1abbd21 => 'Kaardi nimi';

  @override
  String get s183ed60009 => 'OK';

  @override
  String s1ea8fe913b(String p0) {
    return 'Aadress: $p0';
  }

  @override
  String get s16dc13070c =>
      'Home Assistant kasutab iseallkirjastatud sertifikaati. See võeti vastu, sest aadress on koduvõrgus.';

  @override
  String get sd531eb2fc2 =>
      'Home Assistanti ei leitud automaatselt. Sisesta aadress, millega selle avad (nt http://192.168.1.20:8123 või Nabu Casa aadress).';

  @override
  String get s7def041e83 => 'Leitud Home Assistantid:';

  @override
  String s2967a37e01(String p0, String p1) {
    return 'Leitud: $p0 – $p1';
  }

  @override
  String get s8f4c0baf1a =>
      'Automaatselt ei leitud ühtegi seadet. Kirjuta aadress ise – leia see ruuterist või seadme rakendusest.';

  @override
  String get s104238f11e => 'Leitud seadmed – vali enda omad:';

  @override
  String get sd5f9dce947 => 'Otsing ei ole selles võrgus saadaval.';

  @override
  String get s26abc57d91 => 'Õpetada puldi nupud?';

  @override
  String get sc709f38633 =>
      'Põhijuhtimine juba toimib. Õpetada võib ka teisi kaugnuppe, näiteks \"Turbo\".';

  @override
  String get s6cac83dd5e => 'Mitte praegu';

  @override
  String get s97ea2eeb11 => 'Õpeta kohe';

  @override
  String get s09cfb7b2a1 => 'Seade lisatud';

  @override
  String sda9574390f(String p0) {
    return 'Lisatud seade ja $p0 plaadid';
  }

  @override
  String get sd51ee1ec8d =>
      'Eelseadistused on näited. Kontrolli neid enne nende kasutamist seadme kasutusjuhendis.';

  @override
  String get s566585dc66 =>
      'IR on ühesuunaline: soojuspump ei kinnita. Molaplan saadab alati kogu oleku ja näitab, mida ta saatis. Õpi teisi kaugnuppe hiljem: ühendused → blaster → \"Õpi kaugjuhtimispult\".';

  @override
  String get s0dd21e026c => 'Juhend ja automaatne otsing';

  @override
  String get s695a011cc1 => 'Otsin…';

  @override
  String get s47d409fddd => 'Otsinguvõrk';

  @override
  String get sa62eebe6bd => 'Releede tuvastamine';

  @override
  String get s7196b72140 =>
      '⁇  Puudub emakeelne Modbus TCP - RS485 → TCP-värav on vajalik.';

  @override
  String get s2e8ba44677 => 'Allikas';

  @override
  String get sceb8e47d07 => 'Testi ühendust';

  @override
  String get s02ce5f4a01 => 'Töötab!';

  @override
  String get sb9e9e55164 => 'Need kaardid luuakse';

  @override
  String get s1cb2891ef2 =>
      'Täitke väljad, mis on tähistatud *-ga, et näha plaate.';

  @override
  String get s504861ee78 =>
      'Valmis plaate pole - saate neid hiljem pliiatsi nupuga lisada.';

  @override
  String get s1094266d4c => 'Näitab väärtust';

  @override
  String get sf6ae3f3323 => 'Lüliti';

  @override
  String get s20dad69675 => 'Nupp';

  @override
  String get s0e9f94df05 => 'Liugur';

  @override
  String get s109b454866 => 'Kaameravaade';

  @override
  String get s37153e0e80 => 'Täpsemad seaded';

  @override
  String get s0ca55a9cae =>
      'Teised seadmed kasutavad tehnilisi seadistusi (HTTP, MQTT, Modbus...). Kui sinu kaubamärk on kirjas, kasuta seda.\n\nLisaseadistuste sisselülitamine? Neid saab seadistustes välja lülitada.';

  @override
  String get s9630135746 => 'Lülita sisse';

  @override
  String get sbcdff8f72a => 'Milline kaamera sul on?';

  @override
  String get s67bf18fb6f => 'Muu kaamera (ONVIF)';

  @override
  String get s772c158a57 => 'tcp';

  @override
  String get sea00017814 => 'madala latentsusega';

  @override
  String get s2d65587b87 => '8';

  @override
  String get s2ad22696ca => 'Keel';

  @override
  String get s7efc5653d2 => 'Seadme keel';

  @override
  String s3e5741712a(String p0) {
    return 'See Shelly on energiamõõtja – asenda lüliti $p0 mõõtekaartidega?';
  }

  @override
  String sfe2074ae81(String p0) {
    return 'Seadmel on $p0 releed - lisage ülejäänud?';
  }

  @override
  String sf1319d04d0(String p0) {
    return 'Lisa $p0';
  }

  @override
  String get s95f80e9bdf => 'Fix';

  @override
  String get s140acccb81 => 'Täna';

  @override
  String get s66ad384363 => '24 h edasi';

  @override
  String get s6df3187e65 => 'Täna ja homme';

  @override
  String get s76379cf7c6 => '48 h';

  @override
  String get s306729fe62 => 'Hindadeta';

  @override
  String get sff03a35d96 => '1 tunni jooksul';

  @override
  String get sf9e22ac5e7 => 'vanad hinnad';

  @override
  String get sa0bd9ad5b1 => 'Näide kaamera - lisage oma seadme lisamine';

  @override
  String get s4529c1010a => 'Kaameraühenduse valimine';

  @override
  String get s98bf81bba3 => 'Live video ei tööta selles seadmes';

  @override
  String get seb2bb5cbce =>
      'Otseülekannet näidatakse ainult koduvõrgus. Kaameral ei ole kaugkasutamiseks ühtegi pilti.';

  @override
  String get sc95fb5440b => 'Stream lõppes';

  @override
  String get sd55dd196f6 =>
      'Otsevideo puudub. Kontrolli, kas oled koduvõrgus ja RTSP on kaameras sees.';

  @override
  String get s8e574c3313 => 'Võimsus';

  @override
  String get sa9360bdda1 => 'Ventilaator';

  @override
  String get sc7d02fbe84 => 'Soojuspump';

  @override
  String get s8d06ee5308 => 'Häire';

  @override
  String get sfb63e3c23f => 'Lukustage';

  @override
  String get s2f42d90475 => 'Vett';

  @override
  String get sf2d10dd213 => 'Elekter/energia';

  @override
  String get s4594c7448e => 'Säästud / odavaim';

  @override
  String get s291ca127d6 => 'Garaaž';

  @override
  String get sb543af1c63 => 'Uks';

  @override
  String get s60b1079d6c => 'Aken';

  @override
  String get s66ce56ca38 => 'Alusta';

  @override
  String get s0ab3a44562 => 'Taimer';

  @override
  String get s3044a10005 => 'Network';

  @override
  String get s1f67139f55 => 'Saun/küte';

  @override
  String get sf21fd72396 => 'Outlet';

  @override
  String get s7783fe5fca => 'Lemmik';

  @override
  String get s912ea5d2ec => 'Saada';

  @override
  String get se223375393 => 'Nimekiri';

  @override
  String get sfb0b971c01 => 'Õõtsumine';

  @override
  String get see42f2d999 => 'Kaug';

  @override
  String get s9126bf24a0 => 'Päike';

  @override
  String get sdaa7d4de12 => 'Stseen';

  @override
  String get s11cc92bdc3 => 'Radon';

  @override
  String get s095db91dfb => 'CO₂';

  @override
  String get s4b1eda4282 => 'Õhukvaliteet';

  @override
  String get sfe55fd97fa => 'Kõik on vaikne.';

  @override
  String s162c54ed4c(String p0) {
    return '$p0: tehtud';
  }

  @override
  String get se26e839c2f => 'Esmaspäev';

  @override
  String get s763254941f => 'Teisipäev';

  @override
  String get sf3448cdd52 => 'Kolmapäev';

  @override
  String get sc34ca7eddb => 'Neljapäev';

  @override
  String get sfa82438bec => 'Reede';

  @override
  String get s517c348371 => 'Laupäev';

  @override
  String get sb1f0e72163 => 'Pühapäev';

  @override
  String get s80c4ecec94 => 'c/h';

  @override
  String get sbfe79d1f5f => 'Uuendatud';

  @override
  String get sb68e905fc4 => 'Tarbimine (kWh)';

  @override
  String get s5fc5085143 => 'Kulu';

  @override
  String get s2b2118a93b => 'Vanad andmed';

  @override
  String get sb730159a01 => 'Hind praegu';

  @override
  String get s68fcfcfed1 => 'Odavaim tund täna';

  @override
  String get s86ff059f5e => 'Keskmine täna';

  @override
  String get s7b911d48c6 => 'Kalleim tund täna';

  @override
  String get s29dbf49d92 => 'Hetkekulu';

  @override
  String get s723c887da6 => 'min';

  @override
  String get s3b36524e04 => 'kesk.';

  @override
  String get scaaff6345d => 'max';

  @override
  String get s5f131c3ec4 => 'Tarbimine';

  @override
  String get s039bb374fe => 'Arvud on tunnikeskmised';

  @override
  String get s62cfd94468 => 'Odavamad tunnid öösel';

  @override
  String get s7995dff292 =>
      'Kõige odavamatel öötundidel (22–07) sobib hästi veesoojenditele ja elektrisõidukite laadimisele.';

  @override
  String get sf92675687a => 'Odavaimad päevatunnid';

  @override
  String get sf71a753c59 => 'Päeva kõige odavamatel tundidel.';

  @override
  String get s6c070f7367 => 'Väljas, kui elekter on kallis';

  @override
  String get s214f034099 => 'See lülitub üle piiri ja tagasi, kui hind langeb.';

  @override
  String get s3939cfc37e => 'Millal elekter on odav';

  @override
  String get scecc366bc4 => 'Ainult siis, kui hind on alla piiri.';

  @override
  String get s6e700ae773 => 'Hinnajuhtimine eemaldatud';

  @override
  String get s5aa3400a7a => 'Hinnajuhtimine salvestatud';

  @override
  String get s2f5410429b =>
      'Reegel töötab sellel seadmel (kodusillal). Hoia see kodus sees.';

  @override
  String sb86a43361f(String p0) {
    return 'Reegel töötab kodusillal - teie telefon võib olla välja lülitatud.';
  }

  @override
  String get s538517b71b =>
      'Kodusild veel puudub. Reegel salvestatakse, kuid töötab ainult siis, kui alati kodus olev tahvelarvuti või arvuti on sild (Seaded → Kaugjuurdepääs).';

  @override
  String s1a9e9bead3(String p0) {
    return 'Hinnakontroll: $p0';
  }

  @override
  String get s6b609c3376 => 'Millal peab see sees olema?';

  @override
  String get s93e5435cf4 => 'Hinnajuhtimine puudub';

  @override
  String get s55e5c3a177 => 'Mitu tundi sees';

  @override
  String get s52ef5e0b45 => 'Hinnapiir';

  @override
  String get s993193d056 => 'Tulevased sees-ajad';

  @override
  String get s2f7c00a89e => 'Hinnad pole praegu saadaval.';

  @override
  String get s15b42b592c => 'Järgmiseks päevaks pole aega.';

  @override
  String get s0de6e75a52 => 'Homme';

  @override
  String sf87d92faf4(String p0, String p1) {
    return 'Hinnapiirkond $p0. Järgmise päeva hetkehinnad koos käibemaksuga $p1 %. Lisage pindala ja tasude muutmiseks seade \"Elektrihind\".';
  }

  @override
  String get s2adc3a77ed => 'Vali ühenduse tüüp';

  @override
  String get s78d94155f1 => 'Ühendused';

  @override
  String get s776d8b06bf => 'Uus ühendus';

  @override
  String get sc6d89693a5 =>
      'Puuduvad ühendused. Lisage seade või teenus, nt ventilatsiooniseade (Modbus), koduabiline või kaamera.';

  @override
  String get s07c82cb0af => 'Nõutav väli';

  @override
  String get sf702cf0ac6 => 'Kustuta ühendus?';

  @override
  String s6b83de0ab9(String p0) {
    return '$p0 plaadid kasutavad seda ühendust ja lõpetavad töötamise.';
  }

  @override
  String get sccd1325381 => 'Ühendus eemaldatakse sellest seadmest.';

  @override
  String get s837e0fc5e6 =>
      'IR on ühesuunaline: soojuspump ei kinnita käske. Plaadid näitavad viimast saadetud olekut.';

  @override
  String get s09737988fd => 'Ühendus töötab!';

  @override
  String get s0a972aa85e =>
      'Paroolid ja märgid salvestatakse seadme turvalises hoiuruumis.';

  @override
  String get sc51b1e0dc0 => 'Mida sa lisada tahad?';

  @override
  String get s38f5b2ef26 =>
      'Shelly, Sonoff, Hue, kaamera, soojuspump... otsib su koduvõrgust automaatselt läbi.';

  @override
  String get s3b56b2cb8d => 'Cardi';

  @override
  String get sfc846c4cc5 =>
      'Elektri hind, ilm, kaamera, gabariit, märguanne või käsk – uut seadet pole vaja.';

  @override
  String get sf00aa23cf6 =>
      'Millal... kui... teha: tuled päikeseloojangul, lekkehoiatus, odavaimad tunnid, skriptid ja stseenid.';

  @override
  String get s147f47be4c => 'Lisa kaart';

  @override
  String get s229f981388 => 'Kodusild';

  @override
  String get sfc2dc8fc36 => 'Sild: ühenduseta';

  @override
  String get sdedbb30a67 => 'Kodus';

  @override
  String get s9d64d4c166 => 'Kaug';

  @override
  String get s1f8cf57b2c => 'Ühendus puudub';

  @override
  String get s678a751265 => 'Ühenda see seade koju';

  @override
  String get sdae0305965 =>
      'Kodusild (tahvel või PC) on juba olemas. Skaneeri selle QR- koodi või kirjuta 6 numbrit.';

  @override
  String get s5f8284b98f => 'Tee sellest seadmest kodusild';

  @override
  String get s6a95f7843b =>
      'See seade jääb koju, alati sisse (laadija + Wi-Fi) ja edastab teie seadmetele kaugkäske.';

  @override
  String get s2c3ae5833b => 'Muud viisid: VPN, Nabu Casa, cloud MQTT';

  @override
  String get s807e3a32f3 =>
      'Step-by-step juhendid, kui te juba kasutate Tailscale, WireGuard, Home Assistant Cloud või cloud MQTT.';

  @override
  String get sa3e78d5c4e => 'Kodusild vastab - kaugjuurdepääs töötab.';

  @override
  String get s0b57661c18 => 'Kontrolli oma kodu igal pool';

  @override
  String get sb43ef4094c =>
      'Kodus suhtleb Molaplan otse sinu seadmetega. Mujal krüptitakse see läbi sinu kodusilla – pordi edasisuunamist ega ruuteri seadistusi ei ole. Rakendus valib automaatselt õige tee.';

  @override
  String get se96e60e36c =>
      'Kodusild on igasugune Molaplan, mis on alati kodus: arvuti, vana tahvelarvuti või telefon või eraldi sildprogramm näiteks Raspberry Pi või koduabilise masinal. Kui oled eemal, lähevad telefoni käsud sellest läbi sinu seadmetesse, otsast otsani krüptitud. Ruuteril pole midagi seadistada (porti ei edastata).';

  @override
  String get s075e5a4864 => 'Ühendatud koduga';

  @override
  String get sa7679488fb =>
      'Kodus = otse. Kaugus = läbi kodusilla. Ühendus puudub = ei vastused.';

  @override
  String get s19cec9667e => 'Kaugjuurdepääsu testimine';

  @override
  String get s86ad95fa48 => 'Kopeeri kodu armatuurlauad';

  @override
  String get sfaa5185b74 => 'Eemaldage kaugjuurdepääs?';

  @override
  String get sbc44ce6993 =>
      'See seade ei saa siis enam väljastpoolt koju jõuda. Paarida võib igal ajal uuesti.';

  @override
  String get s3563cb1635 => 'Eemalda kaugjuurdepääs';

  @override
  String get s528c4f3a4c => 'See seade on kodusild';

  @override
  String get se7b8d659b5 => 'Täpsem';

  @override
  String get sfd263f3e04 => 'Kaamera värskendab kaugjuhtimispuldi korral';

  @override
  String s99249ddf24(String p0) {
    return 'Kaugjuhtimisega näitab kaamera pilti iga $p0 s (salvestab andmed).';
  }

  @override
  String get s451ea613dd => 'Redaktor';

  @override
  String get s72da730a42 => 'Kaugteenus: ühendatud';

  @override
  String get s421f161f5b => 'Ühendamine kaugteenusega...';

  @override
  String get s88e2b1dad5 =>
      'Puudub ühendus kaugteenusega – proovitakse automaatselt uuesti. Kontrolli internetiühendust.';

  @override
  String get scc0cccf89d => 'Väljas';

  @override
  String get sa1d085d92c => 'Kodusillal ei ole armatuurlaudu kopeerida.';

  @override
  String sa13ef6f8d9(String p0) {
    return 'Koopia: $p0 armatuurlauad';
  }

  @override
  String sab5e7202f5(String p0) {
    return 'Ühendatud \"$p0\"-ga!';
  }

  @override
  String get s30f06b7fb0 =>
      'Nüüd saad oma kodu juhtida kõikjalt. Kopeeri kodusilla armatuurlauad ja seadmed ka sellesse seadmesse?';

  @override
  String get s641263ce18 => 'Ei, aitäh';

  @override
  String get sa7a6c0fc2d => 'ei ole Molaplan kood';

  @override
  String get se2ecf1935a => 'Ühenda koduga';

  @override
  String get s410655fd47 => 'Kuidas ühendada';

  @override
  String get s7c541b8e91 =>
      'Kodusillal (tablett või PC kodus) avatud Molaplan → Seaded → Kaugjuurdepääs → Tee see seade kodusillaks.';

  @override
  String get sc7c83b2f58 =>
      'Vajuta sinna \"Pair a phone\". Ilmub QR-kood ja 6 numbrit.';

  @override
  String get s35284509d4 =>
      'Skaneerige QR-koodi või kirjutage allpool olevad numbrid.';

  @override
  String get s66bb65d8e8 => 'QR- koodi skaneerimine';

  @override
  String get se97cc157ef => 'või sisestage kood';

  @override
  String get s643434044c =>
      'Koodi kasutamisel vajutage ka kodusillal \"Accept\".';

  @override
  String get s9753766742 => 'Vajuta \"Aktsepti\" kodusilla ekraanile...';

  @override
  String get s50e49dd1df => 'Suuna kaamera QR-koodile';

  @override
  String s5d717bb2c5(String p0) {
    return 'Kaamera kasutamine nurjus ($p0). Kaamera kasutamise lubamine või koodi kirjutamine.';
  }

  @override
  String s7132345f20(String p0) {
    return 'Seade \"$p0\" ühendatud!';
  }

  @override
  String get se2e2af02ac =>
      'Kodusild on seade, mis jääb kodus sisse, nt vana tahvelarvuti või arvuti. Kui oled eemal, krüptitakse telefoni käsud selle kaudu sinu seadmetesse.';

  @override
  String get sd64f52490d => 'Hoidke seda laadijal ja kodus Wi-Fi-l.';

  @override
  String get sbb23f25581 =>
      'Hoidke Molaplan lahti. Ekraan jääb sisse, kuni sild on peal.';

  @override
  String get sbfed096278 => 'Kasutage seda seadet kodusillana';

  @override
  String get s13995350ed => 'Seo telefon';

  @override
  String get s6a74454a98 => 'Paaritud seadmed';

  @override
  String get s1e4fc2e7fe => 'Veel mitte. Vajuta \"Pange telefon\".';

  @override
  String get s7ea55c5834 => 'Lisatud';

  @override
  String sfd8d693d04(String p0) {
    return 'Eemalda \"$p0\"?';
  }

  @override
  String get s84572f642e =>
      'Seade ei saa siis enam kaugühendust luua. Seda saab uuesti paari panna.';

  @override
  String get sc58a7d7121 => 'Kodu nimi';

  @override
  String get s9715416100 => 'Skaneeri telefoniga';

  @override
  String get s4e877aeafe =>
      'Telefonis: Molaplan → Seaded → Kaugjuurdepääs → Ühendage see seade kodus';

  @override
  String get sf7fa9632f3 => 'Kehtib';

  @override
  String get s5378bb3f05 => 'Nõustuge selle seadmega?';

  @override
  String s1d8bb7b0a6(String p0) {
    return '\"$p0\" soovib sinu kodu kaugjuhtimist. Nõustu ainult siis, kui see on sinu enda või pereliikme seade, kuhu kood just sisestati.';
  }

  @override
  String get sa04c218f82 => 'Keeldu';

  @override
  String get sdfaf8c242b => 'Nõustu';

  @override
  String get sd64229b6d8 => 'pole veel valmis';

  @override
  String get s088e792ee3 => 'Kaugjuurdepääs on välja lülitatud';

  @override
  String get s85543bf885 => 'Online';

  @override
  String get s3f17564f18 => 'viimati nähtud';

  @override
  String get s9ba8cafced => 'Mis on kaugjuurdepääs?';

  @override
  String get s1cf33c1fbc => 'Väärtus';

  @override
  String get s86029171be => 'Sisse/välja';

  @override
  String get s4ddce888df => 'Nupp / otsetee';

  @override
  String get s357fc9c3fe => 'Liugur / setpoint';

  @override
  String get s14da6beba5 => 'Näitab näitu, nt temperatuuri.';

  @override
  String get se4b1d203df => 'Sisse/väljalülitatud, nt tuli või häire.';

  @override
  String get sc2197ab417 => 'Üks kraan teeb ühte või mitut asja.';

  @override
  String get sd611704caf => 'Väärtuse, nt temperatuuri reguleerimine.';

  @override
  String get sacfc0c0b41 => 'Näitab kaamera pilti.';

  @override
  String get s7172c54c2c => 'Hoiab temperatuuri seatud väärtusel.';

  @override
  String get s76e7a995de => 'Väärtusloetelu';

  @override
  String get s4e1f25d257 => 'Omakäeline';

  @override
  String get sea15760b77 => 'Mida nupp teeb?';

  @override
  String get s630ee9894e =>
      'Vali skript, stseen või seade. Nupp töötab rakenduses ja eemal olles kaugjuurdepääsu kaudu.';

  @override
  String get s1173c2dbf9 => 'Stsenaariume veel pole. Tee see automaatika all.';

  @override
  String get s7b42ecba51 => 'Pole veel stseene, salvesta üks automaatika alt.';

  @override
  String get s589d73245e =>
      'Vahetatavaid seadmeid veel pole. Lisa kõigepealt lüliti.';

  @override
  String get sc5edd6d3d1 => 'Uus kaart';

  @override
  String get sa684fd0716 => 'Muuda kaarti';

  @override
  String get sa7b6366b62 =>
      'Mõõtmine: näidik, trend, värvipiirangud, häired, kümnendkohad ja skaleerimine.';

  @override
  String get sae41bebdab =>
      'Kontroll: kinnitus, lukustus / PIN, min / max / samm, invert ja momentaarne.';

  @override
  String get scf37cbeda8 => 'Ikoon';

  @override
  String get sfeab9bd26f => 'Laius';

  @override
  String get s58be670598 => 'Kõrgus';

  @override
  String get sd7314e8237 => 'Kuvamine';

  @override
  String get s7d6cee9e42 => 'Baarid (15 min)';

  @override
  String get sc0e069225b => 'Trend + Nüüd liin';

  @override
  String get s07647fa07d => 'Range';

  @override
  String get s8feeef3110 => 'Näita homme, kui see on saadaval';

  @override
  String get sad692e6ae5 =>
      'Homsed hinnad ilmuvad iseenesest, kui need on avaldatud (umbes kell 14.00).';

  @override
  String get s1c72b8c56a => 'Trendi pikkus';

  @override
  String get s6bb0c0c7e3 => 'Minimaalne rööpmelaius';

  @override
  String get sa444aab286 => 'Automaatne';

  @override
  String get sbf29caff87 => 'Maksimaalne rööpmelaius';

  @override
  String get sea30815e6a =>
      'Tehnilised plaatide seaded ilmuvad, kui lülitate Seadistustes sisse \"Advanced\".';

  @override
  String get s382afc832f => 'Osariigi allikas';

  @override
  String get s581aee3e96 => 'Valikuline: kus loetakse praegust olekut.';

  @override
  String get s3adc51170c => 'Toorkombinatsioon (täiustatud)';

  @override
  String get s5f542e17e2 =>
      '⁇  Iga kaarditüüp on lubatud igal ühendusel. Vale kombinatsioon võib näidata eksitavaid andmeid, nt \"On\" elektrihinna kohta.';

  @override
  String get scb988b1a4a => 'Väljas: ainult kaart, mida ühendus toetab.';

  @override
  String get se6b18b17d9 => 'Polli intervall (s, 0 = puudub)';

  @override
  String get s01f2b1ee0c =>
      'MQTT, Home Assistant ja WebSocket värskendus otse ilma küsitlusteta.';

  @override
  String get s937448ecf5 => 'Test loe edasi';

  @override
  String get s5cbdea7f7e => 'Kuvamine';

  @override
  String get se6af4b33df => 'Ühik';

  @override
  String get sd5498697da => 'Kümnendkohad';

  @override
  String get s4f7007db78 => 'Väärtusnimed';

  @override
  String get s4aae179c52 => '0=Off;1=Home;2=Away';

  @override
  String get s0c12fda7ca => 'Käskude lülitamine';

  @override
  String get s3a9d9e16ef => '\"On\" väärtused (koma eraldatud, tühi = auto)';

  @override
  String get s1509c5a2a6 => 'käsuliinil';

  @override
  String get s2a1e131afd => 'Väljumiskomando';

  @override
  String get s0201de52c0 =>
      '{\'{value}\'} käsus asendatakse liuguri väärtusega.';

  @override
  String get sc30c9a7e51 => 'Samm';

  @override
  String get s4d6451a63a => 'Käsu määramine';

  @override
  String get sa4082e1a79 => 'Käsud (käivitatakse järjekorras)';

  @override
  String get s467488e572 =>
      'Otsetee võib juhtida mitut seadet järjestikku, viivitustega.';

  @override
  String get sad43973fb3 => 'Lisa käsk';

  @override
  String get sdaef43c622 => 'Kinnitamise küsimine';

  @override
  String get s5210a5ad23 => 'Ühendus';

  @override
  String get s96705fc3df => 'Käsk saadetud';

  @override
  String get sb41db1e809 => 'Proovi';

  @override
  String get s77d2309fd5 => 'Hilinemine enne (ms)';

  @override
  String get s2b463f47ba => 'Peida';

  @override
  String get s2594346d86 => 'Juhendid';

  @override
  String get sfdffaffea4 => 'Puudub';

  @override
  String get sd6c2de0256 => 'Horisontaalne';

  @override
  String get sb8ef66c33e => 'Võrk';

  @override
  String get s0bee1b8ed3 => 'Väärtusskaala';

  @override
  String get sd4e9b57931 => 'Ajatelg';

  @override
  String get s7abdb12fef => 'Andmepunktide markerid';

  @override
  String get s29135ed75a =>
      'Automaatne: teljed ja juhtjooned näitavad, kui kaart on vähemalt 2×2.';

  @override
  String get s638c648b40 => 'Stream';

  @override
  String s32ef3895b8(String p0) {
    return 'Objektiivid / kanal $p0';
  }

  @override
  String get s939603242a => 'Värvused väärtuse järgi';

  @override
  String get s45f927bc62 => 'Kohandatud';

  @override
  String get s319dab47d8 => 'Sujuv';

  @override
  String get s613fbec20e => 'Sammud';

  @override
  String get s25d9db075e => 'Oma piirid ja värvid: Seaded → Advanced.';

  @override
  String get sc0f5a14d2b => 'Värvikünnised (väärtus ≥ piir → värv)';

  @override
  String get scd65d31d4c => 'Limit';

  @override
  String get s30a2c0f460 => 'Lisage künnis';

  @override
  String get s4226eb046f => 'Võta tagasi';

  @override
  String get sd5cb601286 => 'Sabaskaala (lihtne VPN)';

  @override
  String get s0aa851cfb4 =>
      'Teie telefon ja kodu toimivad nagu üks võrk – Molaplan töötab samade aadressidega nagu kodus.';

  @override
  String get s444ca5d58f =>
      'Hea, kui teil on alati arvuti, Raspberry Pi või Home Assistant kodus.';

  @override
  String get sec7b4d1d7a =>
      'Loo Tailscale\'i konto aadressil tailscale.com (Google, Microsoft või Apple\'i sisselogimine).';

  @override
  String get s178c57446d =>
      'Paigalda sabaskaala alati sisselülitatud seadmele kodus. In Home Assistant: Settings → Add-ons → Tailscale.';

  @override
  String get s4faf83aa13 =>
      'Lülitage seal sisse \"alamvõrgu ruuter\" ja sisestage oma koduvõrk, nt 192.168.1.0/24. Siis on kõik teie koduseadmed kättesaadavad.';

  @override
  String get s721719c0e1 =>
      'Teekonna kinnitamine Tailscale admin-konsoolis (Machines → device → Edit route settings).';

  @override
  String get s921f981bda =>
      'Paigalda telefoni Tailscale rakendus ja logi sisse sama kontoga. Lülita sisse VPN.';

  @override
  String get s8ae7e7b2a4 => 'Molaplan kasutab samu aadresse nagu kodus.';

  @override
  String get se92301ff0a => 'https://tailscale.com/download';

  @override
  String get sf6270ae66c => 'https://tailscale.com/kb/1019/subnets';

  @override
  String get s57f0b61334 => 'WireGuard (ruuter VPN)';

  @override
  String get sb9bb49ab92 =>
      'Kui teie ruuter toetab WireGuardi (nt ASUS, FRITZ!Box, UniFi, OpenWrt), liitub teie telefon otse koduvõrguga.';

  @override
  String get s986d264604 =>
      'Hea, kui ruuteril on WireGuard ja teie ühendusel on avalik IP-aadress.';

  @override
  String get sf24b16dc12 =>
      'Avage ruuteri seaded ja otsige \"VPN-server\" → \"WireGuard\".';

  @override
  String get s1e5d1eb832 =>
      'Serveri lubamine ja uue seadme (peer) lisamine telefonile.';

  @override
  String get s8e0252a2b4 =>
      'Ruuter näitab QR- koodi. Paigalda WireGuardi rakendus telefoni ja skaneeri see.';

  @override
  String get s4b3740b727 =>
      'Kontrollida, et \"Lubatud IP-d\" hõlmaks koduvõrku (nt 192.168.1.0/24).';

  @override
  String get sd2e8523b28 =>
      'Lülitage VPN sisse telefonis - Molaplan töötab nagu kodus.';

  @override
  String get saa17c5a456 => 'https://www.wireguard.com/install/';

  @override
  String get se5960424ea =>
      'Paljudel mobiilse lairiba (4G/5G koduinternet) ühendustel puudub avalik IP (CGNAT) ja WireGuard ei ole siis väljastpoolt kättesaadav. Kasuta selle asemel Molaplani kaugjuurdepääsu või Tailscale\'i.';

  @override
  String get sab2dfe387b => 'Home Assistant Cloud (Nabu Casa)';

  @override
  String get s2e0586b37e =>
      'Koduabilise tegijate igakuine tasuline tellimus. Annab Home Assistantile turvalise kaugaadressi.';

  @override
  String get s534e7ec95e => 'Hea, kui teie seade on juba koduabilises.';

  @override
  String get s0f7533967d =>
      'In Home Assistant: Settings → Home Assistant Cloud → Alustage prooviversiooni või logige sisse.';

  @override
  String get s2e60dd8178 => 'Lülita \"Kaugjuhtimine\" sisse.';

  @override
  String get s7a73024451 =>
      'Kopeeri kaugaadress, mis näeb välja järgmine: https://abcd1234.ui.nabu.casa';

  @override
  String get sd4873612f7 =>
      'Molaplan: ühendused → Home Assistant → muudab aadressi võrguaadressiks. Märk jääb samaks.';

  @override
  String get s15223b0e32 => 'Koduabilise plaadid töötavad nüüd kõikjal.';

  @override
  String get s9b3201b1fa => 'https://www.nabucasa.com/';

  @override
  String get s60e7067815 =>
      'See hõlmab ainult Home Assistanti kaudu juhitavaid seadmeid. Teistel (Modbus, kaamerad otse) on Molaplani kaugjuurdepääs või VPN.';

  @override
  String get s8e0d0a2d4e => 'Cloud MQTT (nt HiveMQ Cloud)';

  @override
  String get sd0fff65292 =>
      'Seadmed ja Molaplan räägivad läbi sama pilveserveri. HiveMQ Cloudil on vaba tase, millest piisab koduseks kasutamiseks.';

  @override
  String get s7350b9f98b =>
      'Hea MQTT-seadmetele: Tasmota, ESPHome, Shelly, Zigbee2MQTT, teie enda ESP-lauad.';

  @override
  String get s59b3c7d246 =>
      'Looge tasuta konto aadressil console.hivemq.cloud ja looge tasuta klaster (tasuta / serverita).';

  @override
  String get s04fe436d1e =>
      'Alas \"Juurdepääsu haldamine\" loo kasutajanimi ja parool.';

  @override
  String get sdf0075eab5 =>
      'Kopeerib serveri aadressi (nt abcd.s1.eu.hivemq.cloud). Port on 8883, kus TLS on sees.';

  @override
  String get s9e9be6fc33 =>
      'Pane see server, kasutajanimi ja parool oma seadmete MQTT-seadetesse (TLS sisse lülitatud).';

  @override
  String get s90f1cb151b =>
      'Molaplan: ühendused → MQTT → aadress, port 8883, TLS sees, kasutajanimi ja parool. Tehtud – töötab kõikjal.';

  @override
  String get s77bf29f2f5 => 'https://console.hivemq.cloud/';

  @override
  String get safd2cd2b7b =>
      'Valige tugev parool: igaüks, kes seda teab, saab teie seadmeid juhtida.';

  @override
  String get s9557c0ef28 => 'Kaugjuurdepääsu juhendid';

  @override
  String get sf4d7957b78 => 'Lihtsaim: Molaplan kaugjuurdepääs';

  @override
  String get s8032085166 =>
      'Kontosid pole, ruuteri seadistusi pole. Vaja on ainult tahvelarvutit või arvutit, mis jääb kodus sisse.';

  @override
  String get sd9b48e01fc => 'Teisiti';

  @override
  String get sfe551fd431 => 'Seadmete juhendid';

  @override
  String get sa35e37b4b4 =>
      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Leiti automaatselt.';

  @override
  String get scb28b11e70 => 'Uus vaade';

  @override
  String get s1f9799af4e => 'nt Cottage';

  @override
  String get s3a13f9d077 => 'Armatuurlaua ümbernimetamine';

  @override
  String get sa5bf37213b => 'Kustuta armatuurlaud?';

  @override
  String s10671afc00(String p0, String p1) {
    return '\"$p0\" ja selle $p1 plaadid kustutatakse.';
  }

  @override
  String s897761b5f4(String p0) {
    return 'Armatuurlaud \"$p0\" kustutatud';
  }

  @override
  String get scc5cf9957d => 'Vali plaaditüüp';

  @override
  String get s7cf6340503 => 'Uus seade valmis kaartidega';

  @override
  String get se6ca707cf3 =>
      'Kõige lihtsam: Shelly, ESP32-CAM, Home Assistant...';

  @override
  String get s0789f5f14f => 'DASHBOARDS';

  @override
  String get sfb3e3c456c => 'Kustuta armatuurlaud';

  @override
  String get scdfd80f963 => 'Lisa kaart';

  @override
  String get s71af34b8e9 => 'Tühi vaade';

  @override
  String get s6a210970eb =>
      'Siin on näha seadme plaadid: temperatuurid, lülitid, kaamerad ja kiirklahvid. Alusta seadme lisamisega.';

  @override
  String get s4229fb4103 => 'Lisa oma esimene seade';

  @override
  String get sf67e0d5752 => 'Kustutada kaart?';

  @override
  String s97f46743e0(String p0) {
    return 'Kivi \"$p0\" kustutatud';
  }

  @override
  String get sda9203de80 => 'Konto puudub – seaded ainult selles seadmes. ';

  @override
  String get s8b3e63da21 => 'Konto loomine ›';

  @override
  String get s887c293cad => 'Seade lisatud!  ⁇';

  @override
  String get s84a087a679 =>
      'Loo konto nii, et sinu seadistused säiliksid jasuper bullshit reconciliation. Selleks on vaja ainult e- posti koodi, parooli pole vaja.';

  @override
  String get s907220900d => 'Tere tulemast Molaplani';

  @override
  String get s845ec6276f => 'Teie seadistamine kõigis teie seadmetes';

  @override
  String get s9dfa93453b => 'Telefoni vahetamisel ei lähe midagi kaduma';

  @override
  String get s6aa51b28a5 => 'Seadme paroolid on krüptitud';

  @override
  String get sc6f02b69d3 => 'Konto loomine / sisselogimine';

  @override
  String get sc777bde66f => 'E-posti koodiga - ilma paroolita.';

  @override
  String get se2e5ff2c8a => 'Jätka ilma kontota';

  @override
  String get sb8934a5835 => 'Elektritarbimine';

  @override
  String get s5409dc748f => 'Ei arvestata';

  @override
  String get sf0bbcc217b => 'Kogu objekt';

  @override
  String get s0ad1897b28 => 'Seadme arvesti';

  @override
  String get s99268b5a6c =>
      'Kogu objekt = peaarvesti. Seadme arvesti = üks seade (näidatakse osana kogusummast, ei arvestata kaks korda).';

  @override
  String get se1174af557 => 'Osa arvestist (valikuline)';

  @override
  String get s9773c92c92 => 'Energia ja kulud';

  @override
  String get s43dead6994 => 'Elektrileping';

  @override
  String get sef4d24cdd4 => 'Päev';

  @override
  String get sa62dd794ce => 'Kuu';

  @override
  String get s6b2ebe5aca => 'Vali kõigepealt arvestid';

  @override
  String get sde41f2fac9 =>
      'Märkige allpool, milline meeter mõõdab kogu saiti ja millised üksikud seadmed.';

  @override
  String get s4ad000d885 => 'km-ga';

  @override
  String get s9e214b6e88 => 'km-ta';

  @override
  String get s73771d252c => 'Mõõdetud seadmed kokku';

  @override
  String get s22d03356a9 => 'Muu tarbimine';

  @override
  String get s48b08c5f5a => 'Kuutasud (energia + võrk)';

  @override
  String get s2e8700e0cf => 'Osal kasutusest puudus hind (hetkhind puudus).';

  @override
  String get sbbd89fbc05 =>
      'Kasutamine registreeritakse, kui rakendus on avatud (kogu aeg kodus tahvelarvutis).';

  @override
  String get s64382718ff => 'Arvestid';

  @override
  String get s9a3a0d414e =>
      'Võimsus- või energiakaardid puuduvad (W, kW, Wh, kWh). Lisada näiteks Shelly arvesti.';

  @override
  String get sdb0484d728 => 'Salvestatud';

  @override
  String get se80021e22a =>
      'Kopeeri oma arvelt hinnad. Kirjuta need kas käibemaksuga või ilma – kulusid näidatakse mõlemal viisil.';

  @override
  String get sfb62156afe => 'Hinnapiirkond';

  @override
  String get s1762fb70a7 => 'Energia';

  @override
  String get s2ed3e3cf28 => 'Börsihind';

  @override
  String get s5d1dd0f675 => 'Fikseeritud';

  @override
  String get sedb38796fb => 'Öö/päev';

  @override
  String get s0774cea15a => 'Marginaal';

  @override
  String get s63370fe61a => 'Energia hind';

  @override
  String get s50a7dd89c6 => 'Päevane energia';

  @override
  String get sdeaa5ad900 => 'Öine energia';

  @override
  String get se93c7bcd86 => 'Kuutasu (energia)';

  @override
  String get sb7937e4b91 => 'Võrguteenus';

  @override
  String get s0f89840226 => 'Ühtne tariif';

  @override
  String get sa768f1b352 => 'Võrgutasu';

  @override
  String get s9e5dde22cb => 'Võrgutasu päeval';

  @override
  String get sdf7a4fd2e3 => 'Võrgutasu öösel';

  @override
  String get s4df0aee067 => 'Kuutasu (võrk)';

  @override
  String get s4c59c90975 => 'Öö algab';

  @override
  String get s84decd042b => 'Öö lõpeb';

  @override
  String get s90c26f1e37 => 'Maksud';

  @override
  String get s222cb348a0 => 'Elektriaktsiis';

  @override
  String get sbe412dcaa6 => 'Käibemaks';

  @override
  String get s43b55c13c5 => 'Otsimine nurjus. Kontrolli ühendust.';

  @override
  String get s171834ca33 => 'Kodu asukoht';

  @override
  String get s6f6c2fe37a =>
      'Ilmaprognoos (Open-Meteo) aitab eelkuumutada enne külma ilma.Linnast piisab.';

  @override
  String get s5f663978d6 => 'Asula';

  @override
  String get s7be6460c54 => 'nt Tampere';

  @override
  String get s1576b70590 => 'Elektrikasutus, kulud, leping ja ilm.';

  @override
  String get sa6212aaeb4 => 'Asukoht';

  @override
  String get sa0eeb22daa => 'On juba vaates – kas lisada ikkagi?';

  @override
  String s3507210a2a(String p0, String p1) {
    return '$p0 on juba vaates $p1.';
  }

  @override
  String get s0e655a209f => 'Lisa ikkagi';

  @override
  String get s902eaaff9f => 'Avage';

  @override
  String get s12c2f8e6e4 => 'Ainult koduvõrgus';

  @override
  String s5f7c464e6d(String p0) {
    return 'kell $p0';
  }

  @override
  String s21b64ae0a7(String p0) {
    return '$p0 töötab ainult koduvõrgus. Ruut muutub ise tavaliseks, kui oled jälle kodus.';
  }

  @override
  String get s6b1a8249de => 'Viimane olek';

  @override
  String get s56650a18d5 => 'Tee kaugjuhitavaks ›';

  @override
  String get sa0d8c62e5a => 'Käsku pole seadistatud';

  @override
  String get s1e5d696a26 => 'Käivita seda käsku?';

  @override
  String get s1df6e2eaa7 => 'PIN';

  @override
  String get secab66c046 => 'Selle seadme meeldejätmine';

  @override
  String get s10bf4eab8e =>
      'Salvestatud krüptituna ainult sellesse seadmesse. Vaikimisi PIN- koodi ei salvestata.';

  @override
  String get s856418521a => 'Käske pole seadistatud';

  @override
  String sdfa66ee201(String p0) {
    return '$p0: saadetud';
  }

  @override
  String get s12fc3810a5 => 'Saatis – vastust oodates...';

  @override
  String get sd1c7d49360 => 'Vasta';

  @override
  String get s29fae6a0e8 => 'Hinnajuhtimine sees';

  @override
  String get s59d55f8882 => 'Nimeta ümber';

  @override
  String get s25580038cb => 'Salvestatud PIN-kood eemaldatud';

  @override
  String get sf50c488b24 => 'Unusta salvestatud PIN';

  @override
  String get safe0429a90 => 'Hinnajuhtimine';

  @override
  String get sf3d644dd4c => 'Õpeta puldi nupp';

  @override
  String get sfb1a18d11f => 'Värskenda';

  @override
  String get s72a2328ddd => 'Valgustid';

  @override
  String get sca12be80ca => 'Lülitid';

  @override
  String get sa4c0eeea02 => 'Soojuspumbad ja kliima';

  @override
  String get sa8dbf04ad3 => 'Binaarsed andurid';

  @override
  String get sa7690acf57 => 'Katted, väravad ja uksed';

  @override
  String get s487bf00fc7 => 'Lukud';

  @override
  String get sbe76826428 => 'Ventilaatorid';

  @override
  String get s4b53bcaaf0 => 'Nööbid';

  @override
  String get s5c92d42edd => 'Arvuväljad';

  @override
  String get s3c2ed0c522 => 'Abilülitid';

  @override
  String get sea20d169a3 => 'Meediamängijad';

  @override
  String get sbcb95e1e78 => 'Märki ei aktsepteerita. Loo uus koduabilises.';

  @override
  String get s0b80dc2642 =>
      'Koduabilise kättesaamine nurjus. Kontrolli aadressi.';

  @override
  String get sf32b7f15d8 => 'kaamerad';

  @override
  String get sa7a829cefb => 'Vali Home Assistanti seadmed';

  @override
  String get sefdf8e3316 => 'Laadin seadmeid…';

  @override
  String get s26583a1933 => 'Üks vaade toa kohta';

  @override
  String get sb3e6b54bce => 'Otsing nime või ID järgi';

  @override
  String get safedc10c48 => 'Kõik toad';

  @override
  String get s407f3f7a0c => 'Ruumi ei ole';

  @override
  String get sedb7b77645 => 'Kõik';

  @override
  String s140aba8cd7(String p0) {
    return '$p0 valgustit on Philips Hue valgustid';
  }

  @override
  String get s16aee2aa30 =>
      'Otse Hue Bridge’i kaudu reageerivad need kiiremini ja töötavad ilma Home Assistantita.';

  @override
  String get s3816288db1 => 'Lisa Hue Bridge';

  @override
  String get sa765c9294a => 'Näita kõiki';

  @override
  String sdb088f47a8(String p0) {
    return '$p0 peidetud tehnilised elemendid (diagnostika, konfiguratsioon, uuendused)';
  }

  @override
  String get s3ee8d0a5e3 =>
      'Ruume ei olnud võimalik lugeda – näidati seadmeid ilma ruumideta.';

  @override
  String get sf55fca7a32 => 'Vasteid pole';

  @override
  String get s78cdce874e => 'juba lisatud';

  @override
  String get s7ba50ea69e => 'Magamistuba';

  @override
  String get s9e9723b263 => 'Köök';

  @override
  String get scce769451b => 'Elutuba';

  @override
  String get s9d5dca2dee => 'Vannituba';

  @override
  String get s2569505205 => 'Sauna';

  @override
  String get s1c65dad1f5 => 'Esik';

  @override
  String get sa4d90bb5da => 'Õu / aed';

  @override
  String get s4a7be17a36 => 'Tehnoruum';

  @override
  String get s01e404f15f => 'Töötuba';

  @override
  String get sfd8305add2 => 'Lastetuba';

  @override
  String get scd87fb4dd7 => 'Suvila';

  @override
  String get sdc398885dc => 'Täpsemad seaded';

  @override
  String get s5d477f3cd8 => 'Tavaliselt sa ei vaja neid';

  @override
  String get s2315e0e739 => 'nt';

  @override
  String get sc1c47d2474 => 'Taustapildi valimine';

  @override
  String sa8ce5112ee(String p0) {
    return 'Kuni $p0 taustapilti. Eemalda enne üks.';
  }

  @override
  String get s12a7d631af => 'Välimus';

  @override
  String get s0d83798030 => 'Suurus';

  @override
  String get s64c916e299 => 'Väike';

  @override
  String get s5e3097232a => 'Lai';

  @override
  String get s8971788287 => 'Suur';

  @override
  String get s254a1d8e12 => 'Taustapilt (valikuline)';

  @override
  String get sc48f5f9bcf => 'Vali pilt';

  @override
  String get s7ba9d453ed => 'Tumenda, kui seade on väljas';

  @override
  String get s016ae7b580 =>
      'Pilt on kahanenud (≤ 200 KB) ja sünkroonitud teie kontoga.';

  @override
  String get sabb10f8cb2 =>
      'Pilt on kahanenud (≤ 200 KB) ja seda hoitakse ainult sellel seadmel.';

  @override
  String get sc80648d495 => 'Molaplani näitamine';

  @override
  String get sa4e9c86a86 => 'Lõpeta';

  @override
  String get s4dab2d409b => 'Ekspordi konfiguratsioon';

  @override
  String get s149c1e54d6 => 'Eksporditud seadistused';

  @override
  String get s35f445793b => 'Impordi seadistus';

  @override
  String get sd55be829e3 => 'Kas asendada praegune seadistus?';

  @override
  String get s852dd1795e =>
      'Kõik aktiivsed ühendused ja armatuurlauad asendatakse faili sisuga.';

  @override
  String get s5f2ec17730 => 'Imporditud seadistused';

  @override
  String get sa87fff54f3 => 'Import nurjus';

  @override
  String get s2fd2bfedb8 => 'Konto';

  @override
  String get s4c0ff416ab => 'Samad kodud ja plaadid kõigis teie seadmetes.';

  @override
  String get scc7e418ee3 =>
      'Logi sisse, et arvutil, tahvelarvutil ja telefonil oleksid samad kodud, seadmed ja plaadid. Valikuline.';

  @override
  String get s9bb545e9b3 => 'Logi sisse või loo konto';

  @override
  String get s08d62fd281 => 'Välimus';

  @override
  String get s2b8a2754c6 => 'Teema';

  @override
  String get s79f67deb42 => 'Valgusti';

  @override
  String get s0d6fb52039 => 'Pimedus';

  @override
  String get s70dd7fdd58 => 'Päikesetõusuks ja -loojanguks';

  @override
  String get s21206b61f7 =>
      'Vajab kodu asukohta (Energy › Home). Kuni selle ajani järgitakse seadme seadistusi.';

  @override
  String get s4e23920823 =>
      'Päeval valgus, õhtul pime. Väljas: järgi seadme seadistust.';

  @override
  String get s4b847ce63e =>
      'Valik kehtib selle seadme kohta ja salvestatakse teie kontole uute seadmete vaikeväärtusena.';

  @override
  String get s5ebc02022b => 'Näita tunni keskmisena';

  @override
  String get s68b4d332ca =>
      'Hind, odavaim tööaeg ja hinnakontroll tunnis (tunnitööleping) Väljas: 15 minutit, kui piirkonnas avaldatakse 15-minutilised hinnad.';

  @override
  String get saf496a12a3 => 'Hommikkaart: näita ka priciest tundi';

  @override
  String get sc53b1b78c0 =>
      'Järgmise 24 tunni odavaim tund on alati näidatud selle hinnaga.';

  @override
  String get s0625d54b38 => 'Kaardi suurus';

  @override
  String get s8382da3467 => 'Tavaline';

  @override
  String get s7c1cd8314e => 'Peida ruudud, mis eemalt ei tööta';

  @override
  String get sa0cbbafb4e =>
      'Kodust eemal peidetakse ruudud, mis töötavad ainult koduvõrgus. Vaikimisi jäävad need paigale hallina.';

  @override
  String get s419166b895 => 'Kell ja ilm avaekraanil';

  @override
  String get sec30a8f23e =>
      'Aeg, kuupäev, ilm ja elektrihind vaate ülaosas. Ainult see seade.';

  @override
  String get sf7205b268f => 'Animatsioonid';

  @override
  String get s1535c6411d =>
      'Pehmed üleminekud, kui seade muudab olekut. Väljas = rahulikum ja kergem vanema tahvelarvuti puhul. Ainult see seade.';

  @override
  String get s21f870dbc2 =>
      'Näitab tehnilisi seadistusi: ühendused (HTTP, MQTT, Modbus...), nimikoormused, JSON- i rajad ja plaatide allikad. Enamik inimesi ei vaja neid.';

  @override
  String get sca4c8b88b7 => 'Koduabiline: lisa seadmeid';

  @override
  String get saec69088a5 => 'Kontrollige oma kodu ka väljastpoolt.';

  @override
  String get scc3d01ee5e => 'Juhised: VPN, Nabu Casa, cloud MQTT';

  @override
  String get s90ba544719 => 'Abi';

  @override
  String get sb915c42792 => 'Käivitamise juhendi näitamine';

  @override
  String get sd337a7ddd5 => 'Varundamine ja ülekandmine';

  @override
  String get s07c1048b4f =>
      'Ekspordib konfiguratsiooni JSON-faili ja impordib selle teise seadmesse (nt PC → telefon).';

  @override
  String get s2f797098e7 => 'Paroolide ja märkide kaasamine';

  @override
  String get s26f72949e3 => 'Fail on krüptimata – hoia seda turvaliselt.';

  @override
  String get sdb12678e52 => 'Ekspordi';

  @override
  String get s34686ffb09 => 'Näide';

  @override
  String get sc8327738b3 =>
      'Lisa näidisvaade (kaamera, häire, tuled, ventilatsioon). Näidisseadmed ei ühendu kunagi kuskil – lisa oma seade seadmega Lisa.';

  @override
  String get sec02c7c071 => 'Lisa näidisvaade';

  @override
  String get s522d6584c5 => 'Otsi uuendusi';

  @override
  String get sd178a1d809 =>
      'Oma juhtimisterminal: HTTP, MQTT, Modbus TCP, Home Assistant, kaamerad, WebSocket, TCP ja UDP. Ilma kontota jäävad kõik seaded sellesse seadmesse.';

  @override
  String s84819cca05(String p0) {
    return 'Viimane häire $p0';
  }

  @override
  String get se455dc672b => 'Samm';

  @override
  String get s3ddd2678bf => 'Jäta juhend vahele';

  @override
  String get s171ac59e67 =>
      'Vali allpool oma seade. Kirjuta ainult selle aadress – ülejäänu on sinu eest tehtud.';

  @override
  String get se722dfcec9 =>
      'Molaplan on sinu kodu juhtpaneel. Sa paned sisse täpselt vajalikud seadmed ja nupud.';

  @override
  String get scbac938ead => 'Näe kõike lühidalt';

  @override
  String get se25f930e31 =>
      'Temperatuurid, tuled, alarm ja kaamera ühes vaates.';

  @override
  String get s3e450dba98 => 'Kontroll ühe kraaniga';

  @override
  String get sdda6a3f06e =>
      'Tuled põlevad, suurendavad ventilatsiooni või \"kodust lahkumise\" nuppu, mis teeb korraga palju asju.';

  @override
  String get sbcac0cd35a => 'Sama kodu kõigis seadmetes';

  @override
  String get sd43d517cc7 =>
      'Soovi korral logi sisse ning arvuti, tahvelarvuti ja telefon näitavad sama kodu. Paroolid on sinu seadmes krüptitud. Kontot pole vaja.';

  @override
  String get s70fff97e97 => 'Mul on juba Molaplani konto - logi sisse';

  @override
  String get sd6561a08ca => 'Alustame';

  @override
  String get se5be2a8386 => 'Sinu kaardid on valmis';

  @override
  String get s8162694dbe => 'Lisa oma esimene kaart';

  @override
  String get s7b2a30b77c =>
      'Need plaadid on tehtud sinu seadme jaoks. Sa võid neid hiljem vahetada ja korrastada.';

  @override
  String get s39e163fa49 =>
      'Plaat näitab teavet või juhib seadet. Vali, millist plaati:';

  @override
  String get s4bfb026e45 => 'Teen seda hiljem';

  @override
  String get s3f0351473c => 'Kontrolli oma kodu ka väljastpoolt?';

  @override
  String get s6fe6fe631f =>
      'Kodus on kõik juba töökorras. Väljastpoolt on vaja kodus üht alati sisselülitatud seadet (vana tahvelarvuti või arvuti) – ei mingeid ruuteri seadistusi, ei mingeid kontosid.';

  @override
  String get sb599b7432f => 'Kaugjuurdepääs on sisse lülitatud.';

  @override
  String get s33a294d472 => 'See seade on kodusild.';

  @override
  String get s4aa8cce504 => 'Mitte praegu – ainult kodus';

  @override
  String get sd3c370ca52 => 'Valmis!';

  @override
  String get s1359035b73 => 'Koputa plaati';

  @override
  String get sfd26c8e50b => 'Lüliti lülitab, nupp käivitab oma käsu.';

  @override
  String get s416c8184a7 => 'Pliiatsinupp ülaosas';

  @override
  String get s2ba275defe => 'Muuda, lisa, kustuta ja lohista plaate ümber.';

  @override
  String get se872eeb0f5 => 'Pikalt pressitud plaat';

  @override
  String get s63496941fc =>
      'Vaadake üksikasju ja selgitust, kui midagi on valesti.';

  @override
  String get s080be778d5 =>
      'Leidke see juhend, kaugjuurdepääs ja varukoopiad seal.';

  @override
  String get sae0fae7127 => 'Mine mu armatuurlauale';

  @override
  String get s2a28790ea2 => 'Täislaius';

  @override
  String get s64f4d1e11a => 'Määra kodu asukoht';

  @override
  String get sbf7cc3de9a => 'Proovi nüüd';

  @override
  String get s1becc05ea1 => 'locked=Lukus;unlocked=Lahti;jammed=KINNI';

  @override
  String get s259de02f33 =>
      'open=Avatud;closed=Suletud;opening=Avaneb;closing=Sulgub';

  @override
  String get s64d4364336 =>
      'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming';

  @override
  String get s5b1e227dc4 => 'on=Sees;off=Väljas';

  @override
  String get s3d43664fcc => 'WebSocket';

  @override
  String get sfcbb753f53 => 'URL';

  @override
  String get s81479e1555 => 'Päised (Nimi: väärtus rea kohta)';

  @override
  String get s5811b38d7b => 'Token (Authorization: Bearer)';

  @override
  String get sd512dbbfc7 => 'Teade ühenduse kohta';

  @override
  String get s2c4fd261e2 => 'Iseallkirjastatud sertifikaadi lubamine';

  @override
  String get s4d089aab74 => 'Filter (sõnumi sisu)';

  @override
  String get s55c951a8ad => 'Json';

  @override
  String get s10813e25b3 => 'Regex (1. rühm)';

  @override
  String get s4a282cd247 => 'Nõudeteade (saadetakse lugemisel)';

  @override
  String get sbeef545d37 => 'Teade ({\'{value}\'} = väärtus)';

  @override
  String get s0477f24b6b => 'HTTP / REST';

  @override
  String get s3102ae3a16 => 'Baas-URL';

  @override
  String get s38d0517a8d => 'Autentimine';

  @override
  String get sade17bf83e => 'Puudub';

  @override
  String get s9cbb9f048d => 'Kasutaja + parool (põhiline)';

  @override
  String get s3cb806781e => 'Kasutaja + parool (Digest)';

  @override
  String get sb1920b9d9b => 'Token (Bearer)';

  @override
  String get sed995f57b8 => 'Kasutajanimi';

  @override
  String get s65e35b7cc4 => 'Token';

  @override
  String get s51510ae27a => 'Lisapäised (Nimi: väärtus rea kohta)';

  @override
  String get s361419c448 => 'Aegumine (s)';

  @override
  String get sf235ce5ec0 => 'Meetod';

  @override
  String get s484291707c => 'Path';

  @override
  String get s54c8aed8bc => 'Keha';

  @override
  String get s5c5e9b662c => 'Keha ({\'{value}\'} = väärtus)';

  @override
  String get s8e82ca13cf => 'Content-Type';

  @override
  String s3c045f21ee(String p0, String p1, String p2) {
    return 'Testitud: GET $p0 (baasaadress, $p1 baitid, $p2 ms).';
  }

  @override
  String get s7797602869 => 'Käske ei saadetud ja plaatide teid ei testitud.';

  @override
  String sbf349dfcbd(String p0, String p1) {
    return 'HTTP $p0: seade vastas, kuid keeldus sisselogimisest. Kontrolli kasutajanime, parooli või märgist. $p1';
  }

  @override
  String s3bd10f0ae2(String p0, String p1) {
    return 'HTTP $p0: seade vastas serveri veaga. $p1';
  }

  @override
  String s2a7fa26dd6(String p0, String p1) {
    return '✓ Seade vastas aadressil $p0 (HTTP 404: baasaadressil leht puudub – paljude seadmete puhul tavaline). Ühendus toimib. $p1';
  }

  @override
  String sb2821916bc(String p0, String p1, String p2) {
    return '✓ Ühendus toimib: HTTP $p0. $p1 $p2';
  }

  @override
  String get s58648dc3fc => 'Kaamera (MJPEG / JPEG / RTSP)';

  @override
  String get s1534821f4a => 'Kaamera baas- URL';

  @override
  String get s95533426a3 => 'RTSP aadress (otsevideo kodus)';

  @override
  String get sa1115d4b0b => 'RTSP aadress, valgus (kaart)';

  @override
  String get se995a6862d => 'Režiim';

  @override
  String get s7cf6da2822 => 'Elus (MJPEG)';

  @override
  String get s4cb8ad767b => 'Pilte';

  @override
  String get s15f9cd477c => 'RTSP video';

  @override
  String get s4f356d158a => 'Värskendamine (s, hetktõmmis)';

  @override
  String get scbc6aa5e63 => 'radooni';

  @override
  String get sfc402d7bce => 'co2';

  @override
  String get s7410329f6d => 'air_quality';

  @override
  String get s05ff8e0c34 => 'termostaat';

  @override
  String get s26e6d96d7e => 'niiskuse';

  @override
  String get sfabcfc0188 => 'kiirust';

  @override
  String get s12a1c5653a => 'air_quality';

  @override
  String get s2f37dd80ed => 'aku';

  @override
  String get sd4025b7a32 => 'Õhk (pilv)';

  @override
  String get sf7d012472a => 'Client ID';

  @override
  String get s94bccb8598 =>
      'dashboard.airthings.com → Integrations → API → Create client (Client credentials).';

  @override
  String get sb1a9b21d4f => 'Client secret';

  @override
  String get s2403198fe5 =>
      'Näidatakse kliendi ID kõrval. Hoia seda saladuses.';

  @override
  String get s21b52207e8 => 'Uuendamise intervall (min)';

  @override
  String get saad5ced5fe =>
      'Monitorid uuendavad iga 5 minuti järel; sagedamini küsimine ei too midagi uut.';

  @override
  String get sc844e90e0f => 'Seerianumber';

  @override
  String get s8cee566dd7 =>
      'Monitori seerianumber (10 numbrit) - täidetakse, kui lisate selle loendist.';

  @override
  String get s2d79014611 => 'Mõõtmine';

  @override
  String get s852b4e5c75 =>
      'millist mõõtmist kaart näitab (radoon Bq/m3, CO2 ppm, LOÜ ppb, °C, %, hPa, μg/m3, aku %).';

  @override
  String get s6cd83fc216 => 'Radoon (lühiajaline)';

  @override
  String get s0c4b6446cd => 'Radoon (pikaajaline)';

  @override
  String get s96cc1b3741 => 'VOC';

  @override
  String get sf8496cb6dc => 'Surve';

  @override
  String get s99e44237af => 'PM2.5';

  @override
  String get s951d501a1a => 'PM1';

  @override
  String get sb6d80b9662 => 'Airthings Wave (Bluetooth)';

  @override
  String get s83d2446b44 =>
      'monitori tagaküljel või allosas (10 numbrit, nt 2930xxxxxxxx).';

  @override
  String get s2525f9a4f5 =>
      'Soome on üks piirkond (FI). Rootsis ja Norras sõltub see sellest, kus te elate.';

  @override
  String get s8f4a683abf => 'Käibemaks %';

  @override
  String get s1c7d76a774 => 'Teie riigi käibemaks.';

  @override
  String get se49d0fba92 => 'Müüja marginaal (c/kWh)';

  @override
  String get s20a5e2936a =>
      'Kohapealne lepinguline kasumimarginaal ilma käibemaksuta.';

  @override
  String get s923f9739de => 'Võrgutasu + aktsiis (c/kWh)';

  @override
  String get s2a3498fb0f =>
      'Teie arvelt, kaasa arvatud käibemaks. Jätke 0 ainult energia jaoks.';

  @override
  String get s1d9eabe472 =>
      'Väljas: 15-minutilised hinnad, kui piirkond need avaldab (ELis üks päev ette alates 1. oktoobrist 2025).';

  @override
  String get s515da3a9dd => 'Hinnaserver';

  @override
  String get s98cc9f1c14 => 'Molaplani server tõmbab hindu avatud allikatest.';

  @override
  String get s271885dc8b => 'Mida näidata';

  @override
  String get s1edb6be142 =>
      'Millist hinnanumbrit kaart näitab: nüüd, tänane madalaim / kõrgeim / keskmine, järgmine odav tund või graafik.';

  @override
  String get s46aab99b27 => 'Täna madalaim';

  @override
  String get sf6295f1182 => 'Kõrgeim täna';

  @override
  String get s1aa7abbf72 => 'Keskmine täna';

  @override
  String get s65f496b2dc => 'Järgmine odav tund';

  @override
  String get se446dc324a => 'Hinnatabel (täna ja homme)';

  @override
  String get s2f754e8ab4 => 'Tänaseks pole veel hindasid.';

  @override
  String get s18faad19ed => 'Praegu pole hinda.';

  @override
  String get s29178b43f4 => 'Elektri hind on püsiarveldus.';

  @override
  String get s1a707f2788 => 'Homme: jah.';

  @override
  String get sb85af981c1 => 'Homme: veel mitte (avaldatud kella 14 paiku).';

  @override
  String s6270faf138(String p0, String p1, String p2, String p3) {
    return '✓ Hinnad $p0 ($p1 pesad, $p2 min, allikas $p3).';
  }

  @override
  String get se1bd60873c => 'MQTT';

  @override
  String get s85b9781bb7 => 'Maakleri peremees';

  @override
  String get s800d13debd => 'Port';

  @override
  String get s49fa57061a => 'TLS';

  @override
  String get s0fcef98aad => 'WebSocketi kasutamine (ws:// või wss://)';

  @override
  String get s5089c65c1f => 'Kliendi ID (tühi = auto)';

  @override
  String get s9372a6f755 => 'Keep alive (s)';

  @override
  String get sd373a99107 => 'Oleku teema';

  @override
  String get s518c8aa712 => 'Käsuteema';

  @override
  String get s120726c79a => 'Kasulik koormus ({\'{value}\'} = väärtus)';

  @override
  String get s3660228d11 => 'QoS';

  @override
  String get s1b07c9ba3d => 'Retain';

  @override
  String s91c3d72d1e(String p0) {
    return 'fan $p0';
  }

  @override
  String get s40032ddea9 => 'kiik';

  @override
  String get s7068e8892e =>
      'Tundmatu kood ilma toorandmeteta. Toorandmete lubamine Tasmotas (SetOption58 1) ja proovi uuesti.';

  @override
  String get s6207a45bff => 'IR-lõhkepea (soojuspump)';

  @override
  String get s859c2e7734 => 'Blasteri püsivara';

  @override
  String get s3f8d3fb444 =>
      'tasmota_ http = Tasmota (tasmota-ir) IP. tasmota_ mqtt = Tasmota MQTT maakleri kaudu. esphome = ESPHome climate_ ir. http/ mqtt = muu blaster oma mallidega.';

  @override
  String get s4fb133b1c8 => 'Tasmota (HTTP)';

  @override
  String get sdd5d31034c => 'Tasmota (MQTT)';

  @override
  String get see30b7398b => 'ESPHome';

  @override
  String get scb2d23e10b => 'Kohandatud HTTP';

  @override
  String get s5c6c30aac6 => 'Kohandatud MQTT';

  @override
  String get s38471ae691 => 'Lõhkeaine aadress';

  @override
  String get sda91fafa54 => 'IR blasteri IP-aadress (Tasmota või ESPHome).';

  @override
  String get sf9220a3e4d => 'Kaubamärk IR protokoll';

  @override
  String get s423f2576c4 =>
      'Tasmota IRhvac müüja, nt MITSUBISHI_AC, PANASONIC_AC, DAIKIN. Kui midagi ei juhtu, proovige sama kaubamärgi mõnda muud protokolli.';

  @override
  String get s74ff2fd8a8 => 'Mudel (valikuline)';

  @override
  String get sef4c0e5d90 =>
      'Mõne kaubamärgi IRhvac Mudeli number. Kui pole kindel, jäta tühjaks.';

  @override
  String get s8e7962c184 => 'Tasmota';

  @override
  String get s5ae4cc50db =>
      'Ainult MQTT: alates Tasmota (Configuration → MQTT → Topic).';

  @override
  String get sed30580f59 => 'MQTT maakleri aadress';

  @override
  String get s744ce256bb => 'Ainult MQTT: masin, mis juhib maaklerit.';

  @override
  String get se6754df705 => 'MQTT port';

  @override
  String get sbfc8ee6c86 => 'Kasutajanimi';

  @override
  String get s711670d91a => 'MQTT või veebikasutaja.';

  @override
  String get s3bbd70773d => 'Jäetakse tühjaks, kui seda ei ole vaja.';

  @override
  String get s443fe6f350 => 'ESPHome kliima ID';

  @override
  String get s62feae1a9f => 'Ainult ESPHome: kliimaobjekti ID.';

  @override
  String get se0efd6dfb3 => 'Käsu URL (muu lõhkaja)';

  @override
  String get s5366cbd4df =>
      'Ainult http: URL, mis saab täieliku oleku. Kohatäitjad on loetletud.';

  @override
  String get sce533db7c1 => 'Kasuliku koormuse šabloon (muu lõhkaja)';

  @override
  String get s0fa691e7c7 =>
      'http body või mqtt payload. Tühi = IRhvac JSON ({\'{json}\'}).';

  @override
  String get s8567c5faa6 =>
      'Kokkuvõte = täielik olek tekstina. ruum = lõhkaja temperatuuriandur. Muud = viimane saadetud seadistus.';

  @override
  String get s5d329a0fea => 'Kokkuvõte';

  @override
  String get s5db6506824 => 'Temperatuuri määramine';

  @override
  String get s018d2e08f4 => 'Ventilaator';

  @override
  String get s051944392f => 'Toatemperatuur';

  @override
  String get sdd8cd8132c => 'Mida muuta';

  @override
  String get s2e8b846390 =>
      'Kogu olek saadetakse alati korraga. Väärtus tuleb plaadilt või \"Väärtus\".';

  @override
  String get sb517d97868 =>
      'Nt kuumus, jahutus, automaatne, kuiv, ventilaator või sisse/välja lülitatud. Tühi = plaatide väärtus.';

  @override
  String get sda4a1b2eee => 'Õppitud kood';

  @override
  String get s0cfc723aa2 =>
      'Täidetud, kui salvestad õpitud kaugnupu. Saadetud Tasmota IRsendiga.';

  @override
  String get s3f26cb7602 => 'EsPHome nupp';

  @override
  String get sc71964f422 => 'Ainult ESPHome: õpitud koodi malli nupu ID.';

  @override
  String get s852a166240 => 'Lõhkeaine aadress on kadunud.';

  @override
  String get s75ce01c354 => 'Tasmota vajab veebiparooli.';

  @override
  String sf9d84ad23c(String p0) {
    return 'Tasmota ei tea $p0 Paigalda tasmota- i ehitamine.';
  }

  @override
  String sff167aa9a6(String p0) {
    return 'Tasmota lükkas käsu tagasi: $p0';
  }

  @override
  String s385c6a9a2d(String p0) {
    return 'Tundmatu müüja \"$p0\".';
  }

  @override
  String sb4ea2389cb(String p0) {
    return 'ESPHome kliimat \"$p0\" ei leitud.';
  }

  @override
  String get s34deda2c72 => 'Käsu URL puudub.';

  @override
  String get s04e4777aea => 'Temperatuur puudub.';

  @override
  String get sfce1a094cb => 'Lõhkeainel pole temperatuuriandurit.';

  @override
  String s4536eb33dd(String p0) {
    return 'Temperatuuri ei saadud.';
  }

  @override
  String get s9b5bbfa2c6 => 'Toatemperatuur ainult Tasmota/ESPHome\'ist.';

  @override
  String get s5acc16dafb => 'RF433 vajab Tasmotat.';

  @override
  String get s8478662ad1 => 'Õpetatud koodid vajavad Tasmotat.';

  @override
  String s9f8263b5a0(String p0, String p1) {
    return 'ESPHome nuppu \"$p0\" ei leitud.';
  }

  @override
  String s3296e8d7e7(String p0) {
    return 'Koodi ei ole $p0 s. Suunake pult otse lõhkajale (alla 1 m) ja vajutage uuesti.';
  }

  @override
  String get s1e73ba395d => 'RF433 õppimine vajab Tasmotat.';

  @override
  String get scc47b4b225 => 'Õppimine töötab Tasmota ja ESPHome blastersiga.';

  @override
  String s96adaaf2b6(String p0, String p1, String p2) {
    return '✓ Tasmota vastas (versioon $p0). Testitud: olek 0 at $p1. Soojuspumbale ei saadetud midagi.';
  }

  @override
  String sfce5c770f1(String p0) {
    return 'Maakler OK, aga Tasmota \"$p0\" ei vastanud.';
  }

  @override
  String s2c3b95a054(String p0) {
    return 'Tasmota \"$p0\" vastas MQTT kaudu, soojuspumbale ei saadetud midagi.';
  }

  @override
  String scf9ead3297(String p0, String p1, String p2, String p3) {
    return '✓ ESPHome kliima \"$p0\" leiti. Midagi ei saadetud.';
  }

  @override
  String get s8ad50358b9 =>
      'Teiste lõhkajate testi ei tehta: IR on ühesuunaline. Vajutage toiteplaati ja jälgige soojuspumpa.';

  @override
  String s3b476099a2(String p0) {
    return 'Seade vastas HTTP $p0. Kas web_ server on ESPHome\' is lubatud?';
  }

  @override
  String sd44aec7380(String p0) {
    return 'Ei mingit vastust $p0.';
  }

  @override
  String s120026628c(String p0) {
    return '$p0 hankimine nurjus.';
  }

  @override
  String get s43c9b88580 => 'Auto';

  @override
  String get s36fb6ba26f => 'Modbus TCP';

  @override
  String get sa70cc38354 => 'Peremees';

  @override
  String get sdc5301b750 => 'Ühiku ID';

  @override
  String get s15e327bf8e => 'Aegumine (ms)';

  @override
  String get s666811be3d => 'Raamimine';

  @override
  String get s0f2d3b7a42 =>
      'Odav RS485 kuni Wi-Fi / Etherneti muundur läbipaistvas režiimis kasutab RTU kaadreid.';

  @override
  String get s12ca822cd8 => 'Modbus TCP (normaalne)';

  @override
  String get s731c92978b => 'Modbus RTU üle TCP (RS485 värav)';

  @override
  String get s570f11bec8 => 'Minimaalne lugemisintervall (s)';

  @override
  String get s13e54dbff1 =>
      'Sama registrit ei loeta kunagi sagedamini, kui paljud kaardid seda näitavad.';

  @override
  String get s95d4c6dd5b => 'Paus taotluste vahel (ms)';

  @override
  String get s77b6667fdb => 'Oodake pärast ühendamist (ms)';

  @override
  String get sf4b0409574 => 'Külgnev partii loeb';

  @override
  String get sc011aad1a9 => 'Maksimaalne registreerimine lugemise kohta';

  @override
  String get s942a690567 => 'Lukustuspaus alguses (s)';

  @override
  String get s3746551251 =>
      'Kui seade ei vasta, jäetakse see mõneks ajaks üksi. Paus kahekordistab maksimumi.';

  @override
  String get sf71d800450 => 'Lukustuspaus kõige rohkem (s)';

  @override
  String get sbce68f8691 => 'Ühenduse sulgemine pärast viga';

  @override
  String get sf96bb0c03d => 'Tühja vastuse uuesti proovimine';

  @override
  String get s943b8b6bf3 => 'Registritabel';

  @override
  String get s8283ed1c89 => 'Põllumajandusettevõtete register (4x)';

  @override
  String get s94cf36d710 => 'Mähis (0x)';

  @override
  String get sfb6d4a8639 => 'Sisendregister (3x)';

  @override
  String get s0bbedf814a => 'Diskreetne sisend (1x)';

  @override
  String get sf51ad986eb => 'Aadress (0-põhine)';

  @override
  String get s601f118ac0 => 'Andmetüüp';

  @override
  String get sddd62d21b0 => 'Vahetussõnad (CDAB)';

  @override
  String get see24ec5d84 => 'Skaala';

  @override
  String get s0a239b832b => 'Offset';

  @override
  String get s5f374d3643 => 'Ühiku ID (tühi = ühendus)';

  @override
  String get sef11962984 => 'Kirjuta';

  @override
  String get s779b59ba4b => 'Väärtus ({\'{value}\'} = liugur/lülitus)';

  @override
  String get sefaea1b818 => 'ntfy (teatekanal / käsud)';

  @override
  String get s6a4516e0fe => 'Käsu teema (nimi või täielik URL)';

  @override
  String get se003ecc10b =>
      'Topic käsud saadetakse. Sa võid asetada kogu URL- i, nt https://ntfy.sh/my- teema – sama, mida kasutab sinu iPhone\' i kiirklahv. Teema nimi töötab nagu parool: hoia see pikk ja juhuslik.';

  @override
  String get s800cd08229 => 'Vastamise teema (valikuline)';

  @override
  String get s2e3a66d384 =>
      'Kui koduseade vastab mõnele muule teemale, kirjuta see siia. Jäta tühjaks, kui vastus tuleb samale teemale – siis ignoreeritakse meie enda käsku ja järgmist teadet näidatakse vastusena.';

  @override
  String get s5bc736c04a => 'Juurdepääsuluba (valikuline)';

  @override
  String get s77feae14f5 =>
      'Vajalik ainult kaitstud teema puhul (ntfy konto → Access tokens). Avaliku teema puhul jäta tühjaks.';

  @override
  String get seca0d75969 =>
      'Vaikimisi on avalik ntfy.sh. Muuda ainult enda ntfy serverit. Selle tühistab ülal asuv täielik URL.';

  @override
  String get sddbea594a4 =>
      'latest = uusim sõnum, log = mitu hiljutist sõnumit (uusim esimene).';

  @override
  String get s580abde883 => 'Viimane teade';

  @override
  String get sf6455b6631 => 'Kirjade logi';

  @override
  String get s2bd0e69d44 => 'Teema (valikuline)';

  @override
  String get s4eb1e8ac15 =>
      'Loetav teema. Tühi = ühenduse vastuse teema (või käsuteema).';

  @override
  String get s09fa5c0332 => 'Teadete arv (log)';

  @override
  String get s17fda9fb06 => 'Mitut hiljutist sõnumit logi näitab.';

  @override
  String get s78f2f0d783 => 'Kui kaugele tagasi?';

  @override
  String get s79bdbfd820 =>
      'Nt 30 m, 12h või 2d. Avalik ntfy.sh hoiab sõnumeid umbes 12 tundi.';

  @override
  String get sfe357edcec => 'Käsk (saadetav tekst)';

  @override
  String get s48e102023d =>
      'Saadatav tekst, nt \"uuendamine\". PIN-koodiga lisatakse see tühiku järele: \"uuendamine 1234\".';

  @override
  String get saf2ebedf61 => 'PIN-koodi küsimine ajakirjanduses';

  @override
  String get sfcb5608064 =>
      'Palub PIN-koodi (peidetud) igale vajutamisele ja lisab selle käsule. PIN- koodi ei salvestata, kui sa ei vali \"Mäleta seda seadet\".';

  @override
  String get sfee393b70e => 'Oota vastust';

  @override
  String get sfff5bc52e5 =>
      'Kuulab koduseadme vastust ja näitab seda selles plaadis (ja teatena, kui rakendus on taustal).';

  @override
  String get sbdcbe301b9 => 'Oodata vastust (s)';

  @override
  String get s121542d6d7 =>
      'Kui kaua oodata, enne kui öelda, et vastust ei tulnud.';

  @override
  String get sa53638cfea => 'Vastus jääb plaadile (plaatidele)';

  @override
  String get se6d21484a8 =>
      'Kui kaua vastus jääb plaadile. 0 = kuni järgmise vajutamiseni.';

  @override
  String get s74d68a98d6 => 'Teate pealkiri (valikuline)';

  @override
  String get sc2492ac3ab => 'ntfy kirja pealkiri. Tavaliselt tühi.';

  @override
  String s54ea45f27f(String p0, String p1) {
    return 'ntfy: teema \"$p0\" on kaitstud (HTTP $p1). Lisa ühendusele ligipääsumärk (tk_...).';
  }

  @override
  String get s72c37e530d =>
      'ntfy: liiga palju kirju (HTTP 429). Oota üks hetk ja proovi uuesti.';

  @override
  String get s0870daf796 => 'ntfy: käsuteema puudub';

  @override
  String get s28dc7ea012 => 'ntfy: ühendus suleti enne vastust';

  @override
  String sa4313864fe(String p0, String p1) {
    return 'Käsk saadeti, kuid vastust ei tulnud $p0 s jooksul. Kontrollige, kas koduseade on sisse lülitatud ja kuulake \"$p1\".';
  }

  @override
  String get s85a1947a44 => '(teateid ei ole)';

  @override
  String get s7069b18b7d => 'ntfy: käsu tekst puudub';

  @override
  String s43de3fd299(String p0) {
    return ' Vasta teema: $p0.';
  }

  @override
  String s9ed9eb7f92(String p0, String p1, String p2, String p3) {
    return '✓ ntfy server $p0 vastas ja teema \"$p1\" on loetav ($p2 sõnumid viimases tunnis).$p3 Käsku ei saadetud - koputage plaati proovida.';
  }

  @override
  String get sf0ef0140c3 => 'Home Assistant';

  @override
  String get s1f90ee6992 => 'Pikaajaline juurdepääsuluba';

  @override
  String get sccb0cca8e3 => 'Otseuudised (veebipesa)';

  @override
  String get s8f8e1cfad3 => 'Üksuse identifitseerimiskood';

  @override
  String get s382111aebc => 'Atribuut (tühi = olek)';

  @override
  String get sf500d0ad67 => 'Service';

  @override
  String get s7286715019 => 'Lisaandmed JSON ({\'{value}\'} = väärtus)';

  @override
  String get s1b5b0421c0 => 'Kasulik koorem';

  @override
  String get s44ab1d33df => 'Oota vastust';

  @override
  String get s341bf61e36 => 'Reageerimine kuusena';

  @override
  String get se7cff2d61e => 'TCP (toores)';

  @override
  String get s1dfeacd9f6 => 'UDP';

  @override
  String get sd76aadb97c => 'Veeleke → alarm';

  @override
  String get s0bd0724e83 =>
      'Kiireloomuline teade niipea, kui lekkeandur tuvastab vee (ka vaiksel ajal).';

  @override
  String get sa9f114c81d => 'Tuled põlevad päikeseloojangul';

  @override
  String get s02402a38eb => 'Valitud tuled lülituvad sisse, kui päike loojub.';

  @override
  String get s386fda8330 => 'Kõik maha kell 23:00';

  @override
  String get s3508664550 => 'Valitud seadmed lülituvad välja õhtul.';

  @override
  String get s3775470669 => 'Teatamine, kui seade ei vasta enam';

  @override
  String get s5c07969ac8 =>
      'Teade, kui seade on olnud 10 minutit kättesaamatu.';

  @override
  String get s2cdd15be92 => 'Märguanne, kui temperatuur langeb';

  @override
  String get sa74faa4635 => 'Märge, kui anduri näit langeb alla piiri.';

  @override
  String get s94ed692877 => 'Odavamad töötunnid: seade on sisse lülitatud';

  @override
  String get s9b99909a7c =>
      'Seade päeva kõige odavamatel tundidel (nt veesoojendi).';

  @override
  String get s90d5d2954d => 'Teavitada kallist elektrist';

  @override
  String get s876690515a => 'Teade, kui hetkehind ületab 20 c/kWh.';

  @override
  String get s1906ecb28c => 'Külmumishoiatus';

  @override
  String get s036ecd266d => 'Märge, kui see on väljaspool −15 °C.';

  @override
  String get sacf213e078 => 'Hommikune kokkuvõte kell 7:00';

  @override
  String get sef21ad6784 =>
      'Ilm, elektri hind ja teie kodu seisund teatena igal hommikul.';

  @override
  String get s5d308e6986 => 'VEELEK!';

  @override
  String get s13017ce3b0 => 'Temperatuur langes';

  @override
  String get s4c52f38c8b => 'Elekter on kallis';

  @override
  String get sc797ab9c4c => 'Tere hommikust';

  @override
  String get scec02139b6 => 'Kaart kadunud';

  @override
  String get s66f19d787b => 'Grupp ei vasta';

  @override
  String sed9788d6dc(String p0) {
    return '$p0: käsku pole';
  }

  @override
  String sd39874fbe2(String p0) {
    return '$p0 seadmed';
  }

  @override
  String sbe208615d0(String p0) {
    return '$p0 ei vasta';
  }

  @override
  String get s589eb1bcd3 => 'Koduabiline (näide)';

  @override
  String get sc4fdb87cd7 => 'Kaamera (näide)';

  @override
  String get sd50566a706 => 'Ventilatsiooniseade (näide)';

  @override
  String get s4b4fd14aaf => 'Õu';

  @override
  String get s8ac16d45bc => '';

  @override
  String get sbde42d83a3 => 'Elutoa valgustid';

  @override
  String get sb7c78c63b3 => 'Sissepuhkeõhk';

  @override
  String get sbb2adef009 => 'Ventilaatori kiirus';

  @override
  String get see46441329 => '0=Off;1=Away;2=Home;3=Boost;4=Max';

  @override
  String get sb25aad3bc2 => 'Lahkun kodust';

  @override
  String get s7e5f6a29e3 => 'Head ööd';

  @override
  String get s253122823a => 'Tere hommikust';

  @override
  String get s640293f08f => 'Tere päevast';

  @override
  String get sd8c5bed7de => 'Tere õhtust';

  @override
  String get s4cac4725b8 => 'Grupi seadmed ei vasta';

  @override
  String get s13a91fe322 => 'Juhtseadis puudub';

  @override
  String get s7e461faf91 =>
      'Leia see ruuteri seadmete nimekirjast või seadme rakendusest. Samuti võid puudutada nuppu \"Otsi võrku\".';

  @override
  String get saf4b222a68 => 'Seadme IP-aadress';

  @override
  String get s1bbea216af => 'ESP32-CAM-kaamera';

  @override
  String get saaaeccd0cc => 'Odav Wi-Fi kaamera. Näitab live- videot.';

  @override
  String get saaea39b2de => 'Kaamera IP aadress';

  @override
  String get s6ef2a3f197 =>
      'Näidatakse jadamonitoris alglaadimisel või ruuteri seadmete loendis.';

  @override
  String get sae199413a2 => 'Nt Yard, Hallway.';

  @override
  String get s2dd165b39f => 'Pilditüüp';

  @override
  String get sb66b153f36 =>
      'mjpeg = live video (soovitatav). snapshot = ikka pilt iga paari sekundi tagant.';

  @override
  String get sf81257929d => 'Shelly relee / pistikupesa';

  @override
  String get s2b8ab6defc =>
      'Lülitage valgus või seade sisse/välja ja näidake toidet.';

  @override
  String get s7fcea114f0 => 'Mida see juhib?';

  @override
  String get s864ba0233b =>
      'Uuem (Plus, Pro, Gen3) = Plus / Pro / Gen2+. Old Shelly 1, 2.5, Plug S = Gen1.';

  @override
  String get s92f97cd95e => 'Võimsuse näitamine (W)';

  @override
  String get s54c71d86aa => 'Ainult mõõtmisega (nt pluss 1PM) mudelite puhul.';

  @override
  String get s49671fc56f => 'Kanal';

  @override
  String get s06f8a27d8a => 'Mitmekanaliliste seadmete puhul: 0 = esimene.';

  @override
  String get s259e46c59a => 'Ainult siis, kui määrad parooli.';

  @override
  String get sc130e073ba => 'Relee või pistik töötab Tasmota firmware.';

  @override
  String get s70d8cb97e6 => 'Releed';

  @override
  String get s7a4c459c3a =>
      'Tühi = iga relee, millest seade teatab (avastati automaatselt). Kitsas see: \"1\", \"1,2,4\", \"1-4\" või \"kõik\".';

  @override
  String get s5f1e4a036e => 'Veebiparool';

  @override
  String get s397e83233d =>
      'Ainult siis, kui veebiparool on seadistatud (kasutaja admin).';

  @override
  String get sa0efcdf688 =>
      'ESP32/ESP8266 koos ESPHome\'iga (web_server lubatud).';

  @override
  String get s631420589f => 'Seadme nimi';

  @override
  String get s1db899640b => 'Lülitumise ID (valikuline)';

  @override
  String get sb2e87033fc =>
      'Lüliti nimi YAML-ist väiksemal juhul alakriipsuga.';

  @override
  String get s978ae8f1d6 => 'Anduri ID (valikuline)';

  @override
  String get s4ba12c5866 => 'Anduri nimi samamoodi (vaata seadme veebilehte).';

  @override
  String get s945273ef29 => 'Sensoriüksus';

  @override
  String get s5ca2e25792 => 'Ainult siis, kui web_ server autth on määratud.';

  @override
  String get sb847f22473 => 'Veebi kasutajanimi';

  @override
  String get s76f6067b0f =>
      'Tuled, alarm, andurid - vali nimekirjast, millised neist saavad kaardid.';

  @override
  String get s9f70681d3f => 'Koduabilise aadress';

  @override
  String get s123502628e => 'Aadress, millega avad koduabilise.';

  @override
  String get s92e3c4cd40 => 'Pikaealine märk';

  @override
  String get s4e3f2052b2 =>
      'Home Assistant → oma profiili → Turvalisus → Pikaajaline juurdepääsu märgid → Loo token. Paiguta siia.';

  @override
  String get s54e063bd9c => 'Soojuspump (koduabiline)';

  @override
  String get s2afe650320 =>
      'Õhksoojuspump, mida näidatakse Home Assistantis kliimaüksusena.';

  @override
  String get s48fdd98530 =>
      'Kui see on juba lisatud, kasutatakse sama ühendust uuesti.';

  @override
  String get sfe5ad3202f => 'Ei ole vaja, kui HA on juba lisatud.';

  @override
  String get sce069d8d1a => 'Soojuspumba seade';

  @override
  String get s05e2aaa15c => 'Algab kliimast.';

  @override
  String get se699281c85 => 'Soojuspump (MQTT)';

  @override
  String get s8643040b95 =>
      'Nt mitsubishi2mqtt või sarnane ESP kontroller. Teemad on näited – kontrolli.';

  @override
  String get s2a1148ee77 => 'MQTT maakleri IP';

  @override
  String get s53e472c976 => 'Masin töötab Mosquitto (sageli HA kasti).';

  @override
  String get s29aff3d2a0 => 'MQTT kasutajanimi';

  @override
  String get s37e57de4b9 => 'Jäetakse tühjaks, kui seda ei nõuta.';

  @override
  String get sffe00ea1b3 => 'MQTT parool';

  @override
  String get s407d4a5e56 => 'Baasteema';

  @override
  String get sc1af622c0a =>
      'Kontrollija seadistustest. Olek: <base>/state, käsud: <base>/set.';

  @override
  String get s9783a8fd53 => 'tuba';

  @override
  String get sbc996a7d25 => 'seadeväärtus';

  @override
  String get sa69c0e1ca3 => 'Õhksoojuspump (IR)';

  @override
  String get s025e7bf04d =>
      'Iga kaugjuhitava soojuspumba juhtimine infrapunalõhkeseadmega (Tasmota või ESPHome). IR on ühesuunaline: Molaplan näitab, mida ta viimati saatis.';

  @override
  String get sb5d4127728 => 'IR-purjetaja';

  @override
  String get sc899cf95db =>
      'Enamik valmis IR-lõhkeseadmeid käivitab Tasmota (kasuta tasmota-ir ehitamist). ESPHome = sinu ESPHome- seade koos kliima_ ir- ga.';

  @override
  String get sc096a735fd => 'IR-saatja IP. MQTT puhul maakleri aadress.';

  @override
  String get safc7f1325c => 'Soojuspumba kaubamärk';

  @override
  String get s7675ec1754 =>
      'Vali seadme mark või pult. Kui see ei reageeri, proovi alternatiivse protokolliga \"Muu\".';

  @override
  String get s9702830f91 => 'Protokoll (ainult \"Muu\")';

  @override
  String get s6df0837908 =>
      'Tasmota IRhvaci müüja nimi. Vajalik ainult \"Muu\" jaoks või teise proovimiseks.';

  @override
  String get saa49bfdb90 => 'Näidatud plaatide pealkirjades.';

  @override
  String get sf1971ac29b => 'Tasmota teema (ainult MQTT)';

  @override
  String get s65529d5877 =>
      'Tasmota → Configuration → MQTT → Topic. Muu MQTT-saatja: käsuteema.';

  @override
  String get s321c1677e2 => 'Esfome climate id (ainult Esfome)';

  @override
  String get s4c07dec7b5 =>
      'Climate_ i objekti ID, mida näidatakse seadme veebileheküljel.';

  @override
  String get s2229e548f3 => 'MQTT või veebikasutaja.';

  @override
  String get s06cff48000 => 'Käsu URL (ainult muu HTTP)';

  @override
  String get s5b41e244d6 =>
      'Kohatäitjad: {\'{power}\'} {\'{mode}\'} {\'{temp}\'} {\'{fan}\'} {\'{swing}\'} {\'{vendor}\'} {\'{json}\'}.';

  @override
  String get s9a60c2026e => 'Režiiminupud';

  @override
  String get sd119ce3382 =>
      'Nööbid soojuse, jahutuse, auto, kuiva ja ventilaatori jaoks.';

  @override
  String get s9b8dd7076a => 'Ventilaatori kiirus';

  @override
  String get s9597aa1ae9 => 'Liugur 0–5 (0 = auto).';

  @override
  String get secae50c5dd => 'Õõtsumine';

  @override
  String get s8bcb8433f9 => 'Valjuhääldumine sisse/välja.';

  @override
  String get s78a5e5fa61 => 'Toatemperatuur lõhkamissensorist';

  @override
  String get s2dd6395602 => 'Ainult siis, kui lõhkajal on temperatuuriandur.';

  @override
  String get s4ff78f06ab => 'Õhksoojuspump (teenindusport / ESPHome)';

  @override
  String get s6cc7b6b499 =>
      'ESPHome kontroller siseseadme teeninduspordis (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba).';

  @override
  String get s647e86e5e5 => 'Kliima ID';

  @override
  String get sbeb6af1e1c =>
      'ESPHome\'i seadme kliimaüksus. \"Leia teejuhis soojuspumbad\" leiab selle sinu eest.';

  @override
  String get sbf36d139cb => 'Ainult siis, kui web_serveril on auth.';

  @override
  String get s54d4fdbba4 => 'Ainult siis, kui web_serveril on auth.';

  @override
  String get s84cd6a5180 => 'RF433 pult (Athom IR & RF)';

  @override
  String get s4105198757 =>
      'RF433 raadiokaugseadmete (pesad, varikatused, garaažiuksed) juhtimine Athomiga \"Tasmota IR & RF433 kontroller\". Nupud õpetatakse kohe pärast lisamist.';

  @override
  String get sbc2bf08889 => 'Athomi kontrolleri IP.';

  @override
  String get sc34430eec0 => 'Nt mida sa kontrollid.';

  @override
  String get s12447972e0 => 'Ainult siis, kui on määratud Tasmota veebiparool.';

  @override
  String get s6385f1487e => 'Elektri hind (börs)';

  @override
  String get sead3949d3c =>
      'Tänane ja homne hetkehind 15-minutilise eraldusvõimega: trend Now rea ja/või baaridega. Hinnakontroll: seadmekaardi kaugvajutamine → Hinnakontroll.';

  @override
  String get sef8d24c969 => 'Riik / hinnapiirkond';

  @override
  String get sef4f509f9f => 'Valige oma riik; Rootsis ja Norras oma piirkond.';

  @override
  String get sf3a8631d14 =>
      'Teie arvelt koos käibemaksuga. 0 = ainult energia.';

  @override
  String get sf3be8aac1c => 'Teie lepinguline marginaal ilma käibemaksuta.';

  @override
  String s49dfca65a3(String p0) {
    return 'Elektri hind $p0';
  }

  @override
  String get sfb2b7ccc87 => 'Hinnasuundumus';

  @override
  String get s4790164c94 => 'Täna ja homme graafik';

  @override
  String get sd408a5dbe9 => 'Odavamad tunnid';

  @override
  String get s7ba83434d1 => 'Õhk (radoon ja õhukvaliteet, pilv)';

  @override
  String get s39e8df2552 =>
      'View Plus, View Radon, Hub ja kõik sinu kontol olevad monitorid. Wi-Fi mudelitel ei ole kohalikku rakendusliidest, nii et väärtused pärinevad ametlikust Airthingsi rakendusliidesest, millel on sinu enda volikiri.';

  @override
  String get sbafe369760 =>
      '1) Ava vaade.airthings.com ja logi sisse oma Airthingsi kontoga. 2 Integratsioonid → API → Loo klient (\"Uus API klient\"). 3 Nimeta see nt Molaplan, vali Voo tüüp \"Kliendi volikiri\" ja luba see. 4 Kopeeri kliendi ID siit.';

  @override
  String get sb6a852ab13 =>
      '5) Kopeerib kliendi saladuse samast vaatest. See salvestatakse ainult sellesse seadmesse ja krüptitakse sinu kontol.';

  @override
  String get sc76f519144 =>
      'Wave, Wave Plus, Wave Mini ja Wave Radon kasutavad ainult Bluetoothi. Seda loeb Android-seade või kodusild (nt seinatahvel) umbes 10 m raadiuses.';

  @override
  String get sff5f25f96f =>
      'Monitori tagaküljel (10 numbrit). Algus ütleb mudelile: 2930 = Wave Plus, 2950 = Wave Radon, 2920 = Wave Mini.';

  @override
  String get s8de2de9178 => 'Loe läbi kodusilla';

  @override
  String get s5e605a88ef =>
      'Kui kodusild (nt seinatahvel monitori lähedal) teeb Bluetoothi lugemist.';

  @override
  String get s3330126b01 => 'Ventilatsiooniseade või soojuspump (Modbus TCP)';

  @override
  String get sc16ab2836c =>
      'Temperatuurid, ventilaatori kiirus ja seadistused. Valmis registrikaardid kaubamärkidele (Airfi, Vallox, Enervent, Swegon, Flexit, Ilto, Nilan, NIBE, Thermia) – kontrolli oma käsiraamatust.';

  @override
  String get sb75966bb58 => 'Ühiku või lüüsi IP';

  @override
  String get s751331a84a =>
      'Kui seadmel on ainult RS485, on vaja RS485 → Modbus TCP väravat. Sisesta selle IP.';

  @override
  String get s658cdb6ff8 => 'Kaubamärk';

  @override
  String get s785c0c264c =>
      'Valige bränd, et eeltäita registrid näitena. \"—\" = tühi.';

  @override
  String get s7e9c785c20 => 'Sageli 1.';

  @override
  String get s0591744c19 => 'Peaaegu alati 502.';

  @override
  String get s5ccb7405cf => 'Ventilatsioon';

  @override
  String get se7dfa3594e => 'MQTT-seade';

  @override
  String get s12ab103795 =>
      'Iga seade, mis räägib MQTT (Zigbee2MQTT, oma ESP, ...).';

  @override
  String get sffcfefd91c => 'Masin, mis töötab MQTT maakleriga.';

  @override
  String get s6ac05d979c => 'Mis see on?';

  @override
  String get s460d48d0cc => 'lüliti = sisse/ välja, andur = näitab väärtust.';

  @override
  String get s850c7e1194 => 'Oleku teema';

  @override
  String get s49b7311a1e => 'Teema, kus seade teatab oma olekust.';

  @override
  String get s579969e7e4 => 'Käsu teema (lüliti)';

  @override
  String get s137db4076a => 'Sisse- ja väljalülitamiskäsu teema.';

  @override
  String get s4c95226869 => 'Teates';

  @override
  String get s70f2ea8532 => 'Väljalülitatud teade';

  @override
  String get sdc234849ac => 'JSON';

  @override
  String get sd3f60d4a71 => 'Kui sõnum on JSON, siis välja nimi.';

  @override
  String get s6cee917658 => 'Ühik (sensor)';

  @override
  String get s3cd541d271 => 'Muu Wi-Fi-seade (HTTP)';

  @override
  String get s69885630aa =>
      'Seade, millel on veebi rakendusliides. Näitab üht väärtust, lisab hiljem veel plaate.';

  @override
  String get s200320e245 => 'Oleku tee';

  @override
  String get sc5872d2e30 =>
      'Kus seade teatab oma olekust. Tühjus = pole plaati.';

  @override
  String get s5564de12b2 => 'Väli näitamiseks';

  @override
  String get s377942beb7 => 'Välja nimi vastuses.';

  @override
  String get sbaf1a279c2 => 'Käsk ja vastus (ntfy)';

  @override
  String get se0fb2c7eea =>
      'Saada käsk ntfy sõnumina (nt \"update\" + PIN) ja vaata koduseadme vastust samas plaadis. Sama kanal kui iPhone\'i kiirklahv.';

  @override
  String get s8231329360 => 'Käsuteema URL';

  @override
  String get s206ac44298 =>
      'Aseta sama URL, millele kiirklahvi postitused käske annavad (nt https://ntfy.sh/oma-aihe). Ka teema nimi üksi töötab.';

  @override
  String get s1b3bbae234 =>
      'Ainult siis, kui koduseade vastab mõnele muule teemale. Tühi = sama teema, ignoreeritakse meie enda käsku.';

  @override
  String get s1b08aa4646 =>
      'Tekst, mida näidatakse plaadil, nt \"Uuendamine\" või \"Status\".';

  @override
  String get s5bed8bff00 => 'Käsk';

  @override
  String get se2a81ae67d =>
      'Saadetav tekst. PIN- kood lisatakse tühiku järele, nt \"uuendamine 1234\".';

  @override
  String get s1477964f04 => 'PIN-koodi küsimine igal pressil';

  @override
  String get s62672283f6 =>
      'PIN-koodi küsitakse peidetud ja seda ei salvestata, kui te ei vali \"Mäleta seda seadet\".';

  @override
  String get sb5e914eaf7 =>
      'Ainult kaitstud teema puhul. Jäta tühjaks avaliku teema puhul.';

  @override
  String get s1a98a7e424 => 'Lisa ka teadete logiplaat';

  @override
  String get s5ab6348524 => 'Näitab teema viimaseid sõnumeid oma plaadil.';

  @override
  String get s57e684ac9e => 'Sõnumid';

  @override
  String s3378eb2d0b(String p0) {
    return '$p0 – temperatuur';
  }

  @override
  String get saa437260b8 => 'Saadetud olek (IR on ühesuunaline)';

  @override
  String get seab2c72485 => 'Ventilaator (0 = automaatne)';

  @override
  String s3a38b97f7b(String p0) {
    return '$p0 – ruum';
  }

  @override
  String get s0ceafaa97c => 'energia';
}
