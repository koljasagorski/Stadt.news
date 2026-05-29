# Gelsenkirchen.news

Native iOS-App (SwiftUI, iOS 17+), die offizielle Meldungen aus **Gelsenkirchen**
bündelt — Polizei und Feuerwehr (Presseportal-„Blaulicht") sowie Pressemeldungen
der Stadt — als schnell lesbarer, redaktionell gestalteter Feed.

## Funktionen
- **Feed** der aktuellen Meldungen mit Pull-to-Refresh und Lade-/Fehlerzuständen
- **Quellen** in einem Feed: Polizei, Feuerwehr, Stadt Gelsenkirchen und amtliche Warnungen (BBK/NINA – u. a. Wetter, Hochwasser, Zivilschutz), mit Filterleiste je Quelle
- **Suche** über Titel und Teaser der geladenen Meldungen
- **Lokaler Cache**: der zuletzt geladene Feed wird beim Start sofort gezeigt und im Hintergrund aktualisiert (auch offline lesbar)
- **Artikel-Detail** mit Volltext (server-seitig vom Backend vorbereitet, sonst von der Artikelseite nachgeladen); Teilen und „Im Original lesen"
- **Karten-Ansicht**: Meldungen mit erkennbarem Ort als Pins (Best-Effort-Geocoding aus Straßennamen/Stadtteilen)
- **Lesezeichen** („Gemerkt"): Meldungen speichern und in einer eigenen Liste wiederfinden
- **Push-Mitteilungen** bei neuen Meldungen (OneSignal, ausgelöst vom Cloudflare-Worker), wahlweise je Quelle; Tippen öffnet den Artikel direkt in der App — siehe Setup unten
- Hell-/Dunkelmodus

## Projektstruktur
```
StadtNews/
  App/            App-Einstieg (StadtNewsApp, AppDelegate)
  Models/         Article, City
  Services/       NewsService (RSS), ArticleContentService (Volltext),
                  FeedCache (lokaler Cache), AppSettings, PushService, RSSParser
  ViewModels/     NewsFeedViewModel, ArticleDetailViewModel, IncidentMapModel
  Views/          Feed, Map, Settings, Support, RootView, MainView
  DesignSystem/   Theme, Components (u. a. Masthead/Wortmarke)
  Utilities/      String+HTML, DateParsing
worker/           Cloudflare-Worker (Feed-Aggregation + Push-Auslösung)
```
Das Xcode-Projekt nutzt eine synchronisierte Ordnergruppe — neue Dateien in
`StadtNews/` werden automatisch eingebunden.

> Hinweis: Der interne Target-/Projektname ist weiterhin `StadtNews`, die
> Bundle-ID `news.stadt.app` (für Nutzer nicht sichtbar; die Bundle-ID hängt an
> der Push-Einrichtung).

## Bauen & Starten
1. `Stadt.news.xcodeproj` in Xcode öffnen (iOS 17+).
2. Schema „StadtNews" wählen, auf Simulator oder Gerät starten (⌘R).

Es gibt keine externen Abhängigkeiten, außer dem optionalen OneSignal-SDK für Push.

## Push-Mitteilungen (einmalige Einrichtung)
Push ist im Code vorbereitet, aber inaktiv, bis Folgendes eingerichtet ist:
1. OneSignal-Konto + App (App ID + REST API Key)
2. Apple Developer Program; APNs-Schlüssel (.p8) in OneSignal hinterlegen
3. OneSignal-SDK in Xcode hinzufügen (`https://github.com/OneSignal/OneSignal-iOS-SDK`, Produkt `OneSignalFramework`)
4. App ID in `StadtNews/Services/PushService.swift` eintragen
5. Capabilities: Push Notifications + Background Modes → Remote notifications
6. Worker-Secrets setzen (im Ordner `worker/`):
   `npx wrangler secret put ONESIGNAL_APP_ID` und `… ONESIGNAL_REST_API_KEY`
   (optional `ONESIGNAL_AUTH_SCHEME`, Default „Basic"; neuere OneSignal-Keys nutzen „Key")

Der **Cloudflare-Worker** erkennt in seinem Cron-Lauf neue Meldungen und sendet
dafür eine Push über die OneSignal-REST-API, gefiltert nach den Städte-Tags der
Nutzer. Ohne gesetzte Secrets läuft das als „Dry Run" (sendet nichts); ohne
Apple-APNs-Key in OneSignal erfolgt keine Zustellung an iOS-Geräte.

## Backend (optional, Cloudflare Worker)
Unter [`worker/`](./worker) liegt ein Cloudflare-Worker, der die Feeds
serverseitig vorab aggregiert und unter `GET /v1/feed` als fertiges JSON
ausliefert — das beschleunigt den Start und erlaubt später weitere Quellen
ohne App-Update. Die App nutzt ihn automatisch, sobald eine URL hinterlegt ist,
und fällt sonst auf direktes RSS zurück.

Deployen (Cloudflare-Konto nötig):
```
cd worker
npm install
npx wrangler login
npx wrangler kv namespace create NEWS   # die id in wrangler.jsonc eintragen
npx wrangler deploy                      # die *.workers.dev-URL notieren
```
Danach die URL in `StadtNews/Services/RemoteFeedService.swift` (`baseURL`)
eintragen. Der Worker übernimmt auch die Push-Auslösung (siehe oben);
Geocoding (Karte) bleibt on-device.

## Datenquelle
Presseportal-RSS von Polizei und Feuerwehr Gelsenkirchen (news aktuell GmbH),
der Presse-Newsfeed der Stadt Gelsenkirchen sowie amtliche Warnungen des
Bundesamts für Bevölkerungsschutz und Katastrophenhilfe (BBK) über die
NINA-API (`warnung.bund.de`). Alle Rechte an den Inhalten verbleiben bei den
jeweiligen Herausgebern.

## Roadmap
Geplante Aufgaben und Architektur-Notizen (u. a. das geplante Cloudflare-Backend)
stehen in [`TODO.md`](./TODO.md).
