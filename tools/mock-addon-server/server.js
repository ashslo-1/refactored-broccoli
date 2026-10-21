// Mock Stremio-shaped addon server for the Rokumio client.
//
// Minimal HTTP server (no dependencies) that stands in for a real addon server
// while M2 builds out the stores. Implements the client-facing surface the
// stores speak to: a host manifest, catalog + meta payloads, and health.
//
// Run directly:   node tools/mock-addon-server/server.js [-p 4141] [--host 0.0.0.0]
// Exercised by:   node tools/mock-addon-server/server.test.js (wired into npm test)
"use strict";

const fs = require("fs");
const http = require("http");
const path = require("path");

const manifest = {
    id: "stremio.rokumio.mock",
    version: "0.1.0",
    name: "Rokumio Mock Addon",
    catalogs: [
        { type: "movie", id: "top", name: "Top Movies" },
        { type: "movie", id: "trending", name: "Trending" },
        { type: "series", id: "top", name: "Top Series" },
    ],
    types: ["movie", "series"],
    resources: ["catalog", "meta", "stream", "subtitles"],
};

function sendJson(res, status, body) {
    const text = JSON.stringify(body);
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(text);
}

function catalogResponse(type, id) {
    return {
        metas: [
            { id: `mock:${type}:${id}:1`, type, name: `Mock ${id} One` },
            { id: `mock:${type}:${id}:2`, type, name: `Mock ${id} Two` },
        ],
    };
}

function metaResponse(type, id) {
    if (type === "series") {
        return {
            meta: {
                id: `mock:series:${id}`,
                type: "series",
                name: `Mock ${id} Series`,
                description: `A mock series about ${id}.`,
                releaseInfo: "2023",
                imdbRating: "8.1",
                poster: "https://images.metahub.space/poster/medium/img.png",
                background: "https://images.metahub.space/background/medium/img.png",
                videos: [
                    { id: `mock:series:${id}:s1:e1`, name: `${id} s1e1`, season: 1, episode: 1, runtime: 49 },
                    { id: `mock:series:${id}:s1:e2`, name: `${id} s1e2`, season: 1, episode: 2, runtime: 46 },
                    { id: `mock:series:${id}:s2:e1`, name: `${id} s2e1`, season: 2, episode: 1, runtime: 55 },
                ],
            },
        };
    }
    return {
        meta: {
            id: `mock:movie:${id}`,
            type: "movie",
            name: `Mock ${id} Movie`,
            description: `A mock movie about ${id}.`,
            releaseInfo: "2023",
            imdbRating: "8.6",
            poster: "https://images.metahub.space/poster/medium/img.png",
            background: "https://images.metahub.space/background/medium/img.png",
            runtime: 121,
        },
    };
}

function streamResponse(type, id) {
    const streams = [
        {
            name: "Mock\n4K",
            title: "Interstellar.2014.2160p.BluRay.REMUX.HEVC.DTS-HD.MA.5.1-FGT\n👤 412 💾 54.2 GB 🔗 RARBG",
            type: "torrent",
            infoHash: "6ae29a3a9bf8c1d5b123456789abcdef01234567",
            fileIdx: 1,
        },
        { name: "Mock Direct", url: "http://127.0.0.1:11470/mock/file.mp4" },
    ];
    if (type === "series") {
        streams.push({
            name: "Mock\n4k DV | HDR10+",
            title:
                "Breaking.Bad.S01.2008.2160P._Marjenbo\n" +
                "Breaking Bad  S01E01  Pilot.mkv\n" +
                "👤 113 💾 9.53 GB ⚙️ ThePirateBay\n" +
                "🇬🇧 / 🇷🇺 / 🇺🇦",
            type: "torrent",
            infoHash: "7a307b4f5a9b77e3a45e6f789abcdef01234567",
            fileIdx: 0,
        });
    }
    return { streams };
}

// Caption tracks for the playing video. The download URLs are built from the
// Host header of the request (the address the client used to reach this server),
// so the Roku can fetch the .srt bodies over the LAN instead of pointing at a
// fake https host that cannot be reached.
function subtitleResponse(type, id, host) {
    const base = host ? `http://${host}` : "http://mock.invalid";
    return {
        subtitles: [
            { id: "en", url: `${base}/subtitles/files/en.srt`, lang: "en", langName: "English" },
            { id: "es", url: `${base}/subtitles/files/es.srt`, lang: "es", langName: "Spanish" },
            { id: "de", url: `${base}/subtitles/files/de.srt`, lang: "de", langName: "German" },
        ],
    };
}

