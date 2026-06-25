#!/usr/bin/env bash
# fuguectl-agents.sh — shell-facing Agent Runtime Registry helper
#
# Agent Runtime Registry maps a logical agent id to a concrete runtime harness
# and target. The TypeScript engine owns the canonical parser and coordinator
# behavior; this shell helper gives fuguectl users a small operator surface while
# the broader command set is still migrating from bash to the engine.
#
#   template               print a starter registry JSON
#   validate <file>        validate the registry schema
#   list <file>            print id<TAB>harness<TAB>target<TAB>roles
#   resolve <file> <id>    print resolved fields for one logical agent id
set -uo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fuguectl-lib.sh"

sub="${1:-}"; shift || true

case "$sub" in
  template|validate|list|resolve)
    node - "$sub" "$@" <<'NODE'
const fs = require('node:fs');

const HARNESS_NAMES = ['fugue-cc', 'codex', 'opencode'];
const AGENT_ROLES = ['planner', 'implementer', 'reviewer', 'fixer'];
const PROFILE_KEYS = new Set([
  'id',
  'harness',
  'target',
  'modelFamily',
  'roles',
  'canEditFiles',
  'reviewAllowed',
  'workspace',
  'tags',
]);

const [cmd, ...args] = process.argv.slice(2);

const fail = (message) => {
  console.error(message);
  process.exit(1);
};

const isRecord = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const nonEmpty = (value) => typeof value === 'string' && value.trim().length > 0;
const trimNonEmpty = (value) => (nonEmpty(value) ? value.trim() : undefined);

const parseStringArray = (value, label, allowed) => {
  if (value === undefined) return undefined;
  if (!Array.isArray(value)) fail(`${label} must be an array`);
  const out = [];
  const seen = new Set();
  for (let i = 0; i < value.length; i += 1) {
    const item = trimNonEmpty(value[i]);
    if (item === undefined) fail(`${label}[${String(i)}] must be a non-empty string`);
    if (allowed !== undefined && !allowed.includes(item)) {
      fail(`${label}[${String(i)}] must be one of ${allowed.join(', ')}`);
    }
    if (!seen.has(item)) {
      seen.add(item);
      out.push(item);
    }
  }
  return out;
};

const parseOptionalString = (item, field, label) => {
  if (item[field] === undefined) return undefined;
  const value = trimNonEmpty(item[field]);
  if (value === undefined) fail(`${label} must be a non-empty string`);
  return value;
};

const parseOptionalBoolean = (item, field, label) => {
  if (item[field] === undefined) return undefined;
  if (typeof item[field] !== 'boolean') fail(`${label} must be a boolean`);
  return item[field];
};

const parseProfile = (value, index) => {
  const prefix = `agents[${String(index)}]`;
  if (!isRecord(value)) fail(`${prefix} must be an object`);
  for (const key of Object.keys(value)) {
    if (!PROFILE_KEYS.has(key)) fail(`${prefix} has extra field "${key}"`);
  }
  const id = trimNonEmpty(value.id);
  if (id === undefined) fail(`${prefix}.id must be a non-empty string`);
  if (typeof value.harness !== 'string' || !HARNESS_NAMES.includes(value.harness)) {
    fail(`${prefix}.harness must be one of ${HARNESS_NAMES.join(', ')}`);
  }

  const profile = { id, harness: value.harness };
  const target = parseOptionalString(value, 'target', `${prefix}.target`);
  const modelFamily = parseOptionalString(value, 'modelFamily', `${prefix}.modelFamily`);
  const workspace = parseOptionalString(value, 'workspace', `${prefix}.workspace`);
  const roles = parseStringArray(value.roles, `${prefix}.roles`, AGENT_ROLES);
  const tags = parseStringArray(value.tags, `${prefix}.tags`);
  const canEditFiles = parseOptionalBoolean(value, 'canEditFiles', `${prefix}.canEditFiles`);
  const reviewAllowed = parseOptionalBoolean(value, 'reviewAllowed', `${prefix}.reviewAllowed`);
  if (target !== undefined) profile.target = target;
  if (modelFamily !== undefined) profile.modelFamily = modelFamily;
  if (roles !== undefined) profile.roles = roles;
  if (canEditFiles !== undefined) profile.canEditFiles = canEditFiles;
  if (reviewAllowed !== undefined) profile.reviewAllowed = reviewAllowed;
  if (workspace !== undefined) profile.workspace = workspace;
  if (tags !== undefined) profile.tags = tags;
  return profile;
};

const parseRegistryText = (text) => {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    fail(`invalid JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
  if (!isRecord(parsed)) fail('registry must be an object');
  if (!Array.isArray(parsed.agents)) fail('registry.agents must be an array');
  const ids = new Set();
  const agents = parsed.agents.map((item, index) => {
    const profile = parseProfile(item, index);
    if (ids.has(profile.id)) fail(`registry has duplicate agent "${profile.id}"`);
    ids.add(profile.id);
    return profile;
  });
  return { agents };
};

const readRegistry = (file) => {
  if (!nonEmpty(file)) fail('usage: validate|list <file> OR resolve <file> <id>');
  if (!fs.existsSync(file)) fail(`no agent registry at ${file}`);
  return parseRegistryText(fs.readFileSync(file, 'utf8'));
};

const targetOf = (profile) => profile.target ?? profile.id;
const rolesOf = (profile) => (profile.roles === undefined ? '*' : profile.roles.join(','));

const template = () => ({
  agents: [
    {
      id: 'cc-deepseek',
      harness: 'fugue-cc',
      modelFamily: 'deepseek',
      roles: ['implementer', 'fixer'],
      canEditFiles: true,
      tags: ['reasoning', 'backend'],
    },
    {
      id: 'coder',
      harness: 'codex',
      target: 'gpt-5.5',
      modelFamily: 'openai',
      roles: ['reviewer', 'implementer'],
      reviewAllowed: true,
      workspace: 'review',
    },
    {
      id: 'opencode-kimi',
      harness: 'opencode',
      target: 'kimi/latest',
      modelFamily: 'kimi',
      roles: ['implementer'],
      canEditFiles: true,
    },
  ],
});

if (cmd === 'template') {
  process.stdout.write(`${JSON.stringify(template(), null, 2)}\n`);
} else if (cmd === 'validate') {
  const registry = readRegistry(args[0]);
  process.stdout.write(`OK agent registry valid: ${String(registry.agents.length)} agents\n`);
} else if (cmd === 'list') {
  const registry = readRegistry(args[0]);
  for (const profile of registry.agents) {
    process.stdout.write(`${profile.id}\t${profile.harness}\t${targetOf(profile)}\t${rolesOf(profile)}\n`);
  }
} else if (cmd === 'resolve') {
  const registry = readRegistry(args[0]);
  const id = args[1];
  if (!nonEmpty(id)) fail('usage: resolve <file> <id>');
  const profile = registry.agents.find((agent) => agent.id === id);
  if (profile === undefined) fail(`agent "${id}" not found`);
  process.stdout.write(`id\t${profile.id}\n`);
  process.stdout.write(`harness\t${profile.harness}\n`);
  process.stdout.write(`target\t${targetOf(profile)}\n`);
  process.stdout.write(`modelFamily\t${profile.modelFamily ?? ''}\n`);
  process.stdout.write(`workspace\t${profile.workspace ?? ''}\n`);
  process.stdout.write(`roles\t${rolesOf(profile)}\n`);
}
NODE
    ;;
  ''|-h|--help) sed -n '2,15p' "$0";;
  *) die "unknown subcommand '$sub' (template|validate|list|resolve)";;
esac
