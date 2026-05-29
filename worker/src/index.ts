/**
 * Gelsenkirchen.news aggregation worker.
 *
 * - `scheduled` (cron): fetches the configured RSS feeds, normalises them into
 *   a unified JSON feed and stores it in KV.
 * - `fetch`: serves the prebuilt feed at GET /v1/feed (builds lazily on the
 *   first request if KV is still empty).
 *
 * The article shape mirrors the iOS app's `Article` model so the client can
 * decode it directly. Geocoding stays on-device. Push notifications are sent
 * from the cron run via OneSignal (see pushNewArticles) and only fire once the
 * OneSignal credentials below are configured.
 *
 * Deploy (needs a Cloudflare account):
 *   cd worker && npm install
 *   npx wrangler login
 *   npx wrangler kv namespace create NEWS   # paste the id into wrangler.jsonc
 *   npx wrangler deploy                      # note the *.workers.dev URL
 * Then put that URL into the app's RemoteFeedService.baseURL.
 *
 * Push (optional; needs a OneSignal app with an Apple APNs key uploaded there):
 *   npx wrangler secret put ONESIGNAL_APP_ID
 *   npx wrangler secret put ONESIGNAL_REST_API_KEY
 *   # optional, default "Basic"; newer OneSignal keys use "Key":
 *   npx wrangler secret put ONESIGNAL_AUTH_SCHEME
 */

interface Env {
  NEWS: KVNamespace;
  ONESIGNAL_APP_ID?: string;
  ONESIGNAL_REST_API_KEY?: string;
  ONESIGNAL_AUTH_SCHEME?: string;
}

interface Source {
  cityID: string;
  cityName: string;
  source: string;
  /** Stable id used for per-source push tags (`src_<id>`) and client filtering. */
  sourceID: string;
  feedURL: string;
  format?: "rss" | "atom";
}

interface Article {
  id: string;
  title: string;
  summary: string;
  url: string;
  publishedAt?: string; // ISO 8601
  cityID: string;
  cityName: string;
  source: string;
  sourceID: string;
  /** Full article text, attached on the cron path when extractable. */
  body?: string[];
  contact?: string;
}

// Keep in sync with the app's City catalog.
const SOURCES: Source[] = [
  {
    cityID: "51056",
    cityName: "Gelsenkirchen",
    source: "Polizei Gelsenkirchen",
    sourceID: "polizei",
    feedURL: "https://www.presseportal.de/rss/dienststelle_51056.rss2",
  },
  {
    cityID: "51056",
    cityName: "Gelsenkirchen",
    source: "Feuerwehr Gelsenkirchen",
    sourceID: "feuerwehr",
    feedURL: "https://www.presseportal.de/rss/dienststelle_116260.rss2",
  },
  {
    cityID: "51056",
    cityName: "Gelsenkirchen",
    source: "Stadt Gelsenkirchen",
    sourceID: "stadt",
    feedURL:
      "https://www.gelsenkirchen.de/de/_funktionsnavigation/presse/pressemeldungen/newsfeed/bereich/4-presse",
    format: "atom",
  },
];

const FEED_KEY = "feed:v1";
const USER_AGENT = "Gelsenkirchen.news-worker/1.0 (+https://github.com/koljasagorski/stadt.news)";
const MAX_ARTICLES = 100;

const ONESIGNAL_API = "https://onesignal.com/api/v1/notifications";
const PUSH_FRESH_WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_PUSH_PER_RUN = 6;

// Full-text extraction: only fetch a few new article pages per cron run so we
// stay well under the Workers free-tier subrequest limit (50 per invocation);
// already-extracted bodies are reused from the previous feed.
const MAX_BODY_FETCHES_PER_RUN = 12;

// Official warnings (BBK NINA: aggregates MoWaS, KATWARN, DWD weather, flood …).
// The dashboard endpoint returns only currently active warnings for the region,
// so expired ones drop out automatically. 055130000000 = Gelsenkirchen (ARS).
const WARN_ARS = "055130000000";
const NINA_DASHBOARD = `https://warnung.bund.de/api31/dashboard/${WARN_ARS}.json`;
const ninaWarning = (id: string) => `https://warnung.bund.de/api31/warnings/${encodeURIComponent(id)}.json`;
const MAX_WARNING_DETAILS = 10;

