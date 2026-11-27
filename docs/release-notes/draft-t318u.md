# Luonnos (t318u) – värialueet ja yhtenäiset hintapylväät

*Luonnos: liitetään seuraavaan julkaisuun v0.20.5:n jälkeen. Kaikki kohdat: testaamatta laitteella.*

### Värialueet: alle X, X–Y, yli Y (R520–R522)
- Laatan muokkauksessa värirajat ovat nyt **värialueita**: ensimmäinen rivi "alle X", keskimmäiset "X–Y" ja viimeinen "yli Y". Jokaiselle alueelle valitaan väri.
- Viereiset alueet jakavat saman rajan: kun muutat rajaa, viereinen alue siirtyy mukana. Alueet eivät siksi voi mennä päällekkäin, eikä niiden väliin jää aukkoja. Raja-arvo kuuluu ylempään alueeseen.
- Väärä raja (ei luku, tai ei naapurirajojen välissä) näyttää syyn ("Pitää olla yli 5"), eikä laattaa voi tallentaa ennen korjausta. Tallennettaessa alueet järjestetään.
- Valmiit mallit: sähkölle "Halpa / keski / kallis", "Halpa / keski / kallis / erittäin kallis" ja "Negatiivinen / halpa / kallis"; muille huonelämpö, ulkolämpö, kosteus, CO₂ ja matala/keski/korkea.
- Sama editori toimii kaikissa numeroarvoja näyttävissä laatoissa (hinta, lämpötila…). Sähkön hintakaavion laatassa on enää yksi väriasetus (vanha "Värirajat (arvo ≥ raja → väri)" -lista poistui).
- Vanhat rajat säilyvät sellaisinaan ja näkyvät alueina täsmälleen samoilla väreillä.
- Samat värit näkyvät nyt myös tabletin kotinäytön widgetissä, tilasyötteessä (iPhonen widget), iPhonen hintanäkymässä ja Scriptable-skriptissä.

### Hintapylväät ilman rakoja (R523–R525)
- Pylväät täyttävät koko aikavälinsä tänään ja huomenna, oli data 15 min tai 1 h. Ohuet raot 15 minuutin pylväiden välissä johtuivat reunojen pehmennyksestä tabletin näytöllä; nyt pylväät osuvat tarkasti näytön pikseleihin.
- Jos osa hinnoista on tunnin ja osa 15 minuutin välein, kaikki pylväät näytetään samalla tarkkuudella (1 h = tuntikeskiarvo, 15 min = tunnin hinta neljänä pylväänä).
- Uusi asetus Lisäasetuksissa: **Pylväiden väli** – Ei väliä (oletus), Ohut väli, Tuntien välissä (aiempi ulkoasu).
- Hintasivulla on nyt kaksi kiinteää valintaa **15 min** ja **1 h**. Valittu näyttää, mitä pylväät esittävät.

### Vaatimukset (R520–R529)
| Rivi | Sisältö | Tila |
|---|---|---|
| R520 | Värialueet alle X / X–Y / yli Y kaikille numerolaatoille, täsmällinen siirto vanhoista rajoista | Valmis (testit; testaamatta laitteella) |
| R521 | Ei päällekkäisyyksiä eikä aukkoja, tarkistukset, järjestys tallennettaessa, mallit | Valmis (testit; testaamatta laitteella) |
| R522 | Samat värit sovelluksessa, Android-widgetissä, tilasyötteessä, ?price=-näkymässä ja Scriptable-skriptissä | Valmis (testit; testaamatta laitteella) |
| R523 | Pylväät täyttävät aikavälin (ei rakoja), pikselitarkat reunat, asetus "Pylväiden väli" | Valmis (testit; testaamatta laitteella) |
| R524 | Sekalaisen tarkkuuden (15 min / 1 h) hinnat yhtenäistetään | Valmis (testit; testaamatta laitteella) |
| R525 | Kiinteät valinnat "15 min" ja "1 h"; "Pylväät" ilman "(15 min)" | Valmis (testit; testaamatta laitteella) |
| R526 | Vanhat laatat: rajat ennallaan; pylväiden oletus nyt kiinni toisissaan | Valmis (testit) |
| R527 | Tekstit fi/en/sv/et/es | Valmis |
| R528 | Testit (alueet, geometria, sekadata, widgetit) | Valmis |
| R529 | Varattu | – |
