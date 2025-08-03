## Smart app proxy mode architecture

### Goal
 - To provide a GUI, an http server, and stdio invocation all within a single app. 
 - Keep external simplicy to the user with no node dependencies or separate services required.
 - This should all work within the contraints of a single sandboxed MacOS app.

### App Startup Decision Tree

#### CASE 1  Normal GUI launch (user double-clicks)

*Goal: ensure **only one** GUI instance.*

1. **Check for existing GUI instance**  
   - Read `server.json` and verify the PID is alive.  
   - **FOUND:** bring that app to front, then terminate the new process.  
   - **NOT FOUND / stale:** delete the file and continue.

2. **Become the primary GUI server**  
   - Spin up services (AudioManager, **HTTPServer**, etc.).  
   - After the HTTP server is ready, write `server.json` (see table above).  
   - Show the main window.  
   - **Note:** `StdioProxy` is **not** used in this path.

---

#### CASE 2  Launched with `--stdio` (LLM client spawn)

*Goal: guarantee a GUI server is running **then** act as a proxy. This helper never shows UI.*

1. **Check for existing GUI instance**  
   - If `server.json` + live PID exists → jump straight to **Become a Proxy**.  
   - Otherwise → proceed to **Launch and Discover**.

2. **Launch and Discover**  
   - **Acquire launch lock**  
     - Atomically create `server.json.launching`.  
     - If creation fails, another helper is launching; wait up to **15 s**.  
     - If that other helper disappears without success (lock file vanishes and no `server.json` emerges), **retry** from the top; stale lock files are cleaned up automatically.
   - **Launch GUI app** via `NSWorkspace.launchApplication`.  
   - **Discovery loop** (250 ms poll, 15 s timeout) waits for a valid `server.json`.  
   - **Failure:** timeout ⇒ log to `stderr`, `exit(1)`.

3. **Become a Proxy** (final step in all `--stdio` scenarios)  
   - Read the port from `server.json`; no other services or UI are started.  
   - Enter loop:  
     1. Read one JSON-RPC message from **stdin**.  
     2. POST it to `http://127.0.0.1:<port>/`.  
     3. Forward the HTTP body back to **stdout**.  
   - **Framing:**  
     - The proxy auto-detects **newline-delimited JSON** (MCP 2025-06-18) *or* legacy `Content-Length` framing, echoing replies in the same format.  
   - **Notifications:**  
     - If the HTTP server returns **202 Accepted** (used for JSON-RPC notifications), the proxy writes **no** response to stdout, per MCP spec.  
   - When the client closes stdin, the proxy exits with status 0.

---

### Visual Flowchart (`--stdio` helper only)

```
[ --stdio process starts ]
        |
        v
[ valid server.json? ]──Yes──▶[ Become a Proxy ]
        |
        No
        |
        v
[ create launch lock ]
        |
        v
[ launch GUI app ]
        |
        v
[ discovery loop ≤15 s ]
        |
 ┌──────┴──────┐
 │             │
Yes           Timeout
 │             │
 v             v
[ Become       [ log error,
  a Proxy ]      exit(1) ]
```

### Server-config file (the “source of truth”)
- Path: `~/Library/Application Support/RiffMCP/server.json`
- Keys written by the GUI HTTP server:  

  | key        | type    | example                          | notes                             |
  |------------|---------|----------------------------------|-----------------------------------|
  | `port`     | UInt16  | `3001`                           | resolved listening port           |
  | `host`     | String  | `"127.0.0.1"`                    | always loopback today             |
  | `status`   | String  | `"running"`                      | only “running” is considered live |
  | `pid`      | Int     | `84411`                          | PID of the GUI process            |
  | `instance` | String  | `"0D4E…"`                        | random UUID for sanity-checking   |
  | `timestamp`| Double  | `1.967E9`                        | epoch seconds at write-time       |

### Glossary of Moving Parts
| Component   | Role |
|-------------|------|
| **`HTTPServer`** | Listens on loopback; handles `/` JSON-RPC, `/health`, and `/images/*`. |
| **`StdioProxy`** | Bridge from stdin/stdout JSON-RPC to the running `HTTPServer`. |
| **`ServerConfig`** | Reads/writes `server.json`; cleans stale files. |
| **`ServerProcess`** | Utility for PID checks and launching the GUI app. |
