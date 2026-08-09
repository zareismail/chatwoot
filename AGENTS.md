# Chatwoot Development Guidelines

`AGENTS.md` is the single guidance file for every coding agent working in this repository, and the only one to edit. `CLAUDE.md` imports it with `@AGENTS.md`, and `.windsurf/rules/chatwoot.md` is a symlink to it — so a tool that expects its own path still reads these guidelines, and there is never a second version to keep in sync.

This repo is the **ragham** fork of Chatwoot. Working branch is `ragham`; `develop` is the upstream-tracking base branch.

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed` (quickly populates minimal data for standard feature verification)
- **Seed Search Test Data**: `bundle exec rails search:setup_test_data` (bulk fixture generation for search/performance/manual load scenarios)
- **Seed Account Sample Data (richer test data)**: `Seeders::AccountSeeder` is available as an internal utility and is exposed through Super Admin `Accounts#seed`, but can be used directly in dev workflows too:
  - UI path: Super Admin → Accounts → Seed (enqueues `Internal::SeedAccountJob`).
  - CLI path: `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"` (or call `Seeders::AccountSeeder.new(account: Account.find(<id>)).perform!` directly).
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Single JS Test**: `pnpm test app/javascript/dashboard/path/to/file.spec.js` (vitest specs are colocated next to the source, or under a `specs/` folder)
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **E2E**: Playwright lives in `tests/playwright/` with its own `package.json`/lockfile — install and run from inside that directory (see `tests/playwright/README.md`)
- **Run Project**: `overmind start -f Procfile.dev` (or `make run` / `make force_run` to clear stale sockets & ports first)
- **Attach to a process**: `make debug` (backend) / `make debug_worker` (sidekiq)
- **Rails console**: `bundle exec rails console`
- **Component stories**: `pnpm story:dev` (Histoire)
- **Build the embed SDK**: `pnpm build:sdk` (separate Vite lib build, `vite.lib.config.ts`)
- **Ruby Version**: Manage Ruby via `rbenv` and install the version listed in `.ruby-version` (e.g., `rbenv install $(cat .ruby-version)`)
- **rbenv setup**: Before running any `bundle` or `rspec` commands, init rbenv in your shell (`eval "$(rbenv init -)"`) so the correct Ruby/Bundler versions are used
- Always prefer `bundle exec` for Ruby CLI tasks (rspec, rake, rubocop, etc.)

## Architecture

Rails 7.1 monolith (Ruby 3.4.4) serving a JSON API + several independent Vue 3 SPAs bundled by Vite (`vite-plugin-ruby`). Postgres + Redis; background work on Sidekiq.

### Backend layering

Business logic is deliberately spread across object roles rather than fat models/controllers. Before adding code to a model or controller, check which role it belongs in:

- `app/builders/` — construct aggregates (`ConversationBuilder`, `Messages::*`, `ContactInboxBuilder`). Anything creating a conversation/message from an inbound event goes here.
- `app/finders/` — list queries and filtering (`ConversationFinder`, `MessageFinder`, `NotificationFinder`).
- `app/services/` — provider/integration logic, one directory per channel or vendor (`whatsapp/`, `twilio/`, `facebook/`, `email/`, …) plus cross-cutting services (`FilterService`, `SearchService`, `ActionService`).
- `app/jobs/` — Sidekiq jobs. Queues are strictly priority-ordered in `config/sidekiq.yml` (`critical` → `housekeeping`); pick a queue deliberately.
- `app/policies/` — Pundit authorization.
- `app/listeners/` — event handlers (see below).

### Event pipeline

This is the backbone of realtime and integrations. Code emits `Dispatcher.dispatch(event_name, timestamp, data)`; `Dispatcher` fans out to both `SyncDispatcher` (in-process) and `AsyncDispatcher` (via `EventDispatcherJob`). Listeners in `app/listeners/` are singletons with one method per event name:

