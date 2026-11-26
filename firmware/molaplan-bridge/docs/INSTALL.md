# Molaplan Bridge – asennus / installation

Molaplan Bridge on pieni ESP32-laite, joka on kotona aina päällä ja välittää puhelimen
etäkomennot kodin laitteille päästä päähän salattuina (sama protokolla kuin PC/tabletti-sillalla).
Se ohjaa myös ilmalämpöpumppua infrapunalla (IRhvac) ja RF433-laitteita.

Tuetut laitteet:

| Laite | Profiili | Tila |
|---|---|---|
| Athom "Tasmota IR & RF433 Controller" (ESP32, 4 MB) | `athom_ir_rf` | Nastat Athomin julkisesta GPIO-taulukosta – **ei vielä testattu oikealla laitteella** |
| Mikä tahansa ESP32 DevKit (4 MB) + IR-LED/vastaanotin | `generic` | Käännetty ja yksikkötestattu, ei kenttätestattu |

Release-tiedostot (GitHub Release):

| Tiedosto | Mihin |
|---|---|
| `molaplan-bridge-esp32.bin` | Sovellusimage: Tasmotan web-päivitys (Athom) ja allekirjoitettu OTA |
| `molaplan-bridge-esp32-factory.bin` | Koko flash osoitteeseen 0x0: kertaluonteinen USB-asennus (A/B-osiot) |
| `molaplan-bridge-esp32.manifest.json` | Ed25519-allekirjoitettu OTA-manifesti (versio, SHA-256, osoite) |
| `SHA256SUMS` | Tarkistussummat kaikille tiedostoille |

## Kumpi tapa?

* **A. Ilman johtoja (Tasmotan web-sivulta)** – nopein, ei avata koteloa. Päivitykset vaativat
  myöhemmin yhden käsin tehdyn latauksen per versio (Tasmotan safeboot-sivulla), koska Athomin
  Tasmota-osiotaulussa on vain yksi sovellusosio. Osiotaulua **ei koskaan** kirjoiteta laitteessa
  uudelleen: sähkökatko sen aikana voisi rikkoa laitteen.
* **B. Kertaluonteinen USB-asennus** – suositus valvomattomaan käyttöön. Tämän jälkeen päivitykset
  tulevat etänä ("Päivitä silta" Etäkäyttö-sivulla): allekirjoitus tarkistetaan, uusi versio menee
  toiseen osioon ja vanha käynnistyy itsestään, jos uusi ei toimi (rollback).

## A. Athom: asennus Tasmotan web-sivulta (ei USB:tä)

1. Kytke Athom virtaan ja selvitä sen IP-osoite (reitittimen laitelista, tai Tasmotan oma
   `tasmota-XXXX`-Wi-Fi ensimmäisellä kerralla).
2. Avaa selaimessa `http://<IP>` → **Information**. Tarkista, että *Program Version* on
   Tasmota32 ja että rivillä *Flash* / *Partition* näkyy **safeboot**. Jos safebootia ei ole,
   käytä tapaa B.
3. Ota talteen Tasmotan asetukset: **Configuration → Backup Configuration** (paluuta varten).
4. **Firmware Upgrade → Upgrade by file upload** → valitse `molaplan-bridge-esp32.bin` → **Start upgrade**.
   Tasmota käynnistyy safeboot-tilaan, kirjoittaa tiedoston ja käynnistää Molaplan Bridgen.
5. Valo alkaa vilkkua hitaasti (kerran sekunnissa) = asetustila. Jatka kohdasta **Käyttöönotto**.

Paluu Tasmotaan: lataa safeboot-sivulla virallinen `tasmota32-ir.bin` ja palauta asetukset.

## B. Kertaluonteinen USB-asennus (A/B-osiot)

Tarvitset: USB-sarjasovittimen **3,3 V** logiikalla (CP2102, CH340 tai FT232), 4–5 hyppylankaa ja
tietokoneen, jossa on Python 3 (`pip install esptool`). **Älä koskaan käytä 5 V:n logiikkaa** RX/TX-
nastoissa. Athom saa virtansa USB:stä – irrota sen oma virtajohto, kun käytät sovittimen 3,3 V:ia.

1. Avaa kotelo (ruuvit pohjassa / napsautuskiinnitys). Etsi piirilevyltä nastat **3V3, GND, TX,
   RX** ja **IO0** (merkinnät voivat olla `TXD0/RXD0`, `GPIO0` tai `BOOT`).
