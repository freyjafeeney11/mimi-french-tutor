# Mimi — AI French Teacher

A French-tutoring chatbot with a Godot desktop client and a locally-served LLM backend.

## Overview

Mimi provides two interaction modes — free-form conversation and a structured lesson mode — through a Godot chat interface that talks to a local HTTP API backed by Mistral, served via Ollama.

## Architecture

```
Godot client (GDScript)  --HTTP-->  FastAPI backend  --local call-->  Ollama (Mistral)
     chatbox.gd                       server.py
  - UI + mode toggle                - /chat/ endpoint
  - session ID generation            - session handling
  - request/response parsing        - prompt construction
```

- **Frontend:** Godot 4.3, GDScript. `chatbox.gd` handles user input, a conversational/lesson mode toggle, per-session ID generation, and parses the JSON `{"response": ...}` payload returned by the server.
- **Backend:** FastAPI server (`server.py`) exposing a `/chat/` endpoint that takes a `prompt` and `session_id` and returns the model's reply. Calls a locally running Ollama instance serving Mistral.
- **Standalone experimentation:** `tester.py` loads Mistral directly through Hugging Face `transformers`, for testing generation outside the served pipeline.

## Features

- **Conversational mode** — open-ended chat practice in French.
- **Lesson mode** — a toggleable, more structured teaching flow (currently routed through the same endpoint as conversational mode; server-side differentiation is still to be done).
- **Per-session state** — each client session generates its own ID so the backend can track conversation context independently across sessions.

## Tech stack

| Layer | Tool |
|---|---|
| Frontend | Godot 4.3 (GDScript) |
| Backend | FastAPI (Python) |
| Model serving | Ollama, running Mistral |
| Model experimentation | Hugging Face `transformers` |

## Running it

```bash
# Backend
cd backend
source venv/bin/activate
uvicorn server:app --reload
ollama run mistral

# Frontend
godot frontend/mimi/main.tscn
```


## Roadmap

- [ ] Improve prompt engineering — responses don't yet reliably stay in-character or on-task.
- [ ] Differentiate lesson mode from conversational mode server-side.
- [ ] Decide on and implement a conversation-memory strategy (currently session-scoped; full history vs. summarization vs. fixed window).
- [ ] Set a consistent global personality/system prompt.
- [ ] Add safety rules / guardrails around model output.
- [ ] Add domain-specific reference material (e.g. grammar references) the model can draw on.
- [ ] UI/art polish for the Godot client.
