---
name: tavily
description: "Search the web via bash+curl against Tavily's REST API. Requires TAVILY_API_KEY env var. No tavily tool exists."
allowed-tools: Bash
---

## Search Command

ALWAYS use this exact command (replace QUERY with your search terms):

```bash
curl -sS -X POST 'https://api.tavily.com/search' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -d '{"query":"QUERY","max_results":5}' \
  | jq '.results[:5] | .[] | {title, url, content}'
```

If the query contains quotes or special characters, build the JSON with `jq`:

```bash
curl -sS -X POST 'https://api.tavily.com/search' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -d "$(jq -nc --arg q 'QUERY' '{query:$q,max_results:5}')" \
  | jq '.results[:5] | .[] | {title, url, content}'
```

## URLs Only

```bash
curl -sS -X POST 'https://api.tavily.com/search' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -d '{"query":"QUERY","max_results":5}' \
  | jq -r '.results[:5] | .[].url'
```

## Response Format

Each result object contains:

| Field     | Description                                    |
|-----------|------------------------------------------------|
| `title`   | Page title                                     |
| `url`     | Full URL                                       |
| `content` | Text snippet                                   |
| `score`   | Relevance score (float)                        |

When `include_answer` is set, the top-level `answer` field contains an LLM-generated summary.

## Optional Request Fields

Add these keys to the JSON body as needed:

- `search_depth` -- `"basic"` (default), `"fast"`, `"advanced"` (2 credits), `"ultra-fast"`
- `topic` -- `"general"` (default), `"news"`, `"finance"`
- `include_answer` -- `true` or `"advanced"` for an LLM-generated answer
- `time_range` -- `"day"`, `"week"`, `"month"`, `"year"`
- `include_raw_content` -- `true` for full cleaned page content
- `include_domains` / `exclude_domains` -- JSON arrays of domain strings

Example with news topic and answer:

```bash
curl -sS -X POST 'https://api.tavily.com/search' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -d '{"query":"QUERY","max_results":5,"topic":"news","include_answer":true}' \
  | jq '{answer, results: [.results[:5][] | {title, url, content}]}'
```

## Troubleshooting

- **401 Unauthorized** -- `TAVILY_API_KEY` is missing or invalid. Ensure it is exported in the shell that launched pi.
- **429 / 432 / 433** -- Rate or plan limit exceeded. Check usage at https://app.tavily.com or contact support@tavily.com.

Never paste the API key directly into prompts or log output; always reference `$TAVILY_API_KEY`.