// The streaming server's own settings, the way the real server keeps them:
// a GET answers the current values, a POST merges what it is given into them
// and answers that it did. The merge is the part worth mirroring — the real
// server extends its configuration with the posted object, so writing the
// torrent limits leaves the rest of the configuration alone.
//
// The cacheSize option mirrors the real server's shape: selections carry the
// labels it displays, and its unlimited choice is Infinity — which
// JSON.stringify posts as null, exactly as the real server answers it.
const serverSettings = {
    values: {
        btMaxConnections: 55,
        btHandshakeTimeout: 20000,
        btRequestTimeout: 4000,
        btDownloadSpeedSoftLimit: 2621440,
        btDownloadSpeedHardLimit: 3670016,
        btMinPeersForStable: 5,
        cacheSize: 2147483648,
    },
};

function serverSettingsOptions() {
    return [
        {
            id: "cacheSize",
            label: "CACHING",
            type: "select",
            class: "caching",
            icon: true,
            selections: [
                { name: "no caching", val: 0 },
                { name: "2GB", val: 2147483648 },
                { name: "5GB", val: 5368709120 },
                { name: "10GB", val: 10737418240 },
                { name: "∞", val: Infinity },
            ],
        },
    ];
}

function createAddonServer() {
    const server = http.createServer((req, res) => {
        const pathname = new URL(req.url, "http://localhost").pathname;

        if (req.method === "GET" && pathname === "/health") {
            return sendJson(res, 200, { ok: true });
        }
        if (req.method === "GET" && pathname === "/settings") {
            return sendJson(res, 200, {
                options: serverSettingsOptions(),
                values: { ...serverSettings.values },
                baseUrl: `http://${req.headers.host}`,
            });
        }
        if (req.method === "POST" && pathname === "/settings") {
            let raw = "";
            req.on("data", (chunk) => {
                raw += chunk;
            });
            req.on("end", () => {
                let posted = null;
                try {
                    posted = JSON.parse(raw || "null");
                } catch (err) {
                    posted = null;
                }
                // A body that is not JSON is an empty object here, the same
                // way the real server's body-parser leaves it: the settings
                // are saved unchanged and the call still answers success.
                if (posted && typeof posted === "object" && !Array.isArray(posted)) {
                    Object.assign(serverSettings.values, posted);
                }
                return sendJson(res, 200, { success: true });
            });
            return;
        }
        if (req.method === "GET" && (pathname === "/" || pathname === "/manifest.json")) {
            return sendJson(res, 200, manifest);
        }

        const catalogMatch = pathname.match(/^\/catalog\/([^/]+)\/([^/]+)\/[\w=+%-]+\.json$/);
        if (req.method === "GET" && catalogMatch) {
            return sendJson(res, 200, catalogResponse(catalogMatch[1], catalogMatch[2]));
        }

        const metaMatch = pathname.match(/^\/meta\/([^/]+)\/([^/]+)\.json$/);
        if (req.method === "GET" && metaMatch) {
            return sendJson(res, 200, metaResponse(metaMatch[1], metaMatch[2]));
        }

        const streamMatch = pathname.match(/^\/stream\/([^/]+)\/([^/]+)\.json$/);
        if (req.method === "GET" && streamMatch) {
            return sendJson(res, 200, streamResponse(streamMatch[1], streamMatch[2]));
        }

        const subtitleMatch = pathname.match(/^\/subtitles\/([^/]+)\/([^/]+)\.json$/);
        if (req.method === "GET" && subtitleMatch) {
            return sendJson(res, 200, subtitleResponse(subtitleMatch[1], subtitleMatch[2], req.headers.host));
        }

        const subtitleFile = pathname.match(/^\/subtitles\/files\/([a-z]{2})\.srt$/);
        if (req.method === "GET" && subtitleFile) {
            const file = path.join(__dirname, "srt", subtitleFile[1] + ".srt");
            if (fs.existsSync(file)) {
                res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
                return res.end(fs.readFileSync(file));
            }
            return sendJson(res, 404, { error: "not found" });
        }

        sendJson(res, 404, { error: "not found" });
    });
    return server;
}

if (require.main === module) {
    const portIdx = process.argv.indexOf("-p");
    const hostIdx = process.argv.indexOf("--host");
    const port = Number(portIdx >= 0 ? process.argv[portIdx + 1] : 4141);
    const host = hostIdx >= 0 ? process.argv[hostIdx + 1] : "0.0.0.0";
    createAddonServer().listen(port, host, () => {
        console.log(`mock addon server on http://${host}:${port}`);
    });
}

module.exports = { createAddonServer, manifest };