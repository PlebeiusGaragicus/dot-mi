/**
 * macOS TTS — speaks assistant text with `say`.
 *
 * - Auto TTS: off by default, or pass `--tts-enable` (e.g. in `pi-args`) to start with auto TTS on;
 *   `/tts-toggle` (on | off | no args to toggle) still applies for the session after startup/reload.
 * - Manual: `/say` speaks the last assistant reply in the session.
 * - Replaces URLs with "URL redacted"; strips Markdown `*` and `#` so `say` does not read them aloud.
 * - Only runs when `ctx.hasUI` (interactive TUI).
 * - Speech rate: `say -r` (words per minute), see SAY_RATE_WPM.
 * - A new utterance or a new user prompt cancels any in-flight `say` (no overlapping speech).
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { type ChildProcess, spawn } from "node:child_process";

const URL_REDACTED = "URL redacted";
const MAX_CHARS = 32_000;
/** Words per minute for `say -r` */
const SAY_RATE_WPM = 320;

/** In-memory; initialized from `--tts-enable` on startup/reload, then `/tts-toggle` */
let autoTtsEnabled = false;

let currentSay: ChildProcess | null = null;

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

function speakDarwin(text: string): void {
	stopSay();

	const args: string[] = ["-r", String(SAY_RATE_WPM)];
	const child = spawn("say", args, {
		stdio: ["pipe", "ignore", "ignore"],
	});
	currentSay = child;

	const clearIfCurrent = (): void => {
		if (currentSay === child) currentSay = null;
	};
	child.on("exit", clearIfCurrent);
	child.on("error", clearIfCurrent);

	child.stdin.write(text, "utf8");
	child.stdin.end();
	child.unref();
}

export default function (pi: ExtensionAPI) {
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
		stopSay();
	});

	pi.on("agent_end", async (event, ctx) => {
		if (process.platform !== "darwin" || !ctx.hasUI || !autoTtsEnabled) return;

		const text = getLastAssistantSpeechText(event.messages);
		if (text === null) return;

		speakDarwin(text);
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

			speakDarwin(text);
		},
	});
}
