/**
 * macOS TTS — speaks assistant text with `say`.
 *
 * - Auto TTS: off by default, or pass `--tts-enable` (e.g. in `pi-args`) to start with auto TTS on;
 *   `/tts-toggle` (on | off | no args to toggle) still applies for the session after startup/reload.
 * - Streaming: when auto TTS is on, each completed sentence is queued and spoken as soon as it
 *   arrives during assistant streaming, instead of waiting for the full reply.
 * - Manual: `/say` speaks the last assistant reply in the session; `/say-stop-speaking` halts it.
 * - Replaces URLs with "URL redacted"; strips Markdown `*` and `#` so `say` does not read them aloud.
 * - Only runs when `ctx.hasUI` (interactive TUI) on macOS.
 * - Speech rate: `say -r` (words per minute), see SAY_RATE_WPM.
 * - A new user prompt, `/say-stop-speaking`, or pi exiting all cancel in-flight speech.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { type ChildProcess, spawn } from "node:child_process";

const URL_REDACTED = "URL redacted";
const MAX_CHARS = 32_000;
/** Words per minute for `say -r` */
const SAY_RATE_WPM = 335;
/** Minimum cleaned characters before a sentence is flushed to the queue. Shorter fragments
 *  wait for more text so `say` does not stutter on one-word utterances like "Ok.". */
const MIN_SENTENCE_CHARS = 12;

/** In-memory; initialized from `--tts-enable` on startup/reload, then `/tts-toggle` */
let autoTtsEnabled = false;

let currentSay: ChildProcess | null = null;
const speechQueue: string[] = [];
let speaking = false;

/** Per-contentIndex buffers of streamed text not yet flushed as a sentence */
const pendingByIndex = new Map<number, string>();
/** Per-contentIndex accumulators of completed-but-too-short sentences, prepended to the
 *  next full-length sentence so `say` speaks a longer coherent chunk instead of stuttering
 *  on one-word fragments. */
const shortPrefixByIndex = new Map<number, string>();
/** Set when streaming has already produced at least one spoken sentence for the current
 *  turn so the `agent_end` fallback does not re-speak the whole reply. */
let streamedThisTurn = false;
/** True once exit/signal handlers have been installed (only once per process). */
let exitHandlersInstalled = false;

function stopSay(): void {
	const c = currentSay;
	if (!c) return;
	currentSay = null;
	try {
		c.stdin?.destroy();
		c.kill("SIGTERM");
	} catch {
		/* ignore — process may already be dead */
	}
}

function resetSpeechState(): void {
	speechQueue.length = 0;
	pendingByIndex.clear();
	shortPrefixByIndex.clear();
	streamedThisTurn = false;
	speaking = false;
	stopSay();
}

/** http(s) URLs and bare www.… tokens */
function redactUrlsForSpeech(text: string): string {
	let s = text.replace(/https?:\/\/\S+/gi, URL_REDACTED);
	s = s.replace(/\bwww\.\S+/gi, URL_REDACTED);
	return s.replace(/\s+/g, " ").trim();
}

