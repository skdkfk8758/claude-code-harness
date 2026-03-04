#!/usr/bin/env node
/**
 * CCH Summary Writer — Stop Hook
 * Reads the user's last question and assistant's final response,
 * generates a compact Q→A summary, and writes to .claude/cch/last_summary.
 *
 * Registered for: Stop event
 *
 * Input (stdin JSON):
 *   { last_assistant_message: string, stop_hook_active: boolean, ... }
 *
 * State files:
 *   .claude/cch/last_question  — saved by activity-tracker.mjs on UserPromptSubmit
 *   .claude/cch/last_summary   — written by this script
 */

import { mkdirSync, readFileSync, writeFileSync, existsSync, appendFileSync } from "node:fs";
import { join } from "node:path";

const STATE_DIR = join(process.cwd(), ".claude", "cch");
const GLOBAL_QUESTION_FILE = join(STATE_DIR, "last_question");
const GLOBAL_SUMMARY_FILE = join(STATE_DIR, "last_summary");

const Q_MAX = 70;
const A_MAX = 70;

/** Truncate text with ellipsis */
function truncate(text, max) {
  if (!text) return "";
  if (text.length > max) return text.slice(0, max - 1) + "\u2026";
  return text;
}

/** Extract a short summary from the assistant's response */
function summarizeAnswer(text) {
  if (!text) return "";

  // Split into lines, skip empty and system-reminder lines
  const lines = text.split(/[\r\n]+/).map(l => l.trim()).filter(Boolean);

  for (const line of lines) {
    // Skip markdown headers, code fences, system tags
    if (/^#{1,6}\s/.test(line)) continue;
    if (/^```/.test(line)) continue;
    if (/^<.*>$/.test(line)) continue;
    if (/^---$/.test(line)) continue;
    // Skip lines that are just tool call artifacts or very short
    if (line.length < 3) continue;

    // Strip markdown formatting
    let clean = line
      .replace(/\*\*/g, "")
      .replace(/`([^`]*)`/g, "$1")
      .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
      .trim();

    if (clean.length >= 3) return clean;
  }

  return "";
}

/**
 * Append summary to .omc/notepad.md Working Memory section.
 * Creates the file and section if they don't exist.
 */
function appendToNotepad(cwd, summaryText) {
  const notepadPath = join(cwd, ".omc", "notepad.md");
  const timestamp = new Date().toISOString();
  const entry = `\n- [${timestamp}] ${summaryText}`;

  try {
    if (!existsSync(join(cwd, ".omc"))) {
      mkdirSync(join(cwd, ".omc"), { recursive: true });
    }

    if (!existsSync(notepadPath)) {
      writeFileSync(notepadPath, `# Notepad\n\n## Working Memory\n${entry}\n`, "utf8");
      return;
    }

    const content = readFileSync(notepadPath, "utf8");
    if (content.includes("## Working Memory")) {
      // Append entry after the Working Memory header line
      const updated = content.replace(
        /(## Working Memory\n)/,
        `$1${entry}\n`
      );
      writeFileSync(notepadPath, updated, "utf8");
    } else {
      // Section missing — append it
      appendFileSync(notepadPath, `\n## Working Memory\n${entry}\n`, "utf8");
    }
  } catch {
    // Never block execution
  }
}

/** Summarize the user's question */
function summarizeQuestion(text) {
  if (!text) return "";
  // Strip markdown
  let clean = text
    .replace(/^#{1,6}\s+/, "")
    .replace(/\*\*/g, "")
    .replace(/`([^`]*)`/g, "$1")
    .trim();
  return clean;
}

try {
  const input = JSON.parse(readFileSync(0, "utf8"));

  // Prevent infinite loops
  if (input.stop_hook_active) {
    process.exit(0);
  }

  // Use session_id from Claude Code stdin, fallback to process.ppid
  const SESSION_ID = input.session_id || String(process.ppid || "default");
  const SESSION_DIR = join(STATE_DIR, "sessions", SESSION_ID);
  const QUESTION_FILE = join(SESSION_DIR, "last_question");
  const SUMMARY_FILE = join(SESSION_DIR, "last_summary");

  const assistantMsg = input.last_assistant_message || "";

  // Read saved question: per-session first, then global fallback
  const question = existsSync(QUESTION_FILE)
    ? readFileSync(QUESTION_FILE, "utf8").trim()
    : existsSync(GLOBAL_QUESTION_FILE)
      ? readFileSync(GLOBAL_QUESTION_FILE, "utf8").trim()
      : "";

  if (!question && !assistantMsg) {
    process.exit(0);
  }

  const qSummary = truncate(summarizeQuestion(question), Q_MAX);
  const aSummary = truncate(summarizeAnswer(assistantMsg), A_MAX);

  // Build two-line summary (Q and A on separate lines)
  let summary = "";
  if (qSummary && aSummary) {
    summary = `${qSummary}\n${aSummary}`;
  } else if (qSummary) {
    summary = `${qSummary}\ndone`;
  } else if (aSummary) {
    summary = `\n${aSummary}`;
  }

  if (summary) {
    // Write to per-session directory
    mkdirSync(SESSION_DIR, { recursive: true });
    writeFileSync(SUMMARY_FILE, summary, "utf8");
    // Also write to global fallback location
    mkdirSync(STATE_DIR, { recursive: true });
    writeFileSync(GLOBAL_SUMMARY_FILE, summary, "utf8");
    // Append compact Q→A line to OMC notepad working memory
    const notepadEntry = qSummary && aSummary
      ? `Q: ${qSummary} | A: ${aSummary}`
      : qSummary || aSummary;
    appendToNotepad(process.cwd(), notepadEntry);
  }
} catch {
  // Never block tool execution
}

process.exit(0);
