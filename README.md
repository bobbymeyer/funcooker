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

`/recipe_imports/new` takes a URL or pasted text. The import runs as a
background job and its page refreshes onto the new component when it is done.

| Source | Read by |
| --- | --- |
| Page with `schema.org/Recipe` JSON-LD | Name, description and steps read directly; ingredient lines parsed by the model |
| Page without it | The model, given the page's text with scripts, nav, header, footer, aside and forms removed, cut at 30,000 characters |
| Pasted text | The model |

Each import makes one `Component`: its steps in order, and its ingredient
lines as `{amount, unit, ingredient, note}`. Ingredients are matched to an
existing `Ingredient` by lowercase name, or created.

A page that answers an error, a model that cannot be reached or runs out of
tokens, and a source with no ingredients and no steps each fail the import,
with the reason on its page.

### configuration

| Variable | Default | |
| --- | --- | --- |
| `LLM_BASE_URL` | `https://chat.bobbymeyer.com/v1` | Any OpenAI-compatible endpoint |
| `LLM_MODEL` | none — required | An id from `$LLM_BASE_URL/models` |
| `SOLID_QUEUE_IN_PUMA` | unset | Production: runs import jobs inside Puma |

Each request asks for `temperature: 0`, a `json_schema` response format, and
`chat_template_kwargs: {enable_thinking: false}`, and waits up to 600 seconds
for the reply.

To list the model ids, from a machine on the tailnet:

```sh
curl -s https://chat.bobbymeyer.com/v1/models | jq -r '.data[].id'
```

## tech

- Rails 8.1, Ruby 3.3.6, SQLite
- UI: [its-swiss](https://github.com/bobbymeyer/its-swiss) v1.0.0
- Tests: `bin/rails test`, HTTP stubbed with WebMock
- Lint: `bin/rubocop`
