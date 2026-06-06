#!/usr/bin/env python3
import json
import sys


def write_message(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def result(message_id, payload):
    write_message({"jsonrpc": "2.0", "id": message_id, "result": payload})


def error(message_id, code, message):
    write_message({"jsonrpc": "2.0", "id": message_id, "error": {"code": code, "message": message}})


for line in sys.stdin:
    if not line.strip():
        continue

    message = json.loads(line)
    method = message.get("method")
    message_id = message.get("id")

    if method == "initialize":
        params = message.get("params") or {}
        result(
            message_id,
            {
                "protocolVersion": params.get("protocolVersion", "2025-06-18"),
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "ai-dots-probe", "version": "1.0.0"},
            },
        )
    elif method == "tools/list":
        result(
            message_id,
            {
                "tools": [
                    {
                        "name": "probe",
                        "description": "Return the ai-dots MCP activation marker.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {},
                            "required": [],
                            "additionalProperties": False,
                        },
                    }
                ]
            },
        )
    elif method == "tools/call":
        params = message.get("params") or {}
        if params.get("name") == "probe":
            result(message_id, {"content": [{"type": "text", "text": "ai-dots-mcp-ok"}], "isError": False})
        else:
            error(message_id, -32602, "Unknown tool")
    elif message_id is not None:
        error(message_id, -32601, f"Unknown method: {method}")
