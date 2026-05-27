# Gelsenkirchen.news

Native iOS-App (SwiftUI, iOS 17+), die offizielle Polizeimeldungen aus dem
Presseportal-„Blaulicht" für **Gelsenkirchen** bündelt — als schnell lesbarer,
redaktionell gestalteter Feed.

## Funktionen
- **Feed** der aktuellen Meldungen mit Pull-to-Refresh und Lade-/Fehlerzuständen
- **Lokaler Cache**: der zuletzt geladene Feed wird beim Start sofort gezeigt und im Hintergrund aktualisiert (auch offline lesbar)
- **Artikel-Detail** mit Volltext, der von der Original-Artikelseite nachgeladen wird; Teilen und „Im Original lesen"
- **Karten-Ansicht**: Meldungen mit erkennbarem Ort als Pins (Best-Effort-Geocoding aus Straßennamen/Stadtteilen)
- **Lesezeichen** („Gemerkt"): Meldungen speichern und in einer eigenen Liste wiederfinden
- **Push-Mitteilungen** bei neuen Meldungen (OneSignal + geplanter GitHub-Actions-Poller) — siehe Setup unten
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
scripts/          news_push.py (Feed-Poller für Push)
.github/workflows/news-push.yml (Zeitplan für den Poller)
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
6. GitHub-Secrets: `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`

Der Poller (`scripts/news_push.py`) läuft per GitHub Actions zeitgesteuert, prüft
den Feed und sendet für neue Meldungen eine Push über die OneSignal-REST-API.
Ohne Secrets läuft er als „Dry Run" (sendet nichts).

## Datenquelle
Presseportal-RSS der Polizei Gelsenkirchen (news aktuell GmbH). Alle Rechte an
den Inhalten verbleiben bei den jeweiligen Herausgebern.

## Roadmap
Geplante Aufgaben und Architektur-Notizen (u. a. das geplante Cloudflare-Backend)
stehen in [`TODO.md`](./TODO.md).
