![here comes the funcooker](docs/images/funcooker.png)

# funcooker

a family food system: recipe library, lean stock, derived meal schedule

Spec: [ROADMAP.md](ROADMAP.md)

## quickstart

```sh
bin/setup --skip-server
LLM_MODEL=<model id> bin/dev
```

## library

Every record the app shows can be created, edited and deleted.

| Page | |
| --- | --- |
| `/components` | Filter for all, dishes only, or parts of dishes. New, edit and delete components. On a component: add, edit and remove its ingredient lines (an ingredient by name, or any of a family), steps (position, prep or plate, active or passive, minutes) and sub-components. Deleting a component takes its lines and steps with it; one used inside another, in stock or on the schedule is not deleted |
| `/ingredients` | New, edit and delete ingredients, and their families under **Families**. An ingredient used in a recipe or in stock is not deleted; deleting a family keeps its ingredients |
| `/stock` | First out first: lots expired or expiring within 3 days under **use first**, the rest after, each in expiry order with the days left. Add a lot by hand, edit or delete one. A lot's quantity only changes through a `StockTransaction`: one entered or corrected by hand is `manual` |
| `/receipts` | Delete a receipt. What was stocked from it stays |
| `/recipe_imports` | Past imports; delete one. The recipe it made stays |

## recipe import

`/recipe_imports/new` takes a URL, pasted text, or the name of a dish. The import runs as a
background job and its page refreshes onto the new component when it is done.

| Source | Read by |
| --- | --- |
| Page with `schema.org/Recipe` JSON-LD | Name, description and steps read directly; ingredient lines parsed by the model |
| Page without it | The model, given the page's text with scripts, nav, header, footer, aside and forms removed, cut at 30,000 characters |
| Pasted text | The model |
| Named dish, e.g. "pasta and red sauce, store-bought noodles and sauce" | The model writes it for one adult, at the level chosen under **Written by**. Anything named as store-bought stays a single ingredient. No description |

| Written by | Writes |
| --- | --- |
| divorced dad (default) | The simplest possible version: only what the dish cannot be made without, store-bought wherever a store sells it, fewest steps |
| home cook | A weeknight version: everyday ingredients, quick parts from scratch, basic seasoning |
| Michelin chef | Everything from scratch, refined technique, plated |

Each import makes one `Component`: its steps in order, and its ingredient
lines as `{amount, unit, ingredient, note}`.

Amounts are stored for one adult. The model reports how many adult servings
the source makes — from its yield, estimated when the yield is in pieces
("24 cookies") or missing — and each amount is divided by that, to 4 decimal
places. Amounts written inside step text are not scaled. Ingredients are matched to an
existing `Ingredient` by lowercase name, or created.

A page that answers an error, a model that cannot be reached or runs out of
tokens, a source with no ingredients and no steps, and a serving count that
is not above 0 each fail the import,
with the reason on its page.

## schedule

`/schedule` shows the meal up next with **Cook**, **Served**, **Skip** and
**I'm tired**, how many easy meals the freezer bank holds, a plan form, and
the meals from a week back to four weeks ahead.

**Plan** fills the chosen meals (breakfast, lunch, dinner) over the chosen
days, one slot at a time in date order, for everyone who eats by default.
Dishes that any of them is restricted from are never candidates. The rest are scored, and the highest wins;
ties go to the dish name.

| Signal | Scores | Weight |
| --- | --- | --- |
| Stock | How much of the dish is on hand, 0 to 1. A component on hand covers everything in it; a family slot is covered by any member | 3 |
| Expiry | Each on-hand lot it uses that expires within 4 days, sooner counting more. A lot counts for one dish per plan | 2 |
| Share | The share of its ingredients also in dishes planned within 3 days | 1 |
| Repeat | The same dish within 7 days, closer counting more | −4 |
| Likes | +1 for each diner who likes something in it, −1 for each who dislikes something in it | 1 |

| Origin | Put there by | When the plan is derived again |
| --- | --- | --- |
| planner | **Plan** | Replaced |
| hand | **Add a meal**, or any meal edited by hand | Kept |
| freezer | **I'm tired**, or **Eat next** in the freezer bank | Kept |

