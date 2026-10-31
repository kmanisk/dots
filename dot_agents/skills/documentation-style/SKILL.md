---
name: documentation-style
description: Technical documentation guidelines, README authoring standards, shell scripting standards, and strict invariant to never use emojis anywhere in codebase.
version: 1.1.0
---

## Authority and freshness

This skill is procedural guidance, not a current machine-state authority. Before using any machine-specific path, device name, GPU mode, desktop/session, filesystem, version, or service-state claim below, read `~/.local/share/chezmoi/AGENTS.md`, `~/.local/share/chezmoi/docs/system/SYSTEM_CONTEXT.md`, `~/.local/share/chezmoi/docs/system/SUBSYSTEM_MAP.md`, the owning subsystem documentation, and current repo source; verify live state when available. Higher-authority evidence overrides this skill. Treat dated verification blocks as historical evidence unless re-verified.

# Technical Documentation & Codebase Standards

## Core Invariants

1. **Strictly Zero Emojis Everywhere**: NEVER use emojis in `README.md`, markdown documentation, shell scripts (`.sh`), source code files (`.ts`, `.tsx`, `.go`, `.rs`, `.py`), log outputs (`console.log`, `echo`), comments, commit messages, or pull requests. Use clean, standardized technical prefixes like `[INFO]`, `[WARN]`, `[ERROR]`, `[OK]`.
2. **Clear Typography & Structure**: Rely on standard GitHub-flavored markdown formatting (code spans, bulleted lists, structured tables, and bold headers) rather than decorative Unicode characters or icons.
3. **Architecture Diagrams**: Use Mermaid sequence diagrams, flowcharts, or class diagrams for visual architecture rather than emoji-laden bullet points.
4. **Reproducible Instructions**: Provide exact copy-pasteable commands, configuration schemas, and concrete environment variable specifications.