- `ActionCableListener` → pushes to the dashboard/widget over websockets
- `WebhookListener` / `HookListener` / `InstallationWebhookListener` → outbound integrations
- `NotificationListener`, `AutomationRuleListener`, `CampaignListener`, `CsatSurveyListener`, `ReportingEventListener`

When adding a new domain event: dispatch it, then add a method of the same name to every listener that should react. Do not reach across into another listener's concern.

### Multi-tenancy, inboxes and channels

`Account` is the tenant root; almost every model belongs to an account and API routes are nested under `/api/v1/accounts/:account_id/`. `Inbox` is the account-facing entity and `belongs_to :channel, polymorphic: true`; each concrete channel lives in `app/models/channel/` (`web_widget`, `whatsapp`, `email`, `facebook_page`, `instagram`, `telegram`, `line`, `sms`, `twilio_sms`, `twitter_profile`, `tiktok`, `api`) and mixes in `Channelable`. Adding a channel touches: channel model + migration, a service namespace under `app/services/<provider>/` for send/receive, an inbound webhook controller, and a frontend inbox-settings view.

Feature gating is per-account: flags are declared in `config/features.yml` (order is significant — never reorder) and checked with `account.feature_enabled?('name')`.

### API surfaces

- `/api/v1/accounts/:account_id/...` and `/api/v2/accounts/...` — agent dashboard API (user auth)
- `/api/v1/widget/...` — live-chat widget, authenticated by contact pubsub token
- `/public/api/v1/...` — help center / portal
- `/platform/api/v1/...` — platform apps provisioning API
- `/webhooks/...`, plus per-provider controllers (`app/controllers/twilio`, `instagram`, `google`, `shopify`, …)
- API docs source lives in `swagger/` (assembled into `swagger/swagger.json`)

### Enterprise overlay mechanism

`config/initializers/01_inject_enterprise_edition_module.rb` patches `Module` with `prepend_mod_with` / `include_mod_with` / `extend_mod_with`. An OSS class ends with e.g. `prepend_mod_with('ConversationPolicy')`, and if `enterprise/` is loaded (`ChatwootApp.extensions`), `Enterprise::ConversationPolicy` from `enterprise/app/...` is prepended. Enterprise-only features (Captain AI, SLA, custom roles, voice/Twilio calling, SAML, audit logs) live entirely under `enterprise/`. See the Enterprise Edition Notes section below for the working rules.

### Frontend

Eight Vite entrypoints in `app/javascript/entrypoints/`, each a distinct app mounted from an ERB layout:

| Entrypoint | App | Source |
| --- | --- | --- |
| `dashboard.js` | agent dashboard | `app/javascript/dashboard` |
| `v3app.js` | auth/login/onboarding shell (chosen by `DashboardController#set_application_pack`) | `app/javascript/v3` |
| `widget.js` | live-chat widget (runs inside an iframe) | `app/javascript/widget` |
| `sdk.js` | embed script that injects the widget iframe on customer sites | `app/javascript/sdk` |
| `portal.js` | public help center | `app/javascript/portal` |
| `survey.js` | CSAT survey page | `app/javascript/survey` |
| `superadmin.js`, `superadmin_pages.js` | Administrate-based super admin | `app/javascript/superadmin_pages` |

Dashboard state is mid-migration: legacy Vuex modules in `dashboard/store/modules/` coexist with Pinia stores in `dashboard/stores/`. **New state goes in Pinia.** Likewise `dashboard/components/` is legacy and `dashboard/components-next/` is the target for new UI.

Path aliases (defined once in `vite.shared.ts`, shared by `vite.config.ts` and `vitest.config.ts`): `dashboard`, `next` (→ components-next), `components`, `shared`, `widget`, `survey`, `v3`, `helpers`, `assets`.

## Deployment (ragham)