**Skip** marks the meal skipped and derives every planned meal after it again,
from the stock and dates as they are now. **I'm tired** marks the meal swapped
and puts in its place, for the same people, the frozen dish that expires
soonest that none of them is restricted from. A lot counted in servings must
have enough for them. A meal from the freezer shows **Reheat** in place of
**Cook**.

**Served** on a meal whose dish is in stock whole (a frozen dish, say) draws
its servings from stock. On any other meal it only marks the meal served.

Each meal lists who is eating it and the servings that makes: the sum of
their portions. A new meal starts with everyone who eats by default; tick
anyone else in on the meals they come to. A dish anyone at the meal is
restricted from is refused, naming them. There is no override: a restriction
is something they do not eat. One meal per slot.

## shelf life

A component has two shelf lives, both in days: how long it keeps once made,
which sets the expiry of prepped stock, and how long it keeps frozen, which
sets the expiry of freezer stock. A freezer life of 0 means it does not
freeze well (a dressed salad, mayonnaise), and it cannot go in the freezer.

The model estimates both in one call, conservatively and from food-safety
guidance, for each imported recipe and each component Decompose creates, and
on **Estimate shelf life** (one component) or **Estimate missing shelf
lives** (every component missing either). Only a blank one is filled in,
except with **Estimate again**, which replaces both. The component page shows
the days and where they came from; the components list shows both. Setting
either by hand replaces its estimate. An answer that is not a whole number of
days (above 0 for the fridge, 0 or above for the freezer) is not stored.

## cook