export default {
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(refresh(env));
  },

  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/v1/feed") {
      let body = await env.NEWS.get(FEED_KEY);
      if (!body) {
        const feed = await rebuild(env);
        body = JSON.stringify(feed);
      }
      const etag = `"${hash(body)}"`;
      // Cloudflare's edge may rewrite the ETag to a weak one (W/"…") when it
      // compresses, so normalise the client's value before comparing.
      const ifNoneMatch = request.headers.get("If-None-Match")?.replace(/^W\//, "");
      if (ifNoneMatch === etag) {
        return new Response(null, { status: 304, headers: corsHeaders(etag) });
      }
      return new Response(body, { headers: corsHeaders(etag) });
    }

    return json({ error: "not found" }, 404);
  },
};

async function rebuild(
  env: Env,
  prevArticles?: Article[],
): Promise<{ version: number; updatedAt: string; articles: Article[] }> {
  const all: Article[] = [];
  for (const src of SOURCES) {
    try {
      const xml = await fetchText(src.feedURL);
      all.push(...parseFeed(xml, src));
    } catch (err) {
      console.log(`feed error for ${src.cityName}:`, err);
    }
  }
  all.push(...(await fetchWarnings()));

  // De-duplicate by id, then sort newest first.
  const seen = new Set<string>();
  const unique = all.filter((a) => (seen.has(a.id) ? false : (seen.add(a.id), true)));
  unique.sort((a, b) => (b.publishedAt ?? "").localeCompare(a.publishedAt ?? ""));

  const articles = unique.slice(0, MAX_ARTICLES);
  // Only on the cron path (prevArticles given): attach full article text,
  // reusing bodies already extracted in the previous feed.
  if (prevArticles) await enrichBodies(articles, prevArticles);

  const feed = {
    version: 1,
    updatedAt: new Date().toISOString(),
    articles,
  };
  await env.NEWS.put(FEED_KEY, JSON.stringify(feed));
  return feed;
}

/** Cron path: rebuild the feed and push notifications for newly added articles. */
async function refresh(env: Env): Promise<void> {
  const previousRaw = await env.NEWS.get(FEED_KEY);
  let previousArticles: Article[] = [];
  if (previousRaw) {
    try {
      previousArticles = (JSON.parse(previousRaw) as { articles: Article[] }).articles ?? [];
    } catch {
      previousArticles = [];
    }
  }
  const feed = await rebuild(env, previousArticles);
  await pushNewArticles(env, previousRaw, feed.articles);
}

// MARK: - Push (OneSignal)

/**
 * Sends a OneSignal push for each article that is new since the previous feed.
 * Runs as a no-op until ONESIGNAL_APP_ID + ONESIGNAL_REST_API_KEY are set, and
 * skips the very first run (no previous feed) so existing articles are never
 * blasted out. OneSignal targets only devices tagged for the article's city.
 */
async function pushNewArticles(env: Env, previousRaw: string | null, articles: Article[]): Promise<void> {
  const appId = (env.ONESIGNAL_APP_ID ?? "").trim();
  const apiKey = (env.ONESIGNAL_REST_API_KEY ?? "").trim();
  if (!appId || !apiKey) {
    console.log("push: dry run (OneSignal credentials not set)");
    return;
  }
  if (!previousRaw) {
    console.log("push: seeding run, nothing sent");
    return;
  }

  let previousIds: Set<string>;
  try {
    const prev = JSON.parse(previousRaw) as { articles: Article[] };
    previousIds = new Set(prev.articles.map((a) => a.id));
  } catch {
    return;
  }

  const now = Date.now();
  const fresh = articles.filter(
    (a) =>
      !previousIds.has(a.id) &&
      a.publishedAt !== undefined &&
      now - Date.parse(a.publishedAt) < PUSH_FRESH_WINDOW_MS,
  );

  const scheme = (env.ONESIGNAL_AUTH_SCHEME ?? "Basic").trim() || "Basic";
  for (const article of fresh.slice(0, MAX_PUSH_PER_RUN)) {
    await sendPush(appId, apiKey, scheme, article);
  }
}

