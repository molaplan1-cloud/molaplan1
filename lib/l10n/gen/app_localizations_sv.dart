// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

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
  String get sdfb639365a => 'Ingen internetanslutning';

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
  String get s9dd2ff794f => 'Något gick fel';

  @override
  String get sbb62433c2c => 'Kontrollera inställningarna och försök igen.';

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
  String get s609cb4c5f9 => 'på';

  @override
  String get s356d822497 => 'av';

  @override
  String get sf50732e8e8 => 'dimmable';

  @override
  String s3832b8c729(String p0) {
    return 'hela rummet';
  }

  @override
  String get see129fb410 => 'ljusstyrka';

  @override
  String get sceabe202da => 'camera_';

  @override
  String sb9964cfb3b(String p0) {
    return 'Effekt $p0';
  }

  @override
  String get sfcb44be1a0 => 'Shelly';

  @override
  String get sa6ff717527 =>
      'Reläer och pluggar: Pro 4PM, Plus 1PM, Plug S, 2,5 ... Hittas automatiskt, kakel för varje kanal.';

  @override
  String get sd7e123cd2f =>
      'I Shelly-appen: öppna enheten → växel (inställningar) → Enhetsinformation → IP-adress. Eller i routerns enhetslista: namnet börjar med \"helt...\".';

  @override
  String get s5f2b2ca5f5 => 'på nu';

  @override
  String get s67f64cd925 => 'av nu';

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
  String get s3aaacf80d2 => 'offline';

  @override
  String get s252ebed5af => 'Shelly Cloud';

  @override
  String get s25399cd337 => 'Server Server Server';

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
  String get sa376ec78ec => 'Lampa';

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
  String get s1c2786e15f =>
      'Kameraanvändaren och lösenordet (ofta admin). ONVIF kan behöva aktiveras i kamerainställningarna.';

  @override
  String get s32270de47a => 'Säkerhetskamera';

  @override
  String get s4d3ff251d6 =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz eller någon ONVIF-kamera. Bild på ett kort, live video hemma.';

  @override
  String get se8ea97c5eb =>
      'I kameraappen (enhetsinformation) eller routerns enhetslista.';

  @override
  String get s1577068729 => 'Kamera kamera';

  @override
  String get seeb6c38c8e => 'Kamera';

  @override
  String get s136c6f0d2b => 'Bild på kortet, live video hemma';

  @override
  String get s2101774157 => 'Live video hemma (ingen bild bort)';

  @override
  String get sb662db81d8 =>
      'Adressen ser ofullständig. Använd fyra nummer med prickar, t.ex. 192.168.1.50.';

  @override
  String s738ecfe2bc(String p0) {
    return ' menade du $p0?';
  }

  @override
  String s06e738bf27(String p0) {
    return 'This is not a home network address (they usually start with 192.168.).$p0';
  }

  @override
  String sbae99909c4(String p0) {
    return 'Obs!: den här enheten är på $p0.x - enheten kan vara på ett annat Wi-Fi.';
  }

  @override
  String get s5b44cbe9c0 => 'Hem';

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
  String get s49de879696 => 'Energi';

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
  String get s49ddc3c3b6 => 'Uppdatering nedladdad';

  @override
  String s04a05bb8fc(String p0) {
    return 'Filen verifieras och sparas:\n$p0\n\nFör att använda den:\nNära Molaplan.\nExtrahera zip över den gamla Molaplan-mappen (eller i en ny mapp).\n3. Start molaplan.exe. Dina inställningar hålls.';
  }

  @override
  String get s1dd246ec69 => 'Release page';

  @override
  String get s0f07b20d45 => 'Öppen zip';

  @override
  String get s6e1ebc8baa => 'Öppen mapp';

  @override
  String get sa065e7f650 => 'Tillåt att installera uppdateringar';

  @override
  String get sdc3bf71baf =>
      'Android ber en gång om tillstånd så att Molaplan kan installera sina egna uppdateringar.\n\nTryck på \"Öppna inställningar\".\nSlå på \"Tillåt från den här källan\".\nKom tillbaka och tryck på \"Uppdatera\" igen.';

  @override
  String get sa1bd8d2533 => 'Öppna inställningar';

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
  String s11ee4426b2(String p0) {
    return 'Något gick fel: $p0';
  }

  @override
  String get sbf59e43c36 =>
      'Ingen internetanslutning. Kontrollera Wi-Fi eller mobildata och försök igen.';

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
  String get sdd1cd7bdd5 => 'ESPHome controller IP';

  @override
  String get sa1e21d236a =>
      'Från routerns enhetslista eller ESPHome dashboard.';

  @override
  String get s1bef32afe0 => 'Hitta värmepumpar';

  @override
  String get s9aa9bc9679 => 'Enhet svarade men har ingen klimatenhet.';

  @override
  String get s5a40f12b6a => 'Lägg till';

  @override
  String get s7aa295f82d => 'Inte hemma – byt ›';

  @override
  String get sdc74e0c0e7 => 'Inte i hemnätverket – byt till fjärranslutning ›';

  @override
  String get s3a5c21004e => 'Offline';

  @override
  String get s68cbe596f8 => 'Inloggningen har gått ut';

  @override
  String get s156aa7eeb3 => 'Enheten svarar inte';

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
  String get sa7d212f047 => 'Enheter i hemmets Wi-Fi fungerar ändå.';

  @override
  String get s24ccd151f2 => 'Försök igen';

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
  String get sa3a093e55e => 'Värme';

  @override
  String get s8efb99df1d => 'Kyla';

  @override
  String get s0b98d62330 => 'Värme och kyla';

  @override
  String get s33831dd49f => 'Av';

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
  String get sb1924acbe7 => 'Namn';

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
  String get sf4caddf894 => 'Avancerat';

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
  String get sc1845eb440 => 'Radera';

  @override
  String get s87984716cb => 'Ta bort termostaten?';

  @override
  String get s79786b9f7d => 'Mål';

  @override
  String get sdd309c0a63 => 'Termostaten körs på hembryggan';

  @override
  String get s9c1b5394df =>
      'Ställ in fjärråtkomst på hemmatabletten (Inställningar → Fjärråtkomst). Tills dess kontrollerar det inte någonting.';

  @override
  String get s06cda8c0de => 'Körs på den här enheten (hembrygga).';

  @override
  String get s2342536aea => 'Körs på hembryggan.';

  @override
  String get s798f7b2876 => 'Smart uppvärmning';

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
  String get s23f4820db7 => 'Inte kontrollerbar ännu';

  @override
  String get saae59a3865 => 'via home bridge';

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
  String get s9a018b8166 => 'Du är borta: hembron sökte ditt hemnätverk.';

  @override
  String sc81d032be0(String p0) {
    return '$p0 okända enheter';
  }

  @override
  String get s7f3081821b => 'Molaplan kan inte kontrollera dessa.';

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
  String get sce0949d6fc =>
      'Försök igen. Om det fortsätter att hända, starta om enheten.';

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
  String get sd890121a57 => 'Show home view';

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
  String get s200542b930 => 'Försök igen';

  @override
  String get s8f610a3bb2 => 'Jag är hemifrån';

  @override
  String get sf77125583f => 'Tekniska detaljer';

  @override
  String s77ec7b376b(String p0) {
    return 'Hittade: $p0';
  }

  @override
  String get sac4debdb9c => 'Välj vad som går på hemvyn och namnge dem.';

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
  String get s856a422504 => 'Ställ in fjärråtkomst';

  @override
  String get sd9923cda70 => 'Inte hemma? Sväng på fjärråtkomst';

  @override
  String get s876c7230a2 => 'Lägg till enhet';

  @override
  String get s1e593aeca2 => 'Stäng';

  @override
  String get s3d00dee1a9 => 'Använd';

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
  String get s262f9527aa => 'Väderprognos';

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
  String get s306729fe62 => 'Inga priser';

  @override
  String get s80c4ecec94 => 'c/h';

  @override
  String get sbfe79d1f5f => 'Uppdaterad';

  @override
  String get sb68e905fc4 => 'Förbrukning (kWh)';

  @override
  String get s5fc5085143 => 'Kostnad';

  @override
  String get sb730159a01 => 'Pris nu';

  @override
  String get sbc8fb68b5d => 'Billigast i dag';

  @override
  String get s86ff059f5e => 'Medelpris i dag';

  @override
  String get se3d8d53b4b => 'Dyrast i dag';

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
  String get sa5e6b1e0e3 => 'I morgon efter ca 14:00';

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
  String get s4e35ba5321 =>
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
  String get s406e599999 =>
      'Inga tider under nästa dag (eller morgondagens priser är inte ute ännu).';

  @override
  String get s140acccb81 => 'I dag';

  @override
  String get s0de6e75a52 => 'I morgon';

  @override
  String sf87d92faf4(String p0, String p1) {
    return 'Prisområdet $p0. Dag-ahead spot priser inkl. moms $p1 %. Lägg till \"Elektricitetspris\" enhet för att ändra område och avgifter.';
  }

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
  String get s5f8284b98f => 'Gör den här enheten hembron';

  @override
  String get s6a95f7843b =>
      'Den här enheten stannar hemma, alltid på (laddare + Wi-Fi) och passerar fjärrkommandon till dina enheter.';

  @override
  String get s2c3ae5833b => 'Andra sätt: VPN, Nabu Casa, moln MQTT';

  @override
  String get s807e3a32f3 =>
      'Steg-för-steg guider om du redan använder Tailscale, WireGuard, Home Assistant Cloud eller moln MQTT.';

  @override
  String get sa3e78d5c4e => 'Hembron svarar – fjärråtkomst fungerar.';

  @override
  String get s370acd310d => 'Fjärråtkomst';

  @override
  String get s0b57661c18 => 'Kontrollera ditt hem var som helst';

  @override
  String get sb43ef4094c =>
      'Hemma pratar Molaplan med dina enheter direkt. På andra ställen krypteras det genom din hemmabro - ingen port vidarebefordran eller routerinställningar. Appen plockar rätt väg automatiskt.';

  @override
  String get s075e5a4864 => 'Ansluten till hemmet';

  @override
  String get sa7679488fb =>
      'Hemma = direkt. Fjärr = genom hembron. Ingen anslutning = varken svar.';

  @override
  String get s19cec9667e => 'Test fjärråtkomst';

  @override
  String get s86ad95fa48 => 'Copy home dashboards';

  @override
  String get sfaa5185b74 => 'Ta bort fjärråtkomst?';

  @override
  String get sbc44ce6993 =>
      'Den här enheten kan sedan inte längre komma hem från utsidan. Du kan koppla ihop igen när som helst.';

  @override
  String get s9593939a4c => 'Ta bort';

  @override
  String get s3563cb1635 => 'Ta bort fjärråtkomst';

  @override
  String get s528c4f3a4c => 'Den här enheten är hembron';

  @override
  String get se7b8d659b5 => 'Avancerat';

  @override
  String get sfd263f3e04 => 'Kamera uppdateras när fjärrkontrollen';

  @override
  String s99249ddf24(String p0) {
    return 'Fjärrkameran visar en bild varje $p0 s (besparar data).';
  }

  @override
  String get s451ea613dd => 'Relay server';

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
  String get s3a141e0c32 =>
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
  String s7132345f20(String p0) {
    return 'Enhet \"$p0\" ansluten!';
  }

  @override
  String get sb38b582dab => 'Hembrygga';

  @override
  String get se2e2af02ac =>
      'Hembron är en enhet som stannar hemma, t.ex. en gammal surfplatta eller en dator. När du är borta, din telefons kommandon krypteras genom den till dina enheter.';

  @override
  String get sd64f52490d => 'Håll det på laddaren och på hemmet Wi-Fi.';

  @override
  String get sbb23f25581 =>
      'Håll Molaplan öppen. Skärmen stannar kvar medan bron är på.';

  @override
  String get sbfed096278 => 'Använd den här enheten som hemmabron';

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
  String get sc58a7d7121 => 'Hemmets namn';

  @override
  String get s9715416100 => 'Skanna med telefonen';

  @override
  String get sf54c6d871c =>
      'På telefonen: Molaplan → Inställningar → Fjärråtkomst → Anslut den här enheten hem';

  @override
  String get sf7fa9632f3 => 'Giltigt för';

  @override
  String get s5378bb3f05 => 'Acceptera den här enheten?';

  @override
  String s1d8bb7b0a6(String p0) {
    return '\"$p0\" vill ha fjärrkontroll av ditt hem. Acceptera endast om det är din egen eller en familjemedlems enhet som precis har angett koden.';
  }

  @override
  String get sa04c218f82 => 'Avvisa';

  @override
  String get sdfaf8c242b => 'Godkänn';

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
  String get s76e7a995de => 'Value read';

  @override
  String get sc5edd6d3d1 => 'Nytt kort';

  @override
  String get sa684fd0716 => 'Redigera kort';

  @override
  String get s8a8673aafe => 'Rubrik';

  @override
  String get scf37cbeda8 => 'Ikon';

  @override
  String get sa444aab286 => 'Automatisk';

  @override
  String get sfeab9bd26f => 'Bredd';

  @override
  String get s58be670598 => 'Höjd';

  @override
  String get sea30815e6a =>
      'Tekniska kakelinställningar visas när du slår på \"Avancerad\" i Inställningar.';

  @override
  String get s382afc832f => 'Statlig källa';

  @override
  String get s581aee3e96 => 'Valfritt: där det nuvarande tillståndet läses av.';

  @override
  String get se6b18b17d9 => 'omröstningsintervall (s, 0 = none)';

  @override
  String get s01f2b1ee0c =>
      'MQTT, Home Assistant och WebSocket uppdatering lever utan omröstning.';

  @override
  String get s937448ecf5 => 'Testläsare';

  @override
  String get s5cbdea7f7e => 'Display';

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
  String get sc0f5a14d2b => 'Färgtrösklar (värde ≥gräns → färg)';

  @override
  String get scd65d31d4c => 'Begränsning';

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
  String get s1f9799af4e => 't.ex. stuga';

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
  String get s59622d792b => 'Byt namn';

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
  String get s147f47be4c => 'Lägg till kort';

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
  String get s286e1cfb54 => 'Totalt';

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
  String get sdb0484d728 => 'Sparat';

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
  String get sa0d8c62e5a => 'Inget kommando konfigurerat';

  @override
  String get s1e5d696a26 => 'Kör detta kommando?';

  @override
  String get s1df6e2eaa7 => 'PIN';

  @override
  String get secab66c046 => 'Kom ihåg på denna enhet';

  @override
  String get s10bf4eab8e =>
      'Lagrad krypterad på den här enheten bara. Som standard lagras PIN-koden inte.';

  @override
  String get s912ea5d2ec => 'Skicka';

  @override
  String get s856418521a => 'Inga kommandon konfigurerade';

  @override
  String sdfa66ee201(String p0) {
    return '$p0: Sänd';
  }

  @override
  String get s12fc3810a5 => 'Sent – vänta på svaret...';

  @override
  String get sd1c7d49360 => 'Svara på';

  @override
  String get s38ac222392 => 'Värde';

  @override
  String get s29fae6a0e8 => 'Prisstyrning på';

  @override
  String get s59d55f8882 => 'Byt namn';

  @override
  String get s25580038cb => 'Saved PIN bort';

  @override
  String get sf50c488b24 => 'Glöm frälst PIN';

  @override
  String get safe0429a90 => 'Prisstyrning';

  @override
  String get sf3d644dd4c => 'Lär in en fjärrkontrollknapp';

  @override
  String get sfb1a18d11f => 'Uppdatera';

  @override
  String get s4cbe24240f => 'På';

  @override
  String get s72a2328ddd => 'Lampor';

  @override
  String get sca12be80ca => 'Brytare';

  @override
  String get sa4c0eeea02 => 'Värmepumpar och AC';

  @override
  String get s662fecdc8d => 'Sensorer';

  @override
  String get sa8dbf04ad3 => 'Binära sensorer';

  @override
  String get sa7690acf57 => 'Markiser, portar och dörrar';

  @override
  String get s487bf00fc7 => 'Lås';

  @override
  String get s8d06ee5308 => 'Larm';

  @override
  String get s88ac47e6d1 => 'Kameror';

  @override
  String get sbe76826428 => 'Fläktar';

  @override
  String get s6b7c1c52da => 'Scener';

  @override
  String get s9f1334d4e2 => 'Skript';

  @override
  String get s4b53bcaaf0 => 'Knappar';

  @override
  String get s5c92d42edd => 'Talinmatningar';

  @override
  String get s3c2ed0c522 => 'Hjälpbrytare';

  @override
  String get se9ca7cb470 => 'Automatiseringar';

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
  String s095ca83913(String p0) {
    return '$p0 kort tillagda';
  }

  @override
  String get sa7a829cefb => 'Välj Home Assistant-enheter';

  @override
  String get sefdf8e3316 => 'Hämtar enheter…';

  @override
  String get s26583a1933 => 'En vy per rum';

  @override
  String sf1319d04d0(String p0) {
    return 'Lägg till $p0';
  }

  @override
  String get sb3e6b54bce => 'Sök efter namn eller id';

  @override
  String get safedc10c48 => 'Alla rum';

  @override
  String get s407f3f7a0c => 'Inget rum';

  @override
  String get sedb7b77645 => 'Alla';

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
  String get sceafe9ce2a => 'Filen är inte en bild';

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
  String get s7400a53ab2 => 'Färg';

  @override
  String get s254a1d8e12 => 'Bakgrundsbild (valfri)';

  @override
  String get sc48f5f9bcf => 'Välj bild';

  @override
  String get sf55eee73b8 => 'Ändra bild';

  @override
  String get sf6723451b9 => 'Ta foto';

  @override
  String get sdd957ccc1b => 'Ta bort bild';

  @override
  String get s7ba9d453ed => 'Dämpa när enheten är av';

  @override
  String get s016ae7b580 =>
      'Bilden krymps (≤ 200 KB) och synkroniseras till ditt konto.';

  @override
  String get sabb10f8cb2 =>
      'Bilden krymps (≤ 200 KB) och hålls endast på den här enheten.';

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
  String get s580678cb10 => 'Importera';

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
  String get s9bb545e9b3 => 'Logga in eller skapa ett konto';

  @override
  String get s0625d54b38 => 'Kortstorlek';

  @override
  String get s8382da3467 => 'Normal';

  @override
  String get s21f870dbc2 =>
      'Visar tekniska inställningar: anslutningar (HTTP, MQTT, Modbus...), nyttolast, JSON-vägar och kakelkällor. De flesta behöver inte dessa.';

  @override
  String get sca4c8b88b7 => 'Home Assistant: Lägg till enheter';

  @override
  String get saec69088a5 => 'Styr ditt hem från utsidan också.';

  @override
  String get scc3d01ee5e => 'Guider: VPN, Nabu Casa, moln MQTT';

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
  String get s412c666544 =>
      'Lägg till ett exempel instrumentpanel (kamera, larm, ljus, ventilation). Byt adresserna med din.';

  @override
  String get sec02c7c071 => 'Lägg till exempelvy';

  @override
  String get s522d6584c5 => 'Sök efter uppdateringar';

  @override
  String get sd178a1d809 =>
      'Din egen kontrollterminal: HTTP, MQTT, Modbus TCP, Home Assistant, kameror, WebSocket, TCP och UDP. Utan ett konto stannar alla inställningar på den här enheten.';

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
  String get s64f4d1e11a => 'Ange hemmets plats';

  @override
  String get s8ff5c58a5d => 'Ingen väderprognos';

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
    return 'HTTP $p0: the device answered but refused the login. Check username, password or token. $p1';
  }

  @override
  String s3bd10f0ae2(String p0, String p1) {
    return 'HTTP $p0: the device answered with a server error. $p1';
  }

  @override
  String s2a7fa26dd6(String p0, String p1) {
    return '✓ The device answered at $p0 (HTTP 404: no page at the base address – normal for many devices). The connection works. $p1';
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
  String get s4f356d158a => 'Refresh (s, snapshot)';

  @override
  String get sca7e088857 => 'Elpris';

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
  String get s515da3a9dd => 'Prisserver';

  @override
  String get s98cc9f1c14 => 'Molaplans server hämtar priser från öppna källor.';

  @override
  String get s271885dc8b => 'Vad ska man visa';

  @override
  String get s46282f452b => 'Nu = aktuellt pris, diagram = idag och imorgon.';

  @override
  String get s2f754e8ab4 => 'Inga priser för idag ännu.';

  @override
  String get sd575462da3 => 'i morgon ';

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
  String get s7068e8892e =>
      'Okänd kod utan rådata. Aktivera rådata i Tasmota (SetOption58 1) och försök igen.';

  @override
  String get s6207a45bff => 'IR blaster (värmepump)';

  @override
  String get s859c2e7734 => 'Blaster firmware';

  @override
  String get s3f8d3fb444 =>
      'tasmota_http = Tasmota (tasmota-ir) av IP. tasmota_mqtt = Tasmota via en MQTT-mäklare. esphome = ESPHome klimat_ir. http/mqtt = annan blaster med dina egna mallar.';

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
    return 'Broker OK but Tasmota \"$p0\" did not answer.';
  }

  @override
  String s2c3b95a054(String p0) {
    return '✓ Tasmota \"$p0\" answered via MQTT. Nothing sent to the heat pump.';
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
  String get sa3e8beed42 => 'Värme';

  @override
  String get s6c9668fbd9 => 'Kyla';

  @override
  String get s9db8aefc43 => 'Avfuktning';

  @override
  String get s018d2e08f4 => 'Fläkt';

  @override
  String get s36fb6ba26f => 'Modbus TCP';

  @override
  String get sa70cc38354 => 'Värd';

  @override
  String get sdc5301b750 => 'Enhet Id';

  @override
  String get s15e327bf8e => 'Timeout (ms)';

  @override
  String get s943b8b6bf3 => 'Registrera tabell';

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
  String get s6a4516e0fe => 'Kommandoämne (namn eller fullständig URL)';

  @override
  String get se003ecc10b =>
      'Ämne kommandon skickas till. Du kan klistra in hela URL, t.ex. https://ntfy.sh/my-topic - samma som din iPhone Shortcut använder. ämnesnamnet fungerar som ett lösenord: hålla det länge och slumpmässigt.';

  @override
  String get s800cd08229 => 'Svara på ämne (valfritt)';

  @override
  String get s2e3a66d384 =>
      'Om hemenheten svarar på ett annat ämne, skriv det här. Lämna tomt om svaret kommer på samma ämne - vårt eget kommando ignoreras sedan och nästa meddelande visas som svaret.';

  @override
  String get s5bc736c04a => 'Access token (tillval)';

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
  String get sfee393b70e => 'Vänta på svaret';

  @override
  String get sfff5bc52e5 =>
      'Lyssnar på hemenhetens svar och visar det i den här kakeln (och som ett meddelande när appen är i bakgrunden).';

  @override
  String get sbdcbe301b9 => 'Vänta på svar (s)';

  @override
  String get s121542d6d7 =>
      'Hur lång tid att vänta innan du säger att inget svar kom.';

  @override
  String get sa53638cfea => 'Svaret stannar på plattan (s)';

  @override
  String get se6d21484a8 =>
      'Hur länge svaret stannar på kakeln. 0 = tills nästa press.';

  @override
  String get s74d68a98d6 => 'Meddelande titel (valfritt)';

  @override
  String get sc2492ac3ab => 'ntfy meddelande titel. vanligtvis tom.';

  @override
  String s54ea45f27f(String p0, String p1) {
    return 'ntfy: ämne \"$p0\" skyddas (HTTP $p1). Lägg till en åtkomsttoken (tk_...) till anslutningen.';
  }

  @override
  String get s72c37e530d =>
      'ntfy: för många meddelanden (HTTP 429) Vänta ett ögonblick och försök igen.';

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
  String get sf0ef0140c3 => 'Home Assistant';

  @override
  String get s1f90ee6992 => 'Långlivad access token';

  @override
  String get sccb0cca8e3 => 'Live updates (websocket)';

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
  String get s804e935440 => 'ESP32 kamera';

  @override
  String get s478ddb6e1a => 'Ventilationsenhet (Modbus)';

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
  String get sdccd6e7f24 => 'Modell';

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
  String get s16be1831d6 => 'Endast för enheter med energimätning.';

  @override
  String get s8890d26ef2 => 'Relä nummer';

  @override
  String get s7e6d21d466 => 'För multireläenheter 1, 2, 3...';

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
  String get sc7d02fbe84 => 'Värmepump';

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
  String get se807a72c0a =>
      'Dagens och morgondagens spotpris som ett diagram. Priskontroll: länge tryck på en enhetsplatta → Priskontroll.';

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
  String get s9af9526395 => 'Ventilationsenhet (Modbus TCP)';

  @override
  String get s29dc0baf55 =>
      'Temperaturer och fläkthastighet. Registrera förinställningar är exempel - verifiera med din handbok.';

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
  String get sd82d127f05 =>
      'Klistra på samma URL dina genvägsposter kommandon till (t.ex. https://ntfy.sh/kv-cmd-...). Ämnet ensam fungerar också.';

  @override
  String get s1b3bbae234 =>
      'Endast om hemenheten svarar på ett annat ämne.Empty = samma ämne ignoreras vårt eget kommando.';

  @override
  String get s1b08aa4646 =>
      'Text som visas på kakeln, t.ex. \"Uppdatera\" eller \"Status\".';

  @override
  String get s5bed8bff00 => 'Kommando';

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
  String get sdc84bf286f =>
      'off=Off;heat=Heat;cool=Cool;auto=Auto;heat_cool=Auto;dry=Dry;fan_only=Fan';

  @override
  String s3378eb2d0b(String p0) {
    return '$p0 – temperatur';
  }

  @override
  String get saa437260b8 => 'Sent State (IR är one-way)';

  @override
  String get sfffb54daf4 => 'Tillstånd';

  @override
  String get seab2c72485 => 'Fan (0 = auto)';

  @override
  String get sfb0b971c01 => 'Svängning';

  @override
  String s3a38b97f7b(String p0) {
    return '$p0 – rum';
  }
}
