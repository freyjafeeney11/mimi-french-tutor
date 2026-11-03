# Mimi — AI French Tutor

Mimi is a local-first French learning application that combines a desktop Godot client with a FastAPI backend and an Ollama-hosted LLM. The product is designed around conversation practice, structured lessons, correction feedback, and long-term learner progress tracking.

<img width="689" height="346" alt="Mimi application UI" src="https://github.com/user-attachments/assets/f5462c31-7ad8-42b5-9d16-68f45c934f12" />

## Overview

The system supports two interaction modes:

- Chat mode: free-form French conversation with a persona-based assistant.
- Lesson mode: guided, topic-driven exercises for grammar, vocabulary, slang, conjugation, and practical French scenarios.

The app keeps per-user state locally, tracks lesson attempts and topic progression, and exposes a lightweight API for the client to request responses, corrections, and progress summaries.

## Architecture

```text
Godot client (GDScript)
    |
    | HTTP / JSON
    v
FastAPI backend (backend/server.py)
    |
    +--> Ollama chat endpoint (gemma3:4b by default)
    +--> SQLite persistence (backend/mimi.sqlite3)
    +--> session memory (in-process dict per session/mode)
    |
    +--> progress analytics
    +--> personal fact memory
    +--> grammar correction pipeline

Frontend files:
  frontend/mimi/scripts/chatbox.gd
  frontend/mimi/scenes/progress_dashboard.tscn
  frontend/mimi/scenes/main.tscn

Backend files:
  backend/server.py
  backend/mimi.sqlite3
  backend/requirements.txt
  backend/memory/ (legacy fact imports)
```

### Runtime model

The client sends HTTP requests to the FastAPI server, which then:

1. Builds a prompt that includes a persona, level-specific guidance, learner facts, and lesson context.
2. Maintains per-session conversation history in memory for the current process.
3. Calls Ollama using the local chat API.
4. Parses, sanitizes, and emits line-based assistant bubbles for the UI.
5. Persists learner data to SQLite when needed for progress or memory traces.

### Frontend

The Godot client is responsible for:

- chat input and send actions
- mode toggling between chat and lesson
- session generation and stable user IDs stored under `user://mimi.cfg`
- dynamic bubble rendering and accent shortcuts for French text input
- opening a full-screen progress dashboard
- requesting correction / attempt / topic updates from the backend

Key front-end script:

- `frontend/mimi/scripts/chatbox.gd`

### Backend

The backend is centered around `backend/server.py` and provides the main API surface:

- `POST /chat` - general conversation generation
- `POST /lesson/start` - initialize lesson mode and ask the learner what they want to work on
- `POST /correct` - grammar/vocabulary proofreading for the latest learner input
- `POST /lesson/attempt` - record answer outcomes and topic progress
- `POST /progress/topic` - save or update learner topic status
- `GET /progress/{user_id}` - fetch learner diagnostics and tracked topics
- `GET /memory/{user_id}` - return stored personal facts
- `DELETE /memory/{user_id}` - clear fact memory
- `DELETE /session/{session_id}` - reset an in-memory session

The server is intentionally local-first and keeps no external dependencies beyond the Ollama model runtime and SQLite database.

## Data and state model

### In-memory session state

The backend uses an in-process dictionary keyed by `session_id:mode`:

```python
sessions: dict[str, dict] = {}
```

Each session stores:

- message history
- turn count
- current lesson topic
- mode-specific conversation state

This is ephemeral and resets on server restart.

### SQLite persistence

The app initializes a local SQLite database at `backend/mimi.sqlite3` and creates the following tables:

- `learner_profiles`
  - persistent user profile metadata
  - includes `starting_level` and `estimated_level`

- `skill_progress`
  - per-skill analytics across lesson attempts
  - tracks attempts, correct answers, hinted answers, incorrect answers, and aggregate score

- `learning_events`
  - append-only event log of lesson outcomes
  - stores `session_id`, `skill`, `correct`, `hint_used`, `error_type`, and timestamps

- `learner_topics`
  - topics chosen during lessons
  - includes status values like `practising`, `review`, and `mastered`

- `learner_facts`
  - durable personal facts extracted from learner statements
  - used as memory context for future conversations

This enables the client’s “My Progress” dashboard to show topic history and skill-level diagnostics without requiring a separate service.

## Prompting strategy

The backend composes a layered prompt system.

### Core persona

The `PERSONA` prompt sets the assistant as:

- a young French speaker
- text-message style conversational partner
- warm, observant, and lightly humorous
- not a formal tutor or scripted customer support bot

The persona rules explicitly enforce natural chatting behavior, brief replies, and not repeating previous questions.