`/cook` lists cooking sessions. Both kinds are walked the same way: one step
at a time in large type, with that step's ingredients scaled to the servings
(a step that names none shows the whole component's, on its first step).
**Done** moves on. A passive step with a time has **Start**: it moves to the
countdown strip at the top, which stacks, and is marked done from there. Any
step can be undone.

| Session | Started from | Steps | Finishing it |
| --- | --- | --- | --- |
| Prep | **Plan a prep session** | Every step of each batch, ordered by the model | Adds each batch to stock in servings: a prepped lot keeping for the component's shelf life, and the servings set aside to freeze as a freezer lot keeping for its freezer life; draws the raw ingredients used |
| Plate | **Cook** (or **Reheat**) on a scheduled meal | The steps of each component in it not already prepped or frozen in stock, innermost first, then the dish's own, in recipe order. None when the dish itself is in stock | Draws the prepped and frozen components and raw ingredients used, or the dish itself; marks the meal served |

The prep planner looks at the meals planned over the next days (7 by
default) and suggests every component inside their dishes that has steps,
for the servings those meals need less the prepped and frozen servings in
stock. A meal whose dish is in stock whole needs nothing. Each can be
unticked, its servings changed, or some of them set aside to freeze
(**Of which, freeze**: cook once, freeze half), and any other component
added. A component that does not freeze well cannot be set aside.

The model orders a prep session's steps: long passive steps as early as they
can go, long components first, one active step at a time, grouped by
technique or station. Each component's steps are then put back in their
recipe order within the places they got, and any step it dropped is
appended. If the model cannot be reached, the session says why and can be
cooked in recipe order instead.

Stock is drawn soonest-expiring first, and only from lots in the unit the
recipe measures in. What could not be drawn (none in stock, a different
unit, or too little) is listed on the finished session rather than guessed.

## household

`/household` lists who eats.

| Field | |
| --- | --- |
| Portion | Adult servings they eat, since recipes are stored for one adult: 1 is an adult, 0.5 a small child |
| Eats with us by default | Seated at every new meal. Someone who comes a couple of times a week is left unticked and added to those meals |

Each member's page adds, edits and removes their food needs: an ingredient, a
family or a component, as a restriction (never planned when they are eating)
or a preference that they like or dislike (scored).

## decompose

A component's page has **Decompose** while it is not yet made of other
components. The model breaks the recipe into the parts worth making on their
own (a sauce, a marinade, cooked rice, a dough) and rewrites it to use them,
in a background job.

| | |
| --- | --- |
| Reuse | Given every other component and its ingredients, the model reuses one that is the same or very close, at so many servings, instead of making a new one. The recipe's lines it stands in for are dropped |
| New components | Made from the recipe's own ingredient lines, referred to by id, so nothing is invented. A line can be split between components; a family slot stays a family slot. Each is written for one adult and used at 1 serving |
| The recipe | Keeps only the lines it uses directly, and its steps are rewritten to use the components. A line the model leaves unused stays on the recipe |
| Steps | Every step, new or rewritten, is marked prep or plate, active or passive, with an estimated time. Each component used is linked to the step that uses it |

The model judges the recipe before breaking it up:

| Verdict | When | What happens |
| --- | --- | --- |
| decompose | It has parts that can be made ahead with nothing lost | The rewrite is applied |
| atomic | Nothing in it can meaningfully be made on its own, or its parts only work cooked together | Nothing changes; the component page says why |
| borderline | A part could be made apart, at a cost to the dish (braising a bolognese's meat on its own loses the fond) | Nothing changes yet; the component page shows what would break out and each thing the dish loses, with **Decompose anyway** and **Leave it** |

A borderline plan is only applied to the recipe as it was judged; one edited
since has to be decomposed again. The recipe's ingredients and steps as they
were are kept on the `Decomposition`. A component and anything it is part of are never offered for
reuse inside it. If the model finds nothing to break out, or names a component
that does not exist, nothing changes and the reason is shown.

## receipts

`/receipts/new` takes a photo of a grocery receipt (JPEG, PNG or WebP) or its
text, pasted. The model reads it in a background job into lines, and the
receipt's page refreshes onto them.

| The model gives | |
| --- | --- |
| Store and purchase date | The date falls back to the day the receipt was added |
| Each item | Named as a plain ingredient, reusing an existing `Ingredient`'s name when it is the same thing |
| Quantity and unit | The total bought: "2 @ MILK 1 GAL" is 2 gal; weighed items by weight; counted items by count |
| Food or not | Non-food lines start unticked |
| Shelf life | How long it keeps at home, turned into a date from the purchase date |

Totals, tax, payments, discounts, coupons, deposits and bag fees are left out.

Every line is editable before anything is stocked: whether it is included,
its ingredient, quantity, unit and keep-until date. An ingredient not yet in
the library is marked new. **Stock these** makes one raw `StockItem` lot per
included line, recorded as a `receipt` transaction, and creates any new
ingredients. An included line needs an ingredient and a quantity above 0. A
receipt is stocked once.

A photo the model cannot read fails the receipt with the model's name, the
server's error, and what is needed: a vision-capable model loaded in
llama-swap with its `--mmproj` file, and `LLM_VISION_MODEL` set to its id. A
photo that yields no items says the same. Pasted text needs neither.

## stock

`/stock` lists every lot on hand, soonest to expire first.

## freezer bank

Frozen stock is component stock like prepped stock, only kept in the freezer
and for longer. A frozen component counts wherever a prepped one does: the
planner's stock score, the prep planner, the shopping list and cooking all
draw on it. A frozen dish is an easy meal, the backup plan behind **I'm
tired**.

`/freezer` shows:

| Section | Lists | Actions |
| --- | --- | --- |
| Count | Whole easy meals for everyone who eats by default: each frozen dish's servings over their summed portions, rounded down | |
| to thaw | Frozen servings the meals planned today and tomorrow will draw on, and when to take them out | **Thaw**, set to the servings needed. **Send to Reminders** |
| easy meals | Frozen dishes, soonest to expire first, with the meals each makes | **Eat next** swaps the meal up next for this dish, when it feeds that meal's diners. **Thaw** |
| components | Every other frozen component | **Thaw** |
| freeze before it turns | Prepped lots expiring within 3 days whose component freezes | **Freeze** |

| Move | Takes | Makes |
| --- | --- | --- |
| **Freeze** | Servings of a prepped lot | A freezer lot, keeping for the component's freezer life from today |
| **Thaw** | Servings of a freezer lot | A prepped lot, keeping for the component's shelf life from today |

Both take any number of servings up to the lot's, and are recorded as
`freezer` transactions on both lots. Freezer stock can also be added by hand
from `/stock`.

### thaw reminders

Meals are taken in date order, as cooking takes them. A dish, or a component
inside it, comes from stock when its prepped and frozen servings together
cover the meal; otherwise it is cooked, and the components inside it are
taken the same way. The fridge is used first. What it is short of is a thaw,
from the freezer lot that expires soonest, due the evening before the meal
(or now, for a meal today). Thawing it moves it to the fridge, and it drops
off the list.

| Where | What |
| --- | --- |
| `/schedule` | "Out of the freezer tonight", listing what is due |
| `/freezer` | The list, each with **Thaw** set to the servings needed |
| **Send to Reminders** | Adds each to the `REMINDERS_THAW_LIST` list, due 6pm the day it should come out. Shown only when the app runs on the Mac |
| Daily at 4pm | In production, the app sends that evening's thaws to Reminders itself. It does nothing where Reminders is not available |
| `/freezer.json` | `{ list, items: [{ title, notes, due }] }`, for `lib/reminders/add.js` run on the Mac when the app runs in a container |

A reminder is titled with the component, the servings and the day ("Thaw
salsa verde, 1.5 servings, for Thursday"); one already on the list and not
ticked is skipped, so sending again adds only what is new.

## shopping

`/shopping` lists what to buy for the meals planned over the next days (7 by
default, up to 28): everything they need, scaled to each meal's servings,
less what is on hand.

| | |
| --- | --- |
| Prepped components | Cover as many servings as are in stock, meal by meal in date order; only the rest needs ingredients |
| Stock | Subtracted in the unit the recipe measures in, named ingredients before "any of a family". Stock in another unit is noted, not converted |
| To taste | Listed only when there is none in stock |
| Rounding | Up to whole packs when the ingredient has a pack size in its default unit; counts up to whole numbers |

Each item's notes say which meals it is for, and what is needed and on hand.

To get it into Reminders:

| Route | |
| --- | --- |
| **Send to Reminders** | When the app runs on the Mac itself (not in a container): adds each item to the list named by `REMINDERS_LIST` (default Groceries), creating it if needed, and skips any already there and not completed. It syncs to the phone through iCloud |
| `osascript -l JavaScript lib/reminders/add.js https://<host>/shopping.json` | The same, run on the Mac against the app wherever it is hosted; from a LaunchAgent to keep the list current |
| **Copy for Reminders** | Copies one item per line. Pasted into a Reminders list, each line becomes a reminder; a Groceries list sorts them into sections |
| `/shopping.json` | `{list, from, days, items: [{title, notes}]}`, for a Shortcut; `?days=` sets the window |
| `/shopping.txt` | One item per line |

The Shortcut, built once in the Shortcuts app:

1. **Get Contents of URL**: `https://<host>/shopping.json`
2. **Get Dictionary Value** for `items`
3. **Repeat with Each** item:
   1. **Get Dictionary Value** for `title` in Repeat Item
   2. **Find Reminders** where List is Groceries, Title is the value, and Is Not Completed
   3. **If** Reminders has no value: **Add New Reminder** with the title, in Groceries, with Notes from `notes`

Run again, it only adds what is not already on the list.

The first send asks macOS for access to Reminders. A refusal fails the send
with where to allow it: System Settings → Privacy & Security → Reminders, and
Automation for the process running the app.

## configuration

| Variable | Default | |
| --- | --- | --- |
| `LLM_BASE_URL` | `https://chat.bobbymeyer.com/v1` | Any OpenAI-compatible endpoint |
| `LLM_MODEL` | none — required | An id from `$LLM_BASE_URL/models` |
| `LLM_VISION_MODEL` | `LLM_MODEL` | The model receipt photos go to. It must accept images |
| `REMINDERS_LIST` | `Groceries` | The Reminders list **Send to Reminders** adds the shopping list to |
| `REMINDERS_THAW_LIST` | `Reminders` | The Reminders list thaw reminders go to |
| `TIME_ZONE` | `UTC` | The household's time zone, by tz database name (`America/Los_Angeles`): what today and this evening mean |
| `SOLID_QUEUE_IN_PUMA` | unset | Production: runs jobs, and the daily thaw reminder, inside Puma |

Each request asks for `temperature: 0`, a `json_schema` response format, and
`chat_template_kwargs: {enable_thinking: false}`, and waits up to 600 seconds
for the reply. A photo is sent inline as a base64 `image_url` part.

To list the model ids, from a machine on the tailnet:

```sh
curl -s https://chat.bobbymeyer.com/v1/models | jq -r '.data[].id'
```

## tech

- Rails 8.1, Ruby 3.3.6, SQLite
- UI: [its-swiss](https://github.com/bobbymeyer/its-swiss) v1.0.0
- Tests: `bin/rails test`, HTTP stubbed with WebMock
- Lint: `bin/rubocop`
