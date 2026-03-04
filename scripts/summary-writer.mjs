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

import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
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

/** Summarize the user's question */
function summarizeQuestion(text) {
  if (!text) return "";
  return text
    .replace(/^#{1,6}\s+/, "")
    .replace(/\*\*/g, "")
    .replace(/`([^`]*)`/g, "$1")
    .trim();
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
  let question = "";
  if (existsSync(QUESTION_FILE)) {
    question = readFileSync(QUESTION_FILE, "utf8").trim();
  } else if (existsSync(GLOBAL_QUESTION_FILE)) {
    question = readFileSync(GLOBAL_QUESTION_FILE, "utf8").trim();
  }

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
  }
} catch {
  // Never block tool execution
}

process.exit(0);
