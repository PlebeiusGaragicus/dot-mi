I want to consider @unix-abstraction.md philosophy and using `p` agents like unix utilities / "filters"

For example: let's say we transform our deepresearch agent team into a series of individual unix-like primitives. So, instead of calling an agent team I string together a series of individual agents with `|` wherein I may call:

```sh
echo "daily creatine usage for healthy 30 year old male, health benefits and latest trends in health" | p research | p collector | p summarizer | p draft-report | p final-report < ~/templates/research-template.md"
```

Similar to a unix utility each takes input (weather prompt, URL list, file list, etc), makes side effects to tmp/artifact files, generates output which all can be consumed by the next agent.

---

## what data moves across the pipe?

```sh
echo "daily creatine usage for healthy 30 year old male, health benefits and latest trends in health" | p research | p collector | p summarize | p draft-report | p final-report < ~/templates/research-template.md"
```

`p research`

**usage:** return a list of websites which are likely to assist with the provided research question

 - **input:** research question or topic
 - **side effects:** none
 - **output:** json list of sources, metadata, content snippet

`p collector`

**usage:** scrapes list of urls to tmp directory

 - **input:** list of urls to scrape
 - **side effects:** /tmp/$RUN_ID/*.md
 - **output:** file paths of each scraped file

`p summarize`

**usage:** provide a summary of input file using abstractive and extractive quotations

 - 