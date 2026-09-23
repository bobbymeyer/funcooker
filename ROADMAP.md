# roadmap

Rails app to reduce the time/stress cost of feeding the household: a recipe
library, a stock/inventory system modeled loosely on restaurant kitchen
management, and a scheduler that ties them together.

## principles

- **Stock stays lean, dishes stay varied.** Variety comes from how a small,
  stable set of ingredients/components combine, not from a large rotating
  pantry.
- **Flexibility over fidelity.** Ingredient substitution is simple and flat.
  No weighting/ranking substitutes by closeness.
- **The schedule is derived, not committed.** Re-derive after disruption (a
  missed night, a refused dish) rather than manually repairing a weekly plan.
- **A prepped batch is inventory**, not just a completed task. Prepping a
  component produces a stock item with its own shelf life, on the same
  footing as a raw ingredient.
- **Prefer existing tools over custom UI** where a good one exists (shopping
  list → iOS Reminders).

## tech

- Omakase Rails: ActiveRecord, Hotwire/Turbo/Stimulus, server-rendered views.
  No separate API/SPA layer.
- UI on [its-swiss](https://github.com/bobbymeyer/its-swiss).
- Recipe import and receipt parsing use LLM calls with a fixed, constrained
  output schema (structured extraction; generation only for simple dishes).

## data model

| Model | Fields / role |
| --- | --- |
| `Ingredient` | Canonical raw item — `name`, `category`, `default_unit`, `pack_size` (in the default unit), optional `ingredient_family` |
| `IngredientFamily` | Flat, unranked set of interchangeable `Ingredient`s (e.g. "alliums": shallot, red onion, yellow onion). An ingredient belongs to at most one family |
| `Component` | Modular building block / sub-recipe — `name`, `description`, `source_url`, `shelf_life_days` once prepped (estimated by the model, `shelf_life_note` saying how). Has its own `Step`s. Nests inside other `Component`s through `ComponentPart` |
| Dish | A `Component` that is not the child of any other `Component`. Not a table or subclass: `Component.dishes`, `Component#dish?` |
| `ComponentPart` | Parent `Component` → child `Component`, `quantity`, `unit`, optional consuming `Step`. No cycles |
| `ComponentIngredient` | `Component` → exactly one of a locked `Ingredient` or a substitutable `IngredientFamily`, `quantity` for 1 adult, `unit`, `note`, optional consuming `Step` |
| `Step` | Belongs to a `Component`. `position`, `phase` (`prep`/`plate`), `mode` (`active`/`passive`), `duration_minutes`, `instructions` |
| `StockItem` | One lot. `stockable` (`Ingredient` or `Component`), `kind`, `quantity`, `unit`, `acquired_on`, `expires_on` |
| `StockTransaction` | `StockItem`, `delta`, `source` (`receipt`, `manual`, `step_consumption`, `step_production`), optional `Step` |
| `Decomposition` | `Component`, `status` (`pending`/`processing`/`succeeded`/`failed`/`declined`/`awaiting`/`dismissed`), the model's `verdict`, `reason` and `caveats`, a borderline `plan` waiting on a decision, and the recipe's ingredients and steps as they were before the rewrite |
| `CookingSession` | `kind` (`prep`/`plate`), `status` (`sequencing`/`ready`/`failed`/`done`), the `ScheduleEntry` for a plate session, notes on what stock could not be drawn |
| `PrepBatch` | `CookingSession`, `Component`, `servings`, the prepped `StockItem` it became |
| `CookingTask` | `CookingSession`, `Step`, `servings`, `position`, `cluster`, `started_at`, `completed_at` |
| `Receipt` | A photo or pasted text, `store`, `purchased_on`, `status` (`pending`/`processing`/`parsed`/`failed`/`confirmed`) |
| `ReceiptLine` | `Receipt`, `description` as printed, `ingredient_name`, `quantity`, `unit`, `expires_on`, `included`, the `StockItem` it became |
| `HouseholdMember` | `name`, `portion` (adult servings), `eats_by_default` |
| `MealDiner` | `ScheduleEntry` → `HouseholdMember`: who is eating that meal |
| `FoodNeed` | `HouseholdMember`, polymorphic `subject` (`Ingredient`, `IngredientFamily`, `Component`), `tier`: `restriction` or `preference`, `sentiment`: `likes` or `dislikes` |
| `ScheduleEntry` | `served_on`, `meal_slot` (`breakfast`/`lunch`/`dinner`), dish, `status` (`planned`/`served`/`skipped`/`swapped`), `origin` (`manual`/`derived`/`easy`), its diners. One active meal per slot |
| `ShoppingListItem` | Derived, not stored (`ShoppingList`): `ScheduleEntry` requirements minus on-hand `StockItem`s, rounded up to the `Ingredient`'s `pack_size`. Exported to iOS Reminders directly from the Mac (`osascript` and `lib/reminders/add.js`), by paste, or by a Shortcut reading `/shopping.json` |

### stock kinds

| `kind` | `stockable` |
| --- | --- |
| `raw` | `Ingredient` |
| `prepped` | `Component` |
| `frozen_meal` | A dish — the freezer bank |

### restrictions

The restrictions of everyone eating a `ScheduleEntry` apply to it. A new
entry seats everyone who eats by default; others are added per meal. There is
no override: a restriction is something they do not eat.

| Restricted subject | Violated by |
| --- | --- |
| `Component` | Any dish containing it, at any depth |
| `Ingredient` | A locked slot for that ingredient; a family slot only when every ingredient in the family is restricted |
| `IngredientFamily` | Any slot for the family, and any locked slot for one of its ingredients |

`preference` never violates.

## recipe importer

1. Fetch page → check for [schema.org/Recipe](https://schema.org/Recipe)
   JSON-LD → read name, description and steps directly if present.
2. If absent, send the page's text to the local model, constrained to the
   recipe JSON schema. Pasted text takes the same path. A photographed
   cookbook page takes it too, through a vision model.
3. Ingredient lines come back parsed as `{amount, unit, ingredient, note}`.
   From JSON-LD, only the ingredient lines go to the model.
4. A dish too simple for a recipe site or cookbook (pasta with jarred sauce,
   eggs and toast) can be named instead, and the model writes it for
   ingredient and component tracking. A sophistication scale sets how far it
   goes: divorced dad (the default — the simplest possible version, nothing
   clever or fancy), home cook, Michelin chef.
5. Recipes are always stored for 1 adult. The model reports how many adult
   servings the source makes; the import divides. Later steps scale up to
   whoever is eating.
6. Imported recipes land as a single `Component`. **Decompose** breaks one
   into reusable sub-components with the model, reusing an existing
   component when it is the same or very similar, and rewrites the recipe's
   steps as prep and plate to use them.
7. The model is served by llama-swap on the Studio, over its
   OpenAI-compatible API. Extraction runs as a background job.

Reference for site coverage/patterns:
[recipe-scrapers](https://github.com/hhursev/recipe-scrapers) (Python, not
necessarily a dependency).

## prep and plate

| | Prep | Plate |
| --- | --- | --- |
| When | Batched, whenever the schedule allows | At serving time |
| Consumes | Raw `Ingredient` stock | Mostly `Component` stock |
| Produces | A new `Component` `StockItem` | Nothing — marks the `ScheduleEntry` served |
| UI | Denser planning/table view | Minimal and scannable — large type, one step (or short stack) at a time, tap-to-complete |

- **Active vs. passive steps.** Active steps need hands/attention and can't
  overlap another active step. Passive steps (marinating, oven, resting) are
  scheduled early so their wait absorbs active work on something else.
- **Sequencing.** An LLM step groups/orders prep steps by technique/station
  and duration — long multi-step items first, quick tasks fill dead time —
  respecting active/passive parallelism. Walked through in a single-focus,
  multi-step wizard, one cluster/step at a time.
- **Passive step timer.** Persistent countdown strip above the active-step
  window showing remaining time on running passive steps; stacks when more
  than one is running.

## scheduling

- **Procedural:** greedy heuristic, not a full constraint solver. Candidates
  are `Component.schedulable_for(members)`: dishes that violate no member's
  restriction. Scores them by stock/component reuse, expiry pressure, repeat
  avoidance and `preference` weighting (likes and dislikes). The scheduler
  never schedules a restricted dish.
- Each entry records its origin: planner, hand, or the easy button. Deriving
  replaces the planner's planned entries and keeps the rest; a planner entry
  edited by hand becomes a hand entry. A skip re-derives the planner's
  entries after it.
- **Manual:** create `ScheduleEntry` rows by hand. One whose dish anyone
  eating it is restricted from fails validation and names them.
- The planner plans for those who eat by default. Each meal's servings are
  the sum of its diners' portions.
- The schedule re-derives after disruption. No rigid fixed week.

## freezer bank

- The "up next" dish shows as a card with an easy button ("I'm tired").
  Tapping it swaps the plan to a dish from the frozen meal bank instead of
  entering the scheduled dish's prep/plate flow. No separate energy-check
  step in the scheduler.
- Populated by batch-cooking: cook once, freeze half.
- Stored as `StockItem`s with `kind: frozen_meal`.

## ingredient families

- `IngredientFamily` groups interchangeable ingredients.
- A `ComponentIngredient` points at either a locked `Ingredient` (no swap) or
  an `IngredientFamily` (any member substitutable — stock availability picks
  the winner).
- Flat and unranked.

## stock, receipts, lot tracking

- Each `StockItem` is a lot with `acquired_on` and `expires_on`, so "what's
  near expiry" is queryable and feeds the scheduler's soft preferences.
- Receipt photo or pasted text → same LLM extraction pattern as the recipe
  importer → line items matched to canonical `Ingredient` → confirmation step
  → batch `StockTransaction` write.
- Matching is done by the model: it is given every known ingredient name and
  reuses one when a line is the same thing. Anything else is a new
  ingredient, marked as such at confirmation.
- The model estimates each item's shelf life; the confirmation step can
  change it.
- Photos need a vision-capable model on llama-swap.
- Stock decrements automatically as `Step`s (prep or plate) consume
  ingredients/components. Prep also produces a new `Component` `StockItem`.

## shopping list

- Schedule requirements minus on-hand stock, exported to the iOS Reminders
  grocery list. No custom in-app UI.

## open work

- [calendar integration for prep suggestions](https://github.com/bobbymeyer/funcooker/issues/1)