2. Kytke: sovittimen **GND → GND**, **3V3 → 3V3**, **TX → RX**, **RX → TX** (ristiin).
3. Pidä **IO0 kytkettynä GND:hen** (tai paina BOOT-nappia) samalla kun kytket sovittimen
   tietokoneeseen → ESP32 menee latausmoodiin. IO0:n voi irrottaa, kun seuraava komento vastaa.
4. **Varmuuskopio koko flashista ensin** (tällä pääset aina takaisin alkuperäiseen):

       esptool.py --chip esp32 --port COM5 --baud 460800 read_flash 0 0x400000 athom-varmuuskopio.bin

   (Linux/macOS: `--port /dev/ttyUSB0`.) Säilytä tiedosto.
5. Tarkista ladattu tiedosto: `sha256sum molaplan-bridge-esp32-factory.bin` (Windows:
   `certutil -hashfile molaplan-bridge-esp32-factory.bin SHA256`) ja vertaa `SHA256SUMS`-riviin.
6. Kirjoita:

       esptool.py --chip esp32 --port COM5 --baud 460800 write_flash 0x0 molaplan-bridge-esp32-factory.bin

   esptool tarkistaa kirjoituksen itse (*Hash of data verified*). Erillistä tyhjennystä ei tarvita.
7. Irrota IO0–GND, irrota sovitin, sulje kotelo ja kytke Athomin oma virta. Valo vilkkuu hitaasti
   = asetustila.

Paluu alkuperäiseen: sama kytkentä ja
`esptool.py --chip esp32 --port COM5 write_flash 0x0 athom-varmuuskopio.bin`.

Turvallisuus: latausmoodissa (IO0 alhaalla) ESP32:n ROM-lataaja on aina käytettävissä, joten
väärä tai keskeytynyt kirjoitus ei "brickaa" laitetta – kirjoita uudelleen tai palauta varmuuskopio.

## Käyttöönotto (molemmat tavat)

1. Puhelimen Molaplan: **Asetukset → Etäkäyttö → Lisää kotisilta (Molaplan Bridge -laite)**.
2. Liity puhelimella Wi-Fiin **Molaplan-XXXX** (ei salasanaa), palaa sovellukseen → **Etsi silta**.
3. Valitse kodin Wi-Fi, kirjoita salasana, tarkista laitemalli → **Yhdistä silta kotiin**.
   Wi-Fi-salasana ja yhdistämistunnus lähetetään sillan julkiseen avaimeen salattuina
   (X25519 + HKDF + AES-GCM); avoimesta asetusverkosta ei voi lukea niitä.
4. Silta liittyy kotiverkkoon ja etäpalvelimeen. Puhelin palaa kotiverkkoon / mobiilidataan;
   Etäkäyttö näyttää sillan version ja tilan.

## Valo ja nappi

| Valo | Tila |
|---|---|
| Hidas vilkku (1 Hz) | Asetustila (Wi-Fi `Molaplan-XXXX` ja BLE auki 15 min) |
| Nopea vilkku (4 Hz) | Yhdistetään Wi-Fiin |
| Päällä, lyhyt välähdys pois 3 s välein | Kunnossa: etäyhteys toimii |
| Kaksoisvälähdys 2 s välein | Wi-Fi toimii, etäpalvelin ei vastaa |
| Välke (10 Hz) | Päivitys käynnissä – älä katkaise virtaa |
| 3 lyhyttä + tauko | Virhe (katso `http://<IP>/cs`) |

| Nappi | Toiminto |
|---|---|
| Lyhyt painallus | Tilaraportti (ntfy) |
| Pidä 3 s | Avaa asetustila 15 minuutiksi |
| Pidä 10 s | Tehdasasetukset (vain Molaplan Bridgen omat asetukset) |

## Mikä on testattu / mitä ei

* Testattu automaattisesti (CI): salaus- ja protokollayhteensopivuus sovelluksen kanssa
  (sovelluksen omista koodeista generoidut testivektorit), provisiointi, OTA-manifestin
  allekirjoitus/versio/SHA-256, IRhvac-tila, Modbus/HTTP-pyynnöt, A/B-osiotaulu; ESP32-käännös.
* Sovelluksen puoli: "Lisää kotisilta" -kulku testattu valesiltaa vastaan, joka tekee saman kuin
  laiteohjelmiston `BridgeEngine::provision`.
* **Ei vielä testattu oikealla laitteella:** Athomin nastat (IR-lähetin/-vastaanotin, RF, nappi,
  LED), Tasmota-web-asennus, USB-asennus, BLE-asetus, OTA ja rollback raudalla, IR-koodien toimivuus
  eri lämpöpumpuissa.
