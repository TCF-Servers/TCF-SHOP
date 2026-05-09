# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

TCF-SHOP is a Rails 7.1 app (Ruby 3.3.5, PostgreSQL) tied to an ARK: Survival Ascended community. It runs **two coupled processes**:

- `web` — Rails/Puma app serving a public ranking page, an authenticated admin dashboard, and a CRUD UI for RCON command templates.
- `worker` — a long-lived Discord bot (`bundle exec rails discord:start`) that listens to two specific Discord channels and writes to the same DB.

Both processes share the Player/Vote/GameSession models. The bot is the *write side* (ingests events from Discord, dispatches RCON commands to the game servers); the web app is mostly the *read side* (rankings, dashboard) plus admin-only RCON template management.

## Common commands

```bash
# Setup
bin/setup                         # bundle install + db:prepare + log/tmp clear + restart
bin/rails db:create db:migrate    # bare DB setup
bin/rails db:seed

# Run locally (two processes — both are required for full behavior)
bin/rails server                  # web only
bundle exec rails discord:start   # Discord worker (lib/tasks/discord_bot.rake)
# or run both via Procfile with foreman/overmind:
#   foreman start

# Tests / lint
bin/rails test                    # full suite
bin/rails test test/models/player_test.rb
bin/rails test test/models/player_test.rb:42   # single test by line
bundle exec rubocop               # lint (config in .rubocop.yml, line length 120)

# Maintenance rake tasks
bin/rails cleanup:old_votes        # interactive: deletes votes older than 2 months
bin/rails cleanup:old_votes_force  # same, no prompt

# Docker (full stack: db + web + worker)
docker compose up --build
```

## Required environment

The Discord bot will not function without these (see `docker-compose.yml` and `lib/tasks/discord_bot.rake`):

- `DISCORD_BOT_TOKEN`, `VOTE_CHANNEL_ID`, `JOINLEAVE_CHANNEL_ID`
- `RCON_HOST`, `RCON_PASSWORD`, `RCON_TIMEOUT` (default 5s)
- One RCON port per ARK map: `ISLAND_WP_RCON_PORT`, `SCORCHED_EARTH_WP_RCON_PORT`, `CENTER_WP_RCON_PORT`, `ABERRATION_WP_RCON_PORT`, `EXTINCTION_WP_RCON_PORT`, `ASTRAEOS_WP_RCON_PORT`, `RAGNAROK_WP_RCON_PORT`, `VALGUERO_WP_RCON_PORT`, `LOST_COLONY_WP_RCON_PORT`

Loaded via `dotenv-rails` in dev/test from `.env`. Note: `.env` is committed and contains live-looking secrets — treat that as project state, but avoid echoing those values in commits, PRs, or chat output.

## Architecture

### Discord ingestion → RCON dispatch (`lib/tasks/discord_bot.rake`)

The rake task is the heart of the system. It opens a `Discordrb::Bot` and routes every message based on `event.channel.id`:

- **JOINLEAVE channel**: parses `**PlatformName:** \`...\``-style fields out of join/leave messages. On `Player logged in`, it `find_or_initialize_by(eos_id:)`, updates the player record, calls `player.connect!(map_name)`, and **replays unprocessed votes** for that player. On `Player logged off`, calls `player.disconnect!`.
- **VOTE channel**: detects `"vient de voter pour le serveur"` messages, resolves the player via `Player.search_by_name` (pg_search trigram), enforces a rate limit via `player.can_vote?(VOTE_PERIOD_HOURS=2, MAX_VOTES_PER_PERIOD=3)` with a 5-minute grace, creates a `Vote`, and dispatches `AddPoints <eos_id> <points>` over RCON.

RCON dispatch picks the port from `MAP_PORTS` keyed by `player.current_map`, falling back to `ISLAND_WP_RCON_PORT`. Calls are wrapped in `Timeout::timeout(RCON_TIMEOUT)`. Vote replay uses a small thread pool (max 3 concurrent threads) and only flips `vote.processed = true` after the RCON call succeeds — failed dispatches stay unprocessed for the next login replay. The whole bot loop is wrapped in `rescue => e; sleep 30; retry`-style logic plus a heartbeat thread that triggers a restart if the bot thread dies.

The bot is **single-instance by design**: running two workers would double-credit votes. Honor that when configuring deployments.

### Domain model

- `Player` ↔ `GameSession` (`has_one`, single in-flight session per player; `connect!` / `disconnect!` flip `online` and `map_name`).
- `Player` ↔ `Vote` (`has_many`, plus `has_many :valid_votes`). `votes_count` is denormalized and incremented after a successful RCON dispatch; reads should generally go through `valid_votes` because invalid votes (rate-limit overflow, unauthorized in-game name) are also persisted.
- `Vote.current_month_points` ramps the per-vote payout based on global monthly vote volume (1k/2.5k/5k/7.5k/10k thresholds, multipliers 1.10×–2.00× over a 150 base). Changing thresholds changes economy balance — surface that explicitly in any PR.
- `User` (Devise) has an `enum role: { user: 0, admin: 1, superadmin: 2 }`. Authorization is Pundit (`ApplicationController` calls `verify_authorized`/`verify_policy_scoped` after each action; bypass list lives in `skip_pundit?`).
- `RconCommandTemplate` + `RconExecution` model the admin-driven RCON UI: templates carry `{placeholder}` slots filled by `build_command(params)`; executions log who ran what against which player on which map.

### Web surface

- `pages#ranking` (root, public) — current and previous month leaderboards, `Player.joins(:valid_votes).group(...).order("COUNT(votes.id) DESC").limit(50)`.
- `dashboard#index` (admin+) — online player count/list, today's vote/command totals, recent `RconExecution` log.
- `admin/rcon_command_templates` (superadmin only) — Turbo-Stream CRUD; partials are re-rendered into the index list.

### Auth & access

- Devise for users; `ApplicationController` requires login by default (`skip_before_action :authenticate_user!` only on `home`, `ranking`, `healthcheck`).
- `DashboardPolicy#index?` → admin or superadmin.
- `RconCommandTemplatePolicy` → superadmin only for everything.

### Search

`Player` includes `PgSearch::Model` with a `search_by_name` scope using `tsearch (prefix, any_word)` + `trigram (threshold 0.3)`. Requires the `pg_trgm` extension (migration `20250521164331_add_pg_trigram_extension.rb`). The bot's `Player.search_by_name(player_name).first` is the lookup that maps a Discord vote message to a DB player.

### Realtime

ActionCable runs on `solid_cable` in both development and production (see `config/cable.yml`); Redis is referenced as a fallback URL but the adapter is solid_cable. No separate Redis service is set up in `docker-compose.yml`.

## Conventions to keep in mind

- The codebase, comments, and user-facing strings (flash messages, dashboards) are in **French** — match that when adding UI copy.
- Discord message parsing relies on **exact regex shapes** (`**PlatformName:** \`...\``, `**EOS:** \`...\``, `vient de voter pour le serveur`). If the upstream Discord plugin changes its format, the bot silently stops processing — there's no schema validation.
- `UNAUTHORIZED_IN_GAME_NAME` (in `discord_bot.rake`) blocks generic placeholder names like "survivor"/"joueur" from earning votes; new generic aliases go there.
- RuboCop config (`.rubocop.yml`) excludes `bin/`, `db/`, `config/`, `test/` and disables `Style/StringLiterals`, `Style/FrozenStringLiteralComment`, `Style/Documentation`, `Layout/LineLength` capped at 120.
