#!/usr/bin/env node
/**
 * Plan Document Parser
 * Extracts structured data from CCH plan Markdown documents.
 *
 * Exported: parsePlanDocument(markdownContent, filename) → object
 */

/**
 * Extract work_id from plan filename.
 * "2026-03-03-login-feature.md" → "login-feature"
 * "some-plan.md" → "some-plan"
 */
function extractWorkId(filename) {
  const base = filename.replace(/\.md$/i, "");
  // Remove YYYY-MM-DD- prefix if present
  const stripped = base.replace(/^\d{4}-\d{2}-\d{2}-/, "");
  return stripped || base;
}

/**
 * Extract content of a specific ## section.
 * Returns text between the heading and the next ## heading (or EOF).
 */
function extractSection(content, heading) {
  const pattern = new RegExp(
    `^##\\s+${heading}\\s*$([\\s\\S]*?)(?=^##\\s|$(?!\\s))`,
    "mi"
  );
  const match = content.match(pattern);
  if (!match) return "";
  return match[1].trim();
}

/**
 * Extract all checkbox items from content.
 * Returns: [{ description, done }]
 */
function extractCheckboxes(content) {
  const items = [];
  const re = /^[-*]\s+\[([ xX])\]\s+(.+)$/gm;
  let m;
  while ((m = re.exec(content)) !== null) {
    const text = m[2].trim();
    // Skip template placeholders
    if (/^(Step|Criterion)\s+\d+$/i.test(text)) continue;
    items.push({
      description: text,
      done: m[1] !== " ",
    });
  }
  return items;
}

/**
 * Extract backtick-wrapped file paths from a section.
 */
function extractFilePaths(sectionContent) {
  const paths = [];
  const re = /`([^`]+\.[a-zA-Z]{1,10})`/g;
  let m;
  while ((m = re.exec(sectionContent)) !== null) {
    paths.push(m[1]);
  }
  return paths;
}

/**
 * Detect if the plan is still an empty template.
 */
function isEmptyTemplate(goalText) {
  if (!goalText) return true;
  const stripped = goalText.replace(/<!--[\s\S]*?-->/g, "").trim();
  return stripped.length === 0;
}

/**
 * Parse a plan Markdown document into structured data.
 */
export function parsePlanDocument(content, filename) {
  const work_id = extractWorkId(filename);

  const goalSection = extractSection(content, "Goal");
  const goalStripped = goalSection.replace(/<!--[\s\S]*?-->/g, "").trim();
  const goal = goalStripped.split(/\r?\n/)[0]?.trim() || "";

  const is_empty_template = isEmptyTemplate(goalSection);

  const criteriaSection = extractSection(content, "Acceptance Criteria");

  // Extract tasks from content excluding the Acceptance Criteria section
  const contentWithoutCriteria = criteriaSection
    ? content.replace(criteriaSection, "")
    : content;
  const tasks = extractCheckboxes(contentWithoutCriteria);

  const criteriaItems = criteriaSection
    ? extractCheckboxes(criteriaSection).map((c) => c.description)
    : [];
  if (criteriaItems.length === 0 && criteriaSection) {
    const lines = criteriaSection.split(/\r?\n/);
    for (const line of lines) {
      const m = line.match(/^[-*]\s+(.+)$/);
      if (m) criteriaItems.push(m[1].trim());
    }
  }

  const filesSection =
    extractSection(content, "예상 변경 파일") ||
    extractSection(content, "Changed Files") ||
    extractSection(content, "Files");
  const changed_files = filesSection ? extractFilePaths(filesSection) : [];

  return {
    work_id,
    goal,
    is_empty_template,
    tasks,
    acceptance_criteria: criteriaItems,
    changed_files,
  };
}
