import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/ragex_yeesh"
import topbar from "../vendor/topbar"
import {YeeshTerminal as _YeeshTerminal} from "yeesh/assets/js/yeesh/hook.js"

// Wrap the upstream hook so the xterm Terminal instance is accessible
// from the AsyncBridge hook (needed to push async task output).
const YeeshTerminal = {
  ..._YeeshTerminal,
  mounted() {
    _YeeshTerminal.mounted.call(this);
    // Publish the terminal reference for sibling hooks.
    window.__ragexTerm = this.term;
    window.__ragexPrompt = () => this.prompt;
  },
};

// Receives push_event from TerminalLive.handle_info and writes
// directly to the xterm instance exposed above.
const AsyncBridge = {
  mounted() {
    // --- One-shot output (legacy / non-streamed commands) ---
    this.handleEvent("ragex:async_output", ({ output }) => {
      const term = window.__ragexTerm;
      if (term && output && output.length > 0) {
        const formatted = output.replace(/(?<!\r)\n/g, "\r\n");
        term.writeln(formatted);
        const prompt = window.__ragexPrompt ? window.__ragexPrompt() : "ragex> ";
        term.write(prompt);
      }
    });

    this.handleEvent("ragex:async_error", ({ error }) => {
      const term = window.__ragexTerm;
      if (term) {
        term.writeln("\x1b[31merror: \x1b[0m" + error);
        const prompt = window.__ragexPrompt ? window.__ragexPrompt() : "ragex> ";
        term.write(prompt);
      }
    });

    // --- Streaming output (throttled chunks from audit/chat) ---
    //
    // Raw chunks are written to xterm for real-time feedback.  When the
    // stream finishes the server sends a Marcli-rendered version of the
    // full response; we erase the raw text and replace it.
    let streamStartAbsRow = null;

    this.handleEvent("ragex:stream_chunk", ({ text }) => {
      const term = window.__ragexTerm;
      if (term && text) {
        if (streamStartAbsRow === null) {
          const buf = term.buffer.active;
          streamStartAbsRow = buf.baseY + buf.cursorY;
        }
        const formatted = text.replace(/(?<!\r)\n/g, "\r\n");
        term.write(formatted);
      }
    });

    this.handleEvent("ragex:stream_done", ({ formatted }) => {
      const term = window.__ragexTerm;
      if (term) {
        if (formatted && streamStartAbsRow !== null) {
          // Calculate how many rows the raw stream occupies
          const buf = term.buffer.active;
          const currentAbsRow = buf.baseY + buf.cursorY;
          const lines = currentAbsRow - streamStartAbsRow;

          if (lines > 0) {
            // Move cursor to stream start and clear everything below
            term.write(`\x1b[${lines}A\r\x1b[J`);
          } else {
            // Same line -- just clear the line
            term.write("\r\x1b[K");
          }

          // Write the Marcli-rendered replacement
          const fmtText = formatted.replace(/(?<!\r)\n/g, "\r\n");
          term.write(fmtText);
        }

        term.writeln("");
        const prompt = window.__ragexPrompt ? window.__ragexPrompt() : "ragex> ";
        term.write(prompt);
        streamStartAbsRow = null;
      }
    });
  },
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Ragex analysis tasks (audit, analyze) can run for several minutes.
// The default 30 s heartbeat would kill the WebSocket while the
// LiveView process is blocked in synchronous command execution.
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  heartbeatIntervalMs: 600_000,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, YeeshTerminal, AsyncBridge},
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