async function sendPush(appId: string, apiKey: string, scheme: string, article: Article): Promise<void> {
  const payload = {
    app_id: appId,
    headings: { en: article.source, de: article.source },
    contents: { en: article.title, de: article.title },
    // Implicit AND between filters: only devices that follow this city *and*
    // have this source enabled (src_<id> = 1). The app sets these tags.
    filters: [
      { field: "tag", key: `city_${article.cityID}`, relation: "=", value: "1" },
      { field: "tag", key: `src_${article.sourceID}`, relation: "=", value: "1" },
    ],
    url: article.url,
    data: { city_id: article.cityID, article_url: article.url, source: article.source },
  };
  try {
    const res = await fetch(ONESIGNAL_API, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `${scheme} ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });
    const result = (await res.json()) as { id?: string; recipients?: number; errors?: unknown };
    if (result.errors) {
      console.log("push: OneSignal returned", JSON.stringify(result.errors));
    } else {
      console.log(`push: sent ${result.id ?? "?"} to ${result.recipients ?? "?"} recipients`);
    }
  } catch (err) {
    console.log("push: send failed", err);
  }
}

// MARK: - Fetching

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "application/rss+xml, application/xml;q=0.9",
    },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

// MARK: - Official warnings (BBK NINA)

interface DashboardItem {
  id?: string;
  i18nTitle?: Record<string, string>;
  sent?: string;
}

/**
 * Loads currently active official warnings for Gelsenkirchen and maps them to
 * articles (sourceID "warnung"), so they flow through the same feed, filter and
 * per-source push as everything else. The CAP description/instruction is shipped
 * as the article body, so the detail view works without an extra fetch.
 */
async function fetchWarnings(): Promise<Article[]> {
  let list: DashboardItem[];
  try {
    list = JSON.parse(await fetchText(NINA_DASHBOARD)) as DashboardItem[];
  } catch (err) {
    console.log("warnings: dashboard fetch failed", err);
    return [];
  }
  if (!Array.isArray(list) || list.length === 0) return [];

  const articles: Article[] = [];
  let budget = MAX_WARNING_DETAILS;

  for (const item of list) {
    if (!item?.id) continue;
    const title = pickGerman(item.i18nTitle) || "Amtliche Warnung";
    let summary = title;
    let body: string[] | undefined;
    let url = "https://warnung.bund.de/";
    let source = "Amtliche Warnung";
    let publishedAt = parseDate(item.sent ?? "");

    if (budget > 0) {
      budget--;
      try {
        const detail = JSON.parse(await fetchText(ninaWarning(item.id))) as {
          sent?: string;
          info?: Array<{ event?: string; description?: string; instruction?: string; web?: string }>;
        };
        const info = detail.info?.[0] ?? {};
        source = warningSource(item.id, info.event);
        const description = htmlToParagraphs(info.description ?? "");
        const instruction = htmlToParagraphs(info.instruction ?? "");
        body = [...description, ...instruction];
        if (description.length > 0) summary = description.join(" ").slice(0, 300);
        if (typeof info.web === "string" && /^https?:\/\//i.test(info.web)) url = info.web;
        if (detail.sent) publishedAt = parseDate(detail.sent);
      } catch (err) {
        console.log("warnings: detail fetch failed", item.id, err);
      }
    }

    articles.push({
      id: item.id,
      title,
      summary,
      url,
      publishedAt,
      cityID: "51056",
      cityName: "Gelsenkirchen",
      source,
      sourceID: "warnung",
      body: body && body.length > 0 ? body : undefined,
    });
  }
  return articles;
}

function pickGerman(i18n?: Record<string, string>): string {
  if (!i18n) return "";
  return i18n["de"] ?? Object.values(i18n)[0] ?? "";
}

/** A human label per warning channel; all contain "Warn" so the app maps them. */
function warningSource(id: string, event?: string): string {
  if (id.startsWith("dwd")) return "Wetterwarnung (DWD)";
  if (id.startsWith("lhp")) return "Hochwasserwarnung";
  if (id.startsWith("kat")) return "KATWARN-Warnung";
  if (event && /hochwasser/i.test(event)) return "Hochwasserwarnung";
  return "Amtliche Warnung";
}

// MARK: - Full-text extraction (mirrors the iOS ArticleHTMLExtractor)

/**
 * Attaches `body`/`contact` to the given articles. Bodies already extracted in
 * the previous feed are reused; only a few genuinely new Presseportal pages are
 * fetched per run (the city pages use a different layout and are left as teaser).
 */
async function enrichBodies(articles: Article[], prevArticles: Article[]): Promise<void> {
  const prevById = new Map(prevArticles.map((a) => [a.id, a]));
  let budget = MAX_BODY_FETCHES_PER_RUN;

  for (const article of articles) {
    // Warnings already carry their own body; city pages have no extractable one.
    if (!article.url.includes("presseportal.de")) continue;
    const prev = prevById.get(article.id);
    if (prev?.body && prev.body.length > 0) {
      article.body = prev.body;
      article.contact = prev.contact;
      continue;
    }
    if (budget <= 0) continue;
    budget--;
    try {
      const html = await fetchText(article.url);
      const extracted = extractArticle(html);
      if (extracted.body.length > 0) {
        article.body = extracted.body;
        if (extracted.contact) article.contact = extracted.contact;
      }
    } catch (err) {
      console.log("body fetch failed:", article.url, err);
    }
  }
}

function extractArticle(html: string): { body: string[]; contact?: string } {
  const len = html.length;
  const endMarkers = [
    "contact-headline", "mod-toggle", "Rückfragen bitte an",
    "Nachfragen für Journalist", "originator", "Original-Content von",
  ];

  // Body: between the "(ots)" dateline (after the story-city line) and the
  // contact/attribution block.
  let body: string[] = [];
  const city = html.indexOf("story-city");
  if (city >= 0) {
    const datelineEnd = html.indexOf("</p>", city);
    if (datelineEnd >= 0) {
      const bodyStart = datelineEnd + 4;
      let markerPos = len;
      for (const marker of endMarkers) {
        const pos = html.indexOf(marker, bodyStart);
        if (pos >= 0 && pos < markerPos) markerPos = pos;
      }
      let bodyEnd = html.lastIndexOf("<", markerPos - 1);
      if (bodyEnd < bodyStart) bodyEnd = markerPos;
      if (bodyStart < bodyEnd) body = htmlToParagraphs(html.slice(bodyStart, bodyEnd));
    }
  }

  // Contact: from the contact headline to the end of the attribution line.
  let contact: string | undefined;
  const headline = html.indexOf("contact-headline");
  if (headline >= 0) {
    let contactStart = html.lastIndexOf("<", headline - 1);
    if (contactStart < 0) contactStart = headline;
    let contactEnd = len;
    const originator = html.indexOf("originator", contactStart);
    const contactText = html.indexOf("contact-text", contactStart);
    if (originator >= 0) {
      const pEnd = html.indexOf("</p>", originator);
      if (pEnd >= 0) contactEnd = pEnd + 4;
    } else if (contactText >= 0) {
      const pEnd = html.indexOf("</p>", contactText);
      if (pEnd >= 0) contactEnd = pEnd + 4;
    } else {
      contactEnd = Math.min(len, contactStart + 1200);
    }
    if (contactStart < contactEnd) {
      const text = htmlToParagraphs(html.slice(contactStart, contactEnd)).join("\n");
      if (text) contact = text;
    }
  }

  return { body, contact };
}

/** Like htmlToText, but keeps paragraph breaks and returns one entry per line. */
function htmlToParagraphs(html: string): string[] {
  const text = decodeEntities(
    html
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/(p|div|li|ul|ol|h[1-6]|tr|table|blockquote)>/gi, "\n\n")
      .replace(/<li\b[^>]*>/gi, "• ")
      .replace(/<[^>]+>/g, ""),
  )
    .replace(/\r/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

// MARK: - RSS parsing

function parseFeed(xml: string, src: Source): Article[] {
  return src.format === "atom" ? parseAtom(xml, src) : parseRss(xml, src);
}

function parseRss(xml: string, src: Source): Article[] {
  const items = xml.match(/<item\b[\s\S]*?<\/item>/g) ?? [];
  const articles: Article[] = [];
  for (const item of items) {
    const link = field(item, "link") || field(item, "guid");
    const guid = field(item, "guid") || link;
    if (!link || !guid) continue;

    const title = stripPressCode(htmlToText(field(item, "title")));
    if (!title) continue;

    articles.push({
      id: guid,
      title,
      summary: stripDateline(htmlToText(field(item, "description"))),
      url: link,
      publishedAt: parseDate(field(item, "pubDate")),
      cityID: src.cityID,
      cityName: src.cityName,
      source: src.source,
      sourceID: src.sourceID,
    });
  }
  return articles;
}

function parseAtom(xml: string, src: Source): Article[] {
  const entries = xml.match(/<entry\b[\s\S]*?<\/entry>/g) ?? [];
  const articles: Article[] = [];
  for (const entry of entries) {
    const link = atomLink(entry) || field(entry, "id");
    const id = field(entry, "id") || link;
    if (!link || !id) continue;

    const title = stripPressCode(htmlToText(field(entry, "title")));
    if (!title) continue;

    const summary = stripDateline(htmlToText(field(entry, "summary") || field(entry, "content")));
    const published = parseDate(field(entry, "published") || field(entry, "updated"));

    articles.push({
      id,
      title,
      summary,
      url: link,
      publishedAt: published,
      cityID: src.cityID,
      cityName: src.cityName,
      source: src.source,
      sourceID: src.sourceID,
    });
  }
  return articles;
}

/** Atom: the article URL lives in a <link href="…"> attribute, not in text. */
function atomLink(block: string): string {
  const re = /<link\b([^>]*?)\/?>/gi;
  let match: RegExpExecArray | null;
  while ((match = re.exec(block))) {
    const rel = match[1].match(/\brel="([^"]*)"/)?.[1];
    const href = match[1].match(/\bhref="([^"]*)"/)?.[1];
    if (href && rel !== "self") return href;
  }
  return "";
}

function field(block: string, tag: string): string {
  const match = block.match(new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i"));
  if (!match) return "";
  let value = match[1].trim();
  const cdata = value.match(/^<!\[CDATA\[([\s\S]*?)\]\]>$/);
  if (cdata) value = cdata[1];
  return value.trim();
}

function parseDate(raw: string): string | undefined {
  if (!raw) return undefined;
  const date = new Date(raw);
  return isNaN(date.getTime()) ? undefined : date.toISOString();
}

// MARK: - Text helpers (mirror the iOS app)

function htmlToText(html: string): string {
  return decodeEntities(html.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function decodeEntities(text: string): string {
  const named: Record<string, string> = {
    "&amp;": "&",
    "&lt;": "<",
    "&gt;": ">",
    "&quot;": '"',
    "&apos;": "'",
    "&nbsp;": " ",
    "&hellip;": "…",
    "&ndash;": "–",
    "&mdash;": "—",
    "&euro;": "€",
    "&bdquo;": "„",
    "&ldquo;": "“",
    "&rdquo;": "”",
    "&laquo;": "«",
    "&raquo;": "»",
  };
  return text
    .replace(/&(amp|lt|gt|quot|apos|nbsp|hellip|ndash|mdash|euro|bdquo|ldquo|rdquo|laquo|raquo);/g, (m) => named[m])
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)));
}

/** Drops a leading press code like "POL-GE:". */
function stripPressCode(title: string): string {
  const cleaned = title.replace(/^[A-ZÄÖÜ0-9]{2,}(?:[ -][A-ZÄÖÜ0-9]+)*:\s*/, "").trim();
  return cleaned || title;
}

/** Drops a leading dateline like "Gelsenkirchen (ots) - " or the city's "GE. ". */
function stripDateline(summary: string): string {
  const s = summary.replace(/^GE\.\s+/, "");
  const index = s.indexOf("(ots)");
  if (index < 0 || index > 40) return s;
  const rest = s.slice(index + "(ots)".length).replace(/^[\s\-–:·]+/, "").trim();
  return rest || s;
}

// MARK: - HTTP helpers

function corsHeaders(etag?: string): HeadersInit {
  const headers: Record<string, string> = {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "public, max-age=60",
    "Access-Control-Allow-Origin": "*",
  };
  if (etag) headers["ETag"] = etag;
  return headers;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Access-Control-Allow-Origin": "*" },
  });
}

function hash(text: string): string {
  let h = 5381;
  for (let i = 0; i < text.length; i++) h = ((h << 5) + h + text.charCodeAt(i)) >>> 0;
  return h.toString(16);
}
