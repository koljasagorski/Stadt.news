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
- PRs: #1 (Push + Karte) gemergt; #3 (Rebrand) offen

## Offene Entscheidungen (vor Umsetzung klären)
- [ ] Geocoding serverseitig: Nominatim (gratis, ToS/Rate-Limit) vs. weiter on-device vs. bezahlt (Mapbox/Google)?
- [ ] Push in den Cloudflare-Worker migrieren oder GitHub-Poller behalten?
- [ ] Worker-Sprache: TypeScript ok?
- [ ] API-Hosting: `*.workers.dev` zum Start oder eigene Domain?
- [ ] Home-Screen-Name: „Gelsenkirchen.news" (wird evtl. abgeschnitten) oder „GE.news"?

---

## 1. Performance: lokaler Cache (Instant-Start) — HÖCHSTE PRIORITÄT
Problem: Der Feed wird beim Start kalt übers Netz geladen/geparst; es gibt keinen Cache → der Start fühlt sich langsam an.
- [ ] Letzten Feed lokal persistieren (JSON auf Disk oder `UserDefaults`)
- [ ] Beim Start sofort den gecachten Stand zeigen, dann im Hintergrund aktualisieren
- [ ] `Article` um `Codable` erweitern (für Persistenz)
- Dateien: `StadtNews/ViewModels/NewsFeedViewModel.swift`, `StadtNews/Services/NewsService.swift` (oder neuer `FeedCache`), `StadtNews/Models/Article.swift`
- Fertig, wenn: Neustart die letzten Meldungen sofort zeigt und danach aktualisiert (auch offline nutzbar).

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
- [ ] **Phase 1:** Worker (`scheduled` + `fetch`) aggregiert die aktuelle Quelle, schreibt Feed nach KV, liefert `GET /v1/feed`; App-seitig `RemoteFeedService` mit **RSS-Fallback** + Edge-Cache/ETag
- [ ] **Phase 2:** Quellen-Adapter-Pattern (`id`/`fetch`/`normalize`) → neue Quellen rein serverseitig (siehe Punkt 4)
- [ ] **Phase 3:** Geocoding in den Worker verlagern (Koordinaten in KV cachen); Karte liest `lat/lng` aus der API
- [ ] **Phase 4:** Push in den Worker integrieren; GitHub-Poller abschalten
- Beachten: Free-Tier = 50 externe Subrequests pro Aufruf → Geocoding cachen, pro Lauf begrenzen.
- Tooling: Wrangler, Worker-Code in `worker/`, Secrets via `wrangler secret put`.

## 4. Weitere News-Quellen
- [ ] Quellen-Adapter-Schnittstelle definieren (am besten im Worker, Punkt 3 Phase 2)
- [ ] Einheitliches Artikel-Schema (id, source, title, summary, url, publishedAt, imageUrl, lat/lng, category)
- [ ] Kandidaten sammeln (lokale Medien, Feuerwehr, Stadt-Pressestellen …) und ToS prüfen
- Ziel: neue Quelle = Adapter ergänzen, **kein App-Update**.

## 5. Feature-Backlog (nach Nutzen)
- [ ] **Bilder/Fotos** im Feed und Artikelkopf (RSS-Enclosure/`og:image`; `AsyncImage`)
- [ ] **Lesezeichen** („Gemerkt"): `Article` als `Codable` persistieren, Liste, Bookmark-Button in Detail/Reihe
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
- Aktuell bekommen ~28 % der Meldungen einen präzisen Pin (Straßennamen-Erkennung in `IncidentMapModel.street(in:)`).
- [ ] Mehr Muster: Stadtteile (GE-spezifische Liste), Bundesstraßen (`B\d+`), markante Orte (Bahnhof, Plätze)
- [ ] Fehltreffer weiter reduzieren; ggf. serverseitiges Geocoding (Punkt 3 Phase 3) bevorzugen