/** Remove common Markdown markers the speech synthesizer would speak literally */
function stripMarkdownForSpeech(text: string): string {
	return text.replace(/[*#]/g, "").replace(/\s+/g, " ").trim();
}

type ContentPart = { type: string; text?: string };

function assistantToSpeechText(msg: Record<string, unknown>): string | null {
	if (msg.role !== "assistant" || !Array.isArray(msg.content)) return null;

	const sr = msg.stopReason;
	if (sr === "error" || sr === "aborted") return null;

	const chunks: string[] = [];
	for (const part of msg.content as ContentPart[]) {
		if (part.type === "text" && typeof part.text === "string") chunks.push(part.text);
	}
	const raw = chunks.join("");
	const cleaned = stripMarkdownForSpeech(redactUrlsForSpeech(raw));
	if (cleaned.length === 0) return null;
	return cleaned.length > MAX_CHARS ? cleaned.slice(0, MAX_CHARS) : cleaned;
}

function getLastAssistantSpeechText(messages: unknown[]): string | null {
	for (let i = messages.length - 1; i >= 0; i--) {
		const text = assistantToSpeechText(messages[i] as Record<string, unknown>);
		if (text !== null) return text;
	}
	return null;
}

function getLastAssistantSpeechTextFromSession(entries: unknown[]): string | null {
	for (let i = entries.length - 1; i >= 0; i--) {
		const e = entries[i] as { type?: string; message?: unknown };
		if (e.type !== "message" || e.message === undefined) continue;
		const text = assistantToSpeechText(e.message as Record<string, unknown>);
		if (text !== null) return text;
	}
	return null;
}

/** Split a buffer into complete sentences + the remainder.
 *  Sentence boundaries: `.`, `!`, `?`, `…`, or a newline, optionally followed by closing
 *  quotes/brackets, terminated by whitespace or end-of-string. */
const SENTENCE_END = /([.!?…]+["')\]]*)(?=\s|$)|\n+/g;
function extractSentences(buf: string): { sentences: string[]; rest: string } {
	const sentences: string[] = [];
	let last = 0;
	SENTENCE_END.lastIndex = 0;
	let m: RegExpExecArray | null = SENTENCE_END.exec(buf);
	while (m !== null) {
		const end = m.index + m[0].length;
		const chunk = buf.slice(last, end).trim();
		if (chunk.length > 0) sentences.push(chunk);
		last = end;
		m = SENTENCE_END.exec(buf);
	}
	return { sentences, rest: buf.slice(last) };
}

function enqueueSpeech(text: string): void {
	const cleaned = stripMarkdownForSpeech(redactUrlsForSpeech(text));
	if (!cleaned) return;
	const capped = cleaned.length > MAX_CHARS ? cleaned.slice(0, MAX_CHARS) : cleaned;
	speechQueue.push(capped);
	drainQueue();
}

function drainQueue(): void {
	if (speaking) return;
	if (process.platform !== "darwin" || !autoTtsEnabled) {
		speechQueue.length = 0;
		return;
	}
	const next = speechQueue.shift();
	if (next === undefined) return;

	speaking = true;
	const child = spawn("say", ["-r", String(SAY_RATE_WPM)], {
		stdio: ["pipe", "ignore", "ignore"],
	});
	currentSay = child;

	const done = (): void => {
		if (currentSay === child) currentSay = null;
		speaking = false;
		drainQueue();
	};
	child.on("exit", done);
	child.on("error", done);

	child.stdin.write(next, "utf8");
	child.stdin.end();
	// Intentionally no child.unref(): we want node to wait on `say` during normal flow,
	// and exit handlers below guarantee the child is killed when pi itself exits.
}

/** Speak a full block of text by splitting it into sentences and queuing them.
 *  Used by the manual `/say` command and the `agent_end` fallback. */
function speakBlock(text: string): void {
	const { sentences, rest } = extractSentences(text);
	for (const s of sentences) enqueueSpeech(s);
	if (rest.trim()) enqueueSpeech(rest);
}

function installExitHandlers(): void {
	if (exitHandlersInstalled) return;
	exitHandlersInstalled = true;

	const killOnExit = (): void => {
		const c = currentSay;
		if (!c) return;
		currentSay = null;
		try {
			c.kill("SIGTERM");
		} catch {
			/* ignore */
		}
	};

	process.once("exit", killOnExit);
	for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"] as const) {
		process.once(sig, () => {
			killOnExit();
		});
	}
}

export default function (pi: ExtensionAPI) {
	installExitHandlers();

	pi.registerFlag("tts-enable", {
		type: "boolean",
		default: false,
		description: "Enable automatic TTS after each assistant reply (macOS say)",
	});

	pi.on("session_start", async (event) => {
		if (event.reason !== "startup" && event.reason !== "reload") return;
		autoTtsEnabled = pi.getFlag("tts-enable") === true;
	});

	pi.on("before_agent_start", async () => {
		resetSpeechState();
	});

	pi.on("message_update", async (event) => {
		if (process.platform !== "darwin" || !autoTtsEnabled) return;
		const e = event.assistantMessageEvent;
		if (e.type === "text_delta") {
			const prev = pendingByIndex.get(e.contentIndex) ?? "";
			const next = prev + e.delta;
			const { sentences, rest } = extractSentences(next);
			pendingByIndex.set(e.contentIndex, rest);
			for (const s of sentences) {
				const prefix = shortPrefixByIndex.get(e.contentIndex) ?? "";
				const combined = prefix ? `${prefix} ${s}` : s;
				const cleaned = stripMarkdownForSpeech(redactUrlsForSpeech(combined));
				if (cleaned.length < MIN_SENTENCE_CHARS) {
					shortPrefixByIndex.set(e.contentIndex, combined);
					continue;
				}
				shortPrefixByIndex.delete(e.contentIndex);
				streamedThisTurn = true;
				enqueueSpeech(combined);
			}
		} else if (e.type === "text_end") {
			const tail = pendingByIndex.get(e.contentIndex) ?? "";
			const prefix = shortPrefixByIndex.get(e.contentIndex) ?? "";
			pendingByIndex.delete(e.contentIndex);
			shortPrefixByIndex.delete(e.contentIndex);
			const flush = [prefix, tail].filter((s) => s.trim()).join(" ").trim();
			if (flush) {
				streamedThisTurn = true;
				enqueueSpeech(flush);
			}
		}
	});

	pi.on("message_end", async (event) => {
		const msg = event.message as Record<string, unknown> | undefined;
		const sr = msg?.stopReason;
		if (sr === "error" || sr === "aborted") {
			resetSpeechState();
			return;
		}
		const indexes = new Set<number>([...pendingByIndex.keys(), ...shortPrefixByIndex.keys()]);
		for (const idx of indexes) {
			const tail = pendingByIndex.get(idx) ?? "";
			const prefix = shortPrefixByIndex.get(idx) ?? "";
			pendingByIndex.delete(idx);
			shortPrefixByIndex.delete(idx);
			const flush = [prefix, tail].filter((s) => s.trim()).join(" ").trim();
			if (flush) {
				streamedThisTurn = true;
				enqueueSpeech(flush);
			}
		}
	});

	pi.on("agent_end", async (event, ctx) => {
		if (process.platform !== "darwin" || !ctx.hasUI || !autoTtsEnabled) {
			streamedThisTurn = false;
			return;
		}
		if (streamedThisTurn) {
			streamedThisTurn = false;
			return;
		}

		const text = getLastAssistantSpeechText(event.messages);
		if (text === null) return;
		speakBlock(text);
	});

	pi.on("session_shutdown", async () => {
		resetSpeechState();
	});

	pi.registerCommand("tts-toggle", {
		description: "Toggle or set auto TTS after each reply (on | off | empty to toggle)",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) return;

			const a = args.trim().toLowerCase();

			if (a === "") {
				autoTtsEnabled = !autoTtsEnabled;
			} else if (a === "on") {
				autoTtsEnabled = true;
			} else if (a === "off") {
				autoTtsEnabled = false;
			} else {
				ctx.ui.notify('Usage: /tts-toggle [on|off] — omit args to toggle', "warning");
				return;
			}

			if (!autoTtsEnabled) resetSpeechState();

			ctx.ui.notify(`Auto TTS: ${autoTtsEnabled ? "on" : "off"}`, "info");
		},
	});

	pi.registerCommand("say", {
		description: "Speak the last assistant reply (macOS say)",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			if (process.platform !== "darwin") {
				ctx.ui.notify("TTS is only available on macOS", "warning");
				return;
			}

			const text = getLastAssistantSpeechTextFromSession(ctx.sessionManager.getEntries() as unknown[]);
			if (text === null) {
				ctx.ui.notify("No assistant message to speak yet", "info");
				return;
			}

			// Manual replay: ensure nothing is already queued/playing so sentences do not
			// overlap with a stream still flushing from the previous turn. This also needs
			// autoTtsEnabled so the queue actually drains; temporarily flip it on if needed.
			resetSpeechState();
			const wasEnabled = autoTtsEnabled;
			autoTtsEnabled = true;
			try {
				speakBlock(text);
			} finally {
				autoTtsEnabled = wasEnabled;
			}
		},
	});

	pi.registerCommand("say-stop-speaking", {
		description: "Stop any in-flight macOS `say` speech and clear the TTS queue",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			const hadSomething = currentSay !== null || speechQueue.length > 0;
			resetSpeechState();
			ctx.ui.notify(hadSomething ? "Stopped speaking" : "Nothing to stop", "info");
		},
	});
}
