#!/usr/bin/env node
// stremio-repair — log in to a Stremio account and rewrite its addon
// collection into the official wire shape (addonCollectionSet).
//
// Why this exists: an experiment hit the legacy /api/addonCollectionPut
// endpoint (answers HTTP 200 with {}) with a live authKey and left the
// account's collection in a state modern Stremio apps cannot parse cleanly
// (app-wide add-on fetch errors). The official client (stremio-core) pushes
// the collection through POST /api/addonCollectionSet with entries of exactly
// {manifest, transportUrl, flags:{official, protected}} — extras dropped,
// deduped by transportUrl. This tool rebuilds THAT from whatever the account's
// addonCollectionGet currently returns.
//
// Usage:
//   node tools/stremio-repair.js --email you@example.com            # prompts for the password, DRY RUN
//   node tools/stremio-repair.js --email you@example.com --confirm  # actually writes
//   node tools/stremio-repair.js --auth-key sk_...                  # skip login, use a saved authKey
//
// The password can come from the STREMIO_PASSWORD env var or an interactive
// prompt; prefer the prompt — the terminal history does not log it.
//
// Default is a dry run: it logs in, dumps the current collection, prints what
// it WOULD push, and writes nothing. --confirm performs the set and re-reads
// the collection to verify.
"use strict";

const fs = require("fs");
const path = require("path");
const readline = require("readline");

const API = "https://api.strem.io/api/";

async function api(endpoint, body) {
    const res = await fetch(API + endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch { /* leave null */ }
    return { status: res.status, json, text };
}

function isOkEnvelope(json) {
    return json !== null && typeof json === "object" && json.error === undefined && json.result !== undefined;
}

function normalize(addons) {
    const out = [];
    const seen = new Set();
    for (const addon of addons || []) {
        if (!addon || typeof addon !== "object") continue;
        const manifest = addon.manifest;
        if (!manifest || typeof manifest !== "object" || typeof manifest.id !== "string" || manifest.id === "") continue;
        if (typeof addon.transportUrl !== "string" || addon.transportUrl === "") continue;
        if (seen.has(addon.transportUrl)) continue;
        seen.add(addon.transportUrl);
        const flags = addon.flags && typeof addon.flags === "object" ? addon.flags : {};
        out.push({
            manifest,
            transportUrl: addon.transportUrl,
            flags: { official: flags.official === true, protected: flags.protected === true },
        });
    }
    return out;
}

function summarize(entry, i) {
    const m = entry.manifest;
    const flag = entry.flags.official ? "official" : entry.flags.protected ? "protected" : "user";
    return `  ${String(i + 1).padStart(3)}. ${m.id}  "${m.name || "?"}"  v${m.version || "?"}  [${flag}]  ${entry.transportUrl.slice(0, 72)}`;
}

async function ask(question, silent) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    if (!silent) {
        return new Promise(resolve => rl.question(question, answer => { rl.close(); resolve(answer); }));
    }
    // Mute the echo for passwords by writing the prompt now and taking the
    // answer later; readline cannot suppress echo portably, so the password
    // lands on an empty line.
    process.stdout.write(question);
    return new Promise(resolve => rl.question("", answer => { rl.close(); resolve(answer); }));
}

async function main() {
    const args = process.argv.slice(2);
    const confirm = args.includes("--confirm");
    const emailIdx = args.indexOf("--email");
    const keyIdx = args.indexOf("--auth-key");

    let authKey = null;
    if (keyIdx !== -1 && args[keyIdx + 1]) {
        authKey = args[keyIdx + 1];
        console.log("Using the provided authKey (no login performed).");
    } else {
        const email = emailIdx !== -1 ? args[emailIdx + 1] : await ask("Stremio email: ");
        if (!email || !email.includes("@")) { console.error("no email given"); process.exit(1); }
        let password = process.env.STREMIO_PASSWORD || "";
        if (!password) password = await ask("Stremio password (input is visible; prefer the STREMIO_PASSWORD env var if your terminal history is untrusted): ");
        if (!password) { console.error("no password given"); process.exit(1); }

        const login = await api("login", { type: "Login", email, password, facebook: false });
        if (!isOkEnvelope(login.json) || !login.json.result.authKey) {
            console.error("login failed: HTTP", login.status, login.text.slice(0, 300));
            process.exit(1);
        }
        authKey = login.json.result.authKey;
        console.log("login ok — account:", (login.json.result.user && login.json.result.user.email) || "(email unknown)");
    }

    // 1. Read the collection as the account holds it right now.
    const before = await api("addonCollectionGet", { type: "AddonCollectionGet", authKey, update: true });
    if (!isOkEnvelope(before.json) || !Array.isArray(before.json.result.addons)) {
        console.error("addonCollectionGet failed: HTTP", before.status, before.text.slice(0, 300));
        process.exit(1);
    }
    const rawAddons = before.json.result.addons;
    const dumpPath = path.join(__dirname, "..", `stremio-collection-raw-${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
    fs.writeFileSync(dumpPath, JSON.stringify(before.json.result, null, 2));
    console.log(`current collection: ${rawAddons.length} raw entr(y|ies) — full dump written to ${path.basename(dumpPath)}`);
    rawAddons.forEach((a, i) => {
        const id = a && a.manifest && a.manifest.id;
        const url = a && a.transportUrl;
        const extras = a ? Object.keys(a).filter(k => k !== "manifest" && k !== "transportUrl" && k !== "flags").join(",") : "";
        console.log(`  raw ${i + 1}. ${id || "?"}  extras:[${extras}]  ${String(url || "?").slice(0, 60)}`);
    });

    // 2. Build the official-shape payload.
    const payload = normalize(rawAddons);
    console.log(`normalized payload: ${payload.length} entr(y|ies)`);
    payload.forEach((entry, i) => console.log(summarize(entry, i)));

    if (!confirm) {
        console.log("\nDRY RUN — nothing written. Re-run with --confirm to push this collection.");
        console.log("POST /api/addonCollectionSet { type: \"AddonCollectionSet\", authKey: <redacted>, addons: <the list above> }");
        return;
    }

    // 3. Write it.
    const set = await api("addonCollectionSet", { type: "AddonCollectionSet", authKey, addons: payload });
    console.log("\naddonCollectionSet answered:", set.text.slice(0, 300));
    if (!(set.json && set.json.result && set.json.result.success === true)) {
        console.error("the set did not report success — NOTHING further attempted.");
        process.exit(1);
    }

    // 4. Verify by reading back and diffing ids.
    const after = await api("addonCollectionGet", { type: "AddonCollectionGet", authKey, update: true });
    if (!isOkEnvelope(after.json) || !Array.isArray(after.json.result.addons)) {
        console.error("verification get failed:", after.text.slice(0, 200));
        process.exit(1);
    }
    const beforeIds = payload.map(e => e.manifest.id).sort().join("|");
    const afterIds = after.json.result.addons.map(a => a && a.manifest && a.manifest.id).filter(Boolean).sort().join("|");
    console.log(`verification: pushed ids == read-back ids: ${beforeIds === afterIds ? "YES" : `NO\n  pushed: ${beforeIds}\n  read:   ${afterIds}`}`);
    console.log(`read-back: ${after.json.result.addons.length} entries`);
    if (beforeIds === afterIds) console.log("DONE — the collection now matches the official wire shape. Open a Stremio app and confirm it catalogs normally.");
}

main().catch(err => { console.error("unexpected failure:", err && err.message); process.exit(1); });
