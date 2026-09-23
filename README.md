![here comes the funcooker](docs/images/funcooker.png)

# funcooker

a family food system: recipe library, lean stock, derived meal schedule

Spec: [ROADMAP.md](ROADMAP.md)

## quickstart

```sh
bin/setup --skip-server
LLM_MODEL=<model id> bin/dev
```

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

## configuration

| Variable | Default | |
| --- | --- | --- |
| `LLM_BASE_URL` | `https://chat.bobbymeyer.com/v1` | Any OpenAI-compatible endpoint |
| `LLM_MODEL` | none — required | An id from `$LLM_BASE_URL/models` |
| `LLM_VISION_MODEL` | `LLM_MODEL` | The model receipt photos go to. It must accept images |
| `SOLID_QUEUE_IN_PUMA` | unset | Production: runs import and receipt jobs inside Puma |

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
