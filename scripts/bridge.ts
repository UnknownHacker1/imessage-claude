// iMessage as an app inside Composio: a small MCP server (Streamable HTTP, plain JSON replies).
// Runs on this Mac inside the "Claude iMessage" Terminal window (Terminal has Full Disk Access),
// and Composio reaches it through an ngrok tunnel. Only POST /<secret>/mcp is served, so the
// full URL (kept only in Composio) is the key.
import { Database } from "bun:sqlite";
import { existsSync, readdirSync, readFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";

const HOME = homedir();
const STATE = join(HOME, "imessage-claude", ".state");
const SECRET = readFileSync(join(STATE, "bridge.secret"), "utf8").trim();
const PORT = Number(process.env.BRIDGE_PORT || 8787);
const MCP_PATH = `/${SECRET}/mcp`;
const APPLE_EPOCH_MS = 978307200000;

const chatDb = new Database(join(HOME, "Library", "Messages", "chat.db"), { readonly: true });

// Newer macOS keeps message text in attributedBody (a typedstream) when `text` is null.
// Same decoding as Anthropic's iMessage plugin.
function parseAttributedBody(blob: Uint8Array | null): string | null {
  if (!blob) return null;
  const buf = Buffer.from(blob);
  let i = buf.indexOf("NSString");
  if (i < 0) return null;
  i += "NSString".length;
  while (i < buf.length && buf[i] !== 0x2b) i++;
  if (i >= buf.length) return null;
  i++;
  let len: number;
  const b = buf[i++];
  if (b === 0x81) { len = buf[i]; i += 1; }
  else if (b === 0x82) { len = buf.readUInt16LE(i); i += 2; }
  else if (b === 0x83) { len = buf.readUIntLE(i, 3); i += 3; }
  else { len = b; }
  if (i + len > buf.length) return null;
  return buf.toString("utf8", i, i + len);
}

// --- contacts -----------------------------------------------------------------
type Contact = { name: string; phones: string[]; emails: string[] };
const handleKey = (h: string) => (h.includes("@") ? h.trim().toLowerCase() : h.replace(/[^0-9]/g, "").slice(-10));
let contacts: Contact[] = [];
let byHandle = new Map<string, string>();
let loadedAt = 0;

function contactDbs(): string[] {
  const base = join(HOME, "Library", "Application Support", "AddressBook");
  const out: string[] = [];
  if (existsSync(join(base, "AddressBook-v22.abcddb"))) out.push(join(base, "AddressBook-v22.abcddb"));
  const sources = join(base, "Sources");
  if (existsSync(sources)) {
    for (const d of readdirSync(sources)) {
      const f = join(sources, d, "AddressBook-v22.abcddb");
      if (existsSync(f)) out.push(f);
    }
  }
  return out;
}

function loadContacts() {
  if (Date.now() - loadedAt < 10 * 60 * 1000) return;
  const map = new Map<string, Contact>();
  for (const f of contactDbs()) {
    try {
      const db = new Database(f, { readonly: true });
      const rows = db.query(`
        SELECT r.Z_PK AS id, TRIM(IFNULL(r.ZFIRSTNAME,'') || ' ' || IFNULL(r.ZLASTNAME,'')) AS name, r.ZORGANIZATION AS org,
               p.ZFULLNUMBER AS value, 'phone' AS kind
        FROM ZABCDRECORD r JOIN ZABCDPHONENUMBER p ON p.ZOWNER = r.Z_PK
        UNION ALL
        SELECT r.Z_PK, TRIM(IFNULL(r.ZFIRSTNAME,'') || ' ' || IFNULL(r.ZLASTNAME,'')), r.ZORGANIZATION, e.ZADDRESS, 'email'
        FROM ZABCDRECORD r JOIN ZABCDEMAILADDRESS e ON e.ZOWNER = r.Z_PK`).all() as any[];
      for (const r of rows) {
        const name = r.name || r.org;
        if (!name || !r.value) continue;
        const k = `${f}:${r.id}`;
        const c = map.get(k) ?? { name, phones: [], emails: [] };
        (r.kind === "phone" ? c.phones : c.emails).push(String(r.value));
        map.set(k, c);
      }
      db.close();
    } catch {}
  }
  contacts = [...map.values()];
  byHandle = new Map();
  for (const c of contacts) for (const h of [...c.phones, ...c.emails]) byHandle.set(handleKey(h), c.name);
  loadedAt = Date.now();
}

const who = (h: string | null) => {
  if (!h) return "unknown";
  loadContacts();
  const n = byHandle.get(handleKey(h));
  return n ? `${n} (${h})` : h;
};

function findContacts(q: string): Contact[] {
  loadContacts();
  const s = q.trim().toLowerCase();
  const k = handleKey(q);
  return contacts.filter(c =>
    c.name.toLowerCase().includes(s) ||
    (k.length >= 7 && [...c.phones, ...c.emails].some(h => handleKey(h) === k)));
}

// --- messages -------------------------------------------------------------------
type Row = { text: string | null; attributedBody: Uint8Array | null; date: number; is_from_me: number;
             handle: string | null; chat: string | null; group_name: string | null; style: number | null };

const SELECT = `
  SELECT m.text, m.attributedBody, m.date, m.is_from_me, h.id AS handle,
         c.chat_identifier AS chat, c.display_name AS group_name, c.style AS style
  FROM message m
  LEFT JOIN handle h ON h.ROWID = m.handle_id
  LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
  LEFT JOIN chat c ON c.ROWID = cmj.chat_id`;

const when = (ns: number) => {
  const d = new Date(ns / 1e6 + APPLE_EPOCH_MS);
  return d.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
};

function format(rows: Row[]): string {
  const lines: string[] = [];
  for (const r of rows) {
    const text = (r.text ?? parseAttributedBody(r.attributedBody) ?? "").trim();
    if (!text) continue;
    const group = r.style === 43 ? ` [group: ${r.group_name || r.chat}]` : "";
    const line = r.is_from_me
      ? `${when(r.date)} | me to ${r.style === 43 ? "the group" : who(r.chat)}${group}: ${text}`
      : `${when(r.date)} | from ${who(r.handle)}${group}: ${text}`;
    lines.push(line);
  }
  return lines.length ? lines.join("\n") : "No messages found.";
}

function recent(args: any): string {
  const limit = Math.min(Math.max(Number(args.limit) || 20, 1), 100);
  if (!args.contact) {
    return format(chatDb.query(`${SELECT} WHERE m.text IS NOT NULL OR m.attributedBody IS NOT NULL ORDER BY m.date DESC LIMIT ?`).all(limit) as Row[]);
  }
  const matches = findContacts(String(args.contact));
  const keys = new Set<string>([handleKey(String(args.contact)), ...matches.flatMap(c => [...c.phones, ...c.emails].map(handleKey))]);
  const rows = (chatDb.query(`${SELECT} WHERE m.text IS NOT NULL OR m.attributedBody IS NOT NULL ORDER BY m.date DESC LIMIT 3000`).all() as Row[])
    .filter(r => (r.handle && keys.has(handleKey(r.handle))) || (r.chat && keys.has(handleKey(r.chat))))
    .slice(0, limit);
  return format(rows);
}

function search(args: any): string {
  const q = String(args.query || "").trim();
  if (!q) throw new Error("query is required");
  const limit = Math.min(Math.max(Number(args.limit) || 20, 1), 100);
  const rows = chatDb.query(`${SELECT} WHERE m.text LIKE ? OR instr(m.attributedBody, CAST(? AS BLOB)) > 0 ORDER BY m.date DESC LIMIT ?`)
    .all(`%${q}%`, q, limit) as Row[];
  return format(rows);
}

function contactSearch(args: any): string {
  const q = String(args.query || "").trim();
  if (!q) throw new Error("query is required");
  const found = findContacts(q).slice(0, 20);
  if (!found.length) return `No contacts match "${q}".`;
  return found.map(c => `${c.name}: ${[...c.phones, ...c.emails].join(", ")}`).join("\n");
}

function osascript(lines: string[], argv: string[]): void {
  const cmd = ["osascript", ...lines.flatMap(l => ["-e", l]), ...argv];
  const r = Bun.spawnSync(cmd, { stdout: "pipe", stderr: "pipe" });
  if (r.exitCode !== 0) throw new Error(`Messages could not send: ${r.stderr.toString().trim() || "exit " + r.exitCode}`);
}

function send(args: any): string {
  const text = String(args.text || "");
  let to = String(args.to || "").trim();
  if (!text || !to) throw new Error("to and text are required");
  if (/^(iMessage|SMS|any);[-+];/.test(to)) {
    osascript(['on run argv', 'tell application "Messages" to send (item 1 of argv) to chat id (item 2 of argv)', 'end run'], [text, to]);
    return `Sent to chat ${to}.`;
  }
  const looksLikeAddress = to.includes("@") || to.replace(/[^0-9]/g, "").length >= 7;
  if (!looksLikeAddress) {
    const found = findContacts(to).filter(c => c.phones.length || c.emails.length);
    if (!found.length) throw new Error(`No contact named "${to}". Use contacts_search, or pass a phone number or email.`);
    if (found.length > 1) throw new Error(`Several contacts match "${to}": ${found.slice(0, 8).map(c => c.name).join(", ")}. Pass the exact phone number or email.`);
    to = found[0].phones[0] ?? found[0].emails[0];
  }
  osascript([
    'on run argv',
    'tell application "Messages"',
    'set svc to 1st account whose service type = iMessage',
    'send (item 1 of argv) to participant (item 2 of argv) of svc',
    'end tell',
    'end run',
  ], [text, to]);
  return `Sent to ${who(to)}.`;
}

// --- MCP --------------------------------------------------------------------------
const TOOLS = [
  {
    name: "imessage_recent_messages",
    description: "Read the most recent iMessages on the owner's Mac, newest first. Optionally only the conversation with one contact (name, phone number or email).",
    inputSchema: { type: "object", properties: {
      contact: { type: "string", description: "Optional contact name, phone number or email." },
      limit: { type: "number", description: "How many messages (1-100, default 20)." } } },
    run: recent,
  },
  {
    name: "imessage_search_messages",
    description: "Search the owner's iMessages for a word or phrase, newest first.",
    inputSchema: { type: "object", required: ["query"], properties: {
      query: { type: "string", description: "Text to look for." },
      limit: { type: "number", description: "How many results (1-100, default 20)." } } },
    run: search,
  },
  {
    name: "imessage_send",
    description: "Send an iMessage from the owner's Mac. `to` is a contact name, phone number, email, or a chat id. Confirm with the owner before sending.",
    inputSchema: { type: "object", required: ["to", "text"], properties: {
      to: { type: "string", description: "Contact name, phone number (+15551234567), email, or chat id." },
      text: { type: "string", description: "The message." } } },
    run: send,
  },
  {
    name: "contacts_search",
    description: "Find people in the owner's Mac Contacts by name, phone number or email. Returns their numbers and emails.",
    inputSchema: { type: "object", required: ["query"], properties: { query: { type: "string" } } },
    run: contactSearch,
  },
];

const ok = (id: any, result: any) => ({ jsonrpc: "2.0", id, result });
const fail = (id: any, code: number, message: string) => ({ jsonrpc: "2.0", id, error: { code, message } });

async function handle(msg: any) {
  if (!msg || msg.id === undefined || msg.id === null) return null; // notifications get no reply
  if (msg.method === "initialize" || msg.method === "tools/list") console.log(`${new Date().toISOString()} ${msg.method}`);
  switch (msg.method) {
    case "initialize":
      return ok(msg.id, {
        protocolVersion: msg.params?.protocolVersion ?? "2025-06-18",
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "imessage", version: "1.0.0" },
        instructions: "iMessage on the owner's Mac. Confirm with the owner before sending any message.",
      });
    case "ping":
      return ok(msg.id, {});
    case "tools/list":
      return ok(msg.id, { tools: TOOLS.map(({ run, ...t }) => t) });
    case "tools/call": {
      const tool = TOOLS.find(t => t.name === msg.params?.name);
      if (!tool) return fail(msg.id, -32602, `Unknown tool ${msg.params?.name}`);
      console.log(`${new Date().toISOString()} ${tool.name}`);
      try {
        return ok(msg.id, { content: [{ type: "text", text: tool.run(msg.params?.arguments ?? {}) }] });
      } catch (e: any) {
        return ok(msg.id, { content: [{ type: "text", text: `Error: ${e?.message ?? e}` }], isError: true });
      }
    }
    default:
      return fail(msg.id, -32601, `Method not found: ${msg.method}`);
  }
}

const json = (body: any, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Bun.serve({
  hostname: "127.0.0.1",
  port: PORT,
  async fetch(req) {
    const path = new URL(req.url).pathname;
    if (path === "/health") return new Response("ok");
    if (path !== MCP_PATH) return new Response("Not found", { status: 404 });
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: { Allow: "POST" } });
    let body: any;
    try { body = await req.json(); } catch { return json(fail(null, -32700, "Parse error"), 400); }
    if (Array.isArray(body)) {
      const out = (await Promise.all(body.map(handle))).filter(Boolean);
      return out.length ? json(out) : new Response(null, { status: 202 });
    }
    const out = await handle(body);
    return out ? json(out) : new Response(null, { status: 202 });
  },
});
console.log(`iMessage for Composio listening on 127.0.0.1:${PORT}`);
