#!/usr/bin/env node
/**
 * CCH Activity Tracker Hook
 * Captures current activity from user prompts and task events.
 *
 * Registered for:
 *   - UserPromptSubmit: summarizes user message → last_activity
 *   - PreToolUse:TaskCreate: captures activeForm/subject
 *   - PreToolUse:TaskUpdate: tracks in_progress/completed transitions
 *
 * Priority: TaskCreate/TaskUpdate overrides prompt-based activity.
 */

import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const STATE_DIR = join(process.cwd(), ".claude", "cch");
const STATE_FILE = join(STATE_DIR, "last_activity");
const GLOBAL_QUESTION_FILE = join(STATE_DIR, "last_question");
const MAX_LEN = 30;

/** Extract a short summary from user prompt text */
function summarizePrompt(text) {
  if (!text || text.length < 3) return "";

  // Take first line only
  let line = text.split(/[\r\n]/)[0].trim();

  // Strip markdown formatting
  line = line.replace(/^#{1,6}\s+/, "");
  line = line.replace(/\*\*/g, "");
  line = line.replace(/`([^`]*)`/g, "$1");

  // Skip very short messages (greetings, confirmations)
  if (line.length < 3) return "";

  // Truncate
  if (line.length > MAX_LEN) {
    line = line.slice(0, MAX_LEN - 1) + "\u2026";
  }

  return line;
}

try {
  const input = JSON.parse(readFileSync(0, "utf8"));

  // Use session_id from Claude Code stdin, fallback to process.ppid
  const SESSION_ID = input.session_id || String(process.ppid || "default");
  const SESSION_DIR = join(STATE_DIR, "sessions", SESSION_ID);
  const QUESTION_FILE = join(SESSION_DIR, "last_question");

  const toolName = input.tool_name || "";
  const ti = input.tool_input || {};
  const prompt = input.prompt || "";

  let action = null;

  if (prompt) {
    // UserPromptSubmit event — save raw question for summary-writer
    mkdirSync(SESSION_DIR, { recursive: true });
    const qLine = prompt.split(/[\r\n]/)[0].trim();
    if (qLine.length >= 3) {
      writeFileSync(QUESTION_FILE, qLine, "utf8");
      // Also write to global fallback location
      mkdirSync(STATE_DIR, { recursive: true });
      writeFileSync(GLOBAL_QUESTION_FILE, qLine, "utf8");
    }
    const summary = summarizePrompt(prompt);
    if (summary) action = { type: "prompt", text: summary };
  } else if (toolName === "TaskCreate") {
    const activity = ti.activeForm || ti.subject || "";
    if (activity) action = { type: "create", text: activity };
  } else if (toolName === "TaskUpdate") {
    const status = ti.status || "";
    const activeForm = ti.activeForm || "";
    // in_progress without activeForm: action stays null (keep existing)
    if (status === "in_progress" && activeForm) {
      action = { type: "progress", text: activeForm };
    } else if (status === "completed") {
      action = { type: "completed" };
    }
  }

  if (action) {
    mkdirSync(STATE_DIR, { recursive: true });

    if (action.type === "prompt") {
      // Only write prompt-based activity if no task is actively in progress
      // (avoid overwriting more specific task activity with a generic prompt)
      const current = existsSync(STATE_FILE) ? readFileSync(STATE_FILE, "utf8").trim() : "";
      const isTaskActive = current && !current.startsWith("done: ");
      if (!isTaskActive) {
        writeFileSync(STATE_FILE, action.text, "utf8");
      }
    } else if (action.type === "create" || action.type === "progress") {
      writeFileSync(STATE_FILE, action.text, "utf8");
    } else if (action.type === "completed" && existsSync(STATE_FILE)) {
      const current = readFileSync(STATE_FILE, "utf8").trim();
      if (!current.startsWith("done: ")) {
        writeFileSync(STATE_FILE, `done: ${current}`, "utf8");
      }
    }
  }
} catch {
  // Never block tool execution
}

process.exit(0);