### Lesson prompt extension

When in lesson mode, the server appends a `LESSON_ADDON` prompt that instructs the model to:

- lead a focused lesson around the learner’s chosen topic
- teach one concept at a time
- prefer writing-based tasks over spoken tasks
- maintain a text-only interaction model
- give concise corrections and a fresh follow-up challenge

### Corrective model

The `CORRECTION_SYSTEM` prompt is a strict proofreading policy for the learner’s latest message. It is designed to:

- flag real grammar or vocabulary mistakes conservatively
- allow colloquial French and texting variants
- reject false positives from informal language
- require an exact source phrase match before accepting a correction

The correction endpoint returns JSON with a `has_error` flag and a minimal correction block, which the client uses to display feedback in context.

## Lesson and progress logic

### Topic normalization

The backend normalizes learner topic requests using a set of string-cleaning and topic-mapping rules. Examples include:

- grammar / conjugation requests
- slang and idiom detection
- café / restaurant ordering scenarios
- general topic labels for practice

This lets the app group similar content under stable labels when recording lessons.

### Progress scoring

Each recorded attempt updates a `skill_progress` row. The scoring model differentiates:

- `independent_correct`: correct without hints
- `hinted_correct`: correct after a prompt or partial clue
- `incorrect`: incorrect submission

The profile builder then derives:

- weak skill priorities
- strong skill summaries
- topic recency and review status

This is surfaced in the dashboard as learner diagnostics without pretending to be a formal assessment engine.

### Personal fact memory

When the learner sends a sufficiently long message in chat mode, the backend triggers a background memory-extraction step:

- the model extracts only durable, non-sensitive facts
- the system stores them in `learner_facts`
- the facts are included in future system prompts when relevant

This creates lightweight personalization without forcing a full user-auth system.

## API behavior

### Conversation request flow

`POST /chat` executes the following pipeline:

1. identify the correct `session_id:mode` bucket
2. append the new user message to the in-memory history
3. load facts for the current user
4. load lesson progress if the mode is lesson
5. construct the system prompt with persona + level + memory + progress
6. call Ollama with a moderate temperature and a short generation budget
7. split output into bubble strings for UI rendering
8. store the response in session history

### Correction request flow

`POST /correct`:

1. validates that the learner message is substantial
2. sends only the latest message plus narrow conversation context to the model
3. checks the model output for a valid grammar/vocabulary correction
4. ensures the incorrect phrase exists in the source sentence
5. returns a structured correction payload only when a high-confidence fix is found

## Project structure

```text
mimi-french-tutor/
├── backend/
│   ├── server.py
│   ├── requirements.txt
│   ├── mimi.sqlite3
│   ├── memory/
│   └── venv/
├── frontend/
│   └── mimi/
│       ├── scripts/
│       ├── scenes/
│       ├── art/
│       └── project.godot
├── tester.py
├── launch_mimi.bat
├── readme.md
└── .gitignore
```

## Setup and run

### Prerequisites

- Python 3.11+
- Ollama installed and running locally
- a model available in Ollama, defaulting to `gemma3:4b`
- Godot 4.x for the desktop client

### Environment variables

The backend reads the following configuration values:

```bash
OLLAMA_URL=http://localhost:11434/api/chat
OLLAMA_MODEL=gemma3:4b
MIMI_DATABASE=./backend/mimi.sqlite3
```

### Local backend

```bash
cd backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
ollama run gemma3:4b
uvicorn server:app --reload --host 0.0.0.0 --port 8000
```

### Frontend

```bash
godot frontend/mimi/project.godot
```

There is also a Windows launcher:

```bash
launch_mimi.bat
```

## Current capabilities

- conversational French practice
- lesson-mode topic navigation
- data-driven progress tracking
- local memory capture for learner preferences and personal details
- grammar correction with conservative validation
- user-scoped progress persistence across launches

## Known limitations

- session memory is in-process only and is not durable across server restarts
- the app is intentionally local-only and does not include authentication or multi-user account management
- prompt quality is still dependent on model behavior and may require tuning for more consistent persona adherence
- the UX is functional rather than production-polished

## Development notes

This repo is best treated as a research / prototype application for local language tutoring. The project currently prioritizes:

- fast iteration over full platform engineering
- inference control via local model routing
- learner-aware prompting over generic “chatbot” behavior
- feature experimentation in the Godot client and FastAPI backend

## Roadmap

- improve prompt stability and persona coherence
- persist full conversation history beyond a process lifetime
- expand progress analytics with better learning recommendations
- tune the correction model for fewer false positives
- add broader lesson templates and grammar reference material
- improve UI polish and accessibility in the Godot client
