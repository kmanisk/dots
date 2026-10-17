---
name: documentation-style
description: Technical documentation guidelines, README authoring standards, shell scripting standards, and strict invariant to never use emojis anywhere in codebase.
version: 1.1.0
---

# Technical Documentation & Codebase Standards

## Core Invariants

1. **Strictly Zero Emojis Everywhere**: NEVER use emojis in `README.md`, markdown documentation, shell scripts (`.sh`), source code files (`.ts`, `.tsx`, `.go`, `.rs`, `.py`), log outputs (`console.log`, `echo`), comments, commit messages, or pull requests. Use clean, standardized technical prefixes like `[INFO]`, `[WARN]`, `[ERROR]`, `[OK]`.
2. **Clear Typography & Structure**: Rely on standard GitHub-flavored markdown formatting (code spans, bulleted lists, structured tables, and bold headers) rather than decorative Unicode characters or icons.
3. **Architecture Diagrams**: Use Mermaid sequence diagrams, flowcharts, or class diagrams for visual architecture rather than emoji-laden bullet points.
4. **Reproducible Instructions**: Provide exact copy-pasteable commands, configuration schemas, and concrete environment variable specifications.
