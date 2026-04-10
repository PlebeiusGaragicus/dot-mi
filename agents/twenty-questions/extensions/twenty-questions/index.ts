/**
 * Twenty Questions Extension
 *
 * Demonstrates two extension capabilities:
 *   1. Writing to stdout at extension load time (before user input)
 *   2. System prompt injection via the before_agent_start hook
 *
 * Shows a styled welcome box when pi starts, then injects
 * game rules into the system prompt so the agent plays 20 questions.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const BORDER_COLOR = "\x1b[36m";
const TITLE_COLOR = "\x1b[1;33m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

const GAME_RULES = `# 20 Questions

You are playing a game of 20 questions. The user is thinking of something and you must guess what it is.

## Rules

1. Ask exactly one yes-or-no question at a time.
2. Wait for the user's answer before asking the next question.
3. Keep a running count: display "Question N/20" before each question.
4. Use deductive reasoning -- narrow the category first, then get specific.
5. You may make a guess at any time instead of asking a question (it still counts as one of your 20).
6. After 20 questions, you must make a final guess.

## Strategy

- Start broad: "Is it a living thing?" / "Is it something physical?"
- Eliminate large categories early before drilling into specifics.

## Start

When the user says they are ready, think of a good opening question and begin.`;

function drawBox(lines: string[], width: number): string {
	const top = `${BORDER_COLOR}╭${"─".repeat(width - 2)}╮${RESET}`;
	const bottom = `${BORDER_COLOR}╰${"─".repeat(width - 2)}╯${RESET}`;
	const padded = lines.map((line) => {
		const raw = line.replace(/\x1b\[[0-9;]*m/g, "");
		const pad = Math.max(0, width - 4 - raw.length);
		return `${BORDER_COLOR}│${RESET} ${line}${" ".repeat(pad)} ${BORDER_COLOR}│${RESET}`;
	});
	return [top, ...padded, bottom].join("\n");
}

export default function (pi: ExtensionAPI) {
	if (process.stdout.isTTY) {
		const width = Math.min(process.stdout.columns || 60, 60);
		const box = drawBox(
			[
				`${TITLE_COLOR}🎲  20 Questions${RESET}`,
				"",
				"Think of something -- anything at all.",
				"The agent will ask yes/no questions to guess it.",
				"",
				`${DIM}Say "I'm ready" to start the game.${RESET}`,
			],
			width,
		);
		process.stdout.write(`\n${box}\n\n`);
	}

	pi.on("before_agent_start", async (event) => {
		return { systemPrompt: event.systemPrompt + "\n\n" + GAME_RULES };
	});
}
