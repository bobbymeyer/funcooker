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
  output schema (structured extraction, not open-ended generation).

## data model

| Model | Fields / role |
| --- | --- |
| `Ingredient` | Canonical raw item — `name`, `category`, `default_unit`, optional `ingredient_family` |
| `IngredientFamily` | Flat, unranked set of interchangeable `Ingredient`s (e.g. "alliums": shallot, red onion, yellow onion). An ingredient belongs to at most one family |
| `Component` | Modular building block / sub-recipe — `name`, `description`, `source_url`. Has its own `Step`s. Nests inside other `Component`s through `ComponentPart` |
| Dish | A `Component` that is not the child of any other `Component`. Not a table or subclass: `Component.dishes`, `Component#dish?` |
| `ComponentPart` | Parent `Component` → child `Component`, `quantity`, `unit`, optional consuming `Step`. No cycles |
| `ComponentIngredient` | `Component` → exactly one of a locked `Ingredient` or a substitutable `IngredientFamily`, `quantity`, `unit`, `note`, optional consuming `Step` |
| `Step` | Belongs to a `Component`. `position`, `phase` (`prep`/`plate`), `mode` (`active`/`passive`), `duration_minutes`, `instructions` |
| `StockItem` | One lot. `stockable` (`Ingredient` or `Component`), `kind`, `quantity`, `unit`, `acquired_on`, `expires_on` |
| `StockTransaction` | `StockItem`, `delta`, `source` (`receipt`, `manual`, `step_consumption`, `step_production`), optional `Step` |
| `HouseholdMember` | `name` |
| `FoodNeed` | `HouseholdMember`, polymorphic `subject` (`Ingredient`, `IngredientFamily`, `Component`), `tier`: `restriction` or `preference` |
| `ScheduleEntry` | `served_on`, `meal_slot` (`breakfast`/`lunch`/`dinner`), dish, `status` (`planned`/`served`/`skipped`/`swapped`), `restrictions_overridden` |
| `ShoppingListItem` | Derived, not stored: `ScheduleEntry` requirements minus on-hand `StockItem`s, rounded to purchase units. Exported to iOS Reminders |

### stock kinds

| `kind` | `stockable` |
| --- | --- |
| `raw` | `Ingredient` |
| `prepped` | `Component` |
| `frozen_meal` | A dish — the freezer bank |

### restrictions

The household eats together, so every member's restrictions apply to every
`ScheduleEntry`.

| Restricted subject | Violated by |
| --- | --- |
| `Component` | Any dish containing it, at any depth |
| `Ingredient` | A locked slot for that ingredient; a family slot only when every ingredient in the family is restricted |
| `IngredientFamily` | Any slot for the family, and any locked slot for one of its ingredients |

`preference` never violates.

## recipe importer

1. Fetch page → check for [schema.org/Recipe](https://schema.org/Recipe)
   JSON-LD → parse directly if present.
2. If absent, or the source is a photographed cookbook page, fall back to an
   LLM vision/text pass that emits the same target JSON schema. One importer,
   two entry points.
3. Ingredient lines come back parsed as `{amount, unit, ingredient, note}`
   from the same LLM call. No separate regex parsing step.
4. Imported recipes land as a single `Component`. Breaking them into
   reusable sub-components is manual.

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
  avoidance and `preference` weighting. The scheduler never schedules a
  restricted dish.
- **Manual:** create `ScheduleEntry` rows by hand. One that violates a
  restriction fails validation and names the member. It saves only with
  `restrictions_overridden` set.
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

- Each `StockItem` is a lot with `acquired_on` and `expires_on`, so "what's near expiry" is queryable and feeds the scheduler's soft
  preferences.
- Receipt photo → same LLM extraction pattern as the recipe importer → line
  items fuzzy-matched to canonical `Ingredient` → confirmation step → batch
  `StockTransaction` write.
- Stock decrements automatically as `Step`s (prep or plate) consume
  ingredients/components. Prep also produces a new `Component` `StockItem`.

## shopping list

- Schedule requirements minus on-hand stock, exported to the iOS Reminders
  grocery list. No custom in-app UI.

## open work

- [calendar integration for prep suggestions](https://github.com/bobbymeyer/funcooker/issues/1)
