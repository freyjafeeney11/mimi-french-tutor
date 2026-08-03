# Mimi — AI French Teacher

A French-tutoring chatbot with a Godot desktop client and a locally-served LLM backend.

## Overview

Mimi provides two interaction modes — free-form conversation and a structured lesson mode — through a Godot chat interface that talks to a local HTTP API backed by Mistral, served via Ollama.

## Architecture

```
Godot client (GDScript)  --HTTP-->  FastAPI backend  --local call-->  Ollama (Mistral)
     chatbox.gd                       server.py
  - UI + mode toggle                - /chat/, /lesson/ endpoints
  - session ID generation            - in-memory conversation history
  - request/response parsing        - prompt construction
```

- **Frontend:** Godot 4.3, GDScript. `chatbox.gd` handles user input, a conversational/lesson mode toggle, per-session ID generation, and parses the JSON `{"response": ...}` payload returned by the server.
- **Backend:** FastAPI server (`server.py`) with two endpoints:
  - `/chat/` — casual conversation mode. System prompt sets Mimi as a young, brief, casually-spoken French conversation partner.
  - `/lesson/` — structured lesson mode. System prompt has Mimi teach with real-life analogies and quiz the user after a few exchanges.

  Both endpoints take `prompt` and `session_id`, build a running history string from that session's prior turns, send it to a local Ollama instance (`http://localhost:11434/api/generate`) running Mistral, and stream the response back.
- **Conversation history:** stored in-memory in a `dict` keyed by `session_id` (`conversation_history = {}`). Not persisted — history resets on server restart.
- **Standalone experimentation:**
  - `tester.py` (repo root) — loads Mistral directly through Hugging Face `transformers` (`AutoTokenizer` / `AutoModelForCausalLM`), for testing generation outside the served pipeline.
  - `backend/scripts/train_tokenizer.py` + `corpus.txt` — trains a custom BPE tokenizer (via `tokenizers`) on a small French-teaching dialogue corpus, with an alternate path to save the pretrained GPT-2 tokenizer instead. Not currently wired into `/chat/` or `/lesson/`.

## Features

- **Conversational mode** — open-ended chat practice in French.
- **Lesson mode** — structured teaching flow with analogies and periodic quizzes, served from its own endpoint with its own prompt.
- **Per-session state** — each client session generates its own ID; the backend tracks conversation history independently per session for the lifetime of the server process.

## Tech stack

| Layer | Tool |
|---|---|
| Frontend | Godot 4.3 (GDScript) |
| Backend | FastAPI (Python) |
| Model serving | Ollama, running Mistral |
| Model experimentation | Hugging Face `transformers`, `tokenizers` |

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

Main files to edit: `server.py` (backend logic), `chatbox.gd` (frontend chat handling).

## Roadmap

- [x] Differentiate lesson mode from conversational mode server-side.
- [ ] Improve prompt engineering — responses don't yet reliably stay in-character or on-task.
- [ ] Persist conversation history beyond server restarts (currently in-memory only).
- [ ] Decide whether/how to wire the custom tokenizer experiment into the main pipeline, or drop it.
- [ ] Set a consistent global personality/system prompt shared across modes.
- [ ] Add safety rules / guardrails around model output.
- [ ] Add domain-specific reference material (e.g. grammar references) the model can draw on.
- [ ] UI/art polish for the Godot client.
