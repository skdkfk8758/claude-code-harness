/**
 * Bridge Output Builder
 * Constructs the hook JSON response for plan-bridge.mjs
 */

export const BRIDGE_REASONS = Object.freeze({
  NO_PLAN_FOUND: "no_plan_found",
  EMPTY_TEMPLATE: "empty_template",
  NO_TASKS: "no_tasks",
});

/**
 * Build the hook output JSON for a successful bridge activation.
 *
 * @param {object|null} plan - Parsed plan data (null if no plan found)
 * @param {object} status - { success: boolean, reason?: string }
 * @param {Array} [warnings=[]] - G9: per-command failure warnings from runCchBatch
 * @returns {object} Hook response JSON
 */
export function buildBridgeOutput(plan, status, warnings = []) {
  const base = {
    continue: true,
    hookSpecificOutput: {
      additionalContext: "",
    },
  };

  if (!status.success) {
    let warning = "[CCH BRIDGE WARNING]\n\n";

    if (status.reason === "no_plan_found") {
      warning += "오늘 날짜의 plan 문서를 찾을 수 없습니다.\n";
      warning += "docs/plans/ 디렉토리에 plan 문서를 먼저 작성하세요.";
    } else if (status.reason === "empty_template") {
      warning += "plan 문서가 빈 템플릿 상태입니다.\n";
      warning += `파일: ${plan?.plan_file || "unknown"}\n`;
      warning += "## Goal 섹션과 체크박스 항목을 작성한 후 다시 시도하세요.";
    } else if (status.reason === "no_tasks") {
      warning += "plan 문서에 체크박스 항목(- [ ] ...)이 없습니다.\n";
      warning += `파일: ${plan?.plan_file || "unknown"}\n`;
      warning += "실행할 작업 항목을 추가한 후 다시 시도하세요.";
    } else {
      warning += `예상하지 못한 문제: ${status.reason || "unknown"}`;
    }

    base.hookSpecificOutput.additionalContext = warning;
    return base;
  }

  // Success — build activation context
  const lines = [
    "[CCH BRIDGE ACTIVATED]",
    "",
    "인터뷰 결과가 자동 처리되었습니다:",
    `- 실행 계획: .claude/cch/execution-plan.json`,
    `- Beads: ${plan.bead_id || "N/A"}`,
    "- 모드: code",
    "",
    "지금 즉시 /cch-team 파이프라인을 시작하세요.",
    `작업 ID: ${plan.work_id}`,
    `계획 문서: ${plan.plan_file}`,
    "",
    "실행 계획 요약:",
    `- 목표: ${plan.goal}`,
    `- 작업 수: ${plan.tasks.length}개`,
    `- 완료 기준: ${plan.acceptance_criteria.length}개`,
  ];

  // G9: Append warnings from failed batch commands
  if (warnings.length > 0) {
    lines.push("", "[CCH BRIDGE WARNINGS]");
    for (const w of warnings) {
      lines.push(`- ${w.cmd}: ${w.error}`);
    }
  }

  base.hookSpecificOutput.additionalContext = lines.join("\n");
  return base;
}
