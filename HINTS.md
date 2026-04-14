# list available PlebChat models

```sh
curl -s -H "Authorization: Bearer $PLEBCHAT_API_KEY" "https://api.plebchat.me/v1/models" | jq
```

---

# run evals

```sh
./evals/run-eval.sh --with-retro deepresearch evals/deepresearch-short.txt
```