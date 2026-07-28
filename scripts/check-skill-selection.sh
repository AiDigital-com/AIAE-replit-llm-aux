#!/usr/bin/env bash
# check-skill-selection.sh — detect skills that compete for the same trigger.
#
# Replit reads every skill's frontmatter to decide relevance, and Claude Code
# selects on description alone. Two skills whose descriptions occupy the same
# trigger space are therefore unresolvable: the agent picks arbitrarily, and the
# user gets a different workflow than the one they meant.
#
# This is a heuristic on wording, not a proof of correct selection. Identical
# trigger clauses are deterministic defects and fail. Vocabulary overlap is
# advisory: wording similarity cannot prove that either runtime will select the
# wrong skill, so high scores require review without blocking CI.
#
# Calibration (measured, not guessed): `rule-compliance-audit` and
# `aiae-rule-compliance-audit` shipped with word-for-word identical trigger
# clauses and scored 0.47. The highest legitimate pair at calibration time —
# backend-rule-review vs frontend-style-review, separated by domain — scored
# 0.20. Scores are diagnostics, not a model-selection oracle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="${1:-$ROOT/.claude/skills}"
REVIEW_AT="${SELECTION_REVIEW_AT:-0.35}"
WARN_AT="${SELECTION_WARN_AT:-0.25}"

command -v ruby >/dev/null 2>&1 || { echo "check-skill-selection: ruby is required" >&2; exit 1; }
[ -d "$REGISTRY" ] || { echo "check-skill-selection: no registry at $REGISTRY" >&2; exit 1; }

ruby -rset -ryaml -e '
registry, review_at, warn_at = ARGV[0], ARGV[1].to_f, ARGV[2].to_f

STOP = %w[a an the or and of to for in on with when use uses used this that it its as be is
          are from at by not no do does after before only into over per your you their they
          them if then than more most other others about which what whether should must may
          can will would each any all both same].to_set

def frontmatter(path)
  lines = File.readlines(path)
  return nil unless lines[0]&.chomp == "---"
  close = lines[1..].index { |l| l.chomp == "---" }
  return nil unless close
  YAML.safe_load(lines[1..close].join, permitted_classes: [], aliases: false)
rescue StandardError
  nil
end

skills = {}
Dir.children(registry).sort.each do |dir|
  file = File.join(registry, dir, "SKILL.md")
  next unless File.file?(file)
  meta = frontmatter(file)
  next unless meta.is_a?(Hash) && meta["description"].is_a?(String)
  skills[dir] = meta["description"].gsub(/\s+/, " ").strip
end

abort "check-skill-selection: no skills with descriptions in #{registry}" if skills.empty?

def tokens(text)
  text.downcase.scan(/[a-z][a-z0-9-]{2,}/).reject { |w| STOP.include?(w) }.to_set
end

# The clause that tells the agent *when* to fire. Identical clauses are an
# outright conflict regardless of how the rest of the description differs.
def trigger(text)
  m = text[/\b[Uu]se (?:when|for|after|before)\b.*/]
  m ? m.downcase.gsub(/[^a-z0-9 ]/, " ").gsub(/\s+/, " ").strip : nil
end

pairs = skills.keys.combination(2).map do |a, b|
  ta, tb = tokens(skills[a]), tokens(skills[b])
  union = (ta | tb).size
  j = union.zero? ? 0.0 : (ta & tb).size.fdiv(union)
  [j, a, b, (ta & tb).to_a.sort]
end.sort_by { |j, _, _, _| -j }

failures = 0

skills.keys.combination(2).each do |a, b|
  ta, tb = trigger(skills[a]), trigger(skills[b])
  next unless ta && tb && ta == tb
  warn "check-skill-selection: FAIL - #{a} and #{b} declare an identical trigger clause"
  failures += 1
end

puts "check-skill-selection: #{skills.size} skill(s) in #{registry.sub(%r{^.*/(?=\.)}, "")}"
pairs.first(5).each do |j, a, b, common|
  mark = if j >= review_at then "REVIEW"
         elsif j >= warn_at then "watch"
         else "ok" end
  puts format("  %.2f  %-8s %s x %s", j, mark, a, b)
  puts "          shared: #{common.first(12).join(" ")}" if j >= warn_at
end

review_count = pairs.count { |j, _, _, _| j >= review_at }

if failures.positive?
  warn "check-skill-selection: #{failures} identical trigger pair(s)"
  exit 1
end
puts "check-skill-selection: no identical triggers"
puts "check-skill-selection: #{review_count} vocabulary-overlap pair(s) require manual review" if review_count.positive?
' "$REGISTRY" "$REVIEW_AT" "$WARN_AT"
