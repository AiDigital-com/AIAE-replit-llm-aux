#!/usr/bin/env bash
# Ensure operator-facing skill-selection docs reference names that actually ship.

set -euo pipefail

ROOT="${DOCUMENTED_SKILL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PAYLOAD="${ROOT}/agent-payload.skills"
SELECTION="${ROOT}/.claude/agent_docs/skill-selection.md"
GUIDE="${ROOT}/AI-DEVELOPMENT-GUIDE.md"
INDEX="${ROOT}/.claude/agent_docs/index.md"

for required in "$PAYLOAD" "$SELECTION" "$GUIDE" "$INDEX"; do
  [ -f "$required" ] || {
    echo "check-documented-skill-ids: missing required file: $required" >&2
    exit 1
  }
done

# These are two installed copies of the same routing document. Keeping them
# byte-identical prevents Claude's root guide and detailed index from teaching
# different selection behavior.
cmp -s "$SELECTION" "$GUIDE" || {
  echo "check-documented-skill-ids: AI-DEVELOPMENT-GUIDE.md drifted from skill-selection.md" >&2
  exit 1
}

ruby -e '
root, payload_path, selection_path, index_path = ARGV
payload = File.readlines(payload_path, chomp: true)
  .map(&:strip)
  .reject { |line| line.empty? || line.start_with?("#") }
  .to_h { |name| [name, true] }

references = []
[selection_path].each do |path|
  File.foreach(path).with_index(1) do |line, number|
    line.scan(/`([a-z0-9]+(?:-[a-z0-9]+)+)`/) do |match|
      references << [match.fetch(0), path, number]
    end
  end
end

# index.md also mentions technical packages such as openapi-fetch. Only the
# explicit registry inventory sentence is a skill-ID contract.
File.foreach(index_path).with_index(1) do |line, number|
  next unless line.include?(".claude/skills/") && line.include?("contains reusable workflows")
  line.scan(/`([a-z0-9]+(?:-[a-z0-9]+)+)`/) do |match|
    references << [match.fetch(0), index_path, number]
  end
end

abort "check-documented-skill-ids: no documented skill references found" if references.empty?

missing = references.reject { |name, _, _| payload.key?(name) }
missing.each do |name, path, number|
  warn "check-documented-skill-ids: #{path.delete_prefix("#{root}/")}:#{number} references unshipped skill #{name.inspect}"
end
exit 1 unless missing.empty?

puts "check-documented-skill-ids: #{references.map(&:first).uniq.size} documented skill IDs are shipped"
' "$ROOT" "$PAYLOAD" "$SELECTION" "$INDEX"
