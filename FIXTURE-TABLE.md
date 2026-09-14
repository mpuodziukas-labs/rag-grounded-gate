# Fixture table

Tool under test: `./rag-grounded-gate`, unmodified. Every row below comes from an actual command
run against this repo's `fixtures/` directory. The `check_failed` column lists every check whose
`ok` came back `false` in the verdict JSON. A fixture can trip more than one check when the
failure mode drags a dependent metric down with it (for example a bad span also lowers the
attribution ratio). That is real gate behavior, so it is recorded as-is rather than forced to
isolate a single check.

| class | fixture | command | exit | check_failed |
|---|---|---|---|---|
| 01 | 01-valid | `rag-grounded-gate check fixtures/01-valid/answer.json fixtures/01-valid/chunks` | 0 | none |
| 02 | 02-empty-retrieval-abstain | `rag-grounded-gate check fixtures/02-empty-retrieval-abstain/answer.json fixtures/02-empty-retrieval-abstain/chunks` | 0 | none |
| 03 | 03-empty-retrieval-answered | `rag-grounded-gate check fixtures/03-empty-retrieval-answered/answer.json fixtures/03-empty-retrieval-answered/chunks` | 1 | abstain_on_empty |
| 04 | 04-span-mismatch | `rag-grounded-gate check fixtures/04-span-mismatch/answer.json fixtures/04-span-mismatch/chunks` | 1 | citation_span, attribution_ratio (a mismatched span also fails the attribution check, which re-derives verified spans independently) |
| 05 | 05-sha-unpinned | `rag-grounded-gate check fixtures/05-sha-unpinned/answer.json fixtures/05-sha-unpinned/chunks` | 1 | sha_pin |
| 06 | 06-source-floor-one-source | `rag-grounded-gate check fixtures/06-source-floor-one-source/answer.json fixtures/06-source-floor-one-source/chunks` | 1 | source_floor |
| 07 | 07-stale-chunk-no-flag | `rag-grounded-gate check fixtures/07-stale-chunk-no-flag/answer.json fixtures/07-stale-chunk-no-flag/chunks --ttl 1` | 1 | freshness |
| 08 | 08-attribution-ratio-low | `rag-grounded-gate check fixtures/08-attribution-ratio-low/answer.json fixtures/08-attribution-ratio-low/chunks` | 1 | attribution_ratio |
| 09 | 09-schema-missing-field | `rag-grounded-gate check fixtures/09-schema-missing-field/answer.json fixtures/09-schema-missing-field/chunks` | 2 | schema (generated_utc missing) |

Each exit code above matches the class's expected return code. The gate behavior was not tuned to
fit; only the fixture content (citation span punctuation, to line up with the gate's own
sentence-splitter) was adjusted to hit the intended check.

## Reproduce

```bash
./rag-grounded-gate --selftest   # 19 assertions, self-contained, builds its own fixtures
bash REPRO.sh                    # runs all nine fixtures above and prints "REPRO OK"
```

Every result reproduces from a clean `git clone` with no network and no external data. Python 3
standard library only.

## Deeper suite (not bundled)

Beyond these nine fixtures I run the gate against 20 planted anti-fact canaries and 20
real-shaped negative controls:

* The canaries plant 20 fabricated terms (a made-up protocol name, a fake RFC number, a fake
  pricing tier), each confirmed absent from the source corpus by a literal grep.
* The negative controls ask 20 real-shaped questions on topics next to the corpus (pricing, GDPR,
  ARM64, Kubernetes, licensing, SLAs), each also confirmed corpus-absent.

Both sets require every answer to abstain (`"insufficient context"`). A single confident,
non-abstaining answer flips the command's exit code from 0 to 1. That corpus is not shipped here.
I run it live, or point it at your own chunk store, on request.
