/**
 * Gelsenkirchen.news aggregation worker.
 *
 * - `scheduled` (cron): fetches the configured RSS feeds, normalises them into
 *   a unified JSON feed and stores it in KV.
 * - `fetch`: serves the prebuilt feed at GET /v1/feed (builds lazily on the
 *   first request if KV is still empty).
 *
 * The article shape mirrors the iOS app's `Article` model so the client can
 * decode it directly. Geocoding and push are intentionally NOT done here
 * (geocoding stays on-device; push stays with the GitHub poller).
 *
 * Deploy (needs a Cloudflare account):
 *   cd worker && npm install
 *   npx wrangler login
 *   npx wrangler kv namespace create NEWS   # paste the id into wrangler.jsonc
 *   npx wrangler deploy                      # note the *.workers.dev URL
 * Then put that URL into the app's RemoteFeedService.baseURL.
 */

interface Env {
  NEWS: KVNamespace;
}

interface Source {
  cityID: string;
  cityName: string;
  source: string;
  feedURL: string;
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
}

// Keep in sync with the app's City catalog.
const SOURCES: Source[] = [
  {
    cityID: "51056",
    cityName: "Gelsenkirchen",
    source: "Polizei Gelsenkirchen",
    feedURL: "https://www.presseportal.de/rss/dienststelle_51056.rss2",
  },
  {
    cityID: "51056",
    cityName: "Gelsenkirchen",
    source: "Feuerwehr Gelsenkirchen",
    feedURL: "https://www.presseportal.de/rss/dienststelle_116260.rss2",
  },
];

const FEED_KEY = "feed:v1";
const USER_AGENT = "Gelsenkirchen.news-worker/1.0 (+https://github.com/koljasagorski/stadt.news)";
const MAX_ARTICLES = 100;

export default {
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(rebuild(env));
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
      if (request.headers.get("If-None-Match") === etag) {
        return new Response(null, { status: 304, headers: corsHeaders(etag) });
      }
      return new Response(body, { headers: corsHeaders(etag) });
    }

    return json({ error: "not found" }, 404);
  },
};

async function rebuild(env: Env): Promise<{ version: number; updatedAt: string; articles: Article[] }> {
  const all: Article[] = [];
  for (const src of SOURCES) {
    try {
      const xml = await fetchText(src.feedURL);
      all.push(...parseFeed(xml, src));
    } catch (err) {
      console.log(`feed error for ${src.cityName}:`, err);
    }
  }

  // De-duplicate by id, then sort newest first.
  const seen = new Set<string>();
  const unique = all.filter((a) => (seen.has(a.id) ? false : (seen.add(a.id), true)));
  unique.sort((a, b) => (b.publishedAt ?? "").localeCompare(a.publishedAt ?? ""));

  const feed = {
    version: 1,
    updatedAt: new Date().toISOString(),
    articles: unique.slice(0, MAX_ARTICLES),
  };
  await env.NEWS.put(FEED_KEY, JSON.stringify(feed));
  return feed;
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

// MARK: - RSS parsing

function parseFeed(xml: string, src: Source): Article[] {
  const items = xml.match(/<item\b[\s\S]*?<\/item>/g) ?? [];
  const articles: Article[] = [];
  for (const item of items) {
    const link = field(item, "link") || field(item, "guid");
    const guid = field(item, "guid") || link;
    if (!link || !guid) continue;

    const title = stripPressCode(htmlToText(field(item, "title")));
    if (!title) continue;

    const summary = stripDateline(htmlToText(field(item, "description")));
    const pubDate = field(item, "pubDate");
    const published = parseDate(pubDate);

    articles.push({
      id: guid,
      title,
      summary,
      url: link,
      publishedAt: published,
      cityID: src.cityID,
      cityName: src.cityName,
      source: src.source,
    });
  }
  return articles;
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
  };
  return text
    .replace(/&(amp|lt|gt|quot|apos|nbsp);/g, (m) => named[m])
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)));
}

/** Drops a leading press code like "POL-GE:". */
function stripPressCode(title: string): string {
  const cleaned = title.replace(/^[A-ZÄÖÜ0-9]{2,}(?:[ -][A-ZÄÖÜ0-9]+)*:\s*/, "").trim();
  return cleaned || title;
}

/** Drops a leading dateline like "Gelsenkirchen (ots) - ". */
function stripDateline(summary: string): string {
  const index = summary.indexOf("(ots)");
  if (index < 0 || index > 40) return summary;
  const rest = summary.slice(index + "(ots)".length).replace(/^[\s\-–:·]+/, "").trim();
  return rest || summary;
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
