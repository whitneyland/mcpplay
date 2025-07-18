Goal: 
  To provide a GUI, an http server, and stdio invocation all within a single app. 
  The thought is external simplicy to the user with no node dependencies or separate services required.
  Whether or not this is worth the complexity below...we'll see. If it becomes cumbersome 
  the code is modular enough to strip down to a simple app/server with stdio shims.
  Btw, this should all work within the contraints of a sandboxed app. :)

"Smart App" / Proxy Mode Architecture

================================================================================
                        App Startup Decision Tree
================================================================================

CASE 1: Normal GUI Launch (User double-clicks the app)

The goal is to ensure only one instance of the GUI app is running.

1. CHECK FOR AN EXISTING GUI INSTANCE:
   * The app looks for a valid server.json with a live PID.
   
   * IF FOUND: Another instance is already running. Bring its window to the 
     front and terminate this new, redundant instance.
   
   * IF NOT FOUND (or Stale): Delete any stale file. This instance will 
     become the primary one.

2. BECOME THE PRIMARY GUI SERVER:
   * Initialize all services (AudioManager, HTTPServer, etc.).
   * Start the HTTPServer.
   * On successful server start, write server.json with its port and PID.
   * Show the main application window.
   * The app is now running and ready. The StdioServer is NOT used.

================================================================================

CASE 2: Launched with --stdio (LLM client runs the command)

The goal is to ENSURE A GUI SERVER IS RUNNING AND THEN ACT AS A PROXY TO IT. 
This process will NEVER show its own UI.

1. CHECK FOR AN EXISTING GUI INSTANCE:
   * The process immediately looks for a valid server.json with a live PID.
   
   * IF FOUND: A server is already running and ready.
      * ACTION: Proceed directly to the "Become a Proxy" step below.
   
   * IF NOT FOUND (or Stale): No server is running. The app must be launched 
     first.
      * ACTION: Proceed to the "Launch and Discover" step.

2. LAUNCH AND DISCOVER (The "Server is Not Running" Path):
   * This --stdio process now takes responsibility for starting the main app.
   
   * LAUNCH GUI APP: It executes the system command to open the application 
     bundle (e.g., open /path/to/RiffMCP.app). This is equivalent to the user 
     double-clicking the icon.
   
   * ENTER DISCOVERY LOOP: The --stdio process now waits for the GUI app to 
     finish its startup. It enters a loop with a timeout (e.g., 15 seconds).
      * Inside the loop, it checks every ~200ms for the appearance of a valid 
        server.json file.
   
   * DISCOVERY SUCCESS: As soon as it finds the valid server.json written by 
     the newly launched GUI app, it breaks the loop.
      * ACTION: Proceed to the "Become a Proxy" step.
   
   * DISCOVERY FAILURE: If the loop times out and no valid server.json 
     appears, the GUI app has failed to launch correctly.
      * ACTION: The --stdio process should write a clear error to stderr and 
        exit(1). This signals failure to the LLM client.

3. BECOME A PROXY (The Final Step in All --stdio Scenarios):
   * At this point, a GUI server is guaranteed to be running, and a valid 
     server.json exists.
   * The process reads the port number from the file.
   * It does NOT initialize its own services or UI.
   * It runs the lightweight bridge logic:
      * Loop:
         * Read a full JSON-RPC message from stdin.
         * Forward it via HTTP POST to the discovered server port.
         * Wait for the HTTP response.
         * Write the full response message back to stdout.
   * When the LLM client closes the stdin pipe (signaling the end of the 
     conversation), the loop terminates, and the proxy process calls exit(0).

================================================================================
                    Visual Flowchart (--stdio Process Only)
================================================================================

This flowchart illustrates the logic for a process launched WITH THE --stdio FLAG:

[ --stdio Process Starts ]
           |
           V
[ Check for valid server.json ] -----(Yes)-----> [ Go to "Become a Proxy" ]
           |
          (No)
           |
           V
[ Launch Main GUI App (e.g., `open RiffMCP.app`) ]
           |
           V
[ Enter Discovery Loop (timeout: 15s) ]
           |
           |--> Check for valid server.json every 200ms
           |
           V
[ server.json found? ] -----(No / Timeout)-----> [ Log error to stderr, exit(1) ]
           |
          (Yes)
           |
           V
[ Become a Proxy ]
           |
           |--> Read port from server.json
           |--> Loop:
           |    - Read from stdin
           |    - Forward via HTTP
           |    - Write response to stdout
           |
           V
[ stdin closes, exit(0) ]

================================================================================