- `bash deploy/docker.sh` builds `docker/Dockerfile` and pushes to `registry.hamdocker.ir/raghamapp/chatwoot` with a date tag (`YYYY-MM-DD_HH-MM`). It refuses to run with a dirty working tree.
- The `app` and `sidekiq` pods share the same image — bump the tag in both, restart, then run migrations if the release includes any.

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- Prefer the smallest production-ready change that solves the current problem.
- Build for the expected production path first. Do not add speculative guards, fallbacks, retries, or edge-case handling unless the caller can actually hit that case or production has proven it necessary.
- When an impossible or misconfigured state would indicate a setup/deployment bug, let it fail loudly instead of silently skipping behavior.
- For locked/internal configs that must exist in production, prefer direct reads (`find`, `find_by!`, required hash keys) over silent fallbacks.
- Do not add validation or response checks unless the code uses the result or the check changes behavior meaningfully.
- Prefer existing repo dependencies/client libraries over hand-rolled protocol code for auth, signing, parsing, or API plumbing.
- Avoid one-use private helpers unless they hide real complexity or make the main flow meaningfully easier to read.
- Prefer minimal, readable code over elaborate abstractions; clarity beats cleverness
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- In specs, avoid custom helper methods for setup/data. Prefer `let` values and direct per-example setup; only add a helper when it removes meaningful repeated complexity.
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Prefer `with_modified_env` (from spec helpers) over stubbing `ENV` directly in specs
- Specs in parallel/reloading environments: prefer comparing `error.class.name` over constant class equality when asserting raised errors

## Codex Worktree Workflow

- Use a separate git worktree + branch per task to keep changes isolated.
- Keep Codex-specific local setup under `.codex/` and use `Procfile.worktree` for worktree process orchestration.
- The setup workflow in `.codex/environments/environment.toml` should dynamically generate per-worktree DB/port values (Rails, Vite, Redis DB index) to avoid collisions.
- Start each worktree with its own Overmind socket/title so multiple instances can run at the same time.

## Commit Messages

- **Never commit without explicit acceptance.** Finish the change, verify it, report what
  is left in the working tree, and stop. Wait for the user to say "commit it" (or
  equivalent) before running `git commit`. The same applies to `git push` — approval to
  commit is not approval to push.
- Commit with explicit pathspecs (`git commit -o <files>`), never `git commit -a` or
  `git add .`, so deliberately-dirty files are not swept in. `docker/entrypoints/vite.sh`
  in particular must stay modified-but-uncommitted.
- Prefer Conventional Commits: `type(scope): subject` (scope optional)
- Example: `feat(auth): add user authentication`
- Don't reference Claude in commit messages

## Changelog

- **Every user-facing change gets an entry in `CHANGELOG.md`**, written as part of the
  change rather than afterwards.
- Group entries by the date the work landed, newest first, then by surface
  (Widget / Dashboard / Backend / Android app) and by `Added` / `Changed` / `Fixed` /
  `Removed`.
- Describe the behaviour the user sees and why it changed, not the implementation. Name
  the symptom a fix removes.
- Call out anything that silently changes behaviour — a removed setting, a dropped
  grouping — under `Removed`, since nobody gets an error for relying on it.
- Record constraints a reader would otherwise hit: what a fix depends on, and where a
  change needs a deploy or a companion Android build to take effect.
- Skip housekeeping with nothing user-facing: formatting passes, reindents, README tweaks.

## PR Description Format

- Start with a short, user-facing paragraph describing the product change.
- Add a `Closes` section with relevant issue links (GitHub, Linear, etc.).
- For feature PRs, add `How to test` from a product/UX standpoint.
- For bugfix PRs, use `How to reproduce` when helpful.
- Optionally add a `What changed` section for implementation highlights.
- Do not add a `How this was tested` section listing specs/commands.

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- When modifying existing OSS features for Enterprise-only behavior, add an Enterprise module (via `prepend_mod_with`/`include_mod_with`) instead of editing OSS files directly—especially for policies, controllers, and services. For Enterprise-exclusive features, place code directly under `enterprise/`.

## Branding / White-labeling note

- For user-facing strings that currently contain "Chatwoot" but should adapt to branded/self-hosted installs, prefer applying `replaceInstallationName` from `shared/composables/useBranding` in the UI layer (for example tooltip and suggestion labels) instead of adding hardcoded brand-specific copy.
