# rag-grounded-gate

A small, deterministic gate that decides whether an LLM answer is grounded in its
retrieved context, without asking another model to grade it.

Using an LLM as a judge gives you an opinion. For a RAG system under audit (model-risk
review, SR 11-7, EU AI Act transparency) an opinion isn't evidence. This tool replaces the
opinion with a decision procedure that returns a recorded exit code. It passes only when
every cited span is found verbatim inside a retrieved chunk, the cited chunks are hash-pinned,
the source floor and attribution ratio hold, and the answer abstains when retrieval comes back
empty.

* Deterministic: same inputs give the same verdict and exit code. No sampling, no model call.
* Offline: no network. Nothing about your data leaves the process.
* Self-proving: `./rag-grounded-gate --selftest` builds its own fixtures in a temp directory
  and runs 19 assertions across every check. No external data needed.

## Quickstart

```bash
git clone https://github.com/mpuodziukas-labs/rag-grounded-gate
cd rag-grounded-gate

./rag-grounded-gate --selftest      # 19/19 pass
bash REPRO.sh                       # reproduces every row of FIXTURE-TABLE.md
```

You only need Python 3. There are no third-party dependencies.

## What it checks

`./rag-grounded-gate check <answer.json> <chunks_dir> [--ttl N]` writes a verdict JSON and
returns one of three exit codes:

| exit code | meaning |
|---|---|
| `0` | grounded: every check passed, or a correct abstention on empty retrieval |
| `1` | ungrounded: a groundedness check failed (bad span, unpinned hash, low attribution, stale chunk, abstention violated, or source floor not met) |
| `2` | malformed input: the answer JSON failed schema validation |

There are nine checks, each demonstrated by a fixture built to force one specific exit code.
The full table of class, fixture, command, exit code, and failing check is in
[FIXTURE-TABLE.md](FIXTURE-TABLE.md), and `REPRO.sh` re-runs all of them.

## What "grounded" means here (and what it doesn't)

An answer is grounded when all of these hold:

1. every cited span is a verbatim substring of a retrieved chunk,
2. every cited chunk's SHA-256 is pinned in the answer's `grounded_sha256`,
3. the attribution ratio and the distinct-source floor are met, and
4. on empty retrieval the answer abstains (`"insufficient context"`).

This is a lexical faithfulness and abstention gate, not a semantic judge. Span-containment is a
substring test, so a valid answer that paraphrases, resolves coreference, or aggregates across
chunks can be marked ungrounded when it isn't. That trade-off is on purpose: the gate won't try
to adjudicate semantic entailment, which is exactly where an LLM judge tends to hallucinate. Its
job is verbatim-span faithfulness and abstention discipline, the two properties a model-risk
auditor can check without trusting a model. Use it as a fail-closed floor, not as a replacement
for human review of paraphrase-heavy answers.

## Deeper evaluation (not bundled)

Past the nine fixtures, I run the gate against a private suite of 20 planted anti-fact canaries
(fabricated entities, numbers, and dates confirmed absent from the corpus) and 20 real-shaped
negative controls (plausible questions on topics the corpus doesn't cover). Both require
abstention, and a single non-abstaining answer flips the suite's exit code. That corpus isn't
shipped here. I run it live, or point it at your own chunk store, on request.

## License

MIT. See [LICENSE](LICENSE).
