---
name: excalidraw
description: Use when a user asks for an Excalidraw diagram canvas sketch whiteboard or .excalidraw output.
---

# Excalidraw

Create diagrams that can be inspected and edited in Excalidraw.

## Workflow

1. Identify the diagram type: flow, architecture, sequence, map, or sketch.
2. Use an Excalidraw tool or MCP when available.
3. If no direct tool is available, create a concise `.excalidraw` JSON file or a canvas-ready diagram spec.
4. Keep labels short and layouts readable.
5. Use stable groups, arrows, and named sections for complex diagrams.

## Common Mistakes

- Returning only prose when the user asked for a canvas artifact.
- Using Mermaid as the final answer when Excalidraw output was explicitly requested.
- Overloading the canvas with tiny labels.
