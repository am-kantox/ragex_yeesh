# RagexYeesh

Browser-based terminal interface for [Ragex](https://github.com/Oeditus/ragex) code analysis tools, built with [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) and the [Yeesh](https://github.com/Oeditus/yeesh) terminal component.

RagexYeesh wraps every Ragex Mix task into an interactive web terminal, complete with tab-completion, command history, rich help output, and async execution for long-running analyses. It is designed to run inside the Oeditus Docker pipeline, analyzing a mounted codebase via a single browser tab.

## Architecture

```
Browser (xterm.js)  <-->  Phoenix LiveView  <-->  Yeesh terminal  <-->  Ragex Mix tasks
                                                       |
                                              RagexCommand macro
                                          (path injection, async, help)
```

On startup, the application:

1. Resolves the **working directory** (env var, config, or `cwd`).
2. Starts the Ragex OTP application (loads the Bumblebee embedding model).
3. Pre-analyzes the working directory in the background so the knowledge graph and embeddings are warm before the first interactive command.

## Setup

### Prerequisites

- Elixir >= 1.18
- Erlang/OTP (compatible with Elixir 1.18)
- Node.js >= 20 (for esbuild/tailwind asset compilation)

### Local Development

```sh
# Clone and enter the project
git clone https://github.com/Oeditus/ragex_yeesh.git
cd ragex_yeesh

# Install dependencies and build assets
mix setup

# Set the target codebase (optional, defaults to cwd)
export RAGEX_WORKING_DIR=/path/to/your/project

# Start the Phoenix server
mix phx.server
```

The terminal is available at [http://localhost:4000](http://localhost:4000).

### Docker

The included `Dockerfile` builds a self-contained image with all dependencies, pre-downloaded ML models, and compiled assets.

```sh
docker build -t ragex_yeesh .

docker run -it --rm \
  -p 4000:4000 \
  -v /path/to/your/project:/workspace \
  -e RAGEX_WORKING_DIR=/workspace \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -e PHX_SERVER=true \
  ragex_yeesh
```

Mount the codebase you want to analyze at `/workspace` (or any path matching `RAGEX_WORKING_DIR`).

### Environment Variables

| Variable             | Description                                         | Default            |
|----------------------|-----------------------------------------------------|--------------------|
| `RAGEX_WORKING_DIR`  | Absolute path to the codebase under analysis        | `File.cwd!()`      |
| `DEEPSEEK_API_KEY`   | API key for the DeepSeek AI provider                | --                 |
| `SECRET_KEY_BASE`    | Phoenix secret key (required in prod)               | --                 |
| `PORT`               | HTTP port                                           | `4000`             |
| `PHX_SERVER`         | Set to `true` to start the HTTP server              | --                 |
| `PHX_HOST`           | Hostname for URL generation (prod)                  | `localhost`        |

## Commands

All commands below are available in the browser terminal. Type `help` for a summary list or `help <command>` for detailed usage pulled from the underlying Mix task documentation.

The `--path` flag is automatically injected by the application for commands that accept it; user-supplied `--path` / `-p` values are silently stripped.

### Analysis

#### `analyze`

Analyze source files and build the knowledge graph. Runs asynchronously.

```
analyze [options]
```

Options:
- `--format FORMAT` -- Output format: `text`, `json`, `markdown` (default: `text`)
- `--output FILE` -- Write results to a file instead of the terminal
- `--security` -- Include security vulnerability scanning
- `--business-logic` -- Include business logic analysis (20 analyzers)
- `--complexity` -- Include complexity analysis
- `--smells` -- Include code smell detection
- `--duplicates` -- Include duplication detection
- `--dead-code` -- Include dead code analysis
- `--dependencies` -- Include dependency analysis
- `--quality` -- Include quality metrics
- `--all` -- Include all analyses (default when no specific flags are given)
- `--severity LEVEL` -- Minimum severity: `low`, `medium`, `high`, `critical` (default: `medium`)
- `--threshold FLOAT` -- Duplication threshold 0.0--1.0 (default: `0.85`)
- `--min-complexity INT` -- Minimum complexity to report (default: `10`)
- `--verbose` -- Show detailed progress
- `--with-empty` / `--without-empty` -- Include/exclude empty issue categories (default: `--without-empty`)

#### `audit`

Run a comprehensive AI-powered code audit. Combines static analysis with an AI-generated professional report. Runs asynchronously, streaming results back to the terminal.

```
audit [options]
```

Options:
- `--format FORMAT` -- `json` (default in Mix) or `markdown`
- `--dead-code` -- Include dead-code analysis
- `--provider PROVIDER` -- AI provider override: `deepseek_r1`, `openai`, `anthropic`, `ollama`
- `--model MODEL` -- Model name override

### Interactive

#### `chat`

Interactive codebase Q&A powered by RAG (Retrieval-Augmented Generation).

```
chat [options]
```

Options:
- `--provider PROVIDER` -- AI provider: `deepseek_r1`, `openai`, `anthropic`, `ollama`
- `--model MODEL`, `-m` -- Model name override
- `--strategy STRATEGY`, `-s` -- Retrieval strategy: `fusion`, `semantic_first`, `graph_first`
- `--dead-code` -- Enable dead code analysis
- `--skip-analysis` -- Skip initial codebase analysis (use existing graph data)

Once inside the chat session, type `/help` for interactive sub-commands.

#### `refactor`

Interactive refactoring wizard with operation selection and diff preview.

```
refactor [options]
```

When launched without flags, presents an interactive TUI. Supported operations:
- `rename_function` -- Rename a function across call sites
- `rename_module` -- Rename a module and update references
- `change_signature` -- Modify function parameters
- `extract_function` -- Extract code into a new function
- `inline_function` -- Inline function body into call sites

Direct mode (non-interactive, `rename_function` only):
- `--operation OP` -- Operation name
- `--module MOD` -- Module name
- `--function FN` -- Function name
- `--arity N` -- Function arity
- `--new-name NAME` -- New function name

#### `configure`

Interactive configuration wizard for Ragex settings. Creates a `.ragex.exs` file.

```
configure [options]
```

Options:
- `--show`, `-s` -- Display the current configuration

Covers project type detection, embedding model selection, AI provider setup, analysis exclusions, and cache settings.

#### `dashboard`

Live monitoring dashboard showing real-time Ragex metrics in a TUI.

```
dashboard [options]
```

Options:
- `--interval MS`, `-i` -- Refresh interval in milliseconds (default: `1000`)

Displays: graph statistics, embedding metrics, cache performance, AI usage tracking, and recent activity.

### Cache Management

#### `cache-stats`

View embedding cache statistics (model, dimensions, entity count, disk usage).

```
cache-stats [options]
```

Options:
- `--all` -- Show information about all cached projects

#### `cache-clear`

Clear the embedding cache.

```
cache-clear [options]
```

Options:
- `--current` -- Clear cache for the current project only
- `--all` -- Clear all cached projects
- `--older-than DAYS` -- Clear caches older than N days
- `--force` -- Skip confirmation prompt

#### `cache-refresh`

Refresh the embedding cache incrementally. Runs asynchronously.

```
cache-refresh [options]
```

Options:
- `--full` -- Perform a full refresh (re-analyze all files)
- `--incremental` -- Incremental refresh (default; only changed files)
- `--stats` -- Show detailed statistics after refresh

### AI Management

#### `ai-usage`

View AI provider usage statistics and costs.

```
ai-usage [options]
```

Options:
- `--provider PROVIDER` -- Show stats for a specific provider only

#### `ai-cache-stats`

View AI response cache statistics (hit rates, size, usage by operation).

```
ai-cache-stats
```

No additional options.

#### `ai-cache-clear`

Clear the AI response cache.

```
ai-cache-clear [options]
```

Options:
- `--operation OP` -- Clear cache for a specific operation only (e.g. `query`, `explain`)

### Models & Setup

#### `embeddings-migrate`

Migrate embeddings when changing embedding models.

```
embeddings-migrate [options]
```

Options:
- `--check`, `-c` -- Check current model and embedding compatibility
- `--model MODEL_ID`, `-m` -- Migrate to specified model
- `--force`, `-f` -- Force migration even if dimensions are compatible
- `--clear` -- Clear all embeddings

Available model IDs: `all_minilm_l6_v2` (384d, default), `all_mpnet_base_v2` (768d), `codebert_base` (768d), `paraphrase_multilingual` (384d).

#### `models-download`

Pre-download Bumblebee ML models for offline use.

```
models-download [options]
```

Options:
- `--all` -- Download all available models
- `--models LIST` -- Comma-separated model IDs to download
- `--cache-dir DIR` -- Custom cache directory (overrides `BUMBLEBEE_CACHE_DIR`)
- `--quiet` -- Suppress informational output

#### `completions`

Install shell completion scripts for Ragex Mix tasks.

```
completions [options]
```

Options:
- `--install`, `-i` -- Auto-detect shell and install
- `--shell SHELL`, `-s` -- Target shell: `bash`, `zsh`, `fish`

#### `install-man`

Install Ragex man pages to the system.

```
install-man [options]
```

Options:
- `--install`, `-i` -- Install man pages (may require sudo)

### Built-in Yeesh Commands

In addition to the Ragex commands above, the terminal provides:

- `help` -- List all available commands
- `help <command>` -- Show detailed usage for a command
- `mix <task>` -- Run any arbitrary Mix task (enabled in dev and prod)
- `clear` / `Ctrl+L` -- Clear the terminal screen
- `Ctrl+C` -- Interrupt the current command
- **Tab** -- Autocomplete commands
- **Up/Down** -- Navigate command history

## Working Directory Configuration

All path-aware commands operate on a single working directory, resolved once at startup in the following order:

1. `RAGEX_WORKING_DIR` environment variable
2. `:ragex_yeesh, :working_dir` application config
3. `File.cwd!()`

The resolved path is expanded to an absolute path and stored for the session. To change it, restart the application with a new value.

## License

See `LICENSE` for details.
