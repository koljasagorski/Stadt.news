# Gelsenkirchen.news — To-do / Roadmap

Backlog für künftige Claude-Code-Sitzungen. Die App ist ein nativer SwiftUI-iOS-Client
(iOS 17+), der Polizeimeldungen aus dem Presseportal-RSS für **Gelsenkirchen** anzeigt.
Internes Xcode-Target heißt weiterhin `StadtNews`, Bundle-ID `news.stadt.app`.

> **Hinweis an Claude Code:** Vor Beginn einer Aufgabe diese Datei lesen, den passenden
> Punkt auswählen, nach Erledigung abhaken und committen. Änderungen build-sicher halten
> (die App muss jederzeit kompilieren). Es gibt kein macOS/Xcode in der Cloud-Umgebung →
> Swift-Code kann hier nicht gebaut/visuell getestet werden; das muss der Betreiber tun.

## Bereits erledigt (Baseline)
- [x] Feed (Gelsenkirchen), Pull-to-Refresh, Skeleton-/Fehlerzustände
- [x] Artikel-Detail mit Volltext (von der Artikelseite nachgeladen), Teilen, „Im Original lesen"
- [x] Karten-Ansicht (MapKit) mit Best-Effort-Geocoding aus Straßennamen (`CLGeocoder`, in `UserDefaults` gecacht)
- [x] Push: OneSignal-Wrapper (`PushService`, mit `#if canImport` build-sicher), Einstellungen-Schalter, Städte-Tags; GitHub-Actions-Poller (`scripts/news_push.py`)
- [x] Rebrand auf „Gelsenkirchen.news"; Onboarding entfernt; Einstellungen verschlankt
- [x] Lokaler Feed-Cache (Instant-Start, offline) — `FeedCache`, `Article: Codable`, in `NewsFeedViewModel` integriert
- [x] Karten-Straßenerkennung verbessert (Stadtteile + „Bahnhof"): Trefferquote im Test 6/15 → 12/15
- [x] Lesezeichen („Gemerkt") — `BookmarkStore`, Detail-Button, `BookmarksView`
- [x] Cloudflare-Worker (`worker/`) für Feed-Aggregation + `RemoteFeedService` mit RSS-Fallback (Phase-1-Code; Deploy offen)
- [x] `README.md` angelegt
- PRs: #1 (Push + Karte) gemergt; #3 (Rebrand + Folgearbeiten) offen

## Entscheidungen (getroffen)
- [x] Geocoding bleibt **on-device** (Worker macht kein Geocoding)
- [x] Push bleibt vorerst beim **GitHub-Poller** (Worker macht kein Push)
- [x] Worker-Sprache: **TypeScript**
- [x] API-Hosting: Start auf **`*.workers.dev`**
- [ ] Home-Screen-Name: „Gelsenkirchen.news" (wird evtl. abgeschnitten) oder „GE.news"? (noch offen)

---

## 1. Performance: lokaler Cache (Instant-Start) — ERLEDIGT
- [x] Letzten Feed lokal persistieren (JSON auf Disk) → `StadtNews/Services/FeedCache.swift`
- [x] Beim Start sofort den gecachten Stand zeigen, dann im Hintergrund aktualisieren → `NewsFeedViewModel`
- [x] `Article` um `Codable` erweitert
- Hinweis: In Xcode bauen/ausführen und prüfen, dass der Start jetzt sofort Inhalt zeigt (hier nicht testbar, kein Xcode).

## 2. Push scharfschalten (Betreiber-Setup, teils kein Code)
- [ ] OneSignal-Konto + App anlegen (App ID + REST API Key)
- [ ] Apple Developer Program; APNs-Schlüssel (.p8) erzeugen und in OneSignal hinterlegen
- [ ] OneSignal-SDK in Xcode hinzufügen (`https://github.com/OneSignal/OneSignal-iOS-SDK`, Produkt `OneSignalFramework`)
- [ ] `appID` in `StadtNews/Services/PushService.swift` eintragen
- [ ] Capabilities: Push Notifications + Background Modes → Remote notifications
- [ ] GitHub-Secrets: `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` (optional `ONESIGNAL_AUTH_SCHEME=Key`)
- [ ] Optional: Tippen auf Push öffnet den Artikel in der App (Deeplink) statt im Browser

## 3. Cloudflare-Backend (Aggregations- + Cache-Schicht)
Siehe ausführliches Konzept im Chatverlauf. Ziel: App liest einen schnellen, vorgebauten JSON-Endpunkt statt selbst N Feeds zu laden.
- [x] **Phase 1 (Code fertig, Deploy durch Betreiber offen):** Worker in `worker/` (`scheduled` + `fetch`) aggregiert die Quelle, schreibt nach KV, liefert `GET /v1/feed` (mit ETag/Cache-Control, Lazy-Build); App-seitig `RemoteFeedService` mit **RSS-Fallback**, in `NewsService.feed` eingehängt. Parsing gegen echten Feed mit Node geprüft.
  - Offen für Betreiber: `worker/` deployen (siehe README), KV-`id` in `wrangler.jsonc`, dann `baseURL` in `RemoteFeedService.swift` eintragen.
- [ ] **Phase 2:** Quellen-Adapter-Pattern (`id`/`fetch`/`normalize`) → neue Quellen rein serverseitig (siehe Punkt 4)
- [ ] **Phase 3:** (verworfen, falls Geocoding on-device bleibt) — sonst Geocoding in den Worker verlagern
- [ ] **Phase 4:** (optional) Push in den Worker integrieren; GitHub-Poller abschalten
- Beachten: Free-Tier = 50 externe Subrequests pro Aufruf → bei vielen Quellen begrenzen.
- Tooling: Wrangler, Worker-Code in `worker/`.

## 4. Weitere News-Quellen
- [ ] Quellen-Adapter-Schnittstelle definieren (am besten im Worker, Punkt 3 Phase 2)
- [ ] Einheitliches Artikel-Schema (id, source, title, summary, url, publishedAt, imageUrl, lat/lng, category)
- [ ] Kandidaten sammeln (lokale Medien, Feuerwehr, Stadt-Pressestellen …) und ToS prüfen
- Ziel: neue Quelle = Adapter ergänzen, **kein App-Update**.

## 5. Feature-Backlog (nach Nutzen)
- [~] **Bilder/Fotos** — geprüft: Polizei-Feeds enthalten praktisch keine Bilder (kein `enclosure`/`media:content`, nur vereinzelt `<img>`). Für diese Quelle nicht lohnend; **erst sinnvoll, wenn weitere Quellen mit Bildern dazukommen** (Punkt 4).
- [x] **Lesezeichen** („Gemerkt"): `BookmarkStore` (persistiert), Bookmark-Button in der Detailansicht, Liste (`BookmarksView`), Zugang per Symbol in der Feed-Leiste
- [ ] **Stichwort-/Stadtteil-Alarm** für Push (baut auf Poller/Worker auf)
- [ ] **Story-Format** (durch Top-Schlagzeilen swipen)
- [ ] **Vorlesen/Audio** (`AVSpeechSynthesizer`)
- [ ] **Home-Screen-Widget** (WidgetKit, neueste Schlagzeile)
- [ ] **Suche** im Feed
- [ ] **Gelesen/ungelesen** bzw. „neu seit letztem Besuch"
- [ ] **Tägliches Briefing** (eine Mitteilung „X Meldungen heute")

## 6. Qualität / App-Store-Reife
- [ ] **Tests** (aktuell keine): RSS-Parser, `Article`-Mapping, `String+HTML`, `DateParsing`, Straßen-Extraktion, Push-Tag-Logik
- [ ] Datenschutzerklärung + App-Privacy-Labels (Push/OneSignal sammelt Daten)
- [ ] App-Icon + Launchscreen
- [ ] Accessibility: Dynamic Type, VoiceOver-Labels prüfen
- [ ] Offline-Zustand sauber anzeigen (greift mit Punkt 1)

## 7. Karten-Heuristik verbessern
- [x] Mehr Muster: GE-Stadtteile + „Bahnhof" ergänzt (`IncidentMapModel.locationHint(in:)`); Trefferquote im Test 6/15 → 12/15
- [ ] Optional: Bundesstraßen/Autobahnen (`A/B \d`) — bewusst weggelassen wegen Fehltreffer-Risiko; nur mit Validierung ergänzen
- [ ] Fehltreffer weiter reduzieren; mittelfristig serverseitiges Geocoding (Punkt 3 Phase 3) bevorzugen
