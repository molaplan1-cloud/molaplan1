// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get sc1e35d5171 => 'Pristjänsten';

  @override
  String get s8b22e8d330 => 'Vädertjänsten';

  @override
  String get s252ebed5af => 'Shelly Cloud';

  @override
  String get s10edebf3fa => 'ntfy server';

  @override
  String get sc08176420f => 'Airthings moln';

  @override
  String get sd3d9c263ed => 'Tjänsten';

  @override
  String get sedeaf26f8a => 'ntfy meddelande gräns nådde';

  @override
  String get s5d151d0815 =>
      'ntfy.sh tillåter 250 meddelanden per 12 timmar från ditt hems offentliga IP (alla telefoner, surfplattor, datorer och enhetens egna svar tillsammans). Meddelanden frigörs några minuter - appen frågar nu för staten mindre ofta. En bestående fix: din egen ntfy-server eller ett ntfy-konto med en högre gräns.';

  @override
  String get s349ca716f2 => 'Inget svar från enheten';

  @override
  String get s7aa9e16c41 =>
      'Kommandot nådde ntfy-servern, men inget svar kom från enheten. Kontrollera anslutningens \"Reply-ämne\" - enheten kan svara på ditt eget anmälningsämne - och att enheten är online.';

  @override
  String get sdfb639365a => 'Ingen internetanslutning';

  @override
  String s390dd51af3(String p0) {
    return '$p0 är på internet och kan inte nås. Kontrollera den här enhetens internetanslutning. De senaste uppgifterna visas när de är tillgängliga.';
  }

  @override
  String sbb750bf9d6(String p0) {
    return '$p0 svarar inte, provar en reservkälla';
  }

  @override
  String s4284ebac1e(String p0) {
    return '$p0 svarar inte';
  }

  @override
  String get s828d009fa6 =>
      'Backup-källorna svarade inte just nu heller. Problemet är mest sannolikt på tjänsterna, inte ditt hemnätverk.';

  @override
  String get se21c801ba6 =>
      'Tjänsten har ett problem, troligtvis i tjänsten och inte ditt hemnätverk.';

  @override
  String get s35e0766add => 'Logga in på tjänsten misslyckades';

  @override
  String sa4d255e53c(String p0) {
    return 'Kontrollera kontot, nyckeln eller token för $p0.';
  }

  @override
  String get sd0a2130950 =>
      'Den väntade enheten svarar inte på den här adressen – kontrollera den (http eller https?)';

  @override
  String get sdd5742468b =>
      'Något svarar, men inte som väntat. Prova https:// eller http:// först och kontrollera porten.';

  @override
  String get s03c0a5192b => 'Adress som inte hittats';

  @override
  String get sb3ef01a6fa =>
      'Kontrollera stavningen. Prova IP-adressen (t.ex. 192.168.1.50) istället för ett namn.';

  @override
  String get s274a753ad6 => 'Enhet som inte finns på denna adress';

  @override
  String get s2b503695b6 =>
      'Kontrollera att enheten är på och att din telefon eller dator är på samma Wi-Fi. Kontrollera också IP-adressen - den kan ändras, så reservera en fast adress i routern.';

  @override
  String get sff9ca463e3 => 'Enhet hittades men hamnen är stängd';

  @override
  String get s1d4f4506de =>
      'Kontrollera portnumret och att tjänsten (webb UI, MQTT eller Modbus TCP) är aktiverad på enheten.';

  @override
  String get s8523a9cfd0 => 'Säker anslutning (https) misslyckades';

  @override
  String get sdfd499c1f1 =>
      'Prova http:// istället, eller aktivera \"Tillåt självsignerat certifikat\" under Avancerad.';

  @override
  String get s3fabccc1cd => 'Inloggning, lösenord eller token avvisas';

  @override
  String get sdc2d65f8eb =>
      'Kontrollera referenser. I Home Assistant kan du skapa en ny långlivad token i din profil.';

  @override
  String get se0a7cef6c4 => 'Enhet svarade men objektet hittades inte';

  @override
  String get see02239a35 =>
      'Kontrollera sökvägen eller företagets namn (t.ex. light.living_room).';

  @override
  String get sdec83d1e90 => 'Enheten rapporterade ett fel';

  @override
  String get s3de239ffc5 => 'Kontrollera vägen och nyttolast.';

  @override
  String get s6121e8d8f1 => 'Okänt register på enheten';

  @override
  String get s3474aedf54 =>
      'Kontrollera registret nummer. Om tabellen börjar vid 1 (t.ex. 40001), subtrahera 1. Kontrollera också innehav vs ingång.';

  @override
  String get s2c303f6774 => 'Registertyp som inte stöds';

  @override
  String get s945685fcda =>
      'Prova den andra registreringstypen (hålla inmatning).';

  @override
  String get s07ffbc349a => 'Värde som avvisas av enheten';

  @override
  String get s76b95eef9f =>
      'Värdet är förmodligen ur räckvidd. Kontrollera skalan också.';

  @override
  String get s7746921882 => 'Enhet hittas, men Modbus TCP är avstängd';

  @override
  String get s7e552bd146 =>
      'Det finns en enhet på denna adress, men det accepterar inte Modbus på denna port. Slå på Modbus TCP i enhetsinställningarna (ofta under nätverk / Modbus / fjärrkontroll) och kontrollera hamnen (vanligtvis 502). Du kan också trycka på \"Scan Modbus\". Om enheten fungerar i Home Assistant, kan det redan ha en anslutning (många tillåter bara en) - läs värdena genom HA.';

  @override
  String s0ebc613f20(String p0) {
    return 'Enheten är i lockout, retrying på $p0';
  }

  @override
  String get s317b2b59af =>
      'Enheten svarade inte, så det lämnas ensam ett tag - många enheter låser ut klienter som omröstar för ofta. Pausen växer från 30 sekunder till 5 minuter. Om enheten redan har en anslutning (t.ex. Home Assistant), läs värdena genom HA. Läsintervallet och pauserna är under Avancerade i anslutningen.';

  @override
  String get s33e09089b2 => 'Enheten adress saknas';

  @override
  String get s6180bd540e =>
      'Öppna anslutningen och ange enhet IP-adressen eller tryck på \"Scan Modbus\" för att hitta enheten i nätverket.';

  @override
  String get sd73581c910 => 'Enheten kanske redan har en anslutning';

  @override
  String get scee8d982a2 =>
      'Enheten släppte Modbus-anslutningen direkt. Många enheter tillåter endast en Modbus TCP-anslutning i taget. Om enheten redan finns i Home Assistant (t.ex. modbus.yaml), läs värdena genom HA.';

  @override
  String get s6ca672a111 => 'Ingenting på denna adress';

  @override
  String get sf7a98e1c70 =>
      'Ingenting svarade på denna IP-adress. Kontrollera att enheten är på och i samma nätverk och att IP är rätt (det kan ändras - reservera en fast adress i routern). \"Scan Modbus\" hittar enheter på nätverket.';

  @override
  String get scb0cba44ea => 'Modbus-enheten svarade inte i tid';

  @override
  String get sc03ae7e1c5 =>
      'Kunde inte öppna porten. De vanligaste orsakerna: fel IP, enheten är i ett annat nätverk (gäst Wi-Fi), Modbus TCP är avstängd eller en brandvägg blockerar porten. Kontrollera adressen och porten eller tryck på \"Scan Modbus\".';

  @override
  String get sefba540275 => 'Gateway kan inte nå en enhet med denna enhet id';

  @override
  String get s6e4ed361f3 =>
      'Modbus gateway svarade, men ingen enhet med denna enhet id ligger bakom den. Kontrollera enhetens Modbus-adress (ofta 1) och seriehastigheten och pariteten. \"Scan Modbus\" försöker adresser 1-247.';

  @override
  String get sb66bc0e677 => 'Ingen Modbus svar';

  @override
  String get s6ef5539bc2 =>
      'Ansluten men inget svar. Kontrollera enhetens id (ofta 1) och gateway-serieinställningarna.';

  @override
  String get s17ea4c52d5 => 'Inget svar från enheten';

  @override
  String get s50ecf9ba6f =>
      'Ansluten men inget svar i tid. Kontrollera meddelandet.';

  @override
  String get sf93db545a1 => 'Det finns ett misstag i inställningarna';

  @override
  String get sf19a9f0856 =>
      'Kontrollera fälten, t.ex. att adressen börjar med http:// och siffrorna är siffror.';

  @override
  String get s3976954bef => 'Denna kakel har ingen enhet';

  @override
  String get sc025e0a1f4 =>
      'Öppet redigeringsläge (penna) och välj en enhet för kakeln.';

  @override
  String get s7e11595f9e => 'Hembron är avstängd';

  @override
  String get s2cd1df086e =>
      'Fjärråtkomst går igenom bron hemma (tablet eller PC). Kontrollera att det är på, Molaplan är öppen och det har internet.';

  @override
  String get sdbf06d05d9 =>
      'Din enhet kan inte nå Molaplan fjärrtjänst. Kontrollera mobildata eller Wi-Fi.';

  @override
  String get s8b737f4026 => 'Fjärråtkomst togs bort';

  @override
  String get s4b9e4ca079 =>
      'Den här enheten togs bort på hemmabron. Par igen: Inställningar → Fjärråtkomst.';

  @override
  String get s5b3116ed94 => 'Hembron svarade inte i tid';

  @override
  String get se082095a34 =>
      'Anslutningen kan vara långsam. Försök igen i ett ögonblick.';

  @override
  String get s688a4f4ccb => 'Koden är inte giltig';

  @override
  String get sfa0e226cd0 =>
      'Kontrollera 6 siffror på bryggskärmen. En kod är giltig i 10 minuter och fungerar en gång - tryck på \"Paira en telefon\" på bron igen om det behövs.';

  @override
  String get sfa5c1fb1ac => 'Bron accepterade inte denna enhet';

  @override
  String get s9ad07ab36e =>
      'När du kopplar ihop med koden ber bron om bekräftelse - tryck på \"Acceptera\" där. Eller skanna QR-koden, då behövs ingen bekräftelse.';

  @override
  String get sb5c271ae6a => 'Säkerhetskontroll misslyckades';

  @override
  String get s3d7ca280db =>
      'Anslutningen kunde inte verifieras som säker, så den användes inte igen med QR-koden.';

  @override
  String get s0061b44673 => 'Bron svarade inte';

  @override
  String get sceb894b9b3 =>
      'Acceptera enheten på bryggskärmen inom 3 minuter, eller skanna QR-koden.';

  @override
  String get s700b0ef4de => 'Anslutningen fungerade inte';

  @override
  String get s53a891e670 =>
      'Kontrollera adressen och inställningarna och försök igen. De tekniska detaljerna visar den exakta orsaken.';

  @override
  String get s02480e4c13 => 'Mätningar';

  @override
  String get sd1c778324e => 'kontroller';

  @override
  String get s88ac47e6d1 => 'Kameror';

  @override
  String get sdd5e97b1e2 => 'Klart';

  @override
  String get sad990c999d => 'Halvklart';

  @override
  String get s80bfe8f9ad => 'Mulet';

  @override
  String get s46f3db8514 => 'Dimma';

  @override
  String get sbd81101eb4 => 'Duggregn';

  @override
  String get s960a265544 => 'Regn';

  @override
  String get seab38c2b45 => 'Snöfall';

  @override
  String get sfc65eafa12 => 'Åska';

  @override
  String get s2a3f705876 => 'Lagring av golvvärme (konkret)';

  @override
  String get se02b21f2e5 =>
      'En betongplatta lagrar värme under lång tid: uppvärmning flyttas till de billigaste timmarna, och antalet timmar följer prognosen.';

  @override
  String get sed77dcfc1a => 'Lätt golvvärme';

  @override
  String get s4699e792b9 =>
      'En lätt golv lagrar liten värme: de dyraste timmarna är hoppade, med korta pauser bara.';

  @override
  String get s5d46662c4e => 'Direkta elektriska radiatorer';

  @override
  String get s12e9bbf847 =>
      'Radiatorer lagrar inte värme: endast de dyraste timmarna är hoppade, en timme i taget.';

  @override
  String get s1c0bf9b38b => 'Air-source värmepump';

  @override
  String get s6896be80e0 =>
      'En värmepump fungerar bäst vid en jämn temperatur: målet stiger lite före dyra eller kalla trollformler och sjunker i dyra timmar.';

  @override
  String get s765f87536c => 'Ground-source värmepump';

  @override
  String get s33536024e7 =>
      'Ground-source värme med vattencirkulationen lagrar lite värme: de dyraste timmarna hoppas i pauser på några timmar högst.';

  @override
  String get s3a7d2e6848 => 'Vattenvärmare';

  @override
  String get s4eec9a0479 =>
      'En varmvattenberedare stannar varmt för en dag: den värms upp i de billigaste timmarna på dagen.';

  @override
  String s404f230c13(String p0) {
    return '';
  }

  @override
  String get s798f7b2876 => 'Smart uppvärmning';

  @override
  String get sa2dc343545 =>
      'Fireplace läge slutar: rummet kyls. Uppvärmning är tillbaka till det normala.';

  @override
  String get s78afbd052c =>
      'Fireplace läge slutade (tid är upp). Uppvärmning är tillbaka till det normala.';

  @override
  String get s1f08341033 =>
      'Fireplace läge stoppas. Uppvärmning är tillbaka till det normala.';

  @override
  String get sc27533ae83 => 'Sparsam';

  @override
  String get sdbcb85509b =>
      'Temperaturen får variera mest (+1 / −2 °C). Störst besparing.';

  @override
  String get s380b20be36 => 'Balanserad';

  @override
  String get s66ea783264 =>
      'Liten variation (+1 / −1 °C). Ett bra standardval.';

  @override
  String get see96226e44 => 'Komfort';

  @override
  String get sb403e00b3d =>
      'Nästan jämn temperatur (+0,5 / −0,5 °C). Sparar lite.';

  @override
  String get sd86b823895 => 'Sonoff';

  @override
  String get s5f297ec9d8 =>
      'BASIC, MINI, POW, TH, 4CH ... i DIY-läge, med Tasmota eller ESPHome. Kort är gjorda för dig; fjärranvändning via hembron.';

  @override
  String get s60e829b1b0 =>
      'eWeLink app → enhet → Inställningar visar IP-adressen, eller routerns enhetslista. I DIY-läge behöver du också enhets-ID (10 tecken).';

  @override
  String get s6a46e8954d =>
      'En Sonoff i DIY-läge svarar bara när den berättade sin enhet ID. Hitta den i eWeLink-appen: enhet → Inställningar → Enhets-ID. Tasmota: webblösenordet, om det är inställt.';

  @override
  String get sea057f1a02 =>
      'Endast i DIY-läge när sökningen inte hittade enheten.';

  @override
  String s08d04d58a9(String p0) {
    return 'Kanal $p0';
  }

  @override
  String get s8653f173b6 => 'Temperatur';

  @override
  String get s9cb8820285 => 'Humidity';

  @override
  String get s4899323b9a => 'Effekt';

  @override
  String get se78754330c => 'effekt';

  @override
  String get se317f59de2 => 'VUOTO!';

  @override
  String get se4c4201882 => 'LEAK!';

  @override
  String get sdbcf5515c1 => 'Auki';

  @override
  String get sb0af7213b5 => 'Öppet Öppet Öppet Öppet Öppet';

  @override
  String get sa3477dac6e => 'Liikettä';

  @override
  String get s280df88585 => 'Rörelse';

  @override
  String get s064a959911 => 'Savoa!';

  @override
  String get s50778e2eec => 'Smoke!';

  @override
  String get s1dfa5abe81 => 'Hälytys';

  @override
  String get s50c459fbff => 'Larm';

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
  String get sc2b99541c7 => 'Brytare och reläer';

  @override
  String get sd85dbd8e5e => 'Lampor och dimrar';

  @override
  String get s38935a3c66 => 'Gardiner och rullgardiner';

  @override
  String get s64c6ca7840 => 'Energimätare';

  @override
  String get s662fecdc8d => 'Sensorer';

  @override
  String get s027fcbe1b6 => 'S<blank> s<blank> Sn';

  @override
  String get sa376ec78ec => 'Lampa';

  @override
  String get s6814e463b1 => 'till<blank>';

  @override
  String get s477d8b2c95 => 'Total effekt';

  @override
  String sdaa374b331(String p0) {
    return 'Fas $p0';
  }

  @override
  String get s32c88e5aa6 => 'Ljusnivå';

  @override
  String get sbb26f2192c => 'Batteri';

  @override
  String get s57b4effa42 => 'Dörr / fönster';

  @override
  String get s66350d8e7a => 'Rörelse';

  @override
  String get s29045a726e => 'Vattenläcka';

  @override
  String get s57c2113aee => 'Rök';

  @override
  String get se8422f063f => 'Senns Sensli Senled Sen Sen Sensor';

  @override
  String get s609cb4c5f9 => 'på';

  @override
  String get s356d822497 => 'av';

  @override
  String get s0b2f7d7c80 => 'öppet öppet öppna';

  @override
  String get s7009587b85 => 'Slutna';

  @override
  String get s3b35de231e =>
      '<blank> motslidledde sin grade-före-företa-motred-motstödsföre-före-före-före-före-före-före-före-före-före-före-föregående';

  @override
  String get s3dfa789b85 => 'ALARM';

  @override
  String get sd9b6de0a6a => 'Andra andra';

  @override
  String se7520a3990(String p0) {
    return 'sover - sista $p0';
  }

  @override
  String get s3aaacf80d2 => 'offline';

  @override
  String get see129fb410 => 'ljusstyrka';

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
      'Hue Bridge och dess lampor (också Zigbee lampor parade till det). Par med bryggknappen.';

  @override
  String get sf83a145406 =>
      'I Hue-appen: Inställningar → Hue Bridges → (i) → IP-adress. Eller i routerns enhetslista: \"Philips-hue\".';

  @override
  String get s80ee7a25a9 =>
      'Tryck på den stora runda knappen ovanpå Hue Bridge nu. Vänta här - det ansluter själv.';

  @override
  String get s4dbb677293 => 'nås inte';

  @override
  String get sf50732e8e8 => 'dimmable';

  @override
  String get s68e711123b => 'Temperatur';

  @override
  String get s4082a34467 => 'sensor';

  @override
  String s3832b8c729(String p0) {
    return 'hela rummet';
  }

  @override
  String get sceabe202da => 'camera_';

  @override
  String get s1a73b397a1 => 'sonoff';

  @override
  String get sb8a029d8b4 => 'Hikvision';

  @override
  String get s2e87289ebd => 'Tapo';

  @override
  String get s834e3e8c5d => 'Apple Apple Apple';

  @override
  String get s11d8d321df => 'Apple Apple Apple';

  @override
  String get sceefb34afd => 'Apple Apple Apple';

  @override
  String get s24a447c14c => 'Apple Apple Apple';

  @override
  String get s14418a4f88 => 'Apple Apple Apple';

  @override
  String get saab3e952a6 => 'Apple Apple Apple';

  @override
  String get s7fbbfbf469 => 'Apple Apple Apple';

  @override
  String get s045b27e316 => 'Samsung Samsung Samsung';

  @override
  String get s2c0aede81e => 'Samsung Samsung Samsung';

  @override
  String get s7bd2005e15 => 'Google Google Google Google';

  @override
  String get sdcec96b503 => 'Google Google Google Google';

  @override
  String get s49960d413e => 'Google Google Google Google';

  @override
  String get s99e5776a78 => 'Google Google Google Google';

  @override
  String get sea3c963b09 => 'Sonsan Sonson Sonno Son Son Tillförs Son Sonen';

  @override
  String get s1e7b1fc81c =>
      'Syn<blank> syns<blank> Smäktigt Föregående Synd-Sont-Son-Sänks-S';

  @override
  String get s7dc8f4cf35 => 'Synology';

  @override
  String get s161d78d79c => 'QNAP';

  @override
  String get s2512122220 => 'Broder';

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
  String get s0e225fb918 => 'TP-Link';

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
  String get sdf96423738 => 'Amazon Amazon Amazon Amazon';

  @override
  String get sf253859589 => 'Amazon Amazon Amazon Amazon';

  @override
  String get sec4d80656d => 'Roku';

  @override
  String get s286e1cfb54 => 'Totalt';

  @override
  String sb9964cfb3b(String p0) {
    return 'Effekt $p0';
  }

  @override
  String get s4233362d60 => 'Vattenläck sensor';

  @override
  String get sfcb44be1a0 => 'Shelly';

  @override
  String get sa6ff717527 =>
      'Reläer och pluggar: Pro 4PM, Plus 1PM, Plug S, 2,5 ... Hittas automatiskt, kakel för varje kanal.';

  @override
  String get sd7e123cd2f =>
      'I Shelly-appen: öppna enheten → växel (inställningar) → Enhetsinformation → IP-adress. Eller i routerns enhetslista: namnet börjar med \"helt...\".';

  @override
  String get s9ad7b0076b => 'läcksensor · batteri';

  @override
  String get s815bfa19dc => 'Kontaktorkontroll';

  @override
  String get sb9209fee74 => 'lägg till endast om reläet används';

  @override
  String get s5f2b2ca5f5 => 'på nu';

  @override
  String get s67f64cd925 => 'av nu';

  @override
  String get s8b35cc884f => 'Metering';

  @override
  String get sd8dfb25d31 => 'Shelly Cloud (ingen bro)';

  @override
  String get s350215338a =>
      'Styr Shellys genom Shelly-molnet från var som helst. Du behöver bara nyckeln från Shelly-appen.';

  @override
  String get s64037991c2 =>
      'Shelly app → din profil → Användarinställningar → Auktoriseringsmolnnyckel → Få nyckel. Kopiera och klistra in den här.';

  @override
  String get s062b21969d =>
      'Visas på samma sida under nyckeln (\"Server URI\").';

  @override
  String get sf30bb5d5e6 =>
      'Vanligtvis inte behövs. Om ingenting finns: Shelly app → enhet → inställningar → Enhetsinformation → Enhets-ID. Separat flera med kommatecken.';

  @override
  String get s25399cd337 => 'Server';

  @override
  String get s246c7a46ff =>
      'Shelly app → Användarinställningar → Tillstånd molnnyckel → Server URI.';

  @override
  String get s61a2d946a4 => 'Cloud Key';

  @override
  String get s9d468f5c64 =>
      'Shelly app → Användarinställningar → Tillstånd molnnyckel → Få nyckel.';

  @override
  String get sf34c97592f => 'IKEA Dirigera';

  @override
  String get sb38eac6a87 =>
      'IKEA smart hub och dess lampor och pluggar (Zigbee). Par med knappen på navet.';

  @override
  String get s4e92ab791e =>
      'I IKEA Home smart app: Inställningar → Hub → IP-adress. Eller i routerns enhetslista: \"gw2-...\" eller \"dirigera\".';

  @override
  String get s73824fc3d0 =>
      'Tryck på åtgärdsknappen på botten av Dirigera-navet en gång nu. Vänta här.';

  @override
  String get sda8d9bf1cd => 'Uttag';

  @override
  String get s0185672be7 =>
      'Kameraanvändaren (vanligtvis admin) och lösenordet du ställer in när du aktiverar det.';

  @override
  String get s814f4633e3 =>
      'Användaradmin. Imou: lösenordet är \"Safety-koden\" på kamerans etikett eller enhetens lösenord.';

  @override
  String get s4450807111 =>
      'Kameraanvändaren i Reolink-appen (vanligtvis admin) och dess lösenord.';

  @override
  String get s1095c54819 =>
      'Reolink app → kamera → Inställningar → Nätverk → Avancerade → Serverinställningar: slå på HTTP och RTSP. Batterikameror (Argus) stöds inte.';

  @override
  String get sc79a5fee2b =>
      'Tapo app → kamera → Avancerade inställningar → Kamerakonto. Skapa en användare och lösenord där och skriv dem här (inte din Tapo molninloggning).';

  @override
  String get s174e06b97c =>
      'Skapa först ett kamerakonto: Tapo app → kamera → Avancerade inställningar → Kamerakonto.';

  @override
  String get s21da6fb5dc =>
      'Användaradmin; lösenordet är 6-brevsverifieringskoden på kamerans etikett.';

  @override
  String get s1866ef6dc8 =>
      'Ezviz app → kamera → Inställningar → LAN Live View / RTSP: slå på den (om alternativet finns).';

  @override
  String get s70625d8bbe =>
      'Användaren och lösenordet för kameran i eWeLink-appen (RTSP/ONVIF). På en dual-lens-modell kommer båda linserna från samma enhet.';

  @override
  String get s1a3c354399 =>
      'eWeLink app → kamera → Inställningar: slå på RTSP/ONVIF och ange en användare och lösenord för det (om alternativet finns).';

  @override
  String get s1c2786e15f =>
      'Kameraanvändaren och lösenordet (ofta admin). ONVIF kan behöva aktiveras i kamerainställningarna.';

  @override
  String get s32270de47a => 'Säkerhetskamera';

  @override
  String get s652458eb87 =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz, Sonoff eller någon ONVIF / RTSP-kamera. Bild på ett kort, live video hemma.';

  @override
  String get se8ea97c5eb =>
      'I kameraappen (enhetsinformation) eller routerns enhetslista.';

  @override
  String get s1577068729 => 'Kamera kamera';

  @override
  String get seeb6c38c8e => 'Kamera';

  @override
  String s83d937ae6b(String p0, String p1) {
    return 'Stream $p0/$p1 (egen lins eller kanal)';
  }

  @override
  String get s136c6f0d2b => 'Bild på kortet, live video hemma';

  @override
  String get s2101774157 => 'Live video hemma (ingen bild bort)';

  @override
  String sd63d34bfe9(String p0) {
    return 'Kan inte läsa YAML: $p0';
  }

  @override
  String sc5c9e5e2fc(String p0) {
    return '\"$p0\" använder en seriell port (USB / RS485) - du behöver en RS485 → TCP gateway.';
  }

  @override
  String get s77bf3b424f => '0=Off;1=On';

  @override
  String get s4cbe24240f => 'På';

  @override
  String get s33831dd49f => 'Av';

  @override
  String s69135546c8(String p0) {
    return '$p0 – mål';
  }

  @override
  String sd88c13e972(String p0) {
    return '\"$p0\" var hoppade - lägg till dem för hand.';
  }

  @override
  String get sceebf690e3 =>
      'Inget Modbus TCP-nav som finns i YAML (modbus: ... typ: tcp, värd: ...).';

  @override
  String get sb662db81d8 =>
      'Adressen ser ofullständig. Använd fyra nummer med prickar, t.ex. 192.168.1.50.';

  @override
  String s738ecfe2bc(String p0) {
    return ' menade du $p0?';
  }

  @override
  String s06e738bf27(String p0) {
    return 'Det här är ingen hemnätsadress (de börjar oftast med 192.168.).$p0';
  }

  @override
  String sbae99909c4(String p0) {
    return 'Obs!: den här enheten är på $p0.x - enheten kan vara på ett annat Wi-Fi.';
  }

  @override
  String get s5b44cbe9c0 => 'Hem';

  @override
  String get s5a40f12b6a => 'Lägg till';

  @override
  String get s58aaa6dade => 'Utsikten är låst';

  @override
  String get sdf1af3409c => 'Lås upp';

  @override
  String get s4629a1695c => 'Menyn';

  @override
  String get s41c3cebc48 => 'Lägg till enhet';

  @override
  String get scd04aa5d9e => 'Redigera utsikten';

  @override
  String get sf98121cd3d => 'Rum foto';

  @override
  String get s49de879696 => 'Energi';

  @override
  String get se9ca7cb470 => 'Automatiseringar';

  @override
  String get s41bb837a83 => 'Meddelanden och påminnelser';

  @override
  String get s1da81fd6c3 => 'Inställningar';

  @override
  String get s365492a7d0 => 'Lås utsikten';

  @override
  String get sb2f38410ee =>
      'Enheter kan fortfarande styras, men redigering, inställningar och lägga till enheter är dolda. Lås upp från växelikonen.';

  @override
  String get se497d27174 => 'PIN-kod (tillval)';

  @override
  String get sd21180a166 => 'Utan en PIN en kran låser upp.';

  @override
  String get s809d0eb368 => 'Avbryt';

  @override
  String get sd86ff8e28a => 'Lås';

  @override
  String get s872f93a062 => 'Lås upp?';

  @override
  String get s0cd88e27f4 => 'Redigering och inställningar blir synliga igen.';

  @override
  String get sa5283191be => 'Lås upp';

  @override
  String get sdfc012fb4e => 'PIN-kod';

  @override
  String get sca710b76b5 => 'Fel PIN-kod';

  @override
  String sa0c07ccd04(String p0) {
    return 'Du har den senaste versionen ($p0).';
  }

  @override
  String get sa118d84538 =>
      'Kunde inte söka efter uppdateringar just nu. Kontrollera internetanslutningen och försök igen senare.';

  @override
  String s9f2b092d8c(String p0) {
    return 'Version $p0 är tillgänglig';
  }

  @override
  String sa5133b2c4a(String p0) {
    return 'Du har version $p0.';
  }

  @override
  String get se099b5797e => 'Vad är nytt:';

  @override
  String get s9315c3df42 => 'Hoppa över denna version';

  @override
  String get sdd5c8f0a9d => 'Senare';

  @override
  String get sfbf490ec3f => 'Uppdatera';

  @override
  String get s5a94ef2af1 => 'Nedladdningen var skadad';

  @override
  String get s81e4325573 => 'Ladda ner misslyckad';

  @override
  String get s4b1d3df588 =>
      'Filkontrollsumman matchade inte, så ingenting installerades. Försök igen på ett ögonblick.';

  @override
  String get s0c463c7069 =>
      'Kontrollera internetanslutningen och försök igen. Du kan också ladda ner uppdateringen från releasesidan.';

  @override
  String get s5dd4c9671f => 'Öppen release page';

  @override
  String s8f5be45ff1(String p0) {
    return 'Installera $p0 - appen startar om ett ögonblick.';
  }

  @override
  String sf207ef6dc2(String p0) {
    return 'Installera misslyckade: $p0';
  }

  @override
  String get s49ddc3c3b6 => 'Uppdatering nedladdad';

  @override
  String s04a05bb8fc(String p0) {
    return 'Filen verifieras och sparas:\n$p0\n\nFör att använda den:\nNära Molaplan.\nExtrahera zip över den gamla Molaplan-mappen (eller i en ny mapp).\n3. Start molaplan.exe. Dina inställningar hålls.';
  }

  @override
  String get s1dd246ec69 => 'Versionssida';

  @override
  String get s0f07b20d45 => 'Öppen zip';

  @override
  String get s6e1ebc8baa => 'Öppen mapp';

  @override
  String get s6d9de3f94b => 'Installationen fortsatte inte';

  @override
  String get s25a6f00343 =>
      'Om du annullerade det själv, allt är bra. Om Androids installationsfönster inte visas, tryck på Prova igen.';

  @override
  String get s1e593aeca2 => 'Stäng';

  @override
  String get s200542b930 => 'Försök igen';

  @override
  String get s29e92898c6 =>
      'Bekräfta installationen i Android-fönstret eller meddelandet.';

  @override
  String get s48093a1369 => 'Bekräfta uppdatering';

  @override
  String s6d50eeae10(String p0) {
    return 'Uppdatera $p0 väntar på din bekräftelse. Tryck på Open-installation (eller meddelandet \"Molaplan-päivitys\").';
  }

  @override
  String get s1a5c09b6e4 => 'Öppen installation';

  @override
  String get sd1cdbd3630 => 'Installationen startade inte';

  @override
  String s21972e23c1(String p0, String p1) {
    return 'Android började inte installera $p0.\n\nKontrollera att \"Tillåt från den här källan\" är på för Molaplan och tryck på Uppdatera igen. Du kan också ladda ner APK från releasesidan.\n\nDetalj: $p1';
  }

  @override
  String get sa1bd8d2533 => 'Öppna inställningar';

  @override
  String get sa065e7f650 => 'Tillåt att installera uppdateringar';

  @override
  String get sdc3bf71baf =>
      'Android ber en gång om tillstånd så att Molaplan kan installera sina egna uppdateringar.\n\nTryck på \"Öppna inställningar\".\nSlå på \"Tillåt från den här källan\".\nKom tillbaka och tryck på \"Uppdatera\" igen.';

  @override
  String get s441683b7a8 => 'Verifiera...';

  @override
  String get se83b7fb2ac => 'Ladda ner uppdatering...';

  @override
  String s0b68f81d82(String p0) {
    return 'Molaplan $p0 är tillgänglig. Bron fortsätter att fungera.';
  }

  @override
  String get sb06bee9921 => 'Föreställning';

  @override
  String get sf1b5d0ffa6 =>
      'Lösenordet matchar inte. Skriv ditt kontolösenord.';

  @override
  String sd0219ce512(String p0) {
    return 'Anslutningen fungerade inte: $p0';
  }

  @override
  String get sfad8715d97 =>
      'Kunde inte nå kontotjänsten. Kontrollera Wi-Fi eller mobildata och försök igen.';

  @override
  String get sa052abd601 =>
      'Internet fungerar, men den säkra anslutningen till kontotjänsten misslyckades. Kontrollera enhetsdatum och tid.';

  @override
  String get s9ba7e7a8e6 =>
      'Fel e-post eller lösenord. Kontrollera dem eller tryck på \"Glöm lösenord\".';

  @override
  String get se899b438b5 =>
      'E-postmeddelandet bekräftas ännu inte. Leta efter koden i din e-post.';

  @override
  String get s3fb651ebf3 =>
      'Detta e-postmeddelande har redan ett konto. Logga in i stället.';

  @override
  String get s1eddf46047 => 'Lösenordet måste vara minst 8 tecken.';

  @override
  String get sca19a10c02 => 'Det ser inte ut som en e-postadress.';

  @override
  String get s736463f0d2 =>
      'Koden är fel eller löpt ut. Kontrollera den eller be om en ny.';

  @override
  String get s4800010fa4 => 'För många försök. Vänta en minut och försök igen.';

  @override
  String get sf1a6e42ab0 => 'Din inloggning utgår. Vänligen logga in igen.';

  @override
  String get sf597621fdd =>
      'En annan enhet ändrade installationen samtidigt. Försök igen.';

  @override
  String get se16eef219e =>
      'Kontotjänsten svarade inte ordentligt. Försök igen inom kort.';

  @override
  String get s2ab0ff38c1 => 'Ditt konto har redan en inställning';

  @override
  String get s3ce644ca86 =>
      'Spara den här enhetens inställning till ditt konto?';

  @override
  String get s43d6286f35 =>
      'Denna enhet har sina egna enheter och plattor också. Vad ska vi göra?';

  @override
  String get sd8a380a86d =>
      'Då samma hem, enheter och plattor visas på varje enhet som är inloggad på detta konto.';

  @override
  String get sec25d10ff5 => 'Avboka och signera ut';

  @override
  String get sb7a13da58b => 'Använd kontots installation';

  @override
  String get sf498dceefb => 'Kombinera båda (rekommenderas)';

  @override
  String get s9542718c6f => 'Spara till konto';

  @override
  String get sa711c4833e => 'Skriv din e-postadress.';

  @override
  String get s933dc9caef => 'Minst 8 tecken.';

  @override
  String get sb3cec3f199 => 'Molaplan-konto';

  @override
  String get sb24f053a48 => 'E-post';

  @override
  String get s976a9f2980 => 'Lösenord';

  @override
  String get sc0f9642fb2 => 'Visa lösenord';

  @override
  String get s4d212254bc => 'Kod från e-post';

  @override
  String get s3b86a618be =>
      'Koden anländer om några minuter. Kontrollera spam mappen också.';

  @override
  String get sb35c5ba0fc =>
      'Med ett konto är dina hem, enheter och plattor samma på alla dina enheter - PC, surfplatta och telefon. Hemanslutningen flyttar till en ny enhet utan en QR-kod.\n\nKontot är valfritt: utan en Molaplan fungerar som tidigare och installationen stannar på den här enheten.';

  @override
  String get se697487621 => 'Logga in';

  @override
  String get sec4d25a98e => 'Jag har inget konto – skapa ett';

  @override
  String get s860d0269e0 => 'Logga in med en kod som skickas via e-post';

  @override
  String get s755639049e => 'Glömt lösenord';

  @override
  String get s4a1671a2cc => 'Skapa ett Molaplan-konto';

  @override
  String get s75c960f1e5 => 'Välj ett lösenord (8+ tecken)';

  @override
  String get sea446a95e5 =>
      'Lösenordet skyddar också dina enhetslösenord och molnnycklar: de krypteras på den här enheten innan du sparar. Håll det säkert.';

  @override
  String get s4508b6c2e0 => 'Skapa konto';

  @override
  String s0ca1377846(String p0) {
    return 'Vi skickade en kod till $p0. Skriv den nedan.';
  }

  @override
  String get s07e981c940 => 'Jag har redan ett konto – logga in';

  @override
  String get s2e793f899b => 'Bekräfta din e-post';

  @override
  String get s87b6699e12 => 'Bekräfta';

  @override
  String get s824a7408ab => 'En ny kod skickades.';

  @override
  String get s317ad443fb => 'Ingen kod – skicka en ny';

  @override
  String get scf7e14661c => 'Tillbaka';

  @override
  String get s7d43ee2d5a => 'lokalisering av beläggning av beläggningar';

  @override
  String get s22c960ff4f => 'Logga in med en kod';

  @override
  String get scb167ce8b1 =>
      'o vi själva. vi.. Vi.. Vi. Vi.. Vi. Vi. Vi.. Vi.. Vi. Vi.. Vi.. Vi.. Vi.. Vi.. Vi. Vi.. Vi. Vi. Vi.. Vi. Vi. Vi.. Vi. Vi.. Vi.. Vi... Vi.. Vi... Vi.. Vi... Vi.. Vi.. Vi.. Vi. Vi.... Vi. Vi.. Vi... Vi.. Vi.... Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi.... Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi.. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi. Vi.';

  @override
  String get s7d29d1dfbd =>
      'Vi mailar dig en kod. Inget lösenord som behövs för att logga in.';

  @override
  String get sc350da6f19 => 'Skicka kod';

  @override
  String s23cda12342(String p0) {
    return 'Kod som skickas till $p0.';
  }

  @override
  String get s14d85b9e32 => 'Logga in';

  @override
  String get saa1e3d1f13 => 'Skicka en ny kod';

  @override
  String get se1be2ec8e5 => 'o-logga in med ett lösenord';

  @override
  String get s8c48f847f6 => 'Återställ lösenord';

  @override
  String get safd591d9b6 =>
      'Vi e-postar dig en kod, sedan väljer du ett nytt lösenord.';

  @override
  String get s6807ac704e => 'Nytt lösenord (8+ tecken)';

  @override
  String get sa9b5a0b2df => 'Ändra lösenord och logga in';

  @override
  String get se10ce6962a => 'Synkar…';

  @override
  String get s94d5ea139c => 'Upp till datum på alla dina enheter';

  @override
  String get sc6f1932436 =>
      'Offline – förändringar synkroniseras när du är online';

  @override
  String get s16ab688a9b => 'Sync misslyckades - kommer att gå tillbaka';

  @override
  String get s97d4aa9c1a => 'Inte synkroniserad ännu';

  @override
  String get s40ea946050 => 'Inloggad';

  @override
  String get s456721b668 => 'Synka nu';

  @override
  String get sa9df24980f =>
      'Enhet lösenord och molnnycklar är låsta. Skriv ditt konto lösenord för att öppna dem på den här enheten.';

  @override
  String get sd1723cc065 => 'Konto lösenord';

  @override
  String get s9e9a059c2f => 'Lås upp';

  @override
  String get s8b2b8fdc77 => 'Jag glömde det - starta lösenorden över';

  @override
  String get s5ec8009dfd =>
      'Sparas till kontot: hem, enheter, kakel och deras beställning och hemanslutningen. Enhetslösenord, molnnycklar och hemanslutningsnycklar krypteras på den här enheten med ditt kontolösenord innan du laddar upp - servern kan inte läsa dem.';

  @override
  String get s2ea6f9de12 => 'Byt lösenord';

  @override
  String get s7ebd89c416 => 'Logga ut?';

  @override
  String get sab30063821 =>
      'Den här webbläsaren glömmer hem, kort och hembro länk. Dina data stannar i ditt konto.';

  @override
  String get s6c6165d662 =>
      'Hem och plattor stannar på den här enheten, men ändrar inte längre dina andra enheter.';

  @override
  String get s643325053b => 'Logga ut';

  @override
  String get sfd6f965e64 => 'Radera konto';

  @override
  String get s37bf90cffe =>
      'Permanent raderar kontot och allt som lagras på servern. Den här enheten håller sin egen inställning.';

  @override
  String get sc523d0f28e => 'Radera konto';

  @override
  String get s84fda3e17f => 'Avbryt';

  @override
  String get s162a85c6ef => 'Spara';

  @override
  String get s02c3403918 => 'Välj ett nytt lösenord.';

  @override
  String get s04ab058029 => 'Lösenord ändras.';

  @override
  String get s7c23534562 => 'Starta lösenord över';

  @override
  String get s5ea3703a0a =>
      'Saved enhet lösenord och molnnycklar är förlorade och måste skrivas igen. Hem och kakel stannar. Din inloggningslösenord ändras till denna nya.';

  @override
  String get s321912ef77 => 'Ta bort kontot permanent?';

  @override
  String s3b0ea9bbc7(String p0) {
    return 'Kontot $p0 och allt som lagras på servern raderas. Detta kan inte ångras.\n\nDenna enhet fortsätter att fungera utan ett konto.';
  }

  @override
  String get s139d2075b8 => 'Kontot raderat.';

  @override
  String get sca7e088857 => 'Elpris';

  @override
  String get s83f816fbe3 => 'Exceptionellt dyr el';

  @override
  String get s262f9527aa => 'Väderprognos';

  @override
  String get sfc404aec8b => 'Sensorvärde';

  @override
  String get s58d2896c42 => 'Enhetsstatus';

  @override
  String get s7def336f41 => 'Tid eller datum';

  @override
  String get sf80835a318 => 'Ankomst (förvärmning)';

  @override
  String get s9a37dbb58a => 'i morgon';

  @override
  String get s1fe084d61b => 'idag idag idag idag';

  @override
  String get safd8f4dddf => 'högsta högsta högsta';

  @override
  String get s484731d968 => 'lägsta';

  @override
  String get s77f9bfc303 => 'genomsnittet';

  @override
  String get sc017c085e4 => '(Plocka en enhet)';

  @override
  String s3f09da81b6(String p0, String p1, String p2, String p3) {
    return '$p0: genomsnittligt ≥ $p1 c eller topp ≥ $p2 c eller $p3 × dagen före';
  }

  @override
  String s900c886f50(String p0, String p1, String p2, String p3) {
    return '$p0  $p2 $p3 °C';
  }

  @override
  String s81c88dabf7(String p0, String p1) {
    return '$p0 inte svara $p1 min';
  }

  @override
  String s5414e9e5fd(String p0) {
    return '$p0 stänger av';
  }

  @override
  String s09a43fc401(String p0) {
    return '$p0 slår på';
  }

  @override
  String s56ef33ee50(String p0, String p1, String p2) {
    return 'ankomst $p0 · påminnelse $p1 h innan $p2 °C';
  }

  @override
  String get sdeb38e3907 => 'Min anmälan';

  @override
  String get s5e9a552fe6 => 'Min egen anmälan';

  @override
  String get se2e6db5acc => 'Alla villkor och ditt eget budskap.';

  @override
  String get sc6bec5e6cb => 'Körs på denna hembro, även med appen stängd.';

  @override
  String get se17e32a5c9 =>
      'Hembron är äldre än 0.11.0: påminnelser fungerar bara medan den här appen är öppen. Uppdatera bron (Fjärråtkomst → Mina hembroar).';

  @override
  String get s5fd9e146bf => 'Körs på hembron, även med appen stängd.';

  @override
  String get s563ba24005 =>
      'Ingen hemmabro: påminnelser fungerar medan appen är öppen. En hemmabro håller dem igång hela tiden.';

  @override
  String get sf378d832a1 => 'Lägg till påminnelse';

  @override
  String get s034093c675 =>
      'Få ett meddelande när ett tillstånd är uppfyllt: elpris (till exempel i morgon), väderprognos, ett sensorvärde, ett enhetstillstånd eller en tid.';

  @override
  String get s49a26ce1f2 => 'Välj en färdig mall';

  @override
  String get sc0597b9029 => 'Senaste meddelanden';

  @override
  String get sac8af0108d => 'Inga meddelanden ännu.';

  @override
  String get sf4caddf894 => 'Avancerat';

  @override
  String get sbb2b4bdfc8 => 'Telefonmeddelanden (ntfy), tysta timmar, mute';

  @override
  String get s13d942a5a9 => 'Välj en enhet.';

  @override
  String get sac782d209c => 'Testmeddelande skickas.';

  @override
  String get s67584c9abf => 'Enhet';

  @override
  String get s140acccb81 => 'I dag';

  @override
  String get s0de6e75a52 => 'I morgon';

  @override
  String get sbbf8b7a598 => 'Medelvärde';

  @override
  String get s43b4c610f8 => 'Högsta';

  @override
  String get s9dd0f70be6 => 'Lägsta';

  @override
  String get scd65d31d4c => 'Begränsning';

  @override
  String get s543838d91f => 'Genomsnitt åtminstone';

  @override
  String get s087a7e1b24 => 'eller peak åtminstone';

  @override
  String get s8463e08e0b => 'eller × föregående dags genomsnitt';

  @override
  String get sd8332d82ec =>
      'Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min';

  @override
  String get s109b35551a => 'Max Max Max Max Max';

  @override
  String get sf2c65c5aeb => 'Medelvärde';

  @override
  String get s68b942c864 =>
      'Ställ in hemorten (Energy → Inställningar) för prognosen.';

  @override
  String get s38ac222392 => 'Värde';

  @override
  String get s4cd3d92d4c => 'På';

  @override
  String get sa8e43f2b0e => 'Offline';

  @override
  String get s65f512f499 => 'När offline för';

  @override
  String get sa224d2f5f9 => 'Tid';

  @override
  String get s96b7e2c62c => 'Varje dag (plocka ett datum för en gång)';

  @override
  String get s593004184e => 'Ankomst';

  @override
  String get sa9faf47356 => 'Påminn före';

  @override
  String get sf527ec4275 => 'Måltemperatur';

  @override
  String get s009a96409a => 'Ny påminnelse';

  @override
  String get sb346b2b647 => 'Påminnelse';

  @override
  String get sc1845eb440 => 'Radera';

  @override
  String get sb1924acbe7 => 'Namn';

  @override
  String get s5506524eac => 'När när när';

  @override
  String get s86c5d7fa73 => 'Meddelande';

  @override
  String get s8dda7ee75e =>
      'Du kan använda: {avg} {max} {min} {tim} {värde} {kort} {mål} { ankomst} {datum}';

  @override
  String get sec1bdb2451 => 'Även till telefoner (ntfy)';

  @override
  String get se2de73b535 => 'Alltid visas i appen också.';

  @override
  String get sd84d87d156 => 'Prioritet';

  @override
  String get s7a09198c53 => '5 (även i tysta timmar)';

  @override
  String get se8e58d6206 => 'Inte igen inom';

  @override
  String get s7d773a4dc9 => 'Inte förrän';

  @override
  String get sb86dc1b7bf => 'Testa testtest';

  @override
  String get sfb4df77773 => 'Ge knappen ett namn.';

  @override
  String get s986eb41068 =>
      'Använd Pronto: lägg till dump: pronto till remote_receiver.';

  @override
  String s0d353281af(String p0) {
    return 'Knapp \"$p0\" tillade.';
  }

  @override
  String get s8e4e78e067 => 'Lär in fjärrkontroll';

  @override
  String get s2acab0eccd => 'Klar';

  @override
  String get s608a56ad4b =>
      'Spara fjärrknappar till Molaplan, t.ex. \"Turbo\". Blastaren behöver en IR-mottagare.';

  @override
  String get sa1aed8855e => 'IR fjärrkontroll';

  @override
  String get sded7fb8520 => 'RF433 fjärrkontroll';

  @override
  String get sc8e312a953 =>
      'RF433 = radiofjärrkontroller (sockor, markiser, garageportar, fans). IR = infraröd (värmepumpar, TV-apparater).';

  @override
  String get s63c57060b6 => 'Tryck på \"Startlyssning\".';

  @override
  String get s439f6f3869 =>
      'Placera fjärrkontrollen på blastaren (under 1 m) och tryck på knappen en gång.';

  @override
  String get sd8667596c3 => 'Namn och tryck på \"Spara som knapp\".';

  @override
  String get sd5f1a45865 =>
      'IR är envägs: värmepumpen bekräftar inte. Molaplan visar bara vad den skickade. Learning fungerar på hemmanätverket.';

  @override
  String get s628dc92a8d => 'Lyssna... tryck på fjärrknappen';

  @override
  String get s1313eb829d => 'Börja lyssna';

  @override
  String get s619fdf8b5c => 'Koden mottagen';

  @override
  String get s6264a40ec6 => 'Knappens namn';

  @override
  String get sc630994fba => 'Visas som kakel titel.';

  @override
  String get s09feac6b28 =>
      'ESPHome kan inte ta nya koder över nätverket. Lägg till detta på enheten YAML, installera den och spara sedan knappen:';

  @override
  String get sd6f41faa1d => 'Kopiera';

  @override
  String get s0a7c7a151a => 'Spara som knapp';

  @override
  String get s29adc71f1c =>
      'CN105-kontakt på inomhusplanen. ESPHome: esphome-mitsubishiheatpump.';

  @override
  String get s1d17c9fc6e =>
      'S21 (de flesta väggenheter) eller X50A. Faikin pluggar rakt in; ESPHome: esphome-daikin-s21.';

  @override
  String get s07767f6a03 =>
      'CN-CNT-kontakt (där Panasonics WLAN adapter går) ESPHome: esphome-panasonic-ac.';

  @override
  String get s659b742754 =>
      'Toshiba inomhus serviceport. ESPHome: esphome-toshiba_ac.';

  @override
  String get s7c3bf9542b => 'Skriv enheten IP.';

  @override
  String sdfa6aedae8(String p0, String p1) {
    return '\"$p0\" tillade.';
  }

  @override
  String get sbd2f94e7a4 => 'Värmepump (serviceport/ESPHome)';

  @override
  String get s49b479c566 =>
      'Bästa sättet: en liten ESP32 på inomhusenhetstjänstporten. Till skillnad från IR är det tvåvägs - verkligt tillstånd och rumstemperatur.';

  @override
  String get sc95a59f7c6 =>
      'Säkerhet: Stäng värmepumpen på huvudet innan du öppnar inomhusenheten. Det kan påverka garantin.';

  @override
  String get s7b7121b71e => 'Port by Brand';

  @override
  String get s67c1a8a6a3 => 'Steg';

  @override
  String get s2f9c5f3130 => 'Få en ESP32-kontroll och kabel.';

  @override
  String get s2675e49423 =>
      'Flash ESPHome per projektguide. Inkludera \"web_server:\" - Molaplan använder den.';

  @override
  String get scd70d27319 => 'Anslut den med strömmen av.';

  @override
  String get s56b0cb63ea =>
      'Skriv dess IP nedan och tryck på \"Hitta värmepumpar\".';

  @override
  String get sdd1cd7bdd5 => 'ESPHome-styrenhetens IP';

  @override
  String get sa1e21d236a =>
      'Från routerns enhetslista eller ESPHome dashboard.';

  @override
  String get s1bef32afe0 => 'Hitta värmepumpar';

  @override
  String get s9aa9bc9679 => 'Enhet svarade men har ingen klimatenhet.';

  @override
  String get sec88246e24 => 'Välj ett rum foto';

  @override
  String get s252b8e1289 => 'Foto för vilket rum?';

  @override
  String get sa27e5362de =>
      'Välj en inbyggd rumsbild eller ditt eget foto. Det visas som rubriken eller bakom hela vyn.';

  @override
  String get s84ef77e1ca => 'Välj en egen bild';

  @override
  String get sf55eee73b8 => 'Ändra bild';

  @override
  String get sf6723451b9 => 'Ta foto';

  @override
  String get s0bec34cd24 => 'Rubrikbild';

  @override
  String get s7b1e22fca7 => 'Bakgrund för hela vyn';

  @override
  String get s229e29f9ee => 'Dämpning';

  @override
  String get s38285117e6 => 'Oskärpa';

  @override
  String get sdd957ccc1b => 'Ta bort bild';

  @override
  String s6c487e340b(String p0) {
    return 'På de flesta $p0 bilder. Ta bort en först.';
  }

  @override
  String get sceafe9ce2a => 'Filen är inte en bild';

  @override
  String get s463074e5cc => 'App endast';

  @override
  String get seb8b8d2adf => 'Fungerar endast i appen eller via en hemmabro';

  @override
  String get s3a5c21004e => 'Offline';

  @override
  String get sbc7a87e591 => 'Kunde inte få priser - retrying';

  @override
  String get s3f0837ec84 => 'Kunde inte få vädret - förtrytning';

  @override
  String get s68cbe596f8 => 'Inloggningen har gått ut';

  @override
  String get s599357f47b => 'Inget internet';

  @override
  String get s74fa2d56aa => 'Modbus är avstängd';

  @override
  String get s156aa7eeb3 => 'Enheten svarar inte';

  @override
  String get sbf2cfbb102 => 'Fel enhet id?';

  @override
  String get s9be06479ff => 'Lockout';

  @override
  String get s613938b0b3 => 'Ingen adress';

  @override
  String get s252d8628c7 => 'Upptagen (HA?)';

  @override
  String get s0e3a6bafbf => 'Tjänst som inte svarar';

  @override
  String get s7abcbf1107 => 'Servern hittades inte';

  @override
  String get sca533b6f25 => 'Hembryggan svarar inte';

  @override
  String get s96ad0dc252 => 'Värde som inte finns på enheten';

  @override
  String get s61cdd7287b => 'Inställning saknas';

  @override
  String get s57d0940253 => 'Säkerhetsfel';

  @override
  String get sfec025279e => 'Enheten är offline';

  @override
  String get s1ea16fc636 => 'Kolla nu';

  @override
  String get sbaf1a2b35e => 'Inget nätverk';

  @override
  String get s3f750ce1d4 =>
      'Den här enheten är inte på Wi-Fi och mobildata fungerar inte. Kort visar de sista värden som mottagits.';

  @override
  String get s542a3e9332 => 'Wi-Fi har inget internet';

  @override
  String get sba13ded915 =>
      'Enheter på detta Wi-Fi-arbete; molntjänster och fjärråtkomst gör det inte.';

  @override
  String get se24bfd1257 => 'Fjärrserver som inte svarar';

  @override
  String get s8584be9da3 =>
      'Internet fungerar, men Molaplans fjärrserver svarar inte hemma allt fungerar; fjärråtkomst kommer tillbaka av sig själv.';

  @override
  String get s1e03ade992 => 'Anslutning OK';

  @override
  String get s0fc5f4d788 =>
      'Re-checkade var 15: e tills det fungerar; detta meddelande försvinner sedan av sig själv.';

  @override
  String get s3e05e0efab => 'Wi-Fi/Ethernet-adresser';

  @override
  String get s6b59e217ba => 'Ingen';

  @override
  String get s3b7c55c4fc => 'Kontrollerad';

  @override
  String get sc26c52235c =>
      'Du är borta och hembron svarar inte. Hemnätverksenheter kan inte styras nu.';

  @override
  String get s0fc1c9f296 =>
      'Du är borta. Hemnätverksenheter fungerar på distans endast genom en hembro.';

  @override
  String get se50ed56454 => 'Fjärråtkomst';

  @override
  String get sc5f54cf3c8 => 'Fyll i nyckeln och servern.';

  @override
  String get sb26dad8f73 => 'Inga enheter i molnet med denna nyckel.';

  @override
  String s2c6ce95ec2(String p0) {
    return '$p0 fungerar nu genom Shelly Cloud.';
  }

  @override
  String s5629901cc4(String p0) {
    return 'Kontrollera $p0 hemifrån';
  }

  @override
  String get s064abc90af =>
      'Enheten byts till Shelly Cloud. Alla dess kanaler, namn och kort stannar. Key: Shelly app → din profil → Användarinställningar → Auktoriseringsmolnnyckel.';

  @override
  String get sf16961256b => 'Server (Server URI)';

  @override
  String s28e10c6870(String p0) {
    return 'Vilken av dessa är $p0?';
  }

  @override
  String get s09f5da65e0 => 'Byt till Shelly Cloud';

  @override
  String get sa846059775 => 'Home Assistant läser redan den här enheten';

  @override
  String get s18a1844439 =>
      'Enheten kanske redan har en anslutning (t.ex. Home Assistant) - läs värdena genom HA. Många enheter tillåter endast en Modbus TCP-anslutning.';

  @override
  String sa29df4fc6b(String p0) {
    return '$p0 Modbus värden som finns i Home Assistant. Många enheter tillåter endast en Modbus TCP-anslutning, så läsning genom HA är det säkraste sättet.';
  }

  @override
  String get sb8c40d2c20 => 'Användning via Home Assistant';

  @override
  String get s810014ca02 => 'Importera en hemassistent modbus.yaml';

  @override
  String get sfbf34ee532 =>
      'Paste modbus.yaml (eller modbus: en del av konfiguration.yaml). Anslutningen och korten använder samma register och timing.';

  @override
  String s2d4fbaade1(String p0, String p1) {
    return '$p0 anslutning(s), $p1 kort';
  }

  @override
  String get s580678cb10 => 'Importera';

  @override
  String get s108e078c0c => 'Modbus-enhet som importeras från Home Assistant';

  @override
  String get sa3a093e55e => 'Värmer';

  @override
  String get s8efb99df1d => 'Kyler';

  @override
  String get s0b98d62330 => 'Värme och kyla';

  @override
  String get sa61efb9866 => 'värmer';

  @override
  String get s9a47ee3e3c => 'kyler';

  @override
  String get s156712ac0c => 'väntar';

  @override
  String get s8a1f52a37b => 'Termostaten borttagen';

  @override
  String get s28dc9bc46a => 'Ingen temperaturavläsning';

  @override
  String get s4f1166fe24 =>
      'Ingen hembro: termostaten styr ännu inte. Ställ in fjärråtkomst på hemmatabletten.';

  @override
  String get s29fd8d5b5e => 'Nu';

  @override
  String get see9111ba68 => 'Relä eller brytare (på/av)';

  @override
  String get seaed91ad78 => 'Värmepump eller AC (börvärde)';

  @override
  String get sb757921c13 => 'Värmer';

  @override
  String get s7407864734 => 'Kyler';

  @override
  String get s272aa3f1da => 'Båda';

  @override
  String get sdadb6e3501 => 'Reservvärmare';

  @override
  String get se4e381334d => 'Börjar först när det är tydligt under målet.';

  @override
  String get s17c79c5f4e => 'Power on/off (tillval)';

  @override
  String get s92d88612de => 'Värmeläge knapp (valfritt)';

  @override
  String get s75ac845bab => 'Cool läge knapp (tillval)';

  @override
  String get se12fc46923 => 'Ingen';

  @override
  String get sc590a09db9 => 'Vad värmer eller kyler?';

  @override
  String get sa15ffe53d4 =>
      'Välj en eller flera. t.ex. en värmepump och en backup värmare.';

  @override
  String get sd47a7615a7 => 'Inga lämpliga enheter ännu';

  @override
  String get s3c7649a7f0 =>
      'Lägg först till ett relä (t.ex. Shelly) eller en värmepump (IR eller serviceport), sedan komma tillbaka.';

  @override
  String get see513572ea => 'Varifrån läses temperaturen?';

  @override
  String get s5155522e83 =>
      'Välj en termometer. Flera = nedgång eller genomsnitt.';

  @override
  String get s581fa290f3 =>
      'Valfritt: värmepumpen mäter sig själv. Välj en sensor för att se temperaturen.';

  @override
  String get s7e4d8d60a0 => 'Ingen termometer';

  @override
  String get s0787d80876 => 'Lägg först till en enhet som visar en temperatur.';

  @override
  String get s89661203b7 => 'Första fungerande';

  @override
  String get s0da3005956 => 'Medelvärde';

  @override
  String get s0c6a008ffd => 'Namn och läge';

  @override
  String get s1790a71e85 => 't.ex. Vardagsrum';

  @override
  String get sd5f46903a1 => 'Måltemperatur';

  @override
  String get s6de95e582f => 'Om temperaturen försvinner';

  @override
  String get s8ff25225b4 => 'Stäng av värme/kyla (säkrast)';

  @override
  String get s17cb86f49e => 'Behåll som det är';

  @override
  String get s9624f070ee => 'Hysteres';

  @override
  String get sf070be2c1e => 'Dödband (värme/kyla)';

  @override
  String get s64540136ff => 'Minsta tid på';

  @override
  String get s21713a2177 => 'Minsta tid av';

  @override
  String get s8f7c8eb7d0 => 'Backup värmare när under målet genom';

  @override
  String get sf1eb3b2d34 => 'Sensor förlorad efter ingen läsning för';

  @override
  String get s0ab1430151 => 'Ny termostat';

  @override
  String get sbbc98d573d => 'Redigera termostat';

  @override
  String get s6c3e76828b => 'Nästa';

  @override
  String get s187d328bb1 => 'Redigera';

  @override
  String get s87984716cb => 'Ta bort termostaten?';

  @override
  String get s79786b9f7d => 'Mål';

  @override
  String get sdd309c0a63 => 'Termostaten körs på hembryggan';

  @override
  String get s2a7e9fe291 =>
      'Ställ in fjärråtkomst på hemmatabletten (Inställningar → Fjärråtkomst). Tills dess kontrollerar det inte någonting.';

  @override
  String get s06cda8c0de => 'Körs på den här enheten (hembrygga).';

  @override
  String get s2342536aea => 'Körs på hembryggan.';

  @override
  String get s2c5993c1fd =>
      'Förvärmning före dyr el och kallt väder, och låter temperaturen sjunka lite i dyra timmar.';

  @override
  String get s81c4abc1a5 => 'Övervärme +';

  @override
  String get sdea18b2b40 => 'Undervärme −';

  @override
  String get s523214c8db =>
      'Linje = måltemperatur, barer = elpris, streckad = utomhustemperatur.';

  @override
  String get s94b8f63aa7 => 'Lägg hem plats för vädret';

  @override
  String get s941fbb47fe => 'Planen beräknas…';

  @override
  String get s702ca14235 => 'Tasmota-enhet';

  @override
  String get se0e5f715ad => 'ESPHome-enhet';

  @override
  String get s63b6e55469 => 'HomeKit-enhet';

  @override
  String get s13e301a66e => 'Okänd enhet';

  @override
  String get sddb2c2cb2b => 'Telefon';

  @override
  String get s16cd267576 => 'Surfplatta';

  @override
  String get sec4679ec39 => 'Dator';

  @override
  String get s798f9a0558 => 'Skrivare';

  @override
  String get s06109b8e5c => 'TV / mediaspelare';

  @override
  String get sc4655d321e => 'Högtalare';

  @override
  String get sa9f2f85b3e => 'Router';

  @override
  String get sf8360dcd74 => 'Nätverkslagring';

  @override
  String get s8e21b6f258 => 'Smart enhet';

  @override
  String get sb38b582dab => 'Hembrygga';

  @override
  String get sdf66171e91 => 'Den här enheten';

  @override
  String get s76a76a654e => 'iPhone-surfzon';

  @override
  String get s15d4ca1672 => 'Telefonens surfzon';

  @override
  String get sd54522fe39 => 'Router / surfzon';

  @override
  String get s3294a9422d => 'Säkerhetspanel';

  @override
  String get sb97a2b7ed6 => 'ESP32-enhet';

  @override
  String get s23f4820db7 => 'Inte kontrollerbar ännu';

  @override
  String get sdeeabebed9 => 'Airthings: lägg till via molnet eller Bluetooth';

  @override
  String get saae59a3865 => 'via hembryggan';

  @override
  String get sf226dd023a => 'Kontrollerad med ntfy-meddelanden';

  @override
  String get s0e6aa5168c =>
      'om detta är en säkerhetspanel, lägg till den som en ntfy kommandoenhet';

  @override
  String get sdccd6e7f24 => 'Modell';

  @override
  String get s891a4b434e => ')\'}';

  @override
  String get s43aba09687 => 'Hamnar';

  @override
  String get scee3511db6 => 'Källor';

  @override
  String get sbc46a05125 => 'Namnge enheten';

  @override
  String get s1d5ed84aed => 'Sparas på den här enheten.';

  @override
  String get s3e6dd6ff2d => 'Lägg till som kommandoenhet';

  @override
  String get s59622d792b => 'Byt namn';

  @override
  String get sb616303f5b =>
      'I webbläsaren fungerar enhetssökning endast genom en hembro';

  @override
  String get sef469cadc3 =>
      'Du kan fortfarande lägga till moln och ntfy enheter nedan.';

  @override
  String get sa0fccfbcab => 'via hembron';

  @override
  String get s1169d2d093 => 'Hitta enheter';

  @override
  String get s55b85f29a6 => 'Söker ditt hemnätverk...';

  @override
  String get se9c923ff0b =>
      'Molaplan letar efter enheter som den känner igen på ditt hemnätverk.';

  @override
  String get s3ff2220816 =>
      'Inga kända enheter hittades. Välj varumärket nedan.';

  @override
  String s2a9142dc3e(String p0) {
    return 'Hittade $p0. Tryck på att lägga till.';
  }

  @override
  String get s2fc39b0bd7 => 'Sök igen';

  @override
  String get s0a9acb5af1 => 'Sök efter Sök';

  @override
  String get se3ef5a5658 => 'Skanna Modbus';

  @override
  String get s9a018b8166 => 'Du är borta: hembron sökte ditt hemnätverk.';

  @override
  String get s55d0b95fd2 => 'Detta nätverk';

  @override
  String s955b44aaa4(String p0) {
    return 'Dessa är på den här enhetens eget nätverk, inte på $p0. De läggs inte till i det hemmet.';
  }

  @override
  String sf16a25c313(String p0) {
    return 'Andra enheter i nätverket ($p0)';
  }

  @override
  String get s9e8430c37b =>
      'Molaplan styr inte dessa. iPhones visar sitt namn bara när de vakna.';

  @override
  String s095ca83913(String p0) {
    return '$p0 kort tillagda';
  }

  @override
  String get sd53b0c4edc => 'Airthings övervakar';

  @override
  String sc401e05b53(String p0) {
    return 'Lägg till $p0 kort';
  }

  @override
  String get s212e35a61b => 'Kunde inte lista enheterna';

  @override
  String get s039683f4a5 =>
      'Det finns inga bildskärmar i ditt konto. Lägg till en i Airthings-appen först.';

  @override
  String get sdfff64e4c3 => 'via Hub';

  @override
  String get s7f308d40c8 => 'Värmer';

  @override
  String get s41de361b3e => 'Kyler';

  @override
  String get s4f7ccb7138 => 'Avfuktar';

  @override
  String get s9b2398228e => 'Fläkt';

  @override
  String get s533177c689 => 'Vilar';

  @override
  String get sa3e8beed42 => 'Värme';

  @override
  String get s6c9668fbd9 => 'Kyla';

  @override
  String get sd032c3efec => 'Auto';

  @override
  String get s9db8aefc43 => 'Avfuktning';

  @override
  String get s0117dea8bc => 'Fläkt';

  @override
  String get s11a7c24b38 => 'Inget värde';

  @override
  String get s28b7c227f0 => 'börvärde';

  @override
  String get s81e0c3084b =>
      'Lampans läge kunde inte läsas – styrningen kan ändå fungera.';

  @override
  String get s7400a53ab2 => 'Färg';

  @override
  String get s09aec1d642 => 'Vitt';

  @override
  String get s16ff3849c9 => 'Färgtemperatur';

  @override
  String get sf117c88d83 => 'Varm';

  @override
  String get secb1232aad => 'Kyla';

  @override
  String get sb2fa876c32 => 'Ljusstyrka';

  @override
  String get s34cc93ca61 => 'Favoriter';

  @override
  String get sdc485831ad => 'Tryck länge för att ta bort';

  @override
  String get s3c98732a8c => 'Mätare';

  @override
  String get s6f29aeb685 => 'Trend';

  @override
  String get s3298699c1a => 'Mätare + trend';

  @override
  String get sed593f53ed => 'Värde';

  @override
  String get s9027c88cb7 => 'Samla in data...';

  @override
  String get sf05d2a09f1 => '7 d';

  @override
  String get se38a9bb2ed => 'Senaste';

  @override
  String get s049d71f971 => 'Sista sista';

  @override
  String get s3ec9d77947 => 'Tmrw';

  @override
  String get sed9b5e52f6 => 'Numera nu';

  @override
  String get s1b85ad9e38 =>
      'Letar du efter enheter med Modbus TCP på (port 502, 503 och 5020) och försöker enhetens id. Ta ungefär en halv minut.';

  @override
  String get seb1f4357ea => 'Egen hamn (valfritt)';

  @override
  String get s06760a6970 => 'Skanna igen';

  @override
  String get s23d146db23 => 'Scan';

  @override
  String get s18e7ad553e => 'Scanning...';

  @override
  String get s721647a6cd => 'Du är borta: hembron skannade.';

  @override
  String get s08e57d2d85 => 'Scan misslyckades';

  @override
  String get s4cf60b9350 =>
      'Inga Modbus-enheter hittades. Kontrollera att Modbus TCP finns i enhetsinställningarna och att det är i samma nätverk (inte gäst Wi-Fi).';

  @override
  String get sbd8ee8a14f => 'Modbus-enhet';

  @override
  String get sf0462b25ac => 'gateway';

  @override
  String s28d9c4c7dc(String p0) {
    return '$p0 förinställd';
  }

  @override
  String get sc6cde0d476 => 'från dess tillkännagivande';

  @override
  String get s166da70285 => 'Enheten accepterar inte en anslutning';

  @override
  String get sbe97262d91 =>
      'Enheten kanske redan har en anslutning (t.ex. Home Assistant) - läs värdena genom HA. Många enheter tillåter endast en Modbus TCP-anslutning.';

  @override
  String get s24e5139123 => 'Port öppna, ingen Modbus svar';

  @override
  String get s9041c140be =>
      'Kontrollera enhets-ID och Modbus-inställningarna. Tryck på för att använda den här adressen.';

  @override
  String get sfe54134176 => 'Alla enheter';

  @override
  String get s23baecde5b => 'Enheter';

  @override
  String get s776f46ed8d => 'styrning + inställningar';

  @override
  String get sa7cfbebc2f => 'styrning';

  @override
  String get seff7e04d91 => 'Återkalla installatörens åtkomst?';

  @override
  String s633fa022d1(String p0) {
    return '$p0 kommer inte längre åt dina enheter. Åtkomsten upphör så snart hembryggan får veta det (oftast direkt).';
  }

  @override
  String get sbdfc0cf419 => 'Återkalla åtkomst';

  @override
  String get s98b66fc9d8 => 'Åtkomsten återkallad';

  @override
  String get sbd907def5b => 'Installatör';

  @override
  String get sfb1a18d11f => 'Uppdatera';

  @override
  String get sb9c461d827 =>
      'Installatörsåtkomst kräver ett Molaplan-konto så att installatören kan verifieras och krypteringen fungerar.';

  @override
  String get s9bb545e9b3 => 'Logga in eller skapa ett konto';

  @override
  String get s523c735938 =>
      'Ge en installatör åtkomst till dina enheter med installatörens ID (t.ex. MPL-K7Q-M2X). Molaplan har kontrollerat varje installatörs namn och företag. Lösenord och adresser lämnar aldrig hemmet, och du kan återkalla åtkomsten när som helst.';

  @override
  String get s03be67bc78 => 'Ge åtkomst';

  @override
  String get s65c7781ca3 => 'Installatörer med åtkomst';

  @override
  String get sbb7e4c4c3c => 'Ingen installatör har åtkomst.';

  @override
  String get s84a6d73d1e => 'Ändra enheter eller rättigheter';

  @override
  String get s5fcc7e175d => 'Mina kunder';

  @override
  String get s44dcd38f2b => 'Hantera installatörer';

  @override
  String s2f8dd9569b(String p0, String p1) {
    return 'Mitt installatörs-ID i Molaplan: $p0 ($p1). Så ger du mig åtkomst: Molaplan → Inställningar → Installatör → Ge åtkomst.';
  }

  @override
  String get s0061cbc425 => 'Kopiera meddelandet';

  @override
  String get sdd0f19c6b8 => 'E-post';

  @override
  String get sd57398d989 => 'Sms';

  @override
  String get s4f09cced25 => 'Meddelandet kopierat';

  @override
  String get s2836191df5 => 'Appen kunde inte öppnas – meddelandet kopierades.';

  @override
  String get sd01e57c279 =>
      'Kunden skannar den: Inställningar → Installatör → Ge åtkomst.';

  @override
  String get se83877749c => 'Du är Molaplan-installatör';

  @override
  String get s014468e53e => 'Ditt installatörs-ID';

  @override
  String get s973ddbcd3b =>
      'Ge ID:t till din kund. Med det öppnar kunden åtkomst till sina enheter och ser ditt namn och företag så som Molaplan har verifierat dem.';

  @override
  String get s9e0dd2426d => 'ID kopierat';

  @override
  String get s5224946aa1 => 'Dela';

  @override
  String get s59d0633cbd => 'QR-kod';

  @override
  String get sacc4275348 => 'Ansök om att bli installatör';

  @override
  String get s29acd8486c =>
      'Molaplan kontrollerar ditt namn och företag och ger dig ett installatörs-ID. Du ser resultatet i appen.';

  @override
  String get s7aa9c1e208 => 'Ditt namn';

  @override
  String get s9f3d2fa73f => 'Företag';

  @override
  String get scfe0cd3759 => 't.ex. organisationsnummer eller enskild firma';

  @override
  String get s483b3a689d => 'Meddelande (valfritt)';

  @override
  String get sb7dbf1a527 => 'Skicka ansökan';

  @override
  String get s0b9319b6eb => 'Skriv ditt namn.';

  @override
  String get s9929adfbf5 => 'Ansökan skickad';

  @override
  String get s2570b96a0b => 'Är du installatör?';

  @override
  String s63d8fdf8c2(String p0) {
    return 'Din installatörsstatus ($p0) har tagits bort och kundåtkomster kan inte användas. Fråga Molaplan: molaplan1@gmail.com.';
  }

  @override
  String get s82b8ec7605 =>
      'Som installatör ser du dina kunders enheter, status och larm i den mån varje kund tillåter. Installatörsstatus beviljas av Molaplan.';

  @override
  String s563801d51b(String p0) {
    return 'Ansökan skickad $p0 – väntar på granskning.';
  }

  @override
  String get s1247102567 => 'Dra tillbaka';

  @override
  String get s77f0327b09 => 'Den förra ansökan godkändes inte.';

  @override
  String get s5e130a714c => 'ID:t har formen MPL-XXX-XXX.';

  @override
  String get s16d84ef12f =>
      'Ingen godkänd installatör har detta ID. Kontrollera ID:t med installatören.';

  @override
  String get s7288dc01b6 => 'Ge åtkomst?';

  @override
  String get s2013b9940c => 'Spara ändringarna?';

  @override
  String get sa88745a558 => 'Alla enheter (även sådana som läggs till senare)';

  @override
  String get sd97ead609e => 'Får styra och ändra inställningar';

  @override
  String get s8be70baa9c => 'Får styra, inte ändra inställningar';

  @override
  String get sf2581756af => 'Du kan återkalla åtkomsten när som helst.';

  @override
  String s9a6818b304(String p0) {
    return 'Åtkomst given: $p0';
  }

  @override
  String get sdb0484d728 => 'Sparat';

  @override
  String get s52a64a3307 => 'Ge en installatör åtkomst';

  @override
  String get s2113bddc63 => 'Installatörs-ID';

  @override
  String get s6d7d0273ad => 'Sök';

  @override
  String get s36418f769d => 'Skanna installatörens QR-kod';

  @override
  String get scb4d6b0ddc => 'Installatör verifierad av Molaplan';

  @override
  String get s95fd3e8dc3 => 'Vad kommer installatören åt?';

  @override
  String get s0d395a6edd => 'Valda enheter';

  @override
  String s8affba28ec(String p0) {
    return '$p0 enheter nu; sådana som läggs till senare ingår.';
  }

  @override
  String get sbc76d76351 => 'Får ändra inställningar';

  @override
  String get s4fa2d2d66c =>
      'Temperaturer, lägen och andra inställningar. Av: installatören kan styra och se statusen.';

  @override
  String get s82b62bcb13 => 'Du har inga delbara enheter ännu.';

  @override
  String get s4e60c0286c =>
      'Hembryggan kontrollerar behörigheten för varje begäran. Enheternas lösenord och adresser lämnar aldrig hemmet.';

  @override
  String get sd431b45586 => 'Skriv minst 3 tecken av e-postadressen.';

  @override
  String get s2162e5cad2 => 'Ingen användare hittades.';

  @override
  String get s1ec9cc5828 => 'Installatörsstatus';

  @override
  String get s256fb6b50a => 'Verifierat namn';

  @override
  String get sd8a8961db3 => 't.ex. enskild firma';

  @override
  String get sb57dfb696c => 'Anteckning (endast administratörer)';

  @override
  String get s8ce95234d7 => 'Bevilja';

  @override
  String get s2eca996a49 => 'Namnet saknas.';

  @override
  String s5a4c72db4b(String p0, String p1) {
    return 'Installatör $p0: $p1';
  }

  @override
  String get se06acfd38d => 'Ta bort installatörsstatusen?';

  @override
  String sd35135676e(String p0, String p1, String p2) {
    return '$p0 ($p1) förlorar installatörsstatusen och all kundåtkomst ($p2) upphör direkt. ID:t behålls om statusen beviljas igen senare.';
  }

  @override
  String get se70c0caad3 => 'Ta bort status';

  @override
  String get s2679477d73 => 'Installatörsstatusen borttagen';

  @override
  String get s5ea6251452 =>
      'Bevilja installatörsstatus bara till någon vars namn och företag du har kontrollerat. Samma verktyg finns på molaplan.com/tilaa/hallinta (Asentajat).';

  @override
  String get sa7380f5e5c => 'Sök användare med e-post';

  @override
  String get sc023f30da1 => 'namn@exempel.se';

  @override
  String get s9a7d261596 => 'har inte öppnat appen ännu';

  @override
  String get sd4f8f15670 => 'installatör';

  @override
  String get sfee2ce49ea => 'status borttagen';

  @override
  String get s3ecd52ffc6 => 'Ansökningar';

  @override
  String get se5c4c1e153 => 'Inga öppna ansökningar.';

  @override
  String get s052118a469 => 'Godkänn';

  @override
  String get s493a1eaf08 => 'Decline';

  @override
  String get sc8ab77f768 => 'Installatörer';

  @override
  String get s65f12e7e23 => 'kunder';

  @override
  String get sf36e8af07c => 'Bevilja igen';

  @override
  String get s0361487148 => 'Ta bort installatörsstatus';

  @override
  String get s55d52c5ae1 => 'Denna enhet är inte på Wi-Fi';

  @override
  String s9a4dece965(String p0) {
    return 'Anslut den här enheten till ditt hem Wi-Fi (en $p0 använder). Eller, om du är borta, ställa in hembron så att sökningen körs på en enhet hemma.';
  }

  @override
  String get s3972820cd6 => 'Kunde inte nå enheten';

  @override
  String s0f480abb4a(String p0) {
    return 'Kunde inte nå enheten på $p0';
  }

  @override
  String sa82143ee02(String p0, String p1) {
    return 'Kontrollera att $p0 drivs.\nDen här enheten (eller hemmabron) måste vara på samma Wi-Fi.\nKontrollera adressen - den kan ändras. Tryck på \"Tack\" och sök igen.';
  }

  @override
  String get sd4d7ad1bab => 'En annan enhet svarade';

  @override
  String s5b7d02a301(String p0) {
    return 'Enheten på den adressen är inte $p0. Kontrollera adressen.';
  }

  @override
  String get sdac5622fa8 => 'Enheten begär ett lösenord';

  @override
  String get sbf9ee8aaec =>
      'Ett lösenord är inställt på enheten. Skriv det nedan och tryck på \"Konnect\".';

  @override
  String get s9e22388413 => 'En mer detaljer behövs';

  @override
  String sc8702d4da2(String p0) {
    return '$p0 berättar inte detta själv. Skriv det nedan och tryck på \"Konnect\".';
  }

  @override
  String get s83f57c7c24 => 'Fel lösenord';

  @override
  String get s32e85a0ba2 =>
      'Kontrollera lösenordet (fallet frågor). Du kan ändra det i enhetsappen.';

  @override
  String get sb1d36bfdd3 => 'Knappen trycktes inte i tid';

  @override
  String get sc994f6ec6e =>
      'Tryck på \"Försök igen\" och tryck sedan på knappen direkt.';

  @override
  String get s663202243e => 'Inget att kontrollera hittades';

  @override
  String get sb03997d94b =>
      'Enheten svarade men har inga växlar eller lampor. För molnet, skriv enhets-ID.';

  @override
  String get se6e01118ac => 'Kamera hittades, men inte dess videoadress';

  @override
  String get sca994210fb =>
      'Kameran svarade men berättade inte sin videoadress, och ingen av de vanliga RTSP-adresserna arbetade med denna inloggning. Kontrollera att RTSP/ONVIF finns på i kameraappen eller välj varumärket nedan och tryck på \"Connect\".';

  @override
  String get s869571042f => 'Cloud key eller server som inte accepterats';

  @override
  String get sab1763c592 =>
      'Kopiera nyckeln och servern igen från Shelly-appen (användarinställningarna → auktoriseringsmolnnyckel).';

  @override
  String get s855ffbfd24 => 'Kunde inte nå molnet';

  @override
  String get s739d569a9c => 'Kontrollera internetanslutningen.';

  @override
  String get sc96a3502b5 => 'För många förfrågningar';

  @override
  String get sed917dc2a2 => 'Molnet begränsar begäran. Vänta ett ögonblick.';

  @override
  String get s516dbdd784 => 'Hembron är från date';

  @override
  String get s70089507bf =>
      'Uppdatera Molaplan på bron (Inställningar → Kontrollera för uppdateringar).';

  @override
  String get scc1918f2dc =>
      'Kontrollera att bron hemma är på, Molaplan är öppen och det har internet.';

  @override
  String get se11f9b5084 => 'Kunde inte ansluta till enheten';

  @override
  String get s979376dca6 =>
      'Kontrollera adressen och att enheten är på, försök sedan igen. De tekniska detaljerna visar exakt anledning.';

  @override
  String get sce6d01c270 => 'Skriv adressen först';

  @override
  String get s65bbf3cab4 => 'Kontrollera adressen';

  @override
  String sb711cc1ce2(String p0, String p1) {
    return '$p0 är inte ett hemnätverk adress. De börjar vanligtvis med 192.168. - kontrollera det igen i $p1 app.';
  }

  @override
  String se60794c266(String p0) {
    return 'menade du $p0?';
  }

  @override
  String get s264fda2dee => 'Jag fixar det';

  @override
  String get s0a6098ac78 => 'Prova ändå';

  @override
  String sc1039f5cf6(String p0) {
    return 'Använd $p0';
  }

  @override
  String get s20f777bfef => 'Adressen finns på ett annat nätverk';

  @override
  String sbb1730fa00(String p0, String p1, String p2, String p3) {
    return 'Adress $p0 är inte på samma nätverk som den här enheten ($p1.x). Vanligtvis är den här enheten på ett annat Wi-Fi än $p2.\n\nGå med i samma Wi-Fi, eller ställa in hembron.';
  }

  @override
  String get s43370d968c => 'Fyll i första';

  @override
  String get s915c9a0db3 => 'Välj minst en';

  @override
  String sb160156a36(String p0) {
    return 'Lägg till: $p0';
  }

  @override
  String get s43d448a950 => 'Lägg till i hemvyn';

  @override
  String get sd890121a57 => 'Visa hemvyn';

  @override
  String get sb1717cc67c => 'A) Utan en hembro';

  @override
  String get s2082568a23 => 'Använd Shelly Cloud (ingen bro)';

  @override
  String get s5080d486b8 =>
      'Bäst om ingen enhet alltid stannar hemma - t.ex. din surfplatta reser med dig. Kontroll går via Shellys eget moln. Du behöver en nyckel från Shelly-appen (vi visar var).';

  @override
  String get s82985d5078 => 'B) genom en hembro';

  @override
  String get s78aec2034d =>
      'Hur kommer du att kontrollera ditt hem när du är borta?';

  @override
  String s03b3c3b3c8(String p0) {
    return 'En hembro är en enhet som ALLTID stannar hemma, slås på och på samma Wi-Fi som $p0 - t.ex. en gammal telefon, surfplatta eller PC. Dina andra enheter når den över internet (krypterad, ingen port vidarebefordran). En enhet som du bär runt är inte en bra bro.';
  }

  @override
  String get s688d1308d7 =>
      'När du är inloggad når hemanslutningen alla dina enheter automatiskt.';

  @override
  String get s96feb2f60a =>
      'Den här enheten stannar alltid hemma – gör den till bron';

  @override
  String get sb2a33a1ec4 =>
      'Håll den laddning med Molaplan öppen. Andra enheter ansluter med en QR-kod eller genom att logga in på samma konto.';

  @override
  String get s1b9f4ae6d5 => 'Bron är på en annan enhet - anslut till den';

  @override
  String get s13d739b710 =>
      'Skanna bron QR-koden. Enheter hittas sedan genom bron, även när du är borta.';

  @override
  String get sda6a1e50e9 =>
      'Hoppa för nu - lägg till i hemnätverket (fjärråtkomst kan ställas in senare)';

  @override
  String s6f326a48f9(String p0) {
    return 'Hitta: $p0';
  }

  @override
  String get sc788897ba0 =>
      'Söker genom hembron, så detta fungerar också hemifrån.';

  @override
  String get s0f7361f40c => 'Titta på ditt hem Wi-Fi. Tryck på din.';

  @override
  String get sda2b4c9721 => 'Öppna Wi-Fi inställningar';

  @override
  String get sc93d9cc14b => 'Ansluten – sök igen';

  @override
  String get s13f0596b74 => 'Söker... (ca 5 sekunder)';

  @override
  String s8eabd27f68(String p0, String p1) {
    return 'Ingenting hittas automatiskt. Kontrollera att $p0 är på och på samma Wi-Fi. Du kan också skriva adressen nedan.';
  }

  @override
  String get sa616ab181e => 'Skriv adressen';

  @override
  String get sb439b8abc3 => 'Eller skriv adressen';

  @override
  String get s178e07f06b => 'IP-adress';

  @override
  String get scf487a3699 => 'Var hittar jag det?';

  @override
  String get s9b9b0d01a2 => ' (valfritt)';

  @override
  String get s0a7134d0e3 => 'Tryck på knappen nu';

  @override
  String s43118959d5(String p0) {
    return '$p0 vänster';
  }

  @override
  String get sba10f23f03 => 'Ansluter…';

  @override
  String get s46c87a553f => 'Logga in på kameran';

  @override
  String get se4095d7d95 => 'Enhetens lösenord';

  @override
  String get sdbdf676485 => 'Anslut';

  @override
  String get s8f610a3bb2 => 'Jag är hemifrån';

  @override
  String get sf77125583f => 'Tekniska detaljer';

  @override
  String get sb629592b4b => 'Kamera varumärke';

  @override
  String get se3aa0f7164 => 'RTSP adress';

  @override
  String get s722ac06c6d =>
      'Utan inloggningen läggs användaren och lösenordet automatiskt till.';

  @override
  String s77ec7b376b(String p0) {
    return 'Hittade: $p0';
  }

  @override
  String get sac4debdb9c => 'Välj vad som går på hemvyn och namnge dem.';

  @override
  String get sfe5661e401 => 'Avmarkera alla';

  @override
  String s2618555da0(String p0) {
    return 'Välj alla ($p0)';
  }

  @override
  String get s86c3f92546 => 'Lägg också till ljusstyrka / kraft';

  @override
  String get s91571486e4 => 'Visa också kraft (W)';

  @override
  String sf86536db42(String p0) {
    return 'Klart! $p0 kort tillagda';
  }

  @override
  String get sbfaea66122 =>
      'Brickorna arbetar hemma och bort genom molnet - inget annat att göra.';

  @override
  String get se7c68b3bed =>
      'Brickorna arbetar hemma och bort genom hembron - inget annat att göra.';

  @override
  String get sbc8469cce1 =>
      'Brickorna fungerar på ditt hemnätverk. För att styra från var som helst, ställa in hembron.';

  @override
  String get s417eb9a875 => 'Ställ in fjärråtkomst';

  @override
  String get s53a9fe5e42 =>
      'Det finns inget Molaplan-konto med den e-postadressen.';

  @override
  String get sb4bd4baa5c =>
      'Ingen Molaplan-användare med den adressen. De måste logga in på Molaplan 0.9 en gång - eller skicka dem en inbjudningskod.';

  @override
  String get s7ed2aecb01 =>
      'Ingen delbar utvald (tävlingar kan inte delas ännu).';

  @override
  String get s707b7ff598 => 'Inbjudan finns inte längre.';

  @override
  String get s5ea320fb1c =>
      'Lås upp kontohemligheterna på den här enheten först (Konto → Lås upp med lösenord). Delning använder kontonyckeln.';

  @override
  String get s2855893bfc =>
      'Inbjudan gäller en installatör och kan bara användas av en installatör som Molaplan har godkänt (Inställningar → Installatör → Ansök).';

  @override
  String get sb8df145fc9 => 'Bara Molaplans administratörer kan göra detta.';

  @override
  String get sa562754cb5 => 'Koden är fel, löpt ut eller redan använt.';

  @override
  String get s9c37d7a89c =>
      'Hembron svarar inte. Delningen behöver hembron (fjärråtkomst) - behörigheter verkställs där.';

  @override
  String get sc858a8f851 =>
      'Hembron är för gammal för att dela. Uppdatera den (Fjärråtkomst → Uppdatera bro).';

  @override
  String get s1a52f53861 => 'Ingen anslutning till Molaplan-kontot.';

  @override
  String s2457ec4502(String p0) {
    return 'Kontotjänsten vägrade: $p0';
  }

  @override
  String get s4bc537975e => 'Hembron är offline.';

  @override
  String get s2fb5fe14e4 => 'Andelen återkallades.';

  @override
  String get s7b44d47d45 => 'Hembron svarar inte.';

  @override
  String get s8eddd585bc => 'Ingen anslutning.';

  @override
  String get s47998395f5 => 'Inte tillåtet.';

  @override
  String get s7f504a8c64 => 'Visa endast';

  @override
  String get s9c067115ef => 'Kontrollkontroll';

  @override
  String get s8343921765 => 'Full (kontroll + inställningar)';

  @override
  String get s211d9f0a3a => 'Kod som inte används än';

  @override
  String get s1e6b3fe5dc => 'Väntar på acceptans';

  @override
  String get sb13063b8cd => 'Bekräftas...';

  @override
  String get s13b6f87b0a => 'Aktivt';

  @override
  String get sed1d8dbf2b => 'Declined';

  @override
  String get s0123f33869 => 'Återkallad';

  @override
  String get s844e081db8 => 'Delande';

  @override
  String get scdfdf5d233 =>
      'Att dela behöver ett Molaplan-konto så att inbjudningar kan nå människor och krypteringsarbeten.';

  @override
  String get s85abc4496d =>
      'Ge en familjemedlem, granne eller installatör tillgång till de enheter du väljer. Lösenord och adresser lämnar aldrig hem, och du kan återkalla när som helst.';

  @override
  String get sb4602bb0a6 => 'Dela enheter';

  @override
  String get sffe19ad543 => 'Använd en inbjudningskod';

  @override
  String get s61036a5d51 => 'Inbjudningar till dig';

  @override
  String get s8af08eb19e => 'Enheter';

  @override
  String get sbb84536839 => 'Accepterad';

  @override
  String get sdfaf8c242b => 'Godkänn';

  @override
  String get s2fd1394b33 => 'Delad med mig';

  @override
  String get seaa0c13606 => 'Dina aktier';

  @override
  String get s450c60afd0 => 'Du har inte delat något.';

  @override
  String get s33f41d417c => 'Inbjuda kod';

  @override
  String get s9cdf3dcc87 => 'Återkalla aktien?';

  @override
  String get s9d0ac1d1ee =>
      'Tillgången slutar så snart hembron hör av den (vanligtvis på en gång).';

  @override
  String get s4417570cbb => 'Revoke';

  @override
  String get s280e22cbc9 => 'Dela återkallad';

  @override
  String get sd742357fc8 => 'Ditt namn i aktier';

  @override
  String get sfe0000a1a9 =>
      'Säkerhet: hembron kontrollerar rättigheterna för varje begäran. Anslutningsuppgifterna reser krypterade till mottagarens nyckel endast; enhetslösenord och adresser lämnar aldrig hemmet.';

  @override
  String get s0577e25cbe => 'Lägg till en kund med en kod';

  @override
  String get s3d00dee1a9 => 'Använd';

  @override
  String get sce4c69f42c =>
      'Kod accepterad. Access öppnas när ägarens Molaplan bekräftar det (vanligtvis inom några minuter).';

  @override
  String get sd1520d6367 =>
      'Ge koden (eller länken) till mottagaren: Molaplan → Dela → Använd en inbjudningskod. Giltig i 7 dagar, en gång.';

  @override
  String get s563abff5ad => 'Kopiera länk';

  @override
  String get s0daf5e9cb6 =>
      'Inbjudan skickas – mottagaren accepterar den i Molaplan.';

  @override
  String get s707a062202 => 'Förändringsandelar';

  @override
  String get s79f72dbe13 => '1. vad man ska dela';

  @override
  String get s58e14dc230 =>
      'Tryck på en vy för att dela alla dess enheter, eller välj dem en efter en.';

  @override
  String get sdb49fc5671 => 'Hela utsikten';

  @override
  String get sa7cf1a01d7 => '2. Rättigheter';

  @override
  String get s3b2376ac74 => 'Visa vy';

  @override
  String get s6605942623 => 'Full Full Full Full Full Full Full Full Full Full';

  @override
  String get s9ccbd78d51 => 'Ser stater och avläsningar, kan inte kontrollera.';

  @override
  String get sb143b5c9f1 =>
      'Kan växla och justera, kan inte ändra inställningar (t.ex. temperaturinställningar).';

  @override
  String get s32dc2aa139 =>
      'Kontroll- och enhetsinställningar. Aldrig dina egna vyer eller lösenord.';

  @override
  String get se153d3c421 => '3 till vem';

  @override
  String get s62e68022e1 => 'En Molaplan-användare (e-post)';

  @override
  String get s447da2f746 => 'Inbjuda kod eller länk';

  @override
  String get se7272a5713 => 'Namn för aktien (valfritt)';

  @override
  String get s1f9799af4e => 't.ex. stuga';

  @override
  String get s03f60936b0 => 'Rättigheter per enhet';

  @override
  String get s385022d526 => 'Visa vy';

  @override
  String get s482464ebd5 => 'Kontrollkontroll';

  @override
  String get s5897aaa050 => 'Meddela ett ntfy-ämne (valfritt)';

  @override
  String get sd4faf9db62 =>
      'Meddelandet innehåller inga kod- eller enhetsdetaljer.';

  @override
  String get sdec87898c3 => 'Skapa inbjudningskod';

  @override
  String get s19c2104a9d => 'Skicka inbjudan';

  @override
  String get s8b4d48dfaf => 'Ägare';

  @override
  String get sbfe79d1f5f => 'Uppdaterad';

  @override
  String get s90944b5e7c => 'Uppmärksamhet';

  @override
  String get scf2e61da2c => 'inte svara';

  @override
  String get s1364743ec7 => 'larm';

  @override
  String get s5416a5cdf7 => 'Kör';

  @override
  String get s8debff3196 => 'Visa bild';

  @override
  String get s2220ce611a =>
      'Kunder som gav dig tillgång. Du ser bara de delade enheterna och agerar inom de rättigheter som kunden gav – aldrig deras lösenord.';

  @override
  String get s6f3c62fc03 => 'Din installatörsstatus är inte giltig.';

  @override
  String s7ebc2621b7(String p0) {
    return 'Inga kunder ännu. Ge kunden ditt installatörs-ID $p0: kunden öppnar Inställningar → Installatör → Ge åtkomst.';
  }

  @override
  String get sa52cf49adc => 'Väntar på kundens Molaplan för att bekräfta';

  @override
  String get s35e8813a82 => 'Varningar';

  @override
  String get sc3abd09cd9 => 'Anpassad färg';

  @override
  String get s10e7cef8c1 => 'Hue Hue';

  @override
  String get s59b65e3322 => 'Mättnad';

  @override
  String get s750ed8d878 => 'Ljushet';

  @override
  String get sa39e78050c => 'Välj Välj Välj Välj';

  @override
  String get sd9923cda70 => 'Inte hemma? Sväng på fjärråtkomst';

  @override
  String get sba1684ff6c => 'Inte ännu';

  @override
  String get sef20071510 => 'Kör historia';

  @override
  String get s9f1334d4e2 => 'Skript';

  @override
  String get s6b7c1c52da => 'Scener';

  @override
  String get s8613961a5a => 'Meddelanden';

  @override
  String get s4f745952b8 => 'Kör på denna hembro, även när appen är stängd.';

  @override
  String get s99cbed55fd =>
      'Kör på hemmabron – fungerar även när appen är stängd.';

  @override
  String get s0247948956 =>
      'Hembron är en gammal version: uppdatera den så automationer körs också medan appen är stängd. Kör i den här appen för tillfället.';

  @override
  String get s21fae60578 =>
      'Kör i denna app medan den är öppen. En hembro kör dem medan appen är stängd.';

  @override
  String get s66c54e2286 => 'Automationer är avstängda på den här enheten.';

  @override
  String get s57f6ce1c7f => 'Vad är en hembrygga?';

  @override
  String get s4057f67774 => 'Mon Tue Wed Thu Fri Sat Sun';

  @override
  String get s456d234874 => '(Enhet saknas)';

  @override
  String get sf3779b50c6 => 'på';

  @override
  String get s7c3e905972 =>
      'på At at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at at';

  @override
  String get s61637a44e4 => 'Soluppgång';

  @override
  String get sa0d5958b56 => 'Solnedgång';

  @override
  String s467fd3c653(String p0) {
    return '$p0 billigaste timmar';
  }

  @override
  String s65660a4b23(String p0) {
    return 'Pris över $p0 c/kWh';
  }

  @override
  String sba8fa4af37(String p0) {
    return 'Pris under $p0 c/kWh';
  }

  @override
  String get s3324b26519 => 'Utomhus';

  @override
  String sf3c2cf0323(String p0, String p1) {
    return '$p0 offline $p1 min';
  }

  @override
  String get s1b359d69e2 => 'Skapa automatisering';

  @override
  String get s835865fd04 => 'Mallar';

  @override
  String s73d042449b(String p0, String p1) {
    return 'Inga automationer ännu. Börja från en mall, t.ex. \"$p0\" eller \"$p1\".';
  }

  @override
  String get s8039add5ed => 'Untitled';

  @override
  String get sf2d3a43ee8 => 'Inga runs ännu.';

  @override
  String get s5c7338ab38 => 'Redogjorda automationer';

  @override
  String get s354eb362d8 => 'Välj enheten';

  @override
  String get s73a65d7dff => 'Välj enheterna';

  @override
  String get s6bc0df13b3 => 'Inga enheter ännu.';

  @override
  String get s90db0cb9e0 => 'Ny automation';

  @override
  String get s3aeb373060 => 'Redigera automation';

  @override
  String get sac3c555554 => 'Ta bort automationen?';

  @override
  String get s53879bce24 => 'Vad startar automatiseringen';

  @override
  String get s179f389617 => 'Endast om (valfritt)';

  @override
  String get s803ff4f73b => 'Alla villkor måste hålla';

  @override
  String get sd930bdad70 => 'Lägg till villkor';

  @override
  String get s6f21edea24 =>
      'Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do Do';

  @override
  String get scbe17b6bf8 => 'Åtgärder i ordning';

  @override
  String get secee53bdd2 => 'Mer Mer';

  @override
  String get scb62f41105 => 'Minsta minuter mellan runs';

  @override
  String get s643b680e89 =>
      'Slutar t.ex. en flapping sensor från att skicka dussintals meddelanden.';

  @override
  String get s4c4ab28899 => 'Testa nu';

  @override
  String s7956c29b83(String p0) {
    return 'Ran: $p0';
  }

  @override
  String get s6e85ff5983 => '(inga enheter)';

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
  String get sc300fc12e3 => 'Enhetsvärde';

  @override
  String get sbab0e0dc9d => 'Enhetstillstånd (på/av, sensor)';

  @override
  String get s76de9025a1 => 'Dagens tid';

  @override
  String get s04c0bcdd51 => 'Soluppgång / solnedgång';

  @override
  String get s869f0d57af => 'Vädret (utomhustemperatur)';

  @override
  String get sa4261f6e35 => 'Enhet som inte svarar';

  @override
  String get se0a362c060 => 'Typ';

  @override
  String get s4f62fd1f09 => 'När den vänder';

  @override
  String get sab64be3b87 => 'på/larm';

  @override
  String get sbfd08915bd => 'Off / lugn';

  @override
  String get s0aaa16b331 => 'Tid (HH:MM)';

  @override
  String get s9b4b2b3129 => 'Event';

  @override
  String get s8c6de5d661 => 'Offset på några minuter (−60...60)';

  @override
  String get s59b3e665bf => 'När när när';

  @override
  String get s6a23c4a83f => 'Pris nedan';

  @override
  String get s49083cabf7 => 'Pris ovan';

  @override
  String get s411924155f => 'De billigaste timmarna på dagen';

  @override
  String get s04dc35851a => 'Antal timmar';

  @override
  String get s6f22fd8c19 => 'Minuter';

  @override
  String get s32fa6270c8 => 'Ingen vald = varje dag';

  @override
  String get s966e223f86 => 'Tid fönster';

  @override
  String get s45aae9c551 => 'Weekdays';

  @override
  String get sf05bf9c751 => 'Enhetstillstånd / värde';

  @override
  String get sb74370fc1e => 'Utomhustemperatur';

  @override
  String get s585b4c519f => 'Mörk / ljus';

  @override
  String get s6019108a01 => 'Villkor';

  @override
  String get s9593939a4c => 'Ta bort';

  @override
  String get sc26d444f90 => 'Från';

  @override
  String get s796739363a => 'för att';

  @override
  String get s39d9f766c6 => 'Jämför';

  @override
  String get sa56aea2cf9 => 'State on/off';

  @override
  String get sc2521b6b15 => 'Nummernummer';

  @override
  String get sfffb54daf4 => 'Tillstånd';

  @override
  String get se2b3e45118 => 'mörkt mörkt mörkt';

  @override
  String get s709da04ca2 => 'ljust ljust ljus';

  @override
  String get s723d015dc1 => 'Lägga till åtgärder';

  @override
  String get sae3489a6c9 => 'Kontrollera en enhet';

  @override
  String get s1f6962ba39 => 'Kör en scen';

  @override
  String get s02df6d430a => 'Kör ett skript';

  @override
  String get sed67c16508 => 'Skicka ett meddelande';

  @override
  String get s654489bb29 => 'Vänta';

  @override
  String get sf216517af2 => 'Vänta tills';

  @override
  String get sde1657b024 => 'Om / annat';

  @override
  String get sbc8e165fbf => 'Action';

  @override
  String get s750f16460c => 'Av/på';

  @override
  String get s7a544fe304 => 'Ställ värde';

  @override
  String get s929344a68b => 'Presstryck';

  @override
  String get s02cfe06e04 => 'Scen';

  @override
  String get sdb235c3ced => '(inga scener)';

  @override
  String get sdced476aeb => 'Skript';

  @override
  String get s4f330bfcfb => '(inga skript)';

  @override
  String get s8a8673aafe => 'Rubrik';

  @override
  String get s34900f9d58 => 'Texttext';

  @override
  String get s3c2ee8fe0d => '{summary} = väder, pris och hemstat';

  @override
  String get sb55a08c07c => '1 – tyst';

  @override
  String get s423418208e => '2 – låg';

  @override
  String get sbad27a6b89 => '3 – normalt';

  @override
  String get s8c17000b91 => '4 – hög';

  @override
  String get sa0738def3a => '5 – brådskande (även i tysta timmar)';

  @override
  String get sb33001c92e => 'Tryck öppnar';

  @override
  String get s07d7410408 => 'Appen';

  @override
  String get sfb10dd528e => 'Sekunder';

  @override
  String get sd7ab969914 => 'På de flesta sekunder';

  @override
  String get sccfe5a0d41 => 'Sedan dess,';

  @override
  String get s2d983e951b => 'Else';

  @override
  String get sf936d0b01d => 'Upp';

  @override
  String get s2c7a2bbac1 => 'Nytt manus';

  @override
  String get s5b2dd17cbc =>
      'Ett skript är en lista över steg: styra en enhet, vänta, meddela, om / ring ... Kör den från en knapp, en automation eller på distans (iPhone Shortcut).';

  @override
  String get s6fe2320f3d => 'Stoppa';

  @override
  String get se9ee46a9c8 => 'Kör';

  @override
  String get s45fbc06cdf => 'Mer Mer';

  @override
  String get s0557e03436 => 'Lägg till en knapp på framsidan';

  @override
  String get sfd2d047cb2 => 'Avancerat';

  @override
  String s766b50721b(String p0) {
    return '$p0 steg';
  }

  @override
  String get s061d1b874b =>
      'fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärr fjärrfjärrfjärr fjärrfjärr fjärrfjärr fjärr fjärrfjärr fjärrfjärr fjärrfjärrfjärrfjärr fjärr fjärr fjärr fjärrfjärrfjärrfjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr fjärr f';

  @override
  String sdae343a445(String p0) {
    return 'Knapp till $p0';
  }

  @override
  String get sb886978015 => 'Redigera script';

  @override
  String get scc2c1e2508 => 'Run log';

  @override
  String get sacf2fbc495 => 'Ta bort manuset?';

  @override
  String get s01de653429 => 'Steg';

  @override
  String get s01d3c353e2 => 'Kodkod';

  @override
  String get s637ae4dbf4 => 'Molaplan skript';

  @override
  String get sea09cb0d3b =>
      'Funktioner: få igång toggle vänta meddela scenpriset billigast temp tid timme vardagslogg. Ingen fil eller nätverksåtkomst; 10 min tidsgräns.';

  @override
  String get s4436dfd836 => 'Extern trigger (PIN) är på';

  @override
  String get s759ff4cada => 'Extern trigger, t.ex. iPhone genvägar';

  @override
  String get s420f3ec828 => 'Extern start (valfritt)';

  @override
  String get sb3cef805ee =>
      'Skriptets knapp fungerar utan detta: den kör skriptet i appen, och genom fjärråtkomst automatiskt när du är borta. Du behöver bara detta för att starta skriptet från utanför Molaplan, t.ex. iPhone genvägar.';

  @override
  String get sb6e92eacba => 'Tillåt start från utsidan (PIN)';

  @override
  String get sa1692aa719 =>
      'Ett meddelande till ntfy-adressen eller en iPhone-genväg startar manuset med PIN.';

  @override
  String get s0a5410ea4f => 'Remote PIN (minst 4 tecken)';

  @override
  String sceba001122(String p0, String p1, String p2, String p3) {
    return 'Skicka \"kör $p0 <PIN>\" till $p1\niPhone genvägar: \"Få innehåll av URL\" → $p1, metod POST, kropp: kör $p0 <PIN>';
  }

  @override
  String get seff0aac16e => 'Kopiera URL';

  @override
  String get sff9b69c6ca => 'Klar';

  @override
  String get sa32d82e779 => 'Knapp i appen';

  @override
  String get s65fc3dd69a =>
      'Knappen kör manuset med en kran. Det fungerar hemma och även hemifrån genom hembron - inga genvägar behövs.';

  @override
  String s89638a5b8e(String p0) {
    return 'Knapp i utsikten $p0';
  }

  @override
  String get s509056a76d => 'Lägg till en annan knapp';

  @override
  String get s0f8939787f => 'Knappen skapas när du sparar.';

  @override
  String get s5a8c602b42 => 'Visa vy';

  @override
  String get se49d14ff44 => 'Vilken vy får knappen?';

  @override
  String get s09f745552a => 'Spara nuvarande stat';

  @override
  String get s44367fdec5 => 'Tomma';

  @override
  String get sc41824585d =>
      'En scen sätter många enheter samtidigt, t.ex. \"Movie night\" eller \"All off\".';

  @override
  String s7e7b0848fb(String p0) {
    return '$p0 åtgärder';
  }

  @override
  String get s7cdee3dc7d => 'Vilka enheter går i scenen?';

  @override
  String get sde0d544a4c => 'Scennamn';

  @override
  String get scff2a13871 => 't.ex. filmkväll';

  @override
  String get se3ba6a13bb => 'Ny scen';

  @override
  String get s020a1af0d8 => 'Edit Scen';

  @override
  String get s4dbd6f62bf => 'Ta bort scenen?';

  @override
  String get sf1ed05f7de => 'Knapp på utsikt';

  @override
  String sf1541ca978(String p0) {
    return 'Knapp till $p0';
  }

  @override
  String get se250251ff0 => 'Push-meddelanden';

  @override
  String get s91a8948ad7 => 'Genom ntfy (inget Google-konto behövs)';

  @override
  String get sbdd6c9bad2 => 'Visa på den här enheten';

  @override
  String get se1e0d398d7 =>
      'Appen lyssnar på meddelanden medan du kör (på Windows också från brickan).';

  @override
  String get s6993f32ed2 => 'Kör automationer i denna app';

  @override
  String get sc0f6ea8ebe =>
      'När det inte finns någon hembro. En hemmabro kör alltid dem, även när appen är stängd.';

  @override
  String get sb35519f8e9 => 'Nära till brickan';

  @override
  String get s49ca9b6082 =>
      'Stängning av fönstret håller Molaplan bredvid klockan så meddelanden anländer.';

  @override
  String get sc6d6d4016e => 'Telefon, när Molaplan är stängd';

  @override
  String get sb460bbf010 =>
      'Installera ntfy-appen (Android: Google Play / F-Droid, iPhone: App Store) och prenumerera på detta ämne. Meddelanden anländer även när Molaplan är stängd.';

  @override
  String get saa54f34e98 => 'Copy prenumererar länk';

  @override
  String get s8f19ff1e21 => 'Tyst timmar';

  @override
  String get s1cc7f7a75f => 'Endast brådskande (5) kommer igenom.';

  @override
  String get s973f30f5e8 => 'Från (HH:MM)';

  @override
  String get sb13eeff3cd => 'För (HH:MM)';

  @override
  String get s2f7a5f57b1 => 'Mute Mute';

  @override
  String get sa81c1da011 => '1 timme';

  @override
  String get s0ca30924bd => '8 timmar';

  @override
  String get s38bb718aaf => '24 timmar';

  @override
  String s36ef8a86e1(String p0) {
    return 'Unmute (tills $p0)';
  }

  @override
  String get s0183ae0a12 => 'Skicka ett testmeddelande';

  @override
  String get sd95091858f => 'Molaplans meddelanden fungerar';

  @override
  String get s58a8bfdd9f => 'Test skickat';

  @override
  String get s5c380d76b6 => 'Senaste';

  @override
  String get s9d75942e41 => 'Redo automation';

  @override
  String get s70860413a1 =>
      'Ljus vid solnedgången, vattenläckage → larm, billiga timmar...';

  @override
  String get s8b5be90c1e => 'Din egen automation';

  @override
  String get sa9402c105a => 'När / Om / Gör';

  @override
  String get s4102c7e085 => 'Scen från det nuvarande tillståndet';

  @override
  String get s21ee7e78ee => 'Många enheter med en knapp';

  @override
  String get s5afa6e08f2 => 'Steg i ordning, väntar, om/else';

  @override
  String get s8070a25da8 => 'Gruppkoncernen';

  @override
  String get sf5f1ae9c9e => 't.ex. alla vardagsrumsljus som ett kort';

  @override
  String get s73f89f4de7 => 'Vilka enheter går i gruppen?';

  @override
  String get s5b68340d84 => 'Gruppnamn';

  @override
  String s1b087cdbbd(String p0) {
    return 'Allt: $p0';
  }

  @override
  String get s876c7230a2 => 'Lägg till enhet';

  @override
  String get sa252f06bff =>
      'Välj ditt enhetsmärke. Molaplan hittar det och skapar plattorna.';

  @override
  String get s5b3b5e5a24 =>
      'Sök varumärke eller enhet (t.ex. Shelly, Hue, IKEA)';

  @override
  String get sa427be10c9 => 'Hitta och ansluta automatiskt';

  @override
  String get s6f4cc0844f => 'Kommande – hur man använder den idag';

  @override
  String get s846ee3bc67 => 'Andra enheter';

  @override
  String get sdeadd78d47 => 'Thermostat värme kylning';

  @override
  String get s48264cfe32 => 'Termostat';

  @override
  String get s641a848754 =>
      'Håller den temperatur du vill ha: styr reläer eller en värmepump från en termometer. Kan spara med spotpriser.';

  @override
  String get s94493d01ca => 'Väderprognos temperatur regn vind';

  @override
  String get scb3570338f =>
      'Vädret nu och per timme: temperatur, regn och vind där du bor. Ingen enhet behövs.';

  @override
  String get s2a9b6fedd9 => 'Kan inte hitta ditt varumärke?';

  @override
  String get scfc7244d06 =>
      'Husqvarna, Zigbee, Tuya, värmepumpar... se hur man använder dem idag.';

  @override
  String get sf7b77783e5 => 'Annan (manuell inställning)';

  @override
  String get sc168355ee6 => 'Annan enhet (avancerat)';

  @override
  String get s3022f72ece => 'Alla anslutningstyper.';

  @override
  String get s2d1d488d6d => 'för tekniska användare.';

  @override
  String get s6f1c11270c => 'Innehåller exempelinställningar';

  @override
  String s4f55f417b1(String p0) {
    return 'Enheten har $p0 reläer';
  }

  @override
  String get sab3ebba17a => 'Enheten har 1 relä';

  @override
  String get sfa48c40832 => 'Energimätning';

  @override
  String get sc8d1abbd21 => 'Kortnamn';

  @override
  String get s183ed60009 => 'OK';

  @override
  String s1ea8fe913b(String p0) {
    return 'Adress: $p0';
  }

  @override
  String get s16dc13070c =>
      'Home Assistant använder ett självsignerat certifikat. Det godkändes eftersom adressen finns i hemnätverket.';

  @override
  String get sd531eb2fc2 =>
      'Home Assistant hittades inte automatiskt. Skriv adressen du öppnar den med (t.ex. http://192.168.1.20:8123 eller Nabu Casa-adressen).';

  @override
  String get s7def041e83 => 'Hittade Home Assistant:';

  @override
  String s2967a37e01(String p0, String p1) {
    return 'Hittade: $p0 – $p1';
  }

  @override
  String get s8f4c0baf1a =>
      'Inga enheter hittades automatiskt. Skriv adressen själv - hitta den i routern eller enhetsappen.';

  @override
  String get s104238f11e => 'Hittade enheter – välj din:';

  @override
  String get sd5f9dce947 => 'Sök är inte tillgängligt på detta nätverk.';

  @override
  String get s26abc57d91 => 'Lär in fjärrkontrollens knappar?';

  @override
  String get sc709f38633 =>
      'Grundläggande kontroll fungerar redan. Du kan också lära andra fjärrknappar, t.ex. \"Turbo\".';

  @override
  String get s6cac83dd5e => 'Inte nu';

  @override
  String get s97ea2eeb11 => 'Lär in nu';

  @override
  String get s09cfb7b2a1 => 'Enheten tillagd';

  @override
  String sda9574390f(String p0) {
    return 'Enhet och $p0 kakel tillagda';
  }

  @override
  String get sd51ee1ec8d =>
      'Förinställda inställningar är exempel. Kontrollera dem mot din enhetsmanual innan du förlitar dig på dem.';

  @override
  String get s566585dc66 =>
      'IR är envägs: värmepumpen bekräftar inte. Molaplan skickar alltid hela staten och visar vad den skickade. Lär dig andra fjärrknappar senare: Anslutningar → blaster → \"Lär fjärrkontroll\".';

  @override
  String get s0dd21e026c => 'Guide och automatisk sökning';

  @override
  String get s695a011cc1 => 'Söker…';

  @override
  String get s47d409fddd => 'Sök nätverk';

  @override
  String get sa62eebe6bd => 'Detektera reläer';

  @override
  String get s7196b72140 =>
      'Inga infödda Modbus TCP - en RS485 → TCP-gateway behövs.';

  @override
  String get s2e8ba44677 => 'Källa';

  @override
  String get sceb8e47d07 => 'Testa anslutningen';

  @override
  String get s02ce5f4a01 => 'Fungerar!';

  @override
  String get sb9e9e55164 => 'Dessa kort skapas';

  @override
  String get s1cb2891ef2 => 'Fyll i fälten märkta med * för att se plattorna.';

  @override
  String get s504861ee78 =>
      'Inga färdiga plattor - du kan lägga till dem senare med pennaknappen.';

  @override
  String get s1094266d4c => 'Visar ett värde';

  @override
  String get sf6ae3f3323 => 'Strömbrytare';

  @override
  String get s20dad69675 => 'Knapp';

  @override
  String get s0e9f94df05 => 'Reglage';

  @override
  String get s109b454866 => 'Kamera view';

  @override
  String get s37153e0e80 => 'Avancerade inställningar';

  @override
  String get s0ca55a9cae =>
      'Andra enheter använder tekniska inställningar (HTTP, MQTT, Modbus...). Om ditt varumärke är listat, använd det istället.\n\nSlå på avancerade inställningar? Du kan stänga av dem i Inställningar.';

  @override
  String get s9630135746 => 'Slå på';

  @override
  String get sbcdff8f72a => 'Vilken kamera har du?';

  @override
  String get s67bf18fb6f => 'Övrig kamera (ONVIF)';

  @override
  String get s772c158a57 => 'TCP';

  @override
  String get sea00017814 => 'låg latens';

  @override
  String get s2d65587b87 => '8';

  @override
  String get s2ad22696ca => 'Språk';

  @override
  String get s7efc5653d2 => 'Enhetens språk';

  @override
  String s3e5741712a(String p0) {
    return 'Denna Shelly är en energimätare - ersätt växeln med $p0 mätkort?';
  }

  @override
  String sfe2074ae81(String p0) {
    return 'Enheten har $p0 reläer - lägg till resten?';
  }

  @override
  String sf1319d04d0(String p0) {
    return 'Lägg till $p0';
  }

  @override
  String get s95f80e9bdf => 'Fix';

  @override
  String get s66ad384363 => '24h framåt';

  @override
  String get s6df3187e65 => 'Idag + imorgon';

  @override
  String get s76379cf7c6 => '48 h';

  @override
  String get s306729fe62 => 'Inga priser';

  @override
  String get sff03a35d96 => 'I 1 h';

  @override
  String get sf9e22ac5e7 => 'gamla priser';

  @override
  String get sa0bd9ad5b1 => 'Exempelkamera - lägg till din egen med Add-enhet';

  @override
  String get s4529c1010a => 'Välj en kameraanslutning';

  @override
  String get s98bf81bba3 => 'Live video fungerar inte på den här enheten';

  @override
  String get seb2bb5cbce =>
      'Live video visar bara på hemnätverket. Denna kamera har ingen stillbild för fjärranvändning.';

  @override
  String get sc95fb5440b => 'Stream slutade';

  @override
  String get sd55dd196f6 =>
      'Ingen live-video. Kontrollera att du är på hemmanätverket och RTSP är på i kameran.';

  @override
  String get s8e574c3313 => 'Effekt';

  @override
  String get sa9360bdda1 => 'Fläkt';

  @override
  String get sc7d02fbe84 => 'Värmepump';

  @override
  String get s8d06ee5308 => 'Larm';

  @override
  String get sfb63e3c23f => 'Lås';

  @override
  String get s2f42d90475 => 'Vattenvatten';

  @override
  String get sf2d10dd213 => 'El/kraft';

  @override
  String get s4594c7448e => 'Besparingar / billigast';

  @override
  String get s291ca127d6 => 'Garage';

  @override
  String get sb543af1c63 => 'Dörr';

  @override
  String get s60b1079d6c => 'Fönster';

  @override
  String get s66ce56ca38 => 'Börja';

  @override
  String get s0ab3a44562 => 'Timer';

  @override
  String get s3044a10005 => 'Nätverk';

  @override
  String get s1f67139f55 => 'Sauna / uppvärmning';

  @override
  String get sf21fd72396 => 'Outlet';

  @override
  String get s7783fe5fca => 'Favorit';

  @override
  String get s912ea5d2ec => 'Skicka';

  @override
  String get se223375393 => 'Lista List';

  @override
  String get sfb0b971c01 => 'Svängning';

  @override
  String get see42f2d999 => 'Fjärr';

  @override
  String get s9126bf24a0 => 'Sol sol sol solen';

  @override
  String get sdaa7d4de12 => 'Scen';

  @override
  String get s11cc92bdc3 => 'Radon';

  @override
  String get s095db91dfb => 'CO₂';

  @override
  String get s4b1eda4282 => 'Luftkvalitet';

  @override
  String get sfe55fd97fa => 'All tyst.';

  @override
  String s162c54ed4c(String p0) {
    return '$p0: gjort';
  }

  @override
  String get se26e839c2f => 'Måndag Måndag Måndag';

  @override
  String get s763254941f => 'Tisdag tisdag tisdag';

  @override
  String get sf3448cdd52 => 'Onsdag onsdag onsdag';

  @override
  String get sc34ca7eddb => 'Torsdag torsdag torsdag';

  @override
  String get sfa82438bec => 'fredag fredag fredag';

  @override
  String get s517c348371 => 'Lördag lördag';

  @override
  String get sb1f0e72163 => 'Söndag söndag';

  @override
  String get s80c4ecec94 => 'c/h';

  @override
  String get sb68e905fc4 => 'Förbrukning (kWh)';

  @override
  String get s5fc5085143 => 'Kostnad';

  @override
  String get s2b2118a93b => 'Gamla data';

  @override
  String get sb730159a01 => 'Pris nu';

  @override
  String get s68fcfcfed1 => 'Billigaste timmen i dag';

  @override
  String get s86ff059f5e => 'Medelpris i dag';

  @override
  String get s7b911d48c6 => 'Dyraste timmen i dag';

  @override
  String get s29dbf49d92 => 'Kostnad just nu';

  @override
  String get s723c887da6 =>
      'Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min Min';

  @override
  String get s3b36524e04 => 'medel';

  @override
  String get scaaff6345d => 'max max max max max';

  @override
  String get s5f131c3ec4 => 'Förbrukning';

  @override
  String get s039bb374fe => 'Siffrorna är timmedelvärden';

  @override
  String get s62cfd94468 => 'Billigaste timmar på natten';

  @override
  String get s7995dff292 =>
      'Under de billigaste natttimmarna (22-07). Bra för vattenvärmare och EV-laddning.';

  @override
  String get sf92675687a => 'Billigaste timmar på dagen';

  @override
  String get sf71a753c59 => 'Under de billigaste timmarna på dagen.';

  @override
  String get s6c070f7367 => 'Av när el är dyrt';

  @override
  String get s214f034099 =>
      'Stänger av ovanför gränsen och tillbaka på när priset sjunker.';

  @override
  String get s3939cfc37e => 'När elektricitet är billigt';

  @override
  String get scecc366bc4 => 'Endast när priset ligger under gränsen.';

  @override
  String get s6e700ae773 => 'Prisstyrning borttagen';

  @override
  String get s5aa3400a7a => 'Prisstyrning sparad';

  @override
  String get s2f5410429b =>
      'Regeln körs på den här enheten (hembro). Håll den hemma.';

  @override
  String sb86a43361f(String p0) {
    return 'Regeln körs på hemmabroen - din telefon kan vara avstängd.';
  }

  @override
  String get s538517b71b =>
      'Ingen hembro ännu. Regeln sparas men körs bara en gång en alltid-på tablett eller PC hemma är bron (Inställningar → Fjärråtkomst).';

  @override
  String s1a9e9bead3(String p0) {
    return 'Priskontroll: $p0';
  }

  @override
  String get s6b609c3376 => 'När ska den vara på?';

  @override
  String get s93e5435cf4 => 'Ingen prisstyrning';

  @override
  String get s55e5c3a177 => 'Hur många timmar på';

  @override
  String get s52ef5e0b45 => 'Prisgräns';

  @override
  String get s993193d056 => 'Kommande på-tider';

  @override
  String get s2f7c00a89e => 'Priser som inte är tillgängliga just nu.';

  @override
  String get s15b42b592c => 'Inga tider nästa dag.';

  @override
  String sf87d92faf4(String p0, String p1) {
    return 'Prisområdet $p0. Dag-ahead spot priser inkl. moms $p1 %. Lägg till \"Elektricitetspris\" enhet för att ändra område och avgifter.';
  }

  @override
  String get saa4df8e877 =>
      'Bridge hittades inte. Är telefonen på brons Wi-Fi \"Molaplan-XXXX\"? Om nätverket saknas, håll bronknappen för 3 s (inställningen öppnas i 15 minuter).';

  @override
  String get sf5293b1989 =>
      'Bron är inte i installationsläge. Håll knappen för 3 s och försök igen.';

  @override
  String get s839deeab41 =>
      'Detta är inte bron på etiketten / QR-koden (nyckelbrist). Ingenting skickades.';

  @override
  String get s3694ce006b =>
      'Brons svar är inte giltigt (krypteringsmissmatch). Ingenting sparades.';

  @override
  String s61aea0b713(String p0) {
    return 'Bron avvisade installationen: $p0';
  }

  @override
  String get s63551081b0 => 'Lägg hem bridge';

  @override
  String get s592edd94e7 => 'Molaplan Bridge-enhet';

  @override
  String get sa329968355 =>
      'En liten alltid-på-enhet (t.ex. Athom IR / RF-kontrollen) som passerar fjärrkommandon till dina enheter och styr värmepumpen genom infraröd.';

  @override
  String get sd8790684a6 =>
      'Ström bron. En ny bro öppnar inställningen själv (slow blink, en gång i sekunden).';

  @override
  String get s087004d26c =>
      'Öppna telefonens Wi-Fi-inställningar och gå med i \"Molaplan-XXXX\" (inget lösenord).';

  @override
  String get sf85e449cd8 => 'Kom tillbaka hit och tryck på \"Find bridge\".';

  @override
  String get s57466387fc => 'Hitta bridge';

  @override
  String get sd166e3cf6f => 'Bridge hittade';

  @override
  String get s6b841de5dd => 'Brandvaring';

  @override
  String get s88fa323548 => 'Home Wi-Fi';

  @override
  String get sf48dd63b0a => 'Nätverksnamn';

  @override
  String get s9f9c574cf9 => 'Wi-Fi lösenord';

  @override
  String get sc58a7d7121 => 'Hemmets namn';

  @override
  String get sc452460b0f => 'Styrelsestyrelsen';

  @override
  String get s4bdd633042 => 'Otestade';

  @override
  String get sbe6a859b63 =>
      'Detaljerna skickas krypterad - bron Wi-Fi är öppen, men lösenordet kan inte läsas av det.';

  @override
  String get s77af0820de => 'Anslut bron';

  @override
  String get s1ec01d8473 => 'Bridge ansluten!';

  @override
  String get s88bc217a1b =>
      'Bron går nu med i hemmet Wi-Fi (ljus på med ett kort dopp var tredje när den är ansluten). Byt telefonen tillbaka till hemmet Wi-Fi eller mobildata - Fjärråtkomst visar brostatus.';

  @override
  String get s2adc3a77ed => 'Välj anslutningstyp';

  @override
  String get s78d94155f1 => 'Anslutningar';

  @override
  String get s776d8b06bf => 'Ny anslutning';

  @override
  String get sc6d89693a5 =>
      'Inga anslutningar ännu. Lägg till en enhet eller tjänst, t.ex. ventilationsenhet (Modbus), Home Assistant eller en kamera.';

  @override
  String get s07c82cb0af => 'Krävt fält';

  @override
  String get see3fd4862d => 'Samma ämne två gånger?';

  @override
  String get sb80a9b6813 =>
      'Kommandoämnet och svarsämnet är detsamma. De flesta enheter (t.ex. kameraövervakningspanelen) lyssnar på sitt eget kommandoämne och svarar på ditt anmälningsämne - sedan kommer kommandon aldrig. Spara ändå?';

  @override
  String get s70f720de6d => 'Spara ändå';

  @override
  String get sf702cf0ac6 => 'Radera anslutning?';

  @override
  String s6b83de0ab9(String p0) {
    return '$p0 kakel använder denna anslutning och kommer att sluta fungera.';
  }

  @override
  String get sccd1325381 =>
      'Anslutningen kommer att tas bort från den här enheten.';

  @override
  String get s837e0fc5e6 =>
      'IR är envägs: värmepumpen bekräftar inte kommandon. Tiles visar det sista skickade tillståndet.';

  @override
  String get s09737988fd => 'Anslutningen fungerar!';

  @override
  String get s0a972aa85e =>
      'Lösenord och tokens lagras i enhetens säkra lagring.';

  @override
  String get sd408a5dbe9 => 'Billigaste timmar';

  @override
  String get sa26ae27039 => 'Hoppa över de dyraste timmarna';

  @override
  String get scfd1a72ed5 => 'Väderbaserad pre-värme';

  @override
  String get s2bd403874c =>
      'Värme i de billigaste timmarna på dagen. För lagringsvärme och vattenvärmare.';

  @override
  String get se759c14061 =>
      'Värme normalt men hoppar över de dyraste timmarna i korta pauser.';

  @override
  String get s5cab118d44 =>
      'Pre-heats före dyra eller kalla trollformler och sparar i dyra timmar. Timmarna följer prognosen.';

  @override
  String get sa7480a9930 => 'Billig timme';

  @override
  String get s50812672e5 => 'Väntar på en billig timme';

  @override
  String get seb1c64d9f8 => 'hoppa över en dyr timme';

  @override
  String get s2e52a3d40e => 'normalt normalt normalt normalt';

  @override
  String get sf6d34efdd6 => 'Inga priser – normal uppvärmning';

  @override
  String get s8c42ad8541 => 'Semester läge';

  @override
  String get sc3d8828060 => 'Värme för din retur';

  @override
  String get s577b8c3cf1 => 'Brandplace värmer';

  @override
  String get sbcd02dce0a => 'varmt tillräckligt';

  @override
  String get s22678639dc => 'Säkerhetsgräns: för kall';

  @override
  String get s1e3f154a0a => 'frostskydd';

  @override
  String get s1f2938edec => 'Säkerhetsgräns: för länge';

  @override
  String get s54fce2a7e8 => 'Förvärmning';

  @override
  String get s6b35f75e80 => 'spara medan dyrt';

  @override
  String get sdde7adcb29 =>
      'Smart värme styr värme genom elpris och väder, på ett sätt som passar din uppvärmning typ. Svara på några frågor för att få rekommenderade inställningar.';

  @override
  String get s3d29895a40 => 'Starta undersökningen';

  @override
  String get sb0d738492d => 'Fireplace läge på';

  @override
  String sd1af5ba10d(String p0) {
    return 'Fireplace läge tills $p0';
  }

  @override
  String get s48a7ba4933 => 'Semester läge på';

  @override
  String get s10a95132ce => 'Smart värme är avstängd';

  @override
  String get s035459d8bb => 'Värme följer pris och väder';

  @override
  String get s6b83aed534 =>
      'Behov av en hembro: ställa in fjärråtkomst på hem surfplattan eller PC (inställningar → fjärråtkomst).';

  @override
  String get s830cace8fe => 'Uppdatera hembron (behöver Molaplan 0.10.0).';

  @override
  String get s495c887d23 => 'Körs på hembron, även med appen stängd.';

  @override
  String get s7954d5fca9 => 'Stoppa eldstad läge';

  @override
  String get sf44db20422 => 'Fireplace lit';

  @override
  String get sd172900c2d => 'Semester: edit';

  @override
  String get s5da1e65941 => 'Holiday läge';

  @override
  String get sdca3ad13dd => 'Värmeanordningar';

  @override
  String get sc8c5e37f5d => 'Inga enheter. Lägg till dem i undersökningen.';

  @override
  String get sc6976fa352 => 'Uppvärmningsmeddelanden';

  @override
  String get s1abda8b8f3 =>
      'Hembron är för gammal: uppdatera den (Molaplan 0.10.0).';

  @override
  String get s8c3353e896 => 'Ingen hembro är parad.';

  @override
  String s38ccb420a7(String p0) {
    return 'Fungerade inte: $p0';
  }

  @override
  String s8847ee78e0(String p0) {
    return 'Mål $p0 °C';
  }

  @override
  String s4b761dad85(String p0) {
    return 'Nästa: $p0';
  }

  @override
  String s622f5654cd(String p0) {
    return 'Fel: $p0';
  }

  @override
  String get s697b47220e => 'Smart värme på';

  @override
  String get s45cf6423f8 => 'Redigera undersökningen';

  @override
  String get sf5dbb363af => 'Säkerhetsgränser';

  @override
  String get sf9cd32fb4f => 'Minsta temperaturen';

  @override
  String get sfb0553315b => 'Frostskydd';

  @override
  String s9097fb518a(String p0) {
    return 'Uppvärmning alltid under $p0 °C.';
  }

  @override
  String get s5d37a7088b => 'Längsta tillåtna paus (alla)';

  @override
  String get sb0bb55d6e5 => 'per enhet';

  @override
  String get s17bf76025c =>
      'Säkerhetsgränser åsidosätter pris, semester och eldstadsläge. Minimitemperatur och frostskydd behöver en temperatursensor.';

  @override
  String get s109c7fb7a2 => 'Fireplace';

  @override
  String get s1c15091948 => 'Fireplace läge längd';

  @override
  String get se150ae5acd => 'Thermostats sänktes i eldstadsläge';

  @override
  String get s161f61412e => 'Temperatursensor nära eldstaden';

  @override
  String get s81b30d570b => 'Enhetens sensor';

  @override
  String get s71e80a04a2 => 'Uppvärmningsmeddelanden (ntfy)';

  @override
  String get s5ab83c2574 =>
      'Samma meddelandekanal och tysta timmar som automationer.';

  @override
  String get s32d9d66ffd => 'Ta bort smart uppvärmning';

  @override
  String get s0f995f3d5d => 'Ta bort smart uppvärmning?';

  @override
  String get scc27c1739f => 'Enheterna stannar i sitt nuvarande tillstånd.';

  @override
  String get s3bf2d3643c =>
      'Elektrisk uppvärmning minskas medan eldstaden värmer. Säkerhetsgränser gäller fortfarande.';

  @override
  String get s58b2cdb4e2 => 'Avsluta tidigare när rummet börjar svalna';

  @override
  String get s632723d95f =>
      'Medan du är borta rum hålls svalare, och vattenvärmaren värms bara natten innan du återvänder. Säkerhetsgränser och frostskydd gäller.';

  @override
  String get s2ebf172fad => 'Börjar';

  @override
  String get s0ba54fbd61 => 'Återkomstdag';

  @override
  String get s025d1c3db1 => 'Temperatur medan borta';

  @override
  String get s11e21d4f75 => 'Hur den är kontrollerad';

  @override
  String get s8e6c8ffabb => ' (rekommenderas)';

  @override
  String get sa35e3e99f4 => 'Kontroll på';

  @override
  String get s86c45674db => 'Värme timmar om dagen';

  @override
  String get sbd3dbfd7e9 => 'De flesta dyra timmar hoppade över';

  @override
  String get s1f3d8e19f4 => 'Längsta paus i taget';

  @override
  String get s017c87df20 => 'Komforttemperatur';

  @override
  String get sf83143ae23 => 'Rumstemperatur sensor';

  @override
  String get se68cc54085 => 'Ingen sensor';

  @override
  String get s347ce4c3d2 => 'Minska i eldstad läge';

  @override
  String get s6f88da6bab =>
      'Termostatmålet fastställs av detta; termostatens egen temperatur är komforttemperaturen.';

  @override
  String s87cdb30352(String p0) {
    return 'Uppskattning: om $p0 kWh per dag vid 0 ° C (hela huset).';
  }

  @override
  String get sc161d1f9d9 => 'Hur är huset uppvärmt? Välj allt.';

  @override
  String get saac00e587b => 'isolering';

  @override
  String get s9f103f81c0 => 'Dålig';

  @override
  String get sd51256a0f5 => 'Medelvärde';

  @override
  String get sd5ebaf8a4c => 'Bra bra bra';

  @override
  String get sf584870588 => 'Uppvärmt område';

  @override
  String get s97235bfadb => 'Tillåten temperatur swing';

  @override
  String get s6df5f06d38 =>
      'Ju mer temperaturen kan variera, desto mer värme kan flytta till billiga timmar.';

  @override
  String get s07077e2778 => 'Huset har en spis eller lagra spis';

  @override
  String get sab28f61fad =>
      'Välj vad som styr varje uppvärmning: ett relä eller plugg (på/av) eller en Molaplan termostat (måltemperatur).';

  @override
  String get s90ae2f4451 =>
      'Inga kontrollerbara enheter ännu. Lägg till ett relä eller en termostat först; du kan komma tillbaka till undersökningen senare.';

  @override
  String get sf7b3494ee1 => 'Kontrollera enheten';

  @override
  String get se7ffc07763 => 'Inte kontrollerad';

  @override
  String s5835dc3308(String p0) {
    return 'Thermostat: $p0';
  }

  @override
  String get s075ddc6f0d => 'Rumstemperatursensor (rekommenderad)';

  @override
  String get s016c02be08 => 'Rekommenderade inställningar';

  @override
  String s013bbafbec(String p0, String p1) {
    return 'Hoppa över $p0 dyraste timmar om dagen, högst $p1 h i taget.';
  }

  @override
  String se67c73d855(String p0) {
    return 'Om $p0 värme timmar per dag vid 0 °C.';
  }

  @override
  String get sb7524487f9 => 'Ingen styrenhet – inte kontrollerad.';

  @override
  String get sad1fbf7d03 =>
      'Tryck på \"Fireplace lit\" efter belysning: elektrisk uppvärmning minskas för 12-24 h eller tills sensorn visar kylning.';

  @override
  String get sfb41f90571 =>
      'Du kan ändra metoden och siffrorna senare på enhetssidan under Avancerad.';

  @override
  String get s1706667040 => 'Hus Hus Hus';

  @override
  String get s84005ad77c => 'Enheter';

  @override
  String get s023d14fd87 => 'Rekommendation';

  @override
  String sfde6663859(String p0, String p1) {
    return 'Undersökning $p0/4: $p1';
  }

  @override
  String get sda588a203b => 'Använd dessa';

  @override
  String get sc51b1e0dc0 => 'Vad vill du lägga till?';

  @override
  String get s38f5b2ef26 =>
      'Shelly, Sonoff, Hue, kamera, värmepump... Söker ditt hemnätverk automatiskt.';

  @override
  String get s3b56b2cb8d => 'Kort';

  @override
  String get sfc846c4cc5 =>
      'Elpris, väder, kamera, mätning, meddelande eller kommando – ingen ny enhet behövs.';

  @override
  String get sf00aa23cf6 =>
      'När... gör: lampor vid solnedgången, en läckagevarning, de billigaste timmarna, skript och scener.';

  @override
  String get s147f47be4c => 'Lägg till kort';

  @override
  String get s229f981388 => 'Home bridge på';

  @override
  String get sfc2dc8fc36 => 'Bridge: offline';

  @override
  String get sdedbb30a67 => 'Hemma';

  @override
  String get s9d64d4c166 => 'Fjärr';

  @override
  String get s1f8cf57b2c => 'Ingen anslutning';

  @override
  String get s678a751265 => 'Anslut den här enheten hem';

  @override
  String get sdae0305965 =>
      'Det finns en hembro (tablett eller PC) hemma redan. Skanna dess QR-kod eller skriv 6 siffror.';

  @override
  String get s5f8284b98f => 'Gör den här enheten till hembrygga';

  @override
  String get s6a95f7843b =>
      'Den här enheten stannar hemma, alltid på (laddare + Wi-Fi) och passerar fjärrkommandon till dina enheter.';

  @override
  String get sa949a952bf => 'Lägg till hembro (Molaplan Bridge-enhet)';

  @override
  String get sb641af74b7 =>
      'En liten alltid-på-enhet, t.ex. Athom IR/RF, styr också värmepumpen. Ställ in med telefonen om några minuter.';

  @override
  String get s2c3ae5833b => 'Andra sätt: VPN, Nabu Casa, moln MQTT';

  @override
  String get s807e3a32f3 =>
      'Steg-för-steg guider om du redan använder Tailscale, WireGuard, Home Assistant Cloud eller moln MQTT.';

  @override
  String get sa3e78d5c4e => 'Hembron svarar – fjärråtkomst fungerar.';

  @override
  String get sfaa5185b74 => 'Ta bort fjärråtkomst?';

  @override
  String get sbc44ce6993 =>
      'Den här enheten kan sedan inte längre komma hem från utsidan. Du kan koppla ihop igen när som helst.';

  @override
  String get s0b57661c18 => 'Kontrollera ditt hem var som helst';

  @override
  String get s07dc42dc7a =>
      'Hemma pratar Molaplan med dina enheter direkt, någon annanstans krypterad genom din hembro. Ingenting att ställa in på routern.';

  @override
  String sdde4ff19ce(String p0) {
    return 'Visa enheterna av $p0 här';
  }

  @override
  String get sc5328cbb8f =>
      'Kopiera hembroens vyer till den här enheten. Läsningar och kontroller går sedan igenom hembron.';

  @override
  String get s86ad95fa48 => 'Kopiera hemmets vyer';

  @override
  String get s9b8f1f4a7e => 'Lägg till en hembro';

  @override
  String get sa8c35b8bfb => 'Kom igång';

  @override
  String get s5683f9f7e4 =>
      'En hembro är någon Molaplan som alltid finns hemma: en dator, en gammal surfplatta eller telefon, en Molaplan Bridge-enhet eller det separata broprogrammet. När du är borta, går kommandon genom den end-to-end krypterad.';

  @override
  String get sa75a955933 =>
      'Hemma = den här enheten är på hemmabrons eget nätverk och pratar direkt med enheter. Remote = genom hemmabron. Ingen anslutning = varken svar.';

  @override
  String get s90460344ec =>
      'Hembron är en gammal version och rapporterar inte sitt nätverk, så allt går igenom det. Uppdatera bron för att upptäcka hemma.';

  @override
  String get s19cec9667e => 'Test fjärråtkomst';

  @override
  String get s3563cb1635 => 'Ta bort fjärråtkomst';

  @override
  String get s528c4f3a4c => 'Den här enheten är hembron';

  @override
  String get sfd263f3e04 => 'Kamera uppdateras när fjärrkontrollen';

  @override
  String s99249ddf24(String p0) {
    return 'Fjärrkameran visar en bild varje $p0 s (besparar data).';
  }

  @override
  String get s451ea613dd => 'Reläserver';

  @override
  String sc420bf77fa(String p0) {
    return 'Bron är uppdaterad ($p0).';
  }

  @override
  String sb040f9f612(String p0) {
    return 'Bron installerar $p0 och startar om (cirka en minut).';
  }

  @override
  String s007c4f492d(String p0) {
    return 'Version $p0 nedladdad. Godkänn installationen från meddelandet på bryggenheten.';
  }

  @override
  String s602d8f4a18(String p0) {
    return 'Uppdatera denna bro för hand (version $p0).';
  }

  @override
  String get se8704fa7a4 => 'Bron kunde inte söka efter uppdateringar nu.';

  @override
  String s2db971daf4(String p0) {
    return 'Uppdatering misslyckades: $p0';
  }

  @override
  String get s51fb400921 => ' · uppdateringar tyst';

  @override
  String get s3443bfc674 => ' · uppdateringar behöver godkännande på enheten';

  @override
  String get s8ae159d87a =>
      'Hembro: Äldre än 0.8.0 (ingen version info) Det kan inte uppdateras på distans - uppdatera den en gång på bryggan.';

  @override
  String get s6a02d97944 => 'Home bridge version: checking...';

  @override
  String get s311c531a8e => 'Home bridge version: okänd';

  @override
  String get s70fe8d5ef3 => 'Uppdatera bridge';

  @override
  String s7897a0f8e0(String p0, String p1) {
    return '$p0: up to date ($p1).';
  }

  @override
  String sbcef05dad9(String p0, String p1) {
    return '$p0 installerar $p1 och startar om (cirka en minut).';
  }

  @override
  String s1aee092e31(String p0, String p1) {
    return '$p0: version $p1 nedladdad. Godkänn installationen på broenheten.';
  }

  @override
  String s72774aece1(String p0, String p1) {
    return '$p0 uppdateras för hand (version $p1).';
  }

  @override
  String s238af47c1e(String p0) {
    return '$p0 är äldre än 0.8.0 och kan inte uppdatera sig på distans.';
  }

  @override
  String sb9bee63c5e(String p0) {
    return '$p0 kunde inte kontrollera om uppdateringar nu.';
  }

  @override
  String sd9103f5cee(String p0) {
    return 'Anslut till bron $p0?';
  }

  @override
  String s6046b9ff9c(String p0, String p1) {
    return 'Den här enheten är nu ansluten till $p0. Den växlar till $p1. Ingen kod eller QR behövs - båda är på ditt konto.';
  }

  @override
  String get s053b2f1211 =>
      'Ingen kod eller QR behövs – båda enheterna finns på ditt konto.';

  @override
  String s948bfb1114(String p0) {
    return 'Ansluten till $p0.';
  }

  @override
  String get sc4abf59272 => 'kontrollera...';

  @override
  String get s12b3d49235 => 'Okänd';

  @override
  String get sb9e406274e => 'Online online online';

  @override
  String get sb981e102f1 => 'gamla Molaplan (0.8.0 testbygge eller äldre)';

  @override
  String get s706ee3ad91 => 'Uppdatera en gång på enheten';

  @override
  String get sca90c9c253 => ' (ingen referens på den här enheten)';

  @override
  String get s42b97a989b => 'version okänd';

  @override
  String get se76155b6bd => 'Uppdateringar tyst';

  @override
  String s20889b3dc9(String p0) {
    return 'Uppdatera $p0 en gång på enheten';
  }

  @override
  String get secbc1cfea3 =>
      'Denna hembro kör en gammal Molaplan som inte kan uppdatera sig på distans ännu.\n\nEngångsuppdatering: Öppna Molaplan på bryggan → Inställningar → Kontrollera för uppdateringar → Uppdatera och godkänna installationen. Eller installera det senaste APK över USB.\n\nDärefter fungerar Update från den här listan på distans.';

  @override
  String get s356b6d4d13 => 'Hem broar';

  @override
  String get s57117babe8 => 'Uppdatera';

  @override
  String get s5160bf55ae =>
      'Öppna = använd det hemmet på den här enheten. Uppdatera = installera den senaste Molaplan på bron.';

  @override
  String get s9b2c8181e4 => 'Denna enhet';

  @override
  String get s902eaaff9f => 'Öppet Öppet Öppet Öppet Öppet';

  @override
  String get s72da730a42 => 'Fjärrservice: ansluten';

  @override
  String get s421f161f5b => 'Anslutning till fjärrtjänsten...';

  @override
  String get s88e2b1dad5 =>
      'Ingen anslutning till fjärrtjänsten – retrying automatiskt. Kontrollera internetanslutningen.';

  @override
  String get scc0cccf89d => 'Av';

  @override
  String get sa1d085d92c => 'Hembron har inga instrumentpaneler att kopiera.';

  @override
  String sa13ef6f8d9(String p0) {
    return 'Copied: $p0 dashboards';
  }

  @override
  String sab5e7202f5(String p0) {
    return 'Ansluten till \"$p0\"!';
  }

  @override
  String get s30f06b7fb0 =>
      'Du kan nu styra ditt hem från var som helst. Kopiera hembroens instrumentpaneler och enheter till den här enheten också?';

  @override
  String get s641263ce18 => 'Nej tack';

  @override
  String get sa7a6c0fc2d => 'inte en Molaplan-kod';

  @override
  String get se2ecf1935a => 'Anslut till hemmet';

  @override
  String get s410655fd47 => 'Hur att ansluta';

  @override
  String get s7c541b8e91 =>
      'På hembron (tablett eller PC hemma) öppna Molaplan → Inställningar → Fjärråtkomst → Gör den här enheten hembroen.';

  @override
  String get sc7c83b2f58 =>
      'Tryck på \"Pair a phone\" där. En QR-kod och 6 siffror visas.';

  @override
  String get s35284509d4 => 'Skanna QR-koden eller skriv siffrorna nedan.';

  @override
  String get s66bb65d8e8 => 'Skanna QR-koden';

  @override
  String get se97cc157ef => 'eller skriva koden';

  @override
  String get s3143eb70e1 => '6 siffror från hembroskärmen';

  @override
  String get s643434044c =>
      'När du använder koden trycker du på \"Acceptera\" på hemmabron också.';

  @override
  String get s9753766742 => 'Tryck på \"Acceptera\" på hembroskärmen...';

  @override
  String get s50e49dd1df => 'Peka kameran på QR-koden';

  @override
  String s5d717bb2c5(String p0) {
    return 'Kan inte använda kameran ($p0). Tillåt kameraåtkomst eller skriv koden.';
  }

  @override
  String get s12d40eedd5 => 'Låt springa i bakgrunden';

  @override
  String get s8e1fcae1fe =>
      'För att bron ska fungera med skärmen måste Android låta Molaplan köras i bakgrunden utan batteribegränsningar. Välj \"Tillåt\" i nästa fönster.';

  @override
  String get sd62c460e3d => 'Fortsätt';

  @override
  String s7132345f20(String p0) {
    return 'Enhet \"$p0\" ansluten!';
  }

  @override
  String get se2e2af02ac =>
      'Hembron är en enhet som stannar hemma, t.ex. en gammal surfplatta eller en dator. När du är borta, din telefons kommandon krypteras genom den till dina enheter.';

  @override
  String get sd64f52490d => 'Håll det på laddaren och på hemmet Wi-Fi.';

  @override
  String get seb25c46911 =>
      'Bron körs i bakgrunden: skärmen kan vara avstängd och Molaplan stängd. Det börjar själv efter en omstart och återansluter när nätverket återvänder.';

  @override
  String get sbb23f25581 =>
      'Håll Molaplan öppen. Skärmen stannar kvar medan bron är på.';

  @override
  String get sbfed096278 => 'Använd den här enheten som hemmabron';

  @override
  String get s374a096cb9 => 'Batteribesparing kan stoppa bron';

  @override
  String get s9b1298f7c6 =>
      'Låt Molaplan springa i bakgrunden utan begränsningar.';

  @override
  String get sc8ef04815c => 'Tillåt';

  @override
  String get s2fcba19ec3 => 'Uppdatera automatiskt';

  @override
  String get se7a1731ac0 =>
      'Installerar nya Molaplan-versioner av sig själv (kontrolleras var 6: e). Endast Molaplan-signerade filer med en matchande kontrollsumma.';

  @override
  String get s13995350ed => 'Para ihop en telefon';

  @override
  String get s6a74454a98 => 'Paired enheter';

  @override
  String get s1e4fc2e7fe => 'Ännu inte. Tryck på \"Pair a phone\".';

  @override
  String get s7ea55c5834 => 'Tillagd';

  @override
  String sfd8d693d04(String p0) {
    return 'Ta bort \"$p0\"?';
  }

  @override
  String get s84572f642e =>
      'Enheten kan sedan inte längre anslutas på distans. Det kan paras igen.';

  @override
  String get sf7fa9632f3 => 'Giltigt för';

  @override
  String get s4e877aeafe =>
      'På telefonen: Molaplan → Inställningar → Fjärråtkomst → Anslut den här enheten hem';

  @override
  String get s9715416100 => 'Skanna med telefonen';

  @override
  String get s5378bb3f05 => 'Acceptera den här enheten?';

  @override
  String s1d8bb7b0a6(String p0) {
    return '\"$p0\" vill ha fjärrkontroll av ditt hem. Acceptera endast om det är din egen eller en familjemedlems enhet som precis har angett koden.';
  }

  @override
  String get sa04c218f82 => 'Avvisa';

  @override
  String get sd64229b6d8 => 'Inte inrätta ännu';

  @override
  String get s088e792ee3 => 'Fjärråtkomst är avstängd';

  @override
  String get s85543bf885 => 'Online Online Online';

  @override
  String get s3f17564f18 => 'Senaste sett';

  @override
  String get s9ba8cafced => 'Vad är fjärråtkomst?';

  @override
  String get s1cf33c1fbc => 'Värde';

  @override
  String get s86029171be => 'Av/på';

  @override
  String get s4ddce888df => 'Knapp / genväg';

  @override
  String get s357fc9c3fe => 'Slider / setpoint';

  @override
  String get s14da6beba5 => 'Visar en läsning, t.ex. temperatur.';

  @override
  String get se4b1d203df => 'På/av, t.ex. ett ljus eller larm.';

  @override
  String get sc2197ab417 => 'En kran gör en eller många saker.';

  @override
  String get sd611704caf => 'Justera ett värde, t.ex. temperatur.';

  @override
  String get sacfc0c0b41 => 'Visar en kamerabild.';

  @override
  String get s7172c54c2c => 'Håller temperaturen på inställt värde.';

  @override
  String get s76e7a995de => 'Läst värde';

  @override
  String get s4e1f25d257 => 'Eget kommando';

  @override
  String get sea15760b77 => 'Vad gör knappen?';

  @override
  String get s630ee9894e =>
      'Välj ett skript, en scen eller en enhet. Knappen fungerar i appen och när du är borta, genom fjärråtkomst.';

  @override
  String get s1173c2dbf9 => 'Inga skript ännu. Gör en under Automations.';

  @override
  String get s7b42ecba51 => 'Inga scener ännu. Spara en under Automations.';

  @override
  String get s589d73245e =>
      'Inga växelbara enheter ännu. Lägg till en switch först.';

  @override
  String get sc5edd6d3d1 => 'Nytt kort';

  @override
  String get sa684fd0716 => 'Redigera kort';

  @override
  String get sa7b6366b62 =>
      'Mätning: display, trend, färggränser, larm, decimaler och skalning.';

  @override
  String get sae41bebdab =>
      'Kontroll: bekräftelse, lås / PIN, min / max / steg, invert och momentary.';

  @override
  String get s19485c79b2 => 'Ingen';

  @override
  String get s0483226428 => 'Välj en temperatursensor';

  @override
  String get scf37cbeda8 => 'Ikon';

  @override
  String get sfeab9bd26f => 'Bredd';

  @override
  String get s58be670598 => 'Höjd';

  @override
  String get sd7314e8237 => 'Visning';

  @override
  String get s7d6cee9e42 => 'Barer (15 min)';

  @override
  String get sc0e069225b => 'Trend + Nu linje';

  @override
  String get s07647fa07d => 'Range';

  @override
  String get s8feeef3110 => 'Visa imorgon när tillgängligt';

  @override
  String get sad692e6ae5 =>
      'Morgondagens priser visas av sig själva en gång publicerad (cirka 14:00).';

  @override
  String get s1c72b8c56a => 'Trendlängd';

  @override
  String get s6bb0c0c7e3 => 'Mätarens minimum';

  @override
  String get sa444aab286 => 'Automatisk';

  @override
  String get sbf29caff87 => 'Mätarens maximum';

  @override
  String get sea30815e6a =>
      'Tekniska kakelinställningar visas när du slår på \"Avancerad\" i Inställningar.';

  @override
  String get s382afc832f => 'Statlig källa';

  @override
  String get s581aee3e96 => 'Valfritt: där det nuvarande tillståndet läses av.';

  @override
  String get s3adc51170c => 'Rå kombination (avancerad)';

  @override
  String get s5f542e17e2 =>
      'Varje korttyp är tillåten på varje anslutning. En felaktig kombination kan visa vilseledande data, t.ex. \"På\" för elpriset.';

  @override
  String get scb988b1a4a => 'Av: endast korttyperna stöder anslutningen.';

  @override
  String get se6b18b17d9 => 'omröstningsintervall (s, 0 = none)';

  @override
  String get s01f2b1ee0c =>
      'MQTT, Home Assistant och WebSocket uppdatering lever utan omröstning.';

  @override
  String get s937448ecf5 => 'Testläsare';

  @override
  String get s5cbdea7f7e => 'Visning';

  @override
  String get se6af4b33df => 'Enhet';

  @override
  String get sd5498697da => 'Decimaler';

  @override
  String get s4f7007db78 => 'Värdenamn';

  @override
  String get s4aae179c52 => '0=Off;1=Home;2=Away';

  @override
  String get s0c12fda7ca => 'Toggle kommandon';

  @override
  String get s3a9d9e16ef => '\"På\" värden (komma separerade, tomma = auto)';

  @override
  String get s1509c5a2a6 => 'På kommando';

  @override
  String get s2a1e131afd => 'OFF kommando';

  @override
  String get s0201de52c0 =>
      '{\'{value}\'} i kommandot ersätts av reglaget värde.';

  @override
  String get sc30c9a7e51 => 'Steg Steg';

  @override
  String get s4d6451a63a => 'Ställ in kommando';

  @override
  String get sa4082e1a79 => 'Kommandon (kör i ordning)';

  @override
  String get s467488e572 =>
      'En genväg kan styra flera enheter i sekvens, med förseningar.';

  @override
  String get sad43973fb3 => 'Lägg till kommando';

  @override
  String get sdaef43c622 => 'Be om bekräftelse';

  @override
  String get s5210a5ad23 => 'Anslutning';

  @override
  String get s96705fc3df => 'Kommandot skickat';

  @override
  String get sb41db1e809 => 'Försök försöka';

  @override
  String get s77d2309fd5 => 'Fördröjning före (ms)';

  @override
  String get s2b463f47ba => 'Gömd';

  @override
  String get s2594346d86 => 'Guide linjer';

  @override
  String get sfdffaffea4 => 'Ingen';

  @override
  String get sd6c2de0256 => 'Horisontell';

  @override
  String get sb8ef66c33e => 'Grid';

  @override
  String get s0bee1b8ed3 => 'Värdeskala';

  @override
  String get sd4e9b57931 => 'Tidsaxel';

  @override
  String get s7abdb12fef => 'Datapunkt markörer';

  @override
  String get s29135ed75a =>
      'Auto: Axlar och guidelinjer visar när kortet är minst 2×2.';

  @override
  String get s638c648b40 => 'Stream';

  @override
  String s32ef3895b8(String p0) {
    return 'Lens / kanal $p0';
  }

  @override
  String get s939603242a => 'Färger med värde';

  @override
  String get s45f927bc62 => 'Anpassad';

  @override
  String get s319dab47d8 => 'Smooth';

  @override
  String get s613fbec20e => 'Steg';

  @override
  String get s25d9db075e =>
      'Egna gränser och färger: Inställningar → Avancerade.';

  @override
  String get sc0f5a14d2b => 'Färgtrösklar (värde ≥gräns → färg)';

  @override
  String get s30a2c0f460 => 'Lägg till tröskelvärde';

  @override
  String get s4226eb046f => 'Ångra';

  @override
  String get sd5cb601286 => 'Tailscale (enkel VPN)';

  @override
  String get s0aa851cfb4 =>
      'Gratis för personligt bruk. Din telefon och hem fungerar som ett nätverk - Molaplan arbetar med samma adresser som hemma.';

  @override
  String get s444ca5d58f =>
      'Bra om du har en alltid-på PC, Raspberry Pi eller Home Assistant hemma.';

  @override
  String get sec7b4d1d7a =>
      'Skapa ett Tailscale-konto hos tailscale.com (Google, Microsoft eller Apple sign-in).';

  @override
  String get s178c57446d =>
      'Installera Tailscale på den alltid på enheten hemma. I Home Assistant: Inställningar → Add-ons → Tailscale.';

  @override
  String get s4faf83aa13 =>
      'Slå på \"subnet router\" där och ange ditt hemnätverk, t.ex. 192.168.1.0/24. Sedan är alla dina hemenheter tillgängliga.';

  @override
  String get s721719c0e1 =>
      'Godkänn rutten i Tailscale adminkonsolen (Machines → enhet → Redigera ruttinställningar).';

  @override
  String get s921f981bda =>
      'Installera Tailscale-appen på din telefon och logga in med samma konto. Byt VPN på.';

  @override
  String get s8ae7e7b2a4 =>
      'Molaplan använder samma adresser som hemma. Inget annat att ändra.';

  @override
  String get se92301ff0a => 'https://tailscale.com/download';

  @override
  String get sf6270ae66c => 'https://tailscale.com/kb/1019/subnets';

  @override
  String get s57f0b61334 => 'WireGuard (router VPN)';

  @override
  String get sb9bb49ab92 =>
      'Om din router stöder WireGuard (t.ex. ASUS, FRITZ!Box, UniFi, OpenWrt), ansluter din telefon till hemnätverket direkt.';

  @override
  String get s986d264604 =>
      'Bra om routern har WireGuard och din anslutning har en offentlig IP-adress.';

  @override
  String get sf24b16dc12 =>
      'Öppna routerns inställningar och leta efter \"VPN-server\" → \"WireGuard\".';

  @override
  String get s1e5d1eb832 =>
      'Aktivera servern och lägg till en ny enhet (peer) för telefonen.';

  @override
  String get s8e0252a2b4 =>
      'Routern visar en QR-kod. Installera WireGuard-appen på telefonen och skanna den.';

  @override
  String get s4b3740b727 =>
      'Kontrollera att \"tillåtna IP-filer\" inkluderar hemnätverket (t.ex. 192.168.1.0/24).';

  @override
  String get sd2e8523b28 =>
      'Byt VPN på i telefon – Molaplan fungerar som hemma.';

  @override
  String get saa17c5a456 => 'https://www.wireguard.com/install/';

  @override
  String get se5960424ea =>
      'Många mobila bredband (4G/5G hem internet) anslutningar har ingen offentlig IP (CGNAT) och WireGuard sedan inte kan nås från utsidan. Använd Molaplan fjärråtkomst eller Tailscale istället.';

  @override
  String get sab2dfe387b => 'Home Assistant Cloud (Nabu Casa)';

  @override
  String get s2e0586b37e =>
      'En betald månatlig prenumeration från tillverkarna av Home Assistant. ger en säker fjärradress till Home Assistant.';

  @override
  String get s534e7ec95e => 'Bra om dina enheter redan finns i Home Assistant.';

  @override
  String get s0f7533967d =>
      'In Home Assistant: Inställningar → Home Assistant Cloud → starta rättegången eller logga in.';

  @override
  String get s2e60dd8178 => 'Vrid \"fjärrkontroll\" på.';

  @override
  String get s7a73024451 =>
      'Kopiera fjärradressen, som ser ut: https://abcd1234.ui.nabu.casa';

  @override
  String get sd4873612f7 =>
      'I Molaplan: Anslutningar → Home Assistant → ändra adressen till fjärradressen. Token förblir densamma.';

  @override
  String get s15223b0e32 => 'Home Assistant plattor fungerar nu överallt.';

  @override
  String get s9b3201b1fa => 'https://www.nabucasa.com/';

  @override
  String get s60e7067815 =>
      'Detta täcker endast enheter som styrs via Home Assistant. För andra (Modbus, kameror direkt) använder Molaplan fjärråtkomst eller en VPN.';

  @override
  String get s8e0d0a2d4e => 'Cloud MQTT (t.ex. HiveMQ Cloud)';

  @override
  String get sd0fff65292 =>
      'Enheter och Molaplan pratar genom samma molnserver. HiveMQ Cloud har en gratis nivå som är tillräckligt för hemmabruk.';

  @override
  String get s7350b9f98b =>
      'Bra för MQTT-enheter: Tasmota, ESPHome, Shelly, Zigbee2MQTT, dina egna ESP-kort.';

  @override
  String get s59b3c7d246 =>
      'Skapa ett gratis konto på console.hivemq.cloud och skapa ett gratis kluster (gratis / serverless).';

  @override
  String get s04fe436d1e =>
      'Under \"Access Management\" skapa ett användarnamn och lösenord.';

  @override
  String get sdf0075eab5 =>
      'Kopiera serveradressen (t.ex. abcd.s1.eu.hivemq.cloud). Hamnen är 8883 med TLS på.';

  @override
  String get s9e9be6fc33 =>
      'Sätt den här servern, användarnamn och lösenord i dina enheters MQTT-inställningar (TLS på).';

  @override
  String get s90f1cb151b =>
      'I Molaplan: Anslutningar → MQTT → adress, port 8883, TLS på, användarnamn och lösenord. Done - fungerar överallt.';

  @override
  String get s77bf29f2f5 => 'https://console.hivemq.cloud/';

  @override
  String get safd2cd2b7b =>
      'Välj ett starkt lösenord: alla som vet att det kan styra dina enheter.';

  @override
  String get s9557c0ef28 => 'Fjärråtkomstguider';

  @override
  String get sf4d7957b78 => 'Lättast: Molaplan fjärråtkomst';

  @override
  String get s8032085166 =>
      'Inga konton, inga routerinställningar. Du behöver bara en tablett eller dator som stannar hemma.';

  @override
  String get sd9b48e01fc => 'Andra sätt';

  @override
  String get sfe551fd431 => 'Enhetsguider';

  @override
  String get sa35e37b4b4 =>
      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Hittades automatiskt.';

  @override
  String get scb28b11e70 => 'Ny vy';

  @override
  String get s3a13f9d077 => 'Rename Dashboard';

  @override
  String get sa5bf37213b => 'Radera Dashboard?';

  @override
  String s10671afc00(String p0, String p1) {
    return '\"$p0\" och dess $p1 kakel kommer att raderas.';
  }

  @override
  String s897761b5f4(String p0) {
    return 'Dashboard \"$p0\" raderad';
  }

  @override
  String get scc5cf9957d => 'Välj kakeltyp';

  @override
  String get s7cf6340503 => 'Ny enhet med färdiga kort';

  @override
  String get se6ca707cf3 => 'Lättast: Shelly, ESP32-CAM, Home Assistant';

  @override
  String get s0789f5f14f => 'DASHBOARDS';

  @override
  String get sedb7b77645 => 'Alla';

  @override
  String get sfb3e3c456c => 'Delete Dashboard';

  @override
  String get scdfd80f963 => 'Lägg till kort';

  @override
  String get s71af34b8e9 => 'Tom vy';

  @override
  String get s6a210970eb =>
      'Din enhet plattor visas här: temperaturer, växlar, kameror och genvägar. Börja med att lägga till en enhet.';

  @override
  String get s4229fb4103 => 'Lägg till din första enhet';

  @override
  String get sf67e0d5752 => 'Radera kortet?';

  @override
  String s97f46743e0(String p0) {
    return 'Tile \"$p0\" raderad';
  }

  @override
  String get sda9203de80 => 'lokaler och inställningar ';

  @override
  String get s8b3e63da21 => 'o skapa kontot ›';

  @override
  String get s887c293cad => 'lokala grepp om odlingar för odlingar';

  @override
  String get s84a087a679 => 'l.......';

  @override
  String get s907220900d => 'Välkommen till Molaplan';

  @override
  String get s845ec6276f => 'lokalisering av';

  @override
  String get s9dfa93453b => 'o----------------------------------';

  @override
  String get s6aa51b28a5 => 'lokaler och e-poster';

  @override
  String get sc6f02b69d3 =>
      'o inloggning/inloggning/inloggning/inloggning/inloggning/inloggning/ in';

  @override
  String get sc777bde66f =>
      'lokala försvarslösningar Försvårigheter Försvårigheter Försvårigheter Försvårigheter Försvårigheter';

  @override
  String get se2e5ff2c8a => 'lokalisering utan ett konto';

  @override
  String get sb8934a5835 => 'Elförbrukning';

  @override
  String get s5409dc748f => 'Räknas inte';

  @override
  String get sf0bbcc217b => 'Hela fastigheten';

  @override
  String get s0ad1897b28 => 'Enhetsmätare';

  @override
  String get s99268b5a6c =>
      'Hela fastigheten = huvudmätare. Enhetsmätare = en enhet (visas som en del av totalen, räknas aldrig två gånger).';

  @override
  String get se1174af557 => 'Del av mätare (valfritt)';

  @override
  String get s9773c92c92 => 'Energi och kostnader';

  @override
  String get s43dead6994 => 'Elavtal';

  @override
  String get sef4d24cdd4 => 'Dag';

  @override
  String get sa62dd794ce => 'Månad';

  @override
  String get s6b2ebe5aca => 'Välj dina mätare först';

  @override
  String get sde41f2fac9 =>
      'Markera nedan vilken mätare mäter hela webbplatsen och vilka enstaka enheter.';

  @override
  String get s4ad000d885 => 'inkl. moms';

  @override
  String get s9e214b6e88 => 'exkl. moms';

  @override
  String get s73771d252c => 'Uppmätta enheter totalt';

  @override
  String get s22d03356a9 => 'Övrig förbrukning';

  @override
  String get s48b08c5f5a => 'Fasta avgifter (el + elnät)';

  @override
  String get s2e8700e0cf =>
      'En del av användningen hade inget pris (punktpriset saknades).';

  @override
  String get sbbd89fbc05 =>
      'Användning spelas in medan appen är öppen (hela tiden på hemmatabletten).';

  @override
  String get s64382718ff => 'Mätare';

  @override
  String get s9a3a0d414e =>
      'Inga kraft- eller energikort (W, kW, Wh, kWh). Lägg till t.ex. en Shelly-mätare.';

  @override
  String get se80021e22a =>
      'Kopiera priserna från din räkning. Skriv dem med eller utan moms - kostnaderna visas båda sätten.';

  @override
  String get sfb62156afe => 'Prisområde';

  @override
  String get s1762fb70a7 => 'Energi';

  @override
  String get s2ed3e3cf28 => 'Spotpris';

  @override
  String get s5d1dd0f675 => 'Fast';

  @override
  String get sedb38796fb => 'Natt/dag';

  @override
  String get s0774cea15a => 'Påslag';

  @override
  String get s63370fe61a => 'Elpris';

  @override
  String get s50a7dd89c6 => 'Dagel';

  @override
  String get sdeaa5ad900 => 'Nattel';

  @override
  String get se93c7bcd86 => 'Fast avgift (el)';

  @override
  String get sb7937e4b91 => 'Elnät';

  @override
  String get s0f89840226 => 'Enkeltariff';

  @override
  String get sa768f1b352 => 'Elnätspris';

  @override
  String get s9e5dde22cb => 'Elnät dag';

  @override
  String get sdf7a4fd2e3 => 'Elnät natt';

  @override
  String get s4df0aee067 => 'Fast avgift (elnät)';

  @override
  String get s4c59c90975 => 'Natten börjar';

  @override
  String get s84decd042b => 'Natten slutar';

  @override
  String get s90c26f1e37 => 'Skatter';

  @override
  String get s222cb348a0 => 'Energiskatt';

  @override
  String get sbe412dcaa6 => 'Moms';

  @override
  String get s43b55c13c5 => 'Sök misslyckades. kontrollera anslutningen.';

  @override
  String get s171834ca33 => 'Hemmets plats';

  @override
  String get s6f6c2fe37a =>
      'Väderprognosen (Open-Meteo) hjälper förvärmning före kallt väder.';

  @override
  String get s5f663978d6 => 'Ort';

  @override
  String get s7be6460c54 => 't.ex. Tammerfors';

  @override
  String get s1576b70590 => 'Elanvändning, kostnader, kontrakt och väder.';

  @override
  String get sa6212aaeb4 => 'Plats';

  @override
  String get sa0eeb22daa => 'Finns redan i vyn – lägga till ändå?';

  @override
  String s3507210a2a(String p0, String p1) {
    return '$p0 är redan i synen $p1.';
  }

  @override
  String get s0e655a209f => 'Lägg till ändå';

  @override
  String get s12c2f8e6e4 => 'Endast hemnätverket';

  @override
  String s5f7c464e6d(String p0) {
    return 'kl. $p0';
  }

  @override
  String s21b64ae0a7(String p0) {
    return '$p0 fungerar bara i hemnätverket. Rutan blir normal igen av sig själv när du är hemma.';
  }

  @override
  String get s6b1a8249de => 'Senaste läge';

  @override
  String get s56650a18d5 => 'Gör den fjärrstyrbar ›';

  @override
  String get sa0d8c62e5a => 'Inget kommando konfigurerat';

  @override
  String get s1e5d696a26 => 'Kör detta kommando?';

  @override
  String get sa5ee6618a3 => 'Ändra PIN';

  @override
  String get s66f8ce67ed => 'Gå in i PIN';

  @override
  String get sb7b0c97cfa =>
      'Enheten behöver sin PIN för varje kommando och statusbegäran. Ange den en gång här.';

  @override
  String get s1df6e2eaa7 => 'PIN';

  @override
  String get sb52d5c0b5b =>
      'Webbläsaren lagrar aldrig PIN. Det frågas igen nästa gång du öppnar sidan.';

  @override
  String get secab66c046 => 'Kom ihåg på denna enhet';

  @override
  String get s2a15ea2eab =>
      'Lagrad krypterad på den här enheten bara - inte på kontot eller på andra enheter. Off = frågade igen när appen startar om.';

  @override
  String get s10bf4eab8e =>
      'Lagrad krypterad på den här enheten bara. Som standard lagras PIN-koden inte.';

  @override
  String get s856418521a => 'Inga kommandon konfigurerade';

  @override
  String sb0ba67e677(String p0) {
    return 'Ran på $p0';
  }

  @override
  String sdfa66ee201(String p0) {
    return '$p0: Sänd';
  }

  @override
  String get s12fc3810a5 => 'Sent – vänta på svaret...';

  @override
  String get sd1c7d49360 => 'Svara på';

  @override
  String get s29fae6a0e8 => 'Prisstyrning på';

  @override
  String get s59d55f8882 => 'Byt namn';

  @override
  String get s84ada1ae69 => 'Ändra PIN';

  @override
  String get s25580038cb => 'Saved PIN bort';

  @override
  String get sf50c488b24 => 'Glöm frälst PIN';

  @override
  String get safe0429a90 => 'Prisstyrning';

  @override
  String get sf3d644dd4c => 'Lär in en fjärrkontrollknapp';

  @override
  String get sbb9e9b1229 => 'Ange PIN';

  @override
  String get s72a2328ddd => 'Lampor';

  @override
  String get sca12be80ca => 'Brytare';

  @override
  String get sa4c0eeea02 => 'Värmepumpar och AC';

  @override
  String get sa8dbf04ad3 => 'Binära sensorer';

  @override
  String get sa7690acf57 => 'Markiser, portar och dörrar';

  @override
  String get s487bf00fc7 => 'Lås';

  @override
  String get sbe76826428 => 'Fläktar';

  @override
  String get s4b53bcaaf0 => 'Knappar';

  @override
  String get s5c92d42edd => 'Talinmatningar';

  @override
  String get s3c2ed0c522 => 'Hjälpbrytare';

  @override
  String get sea20d169a3 => 'Mediaspelare';

  @override
  String get sbcb95e1e78 =>
      'Token accepteras inte. Skapa en ny i Home Assistant.';

  @override
  String get s0b80dc2642 =>
      'Kunde inte nå Home Assistant. kontrollera adressen.';

  @override
  String get sf32b7f15d8 => 'Kameror';

  @override
  String get sa7a829cefb => 'Välj Home Assistant-enheter';

  @override
  String get sefdf8e3316 => 'Hämtar enheter…';

  @override
  String get s26583a1933 => 'En vy per rum';

  @override
  String get sb3e6b54bce => 'Sök efter namn eller id';

  @override
  String get safedc10c48 => 'Alla rum';

  @override
  String get s407f3f7a0c => 'Inget rum';

  @override
  String s140aba8cd7(String p0) {
    return '$p0 lampor är Philips Hue-lampor';
  }

  @override
  String get s16aee2aa30 =>
      'Direkt via Hue Bridge svarar de snabbare och fungerar utan Home Assistant.';

  @override
  String get s3816288db1 => 'Lägg till Hue Bridge';

  @override
  String get sa765c9294a => 'Visa alla';

  @override
  String sdb088f47a8(String p0) {
    return '$p0 tekniska objekt dolda (diagnostik, konfiguration, uppdateringar)';
  }

  @override
  String get s3ee8d0a5e3 => 'Rummen kunde inte läsas - visar enheter utan rum.';

  @override
  String get sf55fca7a32 => 'Inga träffar';

  @override
  String get s78cdce874e => 'redan tillagt';

  @override
  String get s7ba50ea69e => 'Sovrum';

  @override
  String get s9e9723b263 => 'Kök';

  @override
  String get scce769451b => 'Vardagsrum';

  @override
  String get s9d5dca2dee => 'Badrum';

  @override
  String get s2569505205 => 'Sauna';

  @override
  String get s1c65dad1f5 => 'Hall';

  @override
  String get sa4d90bb5da => 'Gård / trädgård';

  @override
  String get s4a7be17a36 => 'Teknikrum';

  @override
  String get s01e404f15f => 'Arbetsrum';

  @override
  String get sfd8305add2 => 'Barnrum';

  @override
  String get scd87fb4dd7 => 'Stuga';

  @override
  String get sdc398885dc => 'Avancerade inställningar';

  @override
  String get s5d477f3cd8 => 'Vanligtvis behöver du inte dessa';

  @override
  String get s2315e0e739 => 't.ex.';

  @override
  String get sc1c47d2474 => 'Välj en bakgrundsbild';

  @override
  String sa8ce5112ee(String p0) {
    return 'Högst $p0 bakgrundsbilder. Ta bort en först.';
  }

  @override
  String get s12a7d631af => 'Utseende';

  @override
  String get s0d83798030 => 'Storlek';

  @override
  String get s64c916e299 => 'Liten';

  @override
  String get s5e3097232a => 'Bred';

  @override
  String get s8971788287 => 'Stor';

  @override
  String get s254a1d8e12 => 'Bakgrundsbild (valfri)';

  @override
  String get sc48f5f9bcf => 'Välj bild';

  @override
  String get s7ba9d453ed => 'Dämpa när enheten är av';

  @override
  String get s016ae7b580 =>
      'Bilden krymps (≤ 200 KB) och synkroniseras till ditt konto.';

  @override
  String get sabb10f8cb2 =>
      'Bilden krymps (≤ 200 KB) och hålls endast på den här enheten.';

  @override
  String get s6b536de0c8 =>
      'Genom din hembro: lampor, pluggar, Home Assistant, Shelly, Tasmota, ESPHome, Modbus, kamera stillbilder';

  @override
  String get s082c8c6278 => 'Rakt över internet: ntfy kommandon, elpris, väder';

  @override
  String get s5a419e551c => 'Samma vyer och kort som ditt kontos andra enheter';

  @override
  String get sa8f5c5c719 =>
      'Utan en hembro kan webbläsaren inte styra hem-nätverksenheter';

  @override
  String get sb1c4acea71 =>
      'App bara: enhetssökning, Bluetooth, RTSP-video, som fungerar som hemmabro';

  @override
  String get s2842696c47 => 'Webbläsarversionen är en fjärrkontroll';

  @override
  String get s1cbac3d12d =>
      'Här kontrollerar du bara enheter som kan nås på distans: genom en hembro (Molaplan på en dator, en Android-enhet eller en Molaplan Bridge), ntfy eller en molntjänst. För full lokal kontroll behöver du Molaplan-appen.';

  @override
  String get saffec3d1c7 => 'Beställ PC-appen eller en färdig Android-enhet';

  @override
  String get s2bf22ca429 =>
      'Den här enheten kan inte nås från webbläsaren. Det fungerar i Molaplan-appen, eller härifrån när en hemmabro är på.';

  @override
  String get sc6e6f17ad4 =>
      'Webbläsarversion: du styr fjärrstyrbara enheter. Full kontroll med appen - mer ›';

  @override
  String get sbed5ab99f6 => 'Ditt hems enheter och status i en vy';

  @override
  String get s1ffc6e9e18 =>
      'Kontrollera ljus, pluggar, värmepump och larm med stora kort';

  @override
  String get sb18bf27c69 =>
      'Samma vy på en PC, tablett, telefon och i webbläsaren';

  @override
  String get sdc86a6f82c =>
      'Enhetslösenord är krypterade - bara dina enheter kan öppna dem';

  @override
  String get sb2703f9ad3 => 'Skapa ett konto med en e-postkod';

  @override
  String get s326d86a618 =>
      'Namnet kommer från den spanska \"me mola el plan\" - \"låter bra\".';

  @override
  String get sc80648d495 => 'Visa Molaplan';

  @override
  String get sa4e9c86a86 => 'Quit';

  @override
  String get s4dab2d409b => 'Exportkonfiguration';

  @override
  String get s149c1e54d6 => 'Konfiguration exporterad';

  @override
  String get s35f445793b => 'Importera konfiguration';

  @override
  String get sd55be829e3 => 'Ersätt nuvarande konfiguration?';

  @override
  String get s852dd1795e =>
      'Alla aktuella anslutningar och instrumentpaneler ersätts av filinnehållet.';

  @override
  String get s5f2ec17730 => 'Konfiguration importerad';

  @override
  String get sa87fff54f3 => 'Import misslyckades';

  @override
  String get s2fd2bfedb8 => 'Konto';

  @override
  String get s4c0ff416ab => 'Samma hem och plattor på alla dina enheter.';

  @override
  String get scc7e418ee3 =>
      'Logga in för att ha samma hem, enheter och plattor på PC, surfplatta och telefon. Valfritt.';

  @override
  String get s08d62fd281 => 'Utseende';

  @override
  String get s2b8a2754c6 => 'Tema';

  @override
  String get s79f67deb42 => 'Lampa';

  @override
  String get s0d6fb52039 => 'Mörk';

  @override
  String get s70dd7fdd58 => 'Genom soluppgång och solnedgång';

  @override
  String get s21206b61f7 =>
      'Behov av hemorten (Energy › Hem). Fram till dess följs enhetsinställningen.';

  @override
  String get s4e23920823 =>
      'Ljus om dagen, mörkt på kvällen. Av: följer enhetens inställning.';

  @override
  String get s4b847ce63e =>
      'Valet gäller för den här enheten och sparas på ditt konto som standard för nya enheter.';

  @override
  String get s5ebc02022b => 'Visa som timligt genomsnitt';

  @override
  String get s68b4d332ca =>
      'Pris, billigaste timmar och priskontroll per timme (timme förkortat kontrakt). Av: 15 min där området publicerar 15-mins priser.';

  @override
  String get saf496a12a3 => 'Morgonkort: Visa också den dyraste timmen';

  @override
  String get sc53b1b78c0 =>
      'Den billigaste timmen av nästa 24 h visas alltid med sitt pris.';

  @override
  String get s0625d54b38 => 'Kortstorlek';

  @override
  String get s8382da3467 => 'Normal';

  @override
  String get s7c1cd8314e => 'Dölj rutor som inte fungerar på distans';

  @override
  String get sa0cbbafb4e =>
      'Borta hemifrån döljs rutor som bara fungerar i hemnätverket. Som standard står de kvar, gråtonade.';

  @override
  String get s419166b895 => 'Klocka och väder på hemskärmen';

  @override
  String get sec30a8f23e =>
      'Tid, datum, väder och elpris på toppen av vyn. Denna enhet endast.';

  @override
  String get sf7205b268f => 'Animationer';

  @override
  String get s1535c6411d =>
      'Mjuka övergångar när en enhet ändrar tillstånd. Off = lugnare och lättare för en äldre tablett.';

  @override
  String get s21f870dbc2 =>
      'Visar tekniska inställningar: anslutningar (HTTP, MQTT, Modbus...), nyttolast, JSON-vägar och kakelkällor. De flesta behöver inte dessa.';

  @override
  String get sc84689a549 => 'Enheter och integrationer';

  @override
  String get sca4c8b88b7 => 'Home Assistant: Lägg till enheter';

  @override
  String get saec69088a5 => 'Styr ditt hem från utsidan också.';

  @override
  String get scc3d01ee5e => 'Guider: VPN, Nabu Casa, moln MQTT';

  @override
  String get s535358a517 =>
      'Ge någon, eller en installatör, åtkomst till de enheter du väljer.';

  @override
  String get s25c286a743 => 'Delning – ny inbjudan';

  @override
  String get s90ba544719 => 'Hjälp';

  @override
  String get sb915c42792 => 'Visa den blivande guiden';

  @override
  String get sd337a7ddd5 => 'Backup och överföring';

  @override
  String get s07c1048b4f =>
      'Exportera konfigurationen till en JSON-fil och importera den på en annan enhet (t.ex. PC → telefon).';

  @override
  String get s2f797098e7 => 'Inkludera lösenord och tokens';

  @override
  String get s26f72949e3 => 'Filen är sedan okrypterad - håll den säker.';

  @override
  String get sdb12678e52 => 'Exportera';

  @override
  String get s34686ffb09 => 'Exempel';

  @override
  String get sc8327738b3 =>
      'Lägg till en exempelvy (kamera, larm, lampor, ventilation). Exempelenheterna ansluter aldrig någonstans - lägg till din egen med Lägg till enhet.';

  @override
  String get sec02c7c071 => 'Lägg till exempelvy';

  @override
  String get s057b871ed2 => 'webbläsare version';

  @override
  String get s522d6584c5 => 'Sök efter uppdateringar';

  @override
  String get sd178a1d809 =>
      'Din egen kontrollterminal: HTTP, MQTT, Modbus TCP, Home Assistant, kameror, WebSocket, TCP och UDP. Utan ett konto stannar alla inställningar på den här enheten.';

  @override
  String get sf5bfc4217c => 'Vilken hemassistent?';

  @override
  String get sbc210f9634 =>
      'Du har mer än en Home Assistant-anslutning. En oanvänd (inga kort) kan tas bort.';

  @override
  String get s4f62c41cb3 => 'Inga kort';

  @override
  String get s92c338c3bd => 'kort';

  @override
  String get sd3089f07cc => 'Ta bort oanvänd anslutning';

  @override
  String get s1333776c9f => 'Ta bort anslutningen?';

  @override
  String s84819cca05(String p0) {
    return 'Sista larmet $p0';
  }

  @override
  String get se455dc672b => 'Steg Steg';

  @override
  String get s3ddd2678bf => 'Hoppa över guiden';

  @override
  String get s171ac59e67 =>
      'Välj din enhet nedan. Du fyller bara i sin adress - resten görs för dig.';

  @override
  String get se722dfcec9 =>
      'Molaplan är ditt hem egen kontrollpanel. Du lägger in exakt de enheter och knappar du behöver.';

  @override
  String get scbac938ead => 'Se allt på en blick';

  @override
  String get se25f930e31 => 'Temperaturer, ljus, larm och kamera i en vy.';

  @override
  String get s3e450dba98 => 'Kontrollera med en kran';

  @override
  String get sdda6a3f06e =>
      'Ljus på, öka ventilationen eller en \"Leaving Home\" -knapp som gör många saker samtidigt.';

  @override
  String get sbcac0cd35a => 'Samma hem på alla enheter';

  @override
  String get sd43d517cc7 =>
      'Logga in om du vill, och PC, surfplatta och telefon visar samma hem. Lösenord krypteras på din enhet. Inget konto behövs.';

  @override
  String get s70fff97e97 => 'Jag har redan ett Molaplan-konto - logga in';

  @override
  String get sd6561a08ca => 'Nu börjar vi';

  @override
  String get se5be2a8386 => 'Dina kort är klara';

  @override
  String get s8162694dbe => 'Lägg till ditt första kort';

  @override
  String get s7b2a30b77c =>
      'Dessa plattor gjordes för din enhet. Du kan ändra och ordna dem senare.';

  @override
  String get s39e163fa49 =>
      'En kakel visar information eller styr en enhet. Välj vilken typ av kakel:';

  @override
  String get s4bfb026e45 => 'Jag ska göra detta senare';

  @override
  String get s3f0351473c => 'Kontrollera ditt hem från utsidan också?';

  @override
  String get s6fe6fe631f =>
      'Hemma fungerar allt redan. Från utsidan behöver du en alltid-på-enhet hemma (en gammal surfplatta eller en dator) - inga router-inställningar, inga konton.';

  @override
  String get sb599b7432f => 'Fjärråtkomst är på.';

  @override
  String get s33a294d472 => 'Den här enheten är hembron.';

  @override
  String get s4aa8cce504 => 'Inte nu – bara hemmet';

  @override
  String get sd3c370ca52 => 'Klart!';

  @override
  String get s1359035b73 => 'Tryck på en kakel';

  @override
  String get sfd26c8e50b => 'En switch växlar, en knapp kör sitt kommando.';

  @override
  String get s416c8184a7 => 'Pencil-knappen högst upp';

  @override
  String get s2ba275defe => 'Redigera, lägg till, ta bort och dra kakel runt.';

  @override
  String get se872eeb0f5 => 'Långtrycka en kakel';

  @override
  String get s63496941fc => 'Se detaljer och en förklaring om något är fel.';

  @override
  String get s080be778d5 =>
      'Hitta den här guiden, fjärråtkomst och säkerhetskopior där.';

  @override
  String get sae0fae7127 => 'Gå till min Dashboard';

  @override
  String get s2a28790ea2 => 'Full bredd';

  @override
  String get s64f4d1e11a => 'Ange hemmets plats';

  @override
  String get sbf7cc3de9a => 'Försök nu';

  @override
  String get s1becc05ea1 => 'locked=Låst;unlocked=Olåst;jammed=FASTNAT';

  @override
  String get s259de02f33 =>
      'open=Öppen;closed=Stängd;opening=Öppnas;closing=Stängs';

  @override
  String get s64d4364336 =>
      'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming';

  @override
  String get s5b1e227dc4 => 'on=På;off=Av';

  @override
  String get s3d43664fcc => 'WebSocket';

  @override
  String get sfcbb753f53 => 'URL';

  @override
  String get s81479e1555 => 'Headers (Namn: värde per rad)';

  @override
  String get s5811b38d7b => 'Token (Authorization: Bearer)';

  @override
  String get sd512dbbfc7 => 'Meddelande på connect';

  @override
  String get s2c4fd261e2 => 'Tillåt självsignerat certifikat';

  @override
  String get s4d089aab74 => 'Filter (meddelande innehåller)';

  @override
  String get s55c951a8ad => 'JSON väg';

  @override
  String get s10813e25b3 => 'Regex (grupp 1)';

  @override
  String get s4a282cd247 => 'Begär meddelande (Skicka på läs)';

  @override
  String get sbeef545d37 => 'Meddelande ({\'{value}\'} = värde)';

  @override
  String get s0477f24b6b => 'HTTP / REST';

  @override
  String get s3102ae3a16 => 'Base URL';

  @override
  String get s38d0517a8d => 'Autentisering';

  @override
  String get sade17bf83e => 'Ingen';

  @override
  String get s9cbb9f048d => 'Användare + lösenord (Basic)';

  @override
  String get s3cb806781e => 'Användare + lösenord (Digest)';

  @override
  String get sb1920b9d9b => 'Token (bärare)';

  @override
  String get sed995f57b8 => 'Användarnamn';

  @override
  String get s65e35b7cc4 => 'Token';

  @override
  String get s51510ae27a => 'Extra rubriker (Namn: värde per rad)';

  @override
  String get s361419c448 => 'Timeout (s)';

  @override
  String get sf235ce5ec0 => 'Metod';

  @override
  String get s484291707c => 'Vägen';

  @override
  String get s54c8aed8bc => 'Kropp';

  @override
  String get s5c5e9b662c => 'Kroppen ({\'{value}\'} = värde)';

  @override
  String get s8e82ca13cf => 'Content-Type';

  @override
  String s3c045f21ee(String p0, String p1, String p2) {
    return 'Testad: GET $p0 (basadress, $p1 byte, $p2 ms).';
  }

  @override
  String get s7797602869 =>
      'Inga kommandon skickades och kakelvägar testades inte.';

  @override
  String sbf349dfcbd(String p0, String p1) {
    return 'HTTP $p0: enheten svarade men nekade inloggningen. Kontrollera användarnamn, lösenord eller token. $p1';
  }

  @override
  String s3bd10f0ae2(String p0, String p1) {
    return 'HTTP $p0: enheten svarade med ett serverfel. $p1';
  }

  @override
  String s2a7fa26dd6(String p0, String p1) {
    return '✓ Enheten svarade på $p0 (HTTP 404: ingen sida på basadressen – normalt för många enheter). Anslutningen fungerar. $p1';
  }

  @override
  String sb2821916bc(String p0, String p1, String p2) {
    return 'Anslutning fungerar: HTTP $p0. $p1 $p2';
  }

  @override
  String get s58648dc3fc => 'Kamera (MJPEG / JPEG / RTSP)';

  @override
  String get s1534821f4a => 'Kamerabas URL';

  @override
  String get s95533426a3 => 'RTSP-adress (levande video hemma)';

  @override
  String get sa1115d4b0b => 'RTSP-adress, ljus (kort)';

  @override
  String get se995a6862d => 'Läge';

  @override
  String get s7cf6da2822 => 'Live (MJPEG)';

  @override
  String get s4cb8ad767b => 'Snapshots';

  @override
  String get s15f9cd477c => 'RTSP video';

  @override
  String get s4f356d158a => 'Refresh (s, snapshot)';

  @override
  String get scbc6aa5e63 => 'radon';

  @override
  String get sfc402d7bce => 'co2';

  @override
  String get s7410329f6d => 'air_quality';

  @override
  String get s05ff8e0c34 => 'Termostat';

  @override
  String get s26e6d96d7e => 'Fuktighet';

  @override
  String get sfabcfc0188 => 'hastighet';

  @override
  String get s12a1c5653a => 'air_quality';

  @override
  String get s2f37dd80ed => 'batteribatteri';

  @override
  String get sd4025b7a32 => 'Airthings (moln)';

  @override
  String get sf7d012472a => 'Client ID';

  @override
  String get s94bccb8598 =>
      'dashboard.airthings.com → Integrations → API → Create client (Client credentials).';

  @override
  String get sb1a9b21d4f => 'Client secret';

  @override
  String get s2403198fe5 => 'Visas bredvid kundens ID. Håll den hemlig.';

  @override
  String get s21b52207e8 => 'Uppdateringsintervall (min)';

  @override
  String get saad5ced5fe =>
      'Monitorerna uppdateras var 5: e minut och frågar oftare inte något nytt.';

  @override
  String get sc844e90e0f => 'Serienummer';

  @override
  String get s8cee566dd7 =>
      'Monitorns serienummer (10 siffror) - fylld i när du lägger till den från listan.';

  @override
  String get s2d79014611 => 'Mätning';

  @override
  String get s852b4e5c75 =>
      'Vilken mätning kortet visar (radon Bq/m3, CO2 ppm, VOC ppb, °C, %, hPa, μg/m3, batteri %).';

  @override
  String get s6cd83fc216 => 'Radon (kortsiktig)';

  @override
  String get s0c4b6446cd => 'Radon (långsiktigt)';

  @override
  String get s96cc1b3741 => 'VOC';

  @override
  String get sf8496cb6dc => 'Tryck';

  @override
  String get s99e44237af => 'PM2.5';

  @override
  String get s951d501a1a => 'PM1';

  @override
  String get sb6d80b9662 => 'Airthings Wave (Bluetooth)';

  @override
  String get s83d2446b44 =>
      'På baksidan eller botten av bildskärmen (10 siffror, t.ex. 2930xxxxxxx).';

  @override
  String get s2525f9a4f5 =>
      'Finland är ett område (FI). I Sverige och Norge beror det på var du bor.';

  @override
  String get s8f4a683abf => 'Moms %';

  @override
  String get s1c7d76a774 => 'Ditt lands moms.';

  @override
  String get se49d0fba92 => 'Elhandlarens påslag (c/kWh)';

  @override
  String get s20a5e2936a => 'Spot kontrakt marginal utan moms.';

  @override
  String get s923f9739de => 'Elnät + skatt (c/kWh)';

  @override
  String get s2a3498fb0f =>
      'Från din faktura, inkl. moms. Lämna 0 för energi endast.';

  @override
  String get s1d9eabe472 =>
      'För timmerbillade kontrakt. Av: 15-min priserna där området publicerar dem (EU dag framåt sedan 1 oktober 2025).';

  @override
  String get s515da3a9dd => 'Prisserver';

  @override
  String get s98cc9f1c14 => 'Molaplans server hämtar priser från öppna källor.';

  @override
  String get s271885dc8b => 'Vad ska man visa';

  @override
  String get s1edb6be142 =>
      'Vilket pris siffra kortet visar: nu, dagens lägsta / högsta / genomsnittet, nästa billiga timme eller diagrammet.';

  @override
  String get s46aab99b27 => 'Lägsta idag';

  @override
  String get sf6295f1182 => 'Högst idag';

  @override
  String get s1aa7abbf72 => 'Medelpris i dag';

  @override
  String get s65f496b2dc => 'Nästa billiga timme';

  @override
  String get se446dc324a => 'Prislista (idag och i morgon)';

  @override
  String get s2f754e8ab4 => 'Inga priser för idag ännu.';

  @override
  String get s18faad19ed => 'Inget pris för nu.';

  @override
  String get s29178b43f4 => 'Elpriset är lättläst.';

  @override
  String get s1a707f2788 => 'Imorgon: ja.';

  @override
  String get sb85af981c1 => 'I morgon: ännu inte (publicerad runt 14:00).';

  @override
  String s6270faf138(String p0, String p1, String p2, String p3) {
    return '✓ Priser för $p0 ($p1 slots, $p2 min, källa $p3).';
  }

  @override
  String get se1bd60873c => 'MQTT';

  @override
  String get s85b9781bb7 => 'Broker värd';

  @override
  String get s800d13debd => 'Port Port Port Port';

  @override
  String get s49fa57061a => 'TLS';

  @override
  String get s0fcef98aad => 'Använd WebSocket (ws:// eller wss://)';

  @override
  String get s5089c65c1f => 'Klient-ID (tomt = auto)';

  @override
  String get s9372a6f755 => 'Keep alive (s)';

  @override
  String get sd373a99107 => 'Tillståndsämne';

  @override
  String get s518c8aa712 => 'Kommandoämne';

  @override
  String get s120726c79a => 'Betalning ({\'{value}\'} = värde)';

  @override
  String get s3660228d11 => 'QoS';

  @override
  String get s1b07c9ba3d => 'Retain';

  @override
  String s91c3d72d1e(String p0) {
    return 'fan $p0';
  }

  @override
  String get s40032ddea9 => 'Swing';

  @override
  String s7dcc5e6c76(String p0) {
    return ', vane ';
  }

  @override
  String get s7c815852f2 => 'Inte sänt ännu';

  @override
  String s4795d331a5(String p0) {
    return 'Skickat på $p0';
  }

  @override
  String sff577ce033(String p0, String p1, String p2) {
    return 'Sänd $p0. $p1. på $p2';
  }

  @override
  String get s7068e8892e =>
      'Okänd kod utan rådata. Aktivera rådata i Tasmota (SetOption58 1) och försök igen.';

  @override
  String get s6207a45bff => 'IR blaster (värmepump)';

  @override
  String get s859c2e7734 => 'Sändarens firmware';

  @override
  String get s3f8d3fb444 =>
      'tasmota_http = Tasmota (tasmota-ir) av IP. tasmota_mqtt = Tasmota via en MQTT-mäklare. esphome = ESPHome klimat_ir. http/mqtt = annan blaster med dina egna mallar.';

  @override
  String get s4fb133b1c8 => 'Tasmota (HTTP)';

  @override
  String get sdd5d31034c => 'Tasmota (MQTT)';

  @override
  String get see30b7398b => 'ESPHome';

  @override
  String get scb2d23e10b => 'Anpassad HTTP';

  @override
  String get s5c6c30aac6 => 'Anpassad MQTT';

  @override
  String get s38471ae691 => 'Blaster adress';

  @override
  String get sda91fafa54 =>
      'IP-adress för IR-blastaren (Tasmota eller ESPHome).';

  @override
  String get sf9220a3e4d => 'Brand IR-protokoll';

  @override
  String get s423f2576c4 =>
      'Tasmota IRhvac leverantör, t.ex. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. Om ingenting händer, prova ett annat protokoll av samma varumärke.';

  @override
  String get s74ff2fd8a8 => 'Modell (valfritt)';

  @override
  String get sef4c0e5d90 =>
      'IRhvac Model nummer för vissa märken. Lämna tomt om det är osäkert.';

  @override
  String get s8e7962c184 => 'Tasmota ämne';

  @override
  String get s5ae4cc50db => 'MQTT: från Tasmota (Konfiguration → MQTT → Ämne).';

  @override
  String get sed30580f59 => 'MQTT mäklare adress';

  @override
  String get s744ce256bb => 'MQTT: maskinen som kör mäklaren.';

  @override
  String get se6754df705 => 'MQTT-port';

  @override
  String get sbfc8ee6c86 => 'Användarnamn';

  @override
  String get s711670d91a => 'MQTT eller webbanvändare.';

  @override
  String get s3bbd70773d => 'Lämna tom om det inte behövs.';

  @override
  String get s443fe6f350 => 'ESPHome klimat id';

  @override
  String get s62feae1a9f => 'ESPHome endast: klimatobjektet id.';

  @override
  String get se0efd6dfb3 => 'Kommando URL (andra blaster)';

  @override
  String get s5366cbd4df =>
      'Endast http: URL som tar emot hela staten. Placeholders som listas.';

  @override
  String get sce533db7c1 => 'Payload mall (andra blaster)';

  @override
  String get s0fa691e7c7 =>
      'http body eller mqtt payload. Empty = IRhvac JSON ({\'{json}\'}).';

  @override
  String get s8567c5faa6 =>
      'sammanfattning = fullt tillstånd som text. rum = blastarens temperatursensor. Andra = sista skickad inställning.';

  @override
  String get s5d329a0fea => 'Sammanfattning';

  @override
  String get s5db6506824 => 'Sätt temperatur';

  @override
  String get s018d2e08f4 => 'Fläkt';

  @override
  String get sa00d64c920 => 'Vane';

  @override
  String get s39f8bf0f76 => 'Sent at';

  @override
  String get s051944392f => 'Rumstemperatur';

  @override
  String get sdd8cd8132c => 'Vad man ska ändra';

  @override
  String get s2e8b846390 =>
      'Hela staten skickas alltid på en gång. Värdet kommer från kakeln eller \"Value\".';

  @override
  String get sb517d97868 =>
      'T.ex. värme, svalt, auto, torrt, fan eller on/off. Empty = kakelvärde.';

  @override
  String get sda4a1b2eee => 'Lärd kod';

  @override
  String get s0cfc723aa2 =>
      'Fylld när du sparar en inlärd fjärrknapp. Skicka med Tasmota IRsend.';

  @override
  String get s3f26cb7602 => 'ESPHome knapp';

  @override
  String get sc71964f422 =>
      'ESPHome endast: id av mallknappen för en lärd kod.';

  @override
  String get s852a166240 => 'Blaster adress saknas.';

  @override
  String get s75ce01c354 => 'Tasmota behöver webben lösenord.';

  @override
  String sf9d84ad23c(String p0) {
    return 'Tasmota vet inte $p0. Installera tasmota-ir-byggnaden.';
  }

  @override
  String sff167aa9a6(String p0) {
    return 'Tasmota förkastade kommandot: $p0';
  }

  @override
  String s385c6a9a2d(String p0) {
    return 'Okänd leverantör \"$p0\".';
  }

  @override
  String sb4ea2389cb(String p0) {
    return 'ESPHome klimat \"$p0\" hittades inte.';
  }

  @override
  String get s34deda2c72 => 'Kommando URL saknas.';

  @override
  String get s04e4777aea => 'Temperatur saknas.';

  @override
  String s91e5fff1f0(String p0) {
    return 'rum $p0 °C';
  }

  @override
  String get sfce1a094cb => 'Ingen temperatursensor på blastaren.';

  @override
  String s4536eb33dd(String p0) {
    return 'Ingen temperatur mottagen.';
  }

  @override
  String get s9b5bbfa2c6 => 'Rumstemperatur endast från Tasmota/ESPHome.';

  @override
  String get s5acc16dafb => 'RF433 behöver Tasmota.';

  @override
  String get s8478662ad1 => 'Lärda koder behöver Tasmota.';

  @override
  String s9f8263b5a0(String p0, String p1) {
    return 'ESPHome-knappen \"$p0\" hittades inte.';
  }

  @override
  String s3296e8d7e7(String p0) {
    return 'Ingen kod inom $p0 s. Peka fjärrkontrollen rakt på sprängaren (under 1 m) och tryck igen.';
  }

  @override
  String get s1e73ba395d => 'RF433 lärande behöver Tasmota.';

  @override
  String get scc47b4b225 =>
      'Lärande fungerar med Tasmota och ESPHome blasters.';

  @override
  String s96adaaf2b6(String p0, String p1, String p2) {
    return 'Tasmota svarade (version $p0). Testad: Status 0 på $p1. Inget skickades till värmepumpen.';
  }

  @override
  String sfce5c770f1(String p0) {
    return 'Brokern fungerar men Tasmota \"$p0\" svarade inte.';
  }

  @override
  String s2c3b95a054(String p0) {
    return '✓ Tasmota \"$p0\" svarade via MQTT. Inget skickades till värmepumpen.';
  }

  @override
  String scf9ead3297(String p0, String p1, String p2, String p3) {
    return '✓ ESPHome klimat \"$p0\" hittades. Ingenting skickades.';
  }

  @override
  String get s8ad50358b9 =>
      'Inget test för andra sprängmedel: IR är envägs. Tryck på kraftplattan och titta på värmepumpen.';

  @override
  String s3b476099a2(String p0) {
    return 'Enhet svarade HTTP $p0. Är web_server aktiverad i ESPHome?';
  }

  @override
  String sd44aec7380(String p0) {
    return 'Inget svar från $p0.';
  }

  @override
  String s120026628c(String p0) {
    return 'Kunde inte nå $p0.';
  }

  @override
  String get s43c9b88580 => 'Auto';

  @override
  String get sd3cd4220ae => 'auto auto auto auto auto';

  @override
  String get s640687fc2d => 'högsta högsta högsta';

  @override
  String get s3516ee9f50 => 'Hög högt';

  @override
  String get sb847c3774e => 'Mitten';

  @override
  String get sc4ebe5627c => 'lågt lågt lågt';

  @override
  String get saacae8d5c5 => 'lägsta';

  @override
  String get s30ae7f76e6 => 'ntfy kommandoenhet (kommandon + stat)';

  @override
  String get s6a4516e0fe => 'Kommandoämne (namn eller fullständig URL)';

  @override
  String get scab58fae92 =>
      'Ämnet som hemmet enheten lyssnar på (enhetens eget ämne - inte ditt meddelande ämne). ämnesnamnet fungerar som ett lösenord: hålla det lång och slumpmässig.';

  @override
  String get s800cd08229 => 'Svara på ämne (valfritt)';

  @override
  String get s7e8c7a0cfc =>
      'Om enheten svarar på ett annat ämne (t.ex. ditt personliga meddelandeämne), skriv det här. Empty = kommandoämnet.';

  @override
  String get s7ea9d85150 => 'PIN-kod (tillval)';

  @override
  String get s0694fe4d2b =>
      'Förvarad krypterad på den här enheten. Infogad där mallen säger {pin}.';

  @override
  String get s63971a3ad4 => 'Fråga staten på högst alla (s)';

  @override
  String get scf38de4909 =>
      'Automatisk statusbegäran oftast (alla enheter återanvänder det senaste svaret). Varje förfrågan är två meddelanden; ntfy.sh tillåter 250 meddelanden / 12 h för hela hemnätverket. Tryck och kommandon frågar samtidigt.';

  @override
  String get s4313c720cc => 'Kommando mall';

  @override
  String get sd904dac1cc =>
      '{cmd} = knappens kommando, {pin} = PIN, {cid} = ett id enheten echoes i sitt svar, {värde} = värdet (på / av eller ett nummer). t.ex. \"{cmd} {pin}\" → \"ljus på 1234\".';

  @override
  String get sa45b65f571 => 'Status kommando';

  @override
  String get se464d5ed51 =>
      'Kommandot enheten svarar med sitt tillstånd (t.ex. \"status\" eller \"status json\"). Alla kort av denna enhet delar svaret.';

  @override
  String get s821e8d2d9d => 'Svara titeln innehåller (valfritt)';

  @override
  String get s949ee12ae6 =>
      'Endast meddelanden vars titel innehåller denna text räknas som svaret - användbart när svarsämnet bär andra meddelanden också.';

  @override
  String get sfbcb5f18bd => 'Svaret måste innehålla (regex, valfritt)';

  @override
  String get s79c983aa94 =>
      'Ett vanligt uttryck som svaret (titel + meddelande) måste innehålla.';

  @override
  String get s081eff543d => 'Text till statlig karta';

  @override
  String get s2afc1f1fb8 =>
      'En regel per rad: \"mönster = värde\". Mönstret är en regex som matchar hela den fångade texten (fall-insensitiv). Empty = inbyggd finska och engelska på/av ord.';

  @override
  String get s0976f767e2 => 'Fel svar (regex)';

  @override
  String get sc0fd47e896 =>
      'Ett svar som betyder ett fel (visas i rött) Empty = standard (fel PIN, fel, nekad ...). För JSON: ok:false eller ett felfält.';

  @override
  String get s98d9efa888 => 'Minimitid mellan kommandon (s)';

  @override
  String get sa893722568 =>
      'Om enheten svarar endast t.ex. var 30:e sekund, typ 30: nästa kommando väntar sin tur istället för att gå vilse.';

  @override
  String get sbdcbe301b9 => 'Vänta på svar (s)';

  @override
  String get s5e8e483f10 =>
      'Hur lång tid att vänta på svaret innan du visar ett fel.';

  @override
  String get s31312f141c => 'Status svar giltigt för (s)';

  @override
  String get s0611790300 =>
      'Kort av samma enhet delar en status svar så länge - enheten är inte ombedd onödigt.';

  @override
  String get s5bc736c04a => 'Access token (tillval)';

  @override
  String get scece580659 =>
      'Endast för ett skyddat ämne (ntfy-konto → Access-tokens).';

  @override
  String get s7e91b10006 =>
      'Standard är den offentliga ntfy.sh. En fullständig URL ovan åsidosätter detta.';

  @override
  String get s1b5501c73f => 'JSON väg (JSON svar)';

  @override
  String get s1320bcddf2 =>
      'När enheten svarar med JSON, t.ex. \$.light eller \$.outputs.siren.';

  @override
  String get s4dc975c1cd => 'Från text (regex, grupp 1)';

  @override
  String get s21c23314ed =>
      'För ett textsvar: ett vanligt uttryck vars första grupp är staten, t.ex. ljus:\\s*(\\S+).';

  @override
  String get s63a305f2ab => 'Statuskommando för detta kort (valfritt)';

  @override
  String get s89ad1c43b4 => 'Tomt = enhetens statuskommando.';

  @override
  String get s5bed8bff00 => 'Kommando';

  @override
  String get sec7af7b376 =>
      't.ex. \"ljus på\". PIN och andra delar läggs till av enhetens kommandomall.';

  @override
  String get sfee393b70e => 'Vänta på svaret';

  @override
  String get s3f4dda1fb9 =>
      'Visar enhetens svar (eller ett tydligt fel) på kortet.';

  @override
  String get sa53638cfea => 'Svaret stannar på plattan (s)';

  @override
  String get se6d21484a8 =>
      'Hur länge svaret stannar på kakeln. 0 = tills nästa press.';

  @override
  String get sb56e7e9f81 => 'ntfy: kommandot saknas';

  @override
  String s02e16b2c5c(String p0, String p1) {
    return 'Kommandot skickades, men enheten svarade inte inom $p0 s - är enheten online? Kontrollera också PIN: många enheter svarar inte på fel PIN alls (topiskt \"$p1\").';
  }

  @override
  String sdf4ecde616(String p0, String p1) {
    return 'Kommandot skickades, men enheten svarade inte inom $p0 s - är enheten online? Om det svarar endast vid intervall, öka \"Minimum tid mellan kommandon\" (topisk \"$p1\").';
  }

  @override
  String s1257447096(String p0) {
    return 'Enheten svarade: $p0';
  }

  @override
  String get sc112a20bf5 =>
      'Om enheten svarar på ett annat ämne (t.ex. ditt meddelandeämne), ange det som \"Reply ämne\".';

  @override
  String get sf03877dd0a => ' En PIN lagras.';

  @override
  String get s33cfb86f9f =>
      'Kommandot skickades, men enheten svarade inte i tid - är enheten online? (Nfy-servern fungerar.)';

  @override
  String get s7087533324 =>
      'Inte tillåtet i dagsljus (day_blocked) - ljuset följer dagsljus';

  @override
  String sf3066f08eb(String p0) {
    return 'fel PIN ($p0)';
  }

  @override
  String s14fac6d719(String p0) {
    return 'För många kommandon – vänta ett ögonblick ($p0)';
  }

  @override
  String get s36fb6ba26f => 'Modbus TCP';

  @override
  String get sa70cc38354 => 'Värd';

  @override
  String get sdc5301b750 => 'Enhet Id';

  @override
  String get s15e327bf8e => 'Timeout (ms)';

  @override
  String get s666811be3d => 'Ramning';

  @override
  String get s0f2d3b7a42 =>
      'En billig RS485 till Wi-Fi / Ethernet-omvandlare i transparent läge använder RTU-ramar.';

  @override
  String get s12ca822cd8 => 'Modbus TCP (normalt)';

  @override
  String get s731c92978b => 'Modbus RTU över TCP (RS485 gateway)';

  @override
  String get s570f11bec8 => 'Minsta läsintervall (s)';

  @override
  String get s13e54dbff1 =>
      'Samma register läses aldrig oftare, men många kort visar det.';

  @override
  String get s95d4c6dd5b => 'Paus mellan förfrågningar (ms)';

  @override
  String get s77b6667fdb => 'Vänta efter anslutning (ms)';

  @override
  String get sf4b0409574 => 'Batch intilliggande läser';

  @override
  String get sc011aad1a9 => 'Max register per läs';

  @override
  String get s942a690567 => 'Lockout paus vid första (s)';

  @override
  String get s3746551251 =>
      'När enheten inte svarar lämnas den ensam ett tag. Pausen fördubblas upp till maximum.';

  @override
  String get sf71d800450 => 'Lockout paus på de flesta (s)';

  @override
  String get sbce68f8691 => 'Stäng anslutningen efter ett fel';

  @override
  String get sf96bb0c03d => 'Försök på ett tomt svar';

  @override
  String get s943b8b6bf3 => 'Registrera tabell';

  @override
  String get s8283ed1c89 => 'Innehavsregister (4x)';

  @override
  String get s94cf36d710 => 'Coil (0x)';

  @override
  String get sfb6d4a8639 => 'Ingångsregister (3x)';

  @override
  String get s0bbedf814a => 'Diskret ingång (1x)';

  @override
  String get sf51ad986eb => 'Adress (0-baserad)';

  @override
  String get s601f118ac0 => 'Datatyp';

  @override
  String get sddd62d21b0 => 'Swap ord (CDAB)';

  @override
  String get see24ec5d84 => 'Skala';

  @override
  String get s0a239b832b => 'Offset';

  @override
  String get s5f374d3643 => 'Enhet id (tom = anslutning)';

  @override
  String get sef11962984 => 'Skriv för att';

  @override
  String get s779b59ba4b => 'Värde ({\'{value}\'} = reglage/toggle)';

  @override
  String get sefaea1b818 => 'ntfy (meddelandekanal/kommandon)';

  @override
  String get se003ecc10b =>
      'Ämne kommandon skickas till. Du kan klistra in hela URL, t.ex. https://ntfy.sh/my-topic - samma som din iPhone Shortcut använder. ämnesnamnet fungerar som ett lösenord: hålla det länge och slumpmässigt.';

  @override
  String get s2e3a66d384 =>
      'Om hemenheten svarar på ett annat ämne, skriv det här. Lämna tomt om svaret kommer på samma ämne - vårt eget kommando ignoreras sedan och nästa meddelande visas som svaret.';

  @override
  String get s77feae14f5 =>
      'Endast behövs för ett skyddat ämne (ntfy-konto → Access-tokens). Lämna tomt för ett offentligt ämne.';

  @override
  String get seca0d75969 =>
      'Standard är den offentliga ntfy.sh. Ändra bara för din egen ntfy-server. En fullständig URL ovan åsidosätter detta.';

  @override
  String get sddbea594a4 =>
      'senaste = det senaste meddelandet, log = flera senaste meddelanden (nyaste först).';

  @override
  String get s580abde883 => 'Senaste meddelandet';

  @override
  String get sf6455b6631 => 'Meddelandelogg';

  @override
  String get s2bd0e69d44 => 'Ämne (valfritt)';

  @override
  String get s4eb1e8ac15 =>
      'Ämne att läsa. Empty = anslutningens svarsämne (eller kommandoämnet).';

  @override
  String get s09fa5c0332 => 'Antal meddelanden (logg)';

  @override
  String get s17fda9fb06 => 'Hur många nya meddelanden logg visar.';

  @override
  String get s78f2f0d783 => 'Hur långt tillbaka';

  @override
  String get s79bdbfd820 =>
      '30m, 12h eller 2d. Den offentliga ntfy.sh håller meddelanden i cirka 12 timmar.';

  @override
  String get sfe357edcec => 'Kommando (text för att skicka)';

  @override
  String get s48e102023d =>
      'Texten att skicka, t.ex. \"uppdatering\". Med en PIN-kod läggs den upp efter ett utrymme: \"uppdatera 1234\".';

  @override
  String get saf2ebedf61 => 'Be om en PIN på press';

  @override
  String get sfcb5608064 =>
      'Be om en PIN-kod (dold) på varje press och godkänner den till kommandot. PIN-koden lagras inte om du väljer \"Kom ihåg på den här enheten\".';

  @override
  String get sfff5bc52e5 =>
      'Lyssnar på hemenhetens svar och visar det i den här kakeln (och som ett meddelande när appen är i bakgrunden).';

  @override
  String get s121542d6d7 =>
      'Hur lång tid att vänta innan du säger att inget svar kom.';

  @override
  String get s74d68a98d6 => 'Meddelande titel (valfritt)';

  @override
  String get sc2492ac3ab => 'ntfy meddelande titel. vanligtvis tom.';

  @override
  String s54ea45f27f(String p0, String p1) {
    return 'ntfy: ämne \"$p0\" skyddas (HTTP $p1). Lägg till en åtkomsttoken (tk_...) till anslutningen.';
  }

  @override
  String get s0870daf796 => 'ntfy: kommandoämne saknas';

  @override
  String get s28dc7ea012 => 'ntfy: anslutning stängd innan svaret';

  @override
  String sa4313864fe(String p0, String p1) {
    return 'Kommandot skickades, men inget svar kom inom $p0 s. Kontrollera att hemenheten är på och lyssnar på \"$p1\".';
  }

  @override
  String get s85a1947a44 => '(inga meddelanden)';

  @override
  String get s7069b18b7d => 'ntfy: kommandotext saknas';

  @override
  String s43de3fd299(String p0) {
    return ' Svara på ämne: $p0.';
  }

  @override
  String s9ed9eb7f92(String p0, String p1, String p2, String p3) {
    return '✓ ntfy server $p0 svarade och ämne \"$p1\" är läsbart ($p2 meddelanden i sista timmen). $p3 Inget kommando skickades - tryck på kakeln för att försöka.';
  }

  @override
  String sb9c91fd519(String p0) {
    return 'ntfy: meddelandegräns nått (HTTP 429). Servern tar inga fler meddelanden från detta nätverk (ntfy.sh: 250 meddelanden / 12 h för alla enheter bakom samma offentliga IP, enhetens egna svar också). Nya meddelanden frigör varje minut.';
  }

  @override
  String get sf0ef0140c3 => 'Home Assistant';

  @override
  String get s1f90ee6992 => 'Långlivad access token';

  @override
  String get sccb0cca8e3 => 'Liveuppdateringar (websocket)';

  @override
  String get s8f8e1cfad3 => 'Entity Id';

  @override
  String get s382111aebc => 'Attribut (tom = stat)';

  @override
  String get sf500d0ad67 => 'Tjänsteservice';

  @override
  String get s7286715019 => 'Extra data JSON ({\'{value}\'} = värde)';

  @override
  String get s1b5b0421c0 => 'Payload är hex';

  @override
  String get s44ab1d33df => 'Vänta på svar';

  @override
  String get s341bf61e36 => 'Svar som hex';

  @override
  String get se7cff2d61e => 'TCP (rå)';

  @override
  String get s1dfeacd9f6 => 'UDP';

  @override
  String s6c33f19716(String p0) {
    return 'inte svara ($p0 min)';
  }

  @override
  String get scebcdabe25 => 'av';

  @override
  String get sd4be8bca5f => 'Testa testtest';

  @override
  String get sd76aadb97c => 'Vattenläcka → larm';

  @override
  String get s0bd0724e83 =>
      'En brådskande anmälan så snart en läcksensor upptäcker vatten (även under tysta timmar).';

  @override
  String get sa9f114c81d => 'Ljus på vid solnedgången';

  @override
  String get s02402a38eb => 'De utvalda ljusen slås på när solen sätter.';

  @override
  String get s386fda8330 => 'Allt utanför kl. 23.00';

  @override
  String get s3508664550 => 'De valda enheterna stängs av på kvällen.';

  @override
  String get s3775470669 => 'Meddela när en enhet slutar svara';

  @override
  String get s5c07969ac8 =>
      'En anmälan när en enhet har varit oåtkomlig i 10 minuter.';

  @override
  String get s2cdd15be92 => 'Meddela när temperaturen sjunker';

  @override
  String get sa74faa4635 =>
      'En anmälan när en sensorläsning sjunker under en gräns.';

  @override
  String get s94ed692877 => 'Billigaste timmar: enhet på';

  @override
  String get s9b99909a7c =>
      'En enhet på under dagens billigaste timmar (t.ex. en vattenvärmare).';

  @override
  String get s90d5d2954d => 'Meddela om dyr el';

  @override
  String get s876690515a => 'En anmälan när spotpriset går över 20 c/kWh.';

  @override
  String get s1906ecb28c => 'Frost varning';

  @override
  String get s036ecd266d => 'En anmälan när den är under −15 °C utanför.';

  @override
  String get sacf213e078 => 'Morgonsammanfattning kl. 7.00';

  @override
  String get sef21ad6784 =>
      'Vädret, elpriset och tillståndet i ditt hem som ett meddelande varje morgon.';

  @override
  String get s5d308e6986 => 'Vänstersjön!';

  @override
  String get s13017ce3b0 => 'Temperaturen sjönk';

  @override
  String get s4c52f38c8b => 'El är dyrt';

  @override
  String get sc797ab9c4c => 'God morgon';

  @override
  String get seec5bf7f8d =>
      'I morgon elgenomsnitt {avg} c/kWh (topp {max} på {hour}). Ljus eldstaden.';

  @override
  String get s4a7ea7d7f1 =>
      'Elektricitet är exceptionellt dyrt idag: genomsnittligt {vg} c/kWh, topp {max} på {tim}.';

  @override
  String get se8a2912e3e =>
      'Elektricitet är exceptionellt dyrt i morgon: genomsnitt {avg} c/kWh, topp {max} på {tim}.';

  @override
  String get s0818fd54b1 =>
      'Ankomst till stugan {ankomst}. Vänd värmen på nu, mål {mål} ° C.';

  @override
  String get s57aad0f6c3 =>
      'I morgon: genomsnitt {avg} c/kWh, topp {max} på {tim}.';

  @override
  String get s05394a7333 =>
      'I dag: genomsnitt {avg} c/kWh, topp {max} på {hour}.';

  @override
  String get s412e06dba4 =>
      'Exceptionellt dyr el {datum}: genomsnitt {avg} c/kWh, topp {max} på {tim}.';

  @override
  String get s7f8a4ab629 => 'Prognos {datum}: {temp} °C.';

  @override
  String get s326f105e40 => '{tile}: {value}';

  @override
  String get s65afe3ff6f => 'Ankomst { ankomst}. Vänd värmen på, mål {mål} °C.';

  @override
  String get scec02139b6 => 'Kort saknas';

  @override
  String get s66f19d787b => 'Gruppen svarar inte';

  @override
  String sed9788d6dc(String p0) {
    return '$p0: Inget kommando';
  }

  @override
  String sd39874fbe2(String p0) {
    return '$p0 enheter på';
  }

  @override
  String sbe208615d0(String p0) {
    return '$p0 inte svara';
  }

  @override
  String get s589eb1bcd3 => 'Home Assistant (exempel)';

  @override
  String get sc4fdb87cd7 => 'Kamera (exempel)';

  @override
  String get sd50566a706 => 'Ventilationsenhet (exempel)';

  @override
  String get s4b4fd14aaf => 'Gård';

  @override
  String get s8ac16d45bc => '';

  @override
  String get sbde42d83a3 => 'Vardagsrummets lampor';

  @override
  String get sb7c78c63b3 => 'Tilluft';

  @override
  String get sbb2adef009 => 'Fläkthastighet';

  @override
  String get see46441329 => '0=Off;1=Away;2=Home;3=Boost;4=Max';

  @override
  String get sb25aad3bc2 => 'Jag går hemifrån';

  @override
  String get s7e5f6a29e3 => 'God natt';

  @override
  String get s253122823a => 'God morgon';

  @override
  String get s640293f08f => 'God eftermiddag';

  @override
  String get sd8c5bed7de => 'God kväll';

  @override
  String get s4cac4725b8 => 'Gruppens enheter svarar inte';

  @override
  String get s13a91fe322 => 'Enheten att styra saknas';

  @override
  String get s7e461faf91 =>
      'Hitta det i routerns enhetslista eller enhetsappen. Du kan också trycka på \"Söknätverk\".';

  @override
  String get saf4b222a68 => 'Enhetens IP-adress';

  @override
  String get s1bbea216af => 'ESP32-CAM-kameran';

  @override
  String get saaaeccd0cc => 'Low-cost Wi-Fi kamera. Visar live video.';

  @override
  String get saaea39b2de => 'Kamera IP-adress';

  @override
  String get s6ef2a3f197 =>
      'Visas i seriell bildskärmen på start eller i router enhetslistan.';

  @override
  String get sae199413a2 => 'E.g. Yard, Hall.';

  @override
  String get s2dd165b39f => 'Bildtyp';

  @override
  String get sb66b153f36 =>
      'mjpeg = live video (rekommenderas). snapshot = stillbild varannan sekund.';

  @override
  String get sf81257929d => 'Shelly relä / uttag';

  @override
  String get s2b8ab6defc =>
      'Byt ett ljus eller apparat på / av och visa kraft.';

  @override
  String get s7fcea114f0 => 'Vad styr den?';

  @override
  String get s864ba0233b =>
      'Nyare (Plus, Pro, Gen3) = Plus / Pro / Gen2 +. Old Shelly 1, 2.5, Plug S = Gen1.';

  @override
  String get s92f97cd95e => 'Visa kraft (W)';

  @override
  String get s54c71d86aa => 'Bara för modeller med mätning (t.ex. Plus 1PM).';

  @override
  String get s49671fc56f => 'Kanal';

  @override
  String get s06f8a27d8a => 'För flerkanalsenheter: 0 = första.';

  @override
  String get s259e46c59a => 'Endast om du ställer in ett lösenord.';

  @override
  String get sc130e073ba => 'Relä eller plug kör Tasmota firmware.';

  @override
  String get s70d8cb97e6 => 'Reläer';

  @override
  String get s7a4c459c3a =>
      'Tomma = varje relä enhetsrapporter (upptäcks automatiskt). Smal det: \"1\", \"1,2,4\", \"1-4\" eller \"alla\".';

  @override
  String get s5f1e4a036e => 'Web lösenord';

  @override
  String get s397e83233d =>
      'Endast om ett webblösenord är inställt (användaradmin).';

  @override
  String get sa0efcdf688 =>
      'Din egen ESP32/ESP8266 med ESPHome (web_server aktiverad).';

  @override
  String get s631420589f => 'Enhetens namn';

  @override
  String get s1db899640b => 'Switch id (tillval)';

  @override
  String get sb2e87033fc =>
      'Bytesnamnet från YAML i lägre fall med understreck.';

  @override
  String get s978ae8f1d6 => 'Sensor id (tillval)';

  @override
  String get s4ba12c5866 => 'Sensornamn på samma sätt (se enhetswebbsidan).';

  @override
  String get s945273ef29 => 'Sensor enhet';

  @override
  String get s5ca2e25792 => 'Endast om web_server auth är inställd.';

  @override
  String get sb847f22473 => 'Web användarnamn';

  @override
  String get s76f6067b0f =>
      'Ljus, larm, sensorer – välj från en lista som blir kort.';

  @override
  String get s9f70681d3f => 'Home Assistant Adress';

  @override
  String get s123502628e => 'Adressen du öppnar Home Assistant med.';

  @override
  String get s92e3c4cd40 => 'Långlivad token';

  @override
  String get s4e3f2052b2 =>
      'Hem Assistent → din profil → Säkerhet → Långlivade åtkomsttokens → Skapa token. Klistra det här.';

  @override
  String get s54e063bd9c => 'Värmepump (Home Assistant)';

  @override
  String get s2afe650320 =>
      'Luftvärmepump som visas i Home Assistant som en klimatenhet.';

  @override
  String get s48fdd98530 =>
      'Om det redan har lagts till återanvänds samma anslutning.';

  @override
  String get sfe5ad3202f => 'Det behövs inte om HA redan läggs till.';

  @override
  String get sce069d8d1a => 'Värmepump Entity';

  @override
  String get s05e2aaa15c => 'Börjar med klimat.';

  @override
  String get se699281c85 => 'Värmepump (MQTT)';

  @override
  String get s8643040b95 =>
      'E.g. mitsubishi2mqtt eller liknande ESP-kontroller. Ämnen är exempel - verifiera.';

  @override
  String get s2a1148ee77 => 'MQTT mäklare IP';

  @override
  String get s53e472c976 => 'Maskin som kör Mosquitto (ofta HA-boxen).';

  @override
  String get s29aff3d2a0 => 'MQTT användarnamn';

  @override
  String get s37e57de4b9 => 'Lämna tomt om det inte krävs.';

  @override
  String get sffe00ea1b3 => 'MQTT lösenord';

  @override
  String get s407d4a5e56 => 'Basämne';

  @override
  String get sc1af622c0a =>
      'Från kontrollinställningarna. State: <base>/state, kommandon: <base>/set.';

  @override
  String get s9783a8fd53 => 'rum';

  @override
  String get sbc996a7d25 => 'börvärde';

  @override
  String get sa69c0e1ca3 => 'Luftvärmepump (IR)';

  @override
  String get s025e7bf04d =>
      'Styr någon fjärrstyrd värmepump med en IR-blastare (Tasmota eller ESPHome). IR är envägs: Molaplan visar vad den senast skickade.';

  @override
  String get sb5d4127728 => 'IR blaster';

  @override
  String get sc899cf95db =>
      'De flesta färdiga IR-blastare kör Tasmota (använd tasmota-ir-byggnaden). ESPHome = din ESPHome-enhet med klimat_ir.';

  @override
  String get sc096a735fd => 'IP av IR-sändaren. För MQTT, mäklaren adress.';

  @override
  String get safc7f1325c => 'Värmepumpens märke';

  @override
  String get s7675ec1754 =>
      'Välj märket på enheten eller fjärrkontrollen. Om det inte reagerar, prova \"Övrigt\" med ett alternativt protokoll.';

  @override
  String get s9702830f91 => 'Protokoll (endast \"andra\")';

  @override
  String get s6df0837908 =>
      'Tasmota IRhvac leverantörsnamn. behövs bara för \"Övrigt\" eller för att prova en annan.';

  @override
  String get saa49bfdb90 => 'Visas i kakeltitlar.';

  @override
  String get sf1971ac29b => 'Tasmota ämne (endast MQTT)';

  @override
  String get s65529d5877 =>
      'Tasmota → Konfiguration → MQTT → Ämne. Andra MQTT blaster: kommandoämne.';

  @override
  String get s321c1677e2 => 'ESPHome klimat id (endast ESPHome)';

  @override
  String get s4c07dec7b5 =>
      'Climate_ir objekt id, som visas på enhetens webbsida.';

  @override
  String get s2229e548f3 => 'MQTT eller webbanvändare.';

  @override
  String get s06cff48000 => 'Command URL (endast HTTP)';

  @override
  String get s5b41e244d6 =>
      'Placeholders: {\'{power}\'} {\'{mode}\'} {\'{temp}\'} {\'{fan}\'} {\'{swing}\'} {\'{vendor}\'} {\'{json}\'}.';

  @override
  String get s9a60c2026e => 'Lägesknappar';

  @override
  String get sd119ce3382 => 'Knappar för värme, cool, auto, torr och fläkt.';

  @override
  String get s9b8dd7076a => 'Fläkthastighet';

  @override
  String get s9597aa1ae9 => 'Slider 0-5 (0 = auto).';

  @override
  String get secae50c5dd => 'Svängning';

  @override
  String get s8bcb8433f9 => 'Louver svänger på/av.';

  @override
  String get sc5d938e26e => 'Vane position';

  @override
  String get s5ce3991e13 =>
      'Slider för luftriktningen (0 = enheten bestämmer, 5 = lägst).';

  @override
  String get s78a5e5fa61 => 'Rumstemperatur från blaster sensor';

  @override
  String get s2dd6395602 => 'Endast om blastaren har en temperatursensor.';

  @override
  String get s4ff78f06ab => 'Luftvärmepump (serviceport/ESPHome)';

  @override
  String get s6cc7b6b499 =>
      'ESPHome controller på inomhus enhet service port (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba).';

  @override
  String get s647e86e5e5 => 'Klimat id';

  @override
  String get sbeb6af1e1c =>
      'Klimatenheten hos ESPHome-enheten. \"Hitta värmepumpar\" i guiden finner det för dig.';

  @override
  String get sbf36d139cb => 'Endast om web_server har auth.';

  @override
  String get s54d4fdbba4 => 'Endast om web_server har auth.';

  @override
  String get s84cd6a5180 => 'RF433-fjärrkontroll (Athom IR & RF)';

  @override
  String get s4105198757 =>
      'Kontrollera RF433 radio-avlägsna enheter (sockor, markiser, garageportar) med Athom \"Tasmota IR & RF433 Controller\". Du lär knapparna direkt efter att ha lagt till.';

  @override
  String get sbc2bf08889 => 'IP av Athom controller.';

  @override
  String get sc34430eec0 => 't.ex. vad du kontrollerar.';

  @override
  String get s12447972e0 => 'Bara om ett Tasmota-webblösenord är inställt.';

  @override
  String get s6385f1487e => 'Elpris (spot)';

  @override
  String get sead3949d3c =>
      'Dagens och morgondagens spotpris vid 15-minuters upplösning: en trend med en Nu-linje och / eller barer. Priskontroll: länge trycka på ett enhetskort → Priskontroll.';

  @override
  String get sef8d24c969 => 'Land / prisområde';

  @override
  String get sef4f509f9f => 'Välj ditt land, i Sverige och Norge ditt område.';

  @override
  String get sf3a8631d14 => 'Från din faktura inkl. moms. 0 = endast energi.';

  @override
  String get sf3be8aac1c => 'Din avtalsmarginal utan moms.';

  @override
  String s49dfca65a3(String p0) {
    return 'Elpriset $p0';
  }

  @override
  String get sfb2b7ccc87 => 'Pris trend';

  @override
  String get s4790164c94 => 'Idag och imorgon diagram';

  @override
  String get s7ba83434d1 => 'Airthings (radon och luftkvalitet, moln)';

  @override
  String get s39e8df2552 =>
      'View Plus, View Radon, Hub och varje bildskärm på ditt konto. Wi-Fi-modellerna har ingen lokal API, så värdena kommer från den officiella Airthings API med dina egna referenser.';

  @override
  String get sbafe369760 =>
      '1) Öppen vy.airthings.com och logga in med ditt Airthings-konto. 2) Integrationer → API → Skapa klient (\"Nya API-klient\"). 3) Namn det t.ex. Molaplan, välj Flow-typ \"Klientuppgifter\" och aktivera det. 4) Kopiera Klient-ID här.';

  @override
  String get sb6a852ab13 =>
      '5) Kopiera kundens hemlighet från samma vy. Den lagras endast på den här enheten och krypteras i ditt konto.';

  @override
  String get sc76f519144 =>
      'Wave, Wave Plus, Wave Mini och Wave Radon använder endast Bluetooth. Läs av en Android-enhet eller hembron (t.ex. en väggtablett) inom cirka 10 m.';

  @override
  String get sff5f25f96f =>
      'På baksidan av bildskärmen (10 siffror). Början berättar modellen: 2930 = Wave Plus, 2950 = Wave Radon, 2920 = Wave Mini.';

  @override
  String get s8de2de9178 => 'Läs igenom hembron';

  @override
  String get s5e605a88ef =>
      'När hembron (t.ex. en väggtablett nära bildskärmen) läser Bluetooth-läsningen.';

  @override
  String get s3330126b01 => 'Ventilationsenhet eller värmepump (Modbus TCP)';

  @override
  String get sc16ab2836c =>
      'Temperaturer, fläkthastighet och inställningar. Ready registerkartor för varumärken (Airfi, Vallox, Enervent, Swegon, Flexit, Ilto, Nilan, NIBE, Thermia) - verifiera med din manual.';

  @override
  String get sb75966bb58 => 'Enhet eller gateway IP';

  @override
  String get s751331a84a =>
      'Om enheten bara har RS485 behöver du en RS485 → Modbus TCP-gateway.';

  @override
  String get s658cdb6ff8 => 'Märke';

  @override
  String get s785c0c264c =>
      'Välj ett varumärke för att fylla i register som ett exempel. \"-\" = tom.';

  @override
  String get s7e9c785c20 => 'Ofta 1.';

  @override
  String get s0591744c19 => 'Nästan alltid 502.';

  @override
  String get s5ccb7405cf => 'Ventilation';

  @override
  String get se7dfa3594e => 'MQTT-enhet';

  @override
  String get s12ab103795 =>
      'Alla enheter som talar MQTT (Zigbee2MQTT, din egen ESP, ...).';

  @override
  String get sffcfefd91c => 'Maskin som kör MQTT mäklare.';

  @override
  String get s6ac05d979c => 'Vad är det?';

  @override
  String get s460d48d0cc => 'switch = on/off, sensor = visar ett värde.';

  @override
  String get s850c7e1194 => 'Tillståndsämne';

  @override
  String get s49b7311a1e => 'Ämne där enheten rapporterar sitt tillstånd.';

  @override
  String get s579969e7e4 => 'Kommandoämne (switch)';

  @override
  String get s137db4076a => 'Ämnet för kommandot på/off.';

  @override
  String get s4c95226869 => 'På meddelande';

  @override
  String get s70f2ea8532 => 'Off-meddelande';

  @override
  String get sdc234849ac => 'JSON-fältet';

  @override
  String get sd3f60d4a71 => 'Om meddelandet är JSON, fältnamnet.';

  @override
  String get s6cee917658 => 'Enhet (sensor)';

  @override
  String get s3cd541d271 => 'Andra Wi-Fi-enhet (HTTP)';

  @override
  String get s69885630aa =>
      'En enhet med ett webb-API. Visar ett värde; lägg till fler plattor senare.';

  @override
  String get s200320e245 => 'Statussökväg';

  @override
  String get sc5872d2e30 =>
      'Där enheten rapporterar sitt tillstånd. Empty = ingen kakel nu.';

  @override
  String get s5564de12b2 => 'Fält att visa';

  @override
  String get s377942beb7 => 'Fältnamn i svaret.';

  @override
  String get sbaf1a279c2 => 'Kommando och svar (ntfy)';

  @override
  String get se0fb2c7eea =>
      'Skicka ett kommando som ett ntfy-meddelande (t.ex. \"uppdatering\" + PIN) och se hemenhetens svar i samma kakel. Samma kanal som en iPhone-genväg.';

  @override
  String get s8231329360 => 'Kommando ämne URL';

  @override
  String get s206ac44298 =>
      'Klistra på samma URL dina genvägsposter kommandon till (t.ex. https://ntfy.sh/oma-aihe). Ämnet ensam fungerar också.';

  @override
  String get s1b3bbae234 =>
      'Endast om hemenheten svarar på ett annat ämne.Empty = samma ämne ignoreras vårt eget kommando.';

  @override
  String get s1b08aa4646 =>
      'Text som visas på kakeln, t.ex. \"Uppdatera\" eller \"Status\".';

  @override
  String get se2a81ae67d =>
      'Texten att skicka. PIN-koden läggs till efter ett utrymme, t.ex. \"uppdatera 1234\".';

  @override
  String get s1477964f04 => 'Be om PIN på varje press';

  @override
  String get s62672283f6 =>
      'PIN-koden är dold och lagras inte om du inte väljer \"Kom ihåg på den här enheten\".';

  @override
  String get sb5e914eaf7 =>
      'Endast för ett skyddat ämne. Lämna tomt för ett offentligt ämne.';

  @override
  String get s1a98a7e424 => 'Lägg också till ett meddelande log tile';

  @override
  String get s5ab6348524 =>
      'Visar de senaste meddelandena i ämnet i sin egen kakel.';

  @override
  String get s57e684ac9e => 'Meddelanden';

  @override
  String get s021372fd08 => 'ntfy kommandoenhet';

  @override
  String get s120a222880 =>
      'En enhet som styrs med ntfy-meddelanden: on/off switchar, stat och PIN. Arbetar hemma och bort utan en hembro.';

  @override
  String get s6f139b5bcc => 'Preset';

  @override
  String get sa149146483 =>
      'Kameraövervakning: ljus, siren, larm på / av / bekräftelse och stat. Ämnet och PIN är dina egna.';

  @override
  String get sb6b101dd23 => 'Egen enhet';

  @override
  String get s1ffb53e7f3 => 'Kameraövervakning (kv panel)';

  @override
  String get s7a46c8c335 => 'Kommandoämne';

  @override
  String get safaab25703 =>
      'Ämnet (eller full URL) enheten lyssnar på - enhetens eget ämne, inte ditt meddelande ämne.';

  @override
  String get sc1ddf7feb4 =>
      'Om enheten svarar på ett annat ämne (t.ex. ditt anmälningsämne). Empty = samma ämne.';

  @override
  String get s24779d22ca =>
      'Om svarsämnet också har andra meddelanden: endast meddelanden med denna titel är svar.';

  @override
  String get s17c9df50af => 'Lagras krypterad. Läggs till kommandon av mallen.';

  @override
  String get s4427fd3bd1 =>
      '{cmd} = kommando, {pin} = PIN, {cid} = en id enhet echoes. e.g. \"{cmd} {pin}\".';

  @override
  String get s4549a9cb7f =>
      'Kommandot enheten svarar med sitt tillstånd, t.ex. \"status\" eller \"status json\".';

  @override
  String get s5f019b05f1 => 'Status reply format';

  @override
  String get sb1f9470ebd =>
      'JSON: {\"light\": 1, …}. Text: \"Light: ON, …\" – the state is read after the name.';

  @override
  String get s96a5a283cf => 'JSON';

  @override
  String get s3f8b9eaf4b => 'Switches (en per rad: Namn = nyckel)';

  @override
  String get sb7fd9fb70a =>
      'E.g. \"Yard light = yardlight\". Nyckeln är ordet enheten använder i kommandon och tillstånd.';

  @override
  String get s9efd151ae8 => 'På kommando';

  @override
  String get s29d460cd3b =>
      '{key} = växelnyckeln. t.ex. \"{key} on\" → \"light on\".';

  @override
  String get s8dab09a808 => 'Off kommando';

  @override
  String get s93698f5ccb => 'JSON-banan prefix av växlarna (tillval)';

  @override
  String get s2179eef80d =>
      'If the switches sit under a group in the JSON, e.g. {\"relays\":{\"light\":1}}, type \"relays.\" – the key is then read from relays.light.';

  @override
  String get s50ade0ed0a => 'Statuskort JSON-banan (valfritt)';

  @override
  String get s9049a8a920 =>
      'Vad statuskortet visar från ett JSON svar, t.ex. \"state\". Empty = hela svaret.';

  @override
  String get s54b3e63eca => 'Statligt uppdaterat intervall (s)';

  @override
  String get s22a6e8c7ef =>
      'Hur ofta är staten frågad. Aldrig kortare än enhetens minsta kommandointervall.';

  @override
  String get s91158c0de5 => 'Om enheten svarar endast t.ex. var 30: e, typ 30.';

  @override
  String get s07f819fc55 =>
      'Kameraövervakning: fyll i svarsämnet - panelen svarar på användarens eget anmälningsämne (på panelen: Inställningar → Användare → anmälningsämne).';

  @override
  String get sa4a5b0baa1 =>
      'Kameraövervakning: kommandoämnet och svarsämnet kan inte vara detsamma. Kommandoämnet är panelens eget ämne (på panelen: Inställningar → ntfy), svarsämnet är ditt anmälningsämne.';

  @override
  String get s23f70f51ff => 'Kommando enhet';

  @override
  String sfeb36cc60a(String p0) {
    return '$p0 – staten';
  }

  @override
  String s3378eb2d0b(String p0) {
    return '$p0 – temperatur';
  }

  @override
  String get sdfa0c29399 => 'Senast skickad (IR är envägs)';

  @override
  String get seab2c72485 => 'Fan (0 = auto)';

  @override
  String get s7847d8821b => 'Vane (0 = auto, 5 = lägst)';

  @override
  String s3a38b97f7b(String p0) {
    return '$p0 – rum';
  }

  @override
  String get s0ceafaa97c => 'Energi energi';
}
