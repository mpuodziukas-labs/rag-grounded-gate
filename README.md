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
  and runs 32 assertions across every check. No external data needed.

## Quickstart

```bash
git clone https://github.com/mpuodziukas-labs/rag-grounded-gate
cd rag-grounded-gate

./rag-grounded-gate --selftest      # prints 7 verdict lines + 32/32 pass
bash REPRO.sh                       # reproduces every row of FIXTURE-TABLE.md
```

You only need Python 3. There are no third-party dependencies.

## What it checks

`./rag-grounded-gate check <answer.json> <chunks_dir> [--source-min N] [--ttl N] [--attr-min F]`
writes a verdict JSON and returns one of three exit codes:

| exit code | meaning |
|---|---|
| `0` | grounded: every check passed, or a correct abstention on empty retrieval |
| `1` | ungrounded: a groundedness check failed (bad span, unpinned hash, low attribution, stale chunk, abstention violated, or source floor not met) |
| `2` | malformed input: the answer JSON failed schema validation |

There are seven checks (`schema`, `abstain_on_empty`, `citation_span`, `sha_pin`, `source_floor`,
`freshness`, `attribution_ratio`) and nine fixtures: two that pass and seven that each force one
failing check. A failure can cascade into a second check (fixture 04's bad span also lowers the
attribution ratio); the table records that as-is rather than forcing one check per row. The full
table of class, fixture, command, exit code, and failing check is in
[FIXTURE-TABLE.md](FIXTURE-TABLE.md), and `REPRO.sh` re-runs all of them and asserts the
selftest count (32/32) rather than only its exit code.

Defaults: `--ttl 604800` (7 days), `--source-min 2` (distinct source URLs, see point 5 below),
`--attr-min 0.9` (90% of the answer's sentences must be attributed to a verified citation).

`answer.schema.json` in this repo is a standalone JSON Schema (draft 2020-12) describing the
`answer.json` contract, so a consumer can validate an answer file without running this tool.

## What "grounded" means here (and what it doesn't)

An answer is grounded when all of these hold:

1. the answer JSON passes schema validation (otherwise exit `2`, nothing else is evaluated),
2. every cited span is a verbatim substring of a retrieved chunk,
3. every cited chunk's SHA-256 is pinned in the answer's `grounded_sha256`,
4. every cited chunk is inside the freshness TTL or carries an explicit stale flag,
5. the attribution ratio is met and the cited chunks come from at least `--source-min` distinct
   source URLs (read from each cited chunk's `meta.json`, not distinct SHA-256 hashes: two
   different chunks from the same URL count as one source), and
6. on empty retrieval the answer abstains with the literal string `insufficient context`
   (an exact match; any other refusal wording counts as answering, by design, so that
   abstention is machine-checkable rather than interpreted).

Span matching is byte-exact: it is a raw substring test on the chunk's UTF-8 text, with no case
folding and no Unicode normalization. A citation that differs from the chunk only in case, or
that is in a different Unicode normalization form (NFD vs NFC) for the same visible text, is
reported ungrounded even though a human reading both on screen would call them identical.

`chunks_dir` is assumed to be a trusted, locally-controlled directory. The gate does not defend
against symlinks inside it, and `chunk_id` values are restricted to a safe filename character set
so a citation cannot walk outside `chunks_dir` with `../` or an absolute path.

This is a lexical faithfulness and abstention gate, not a semantic judge. Span-containment is a
substring test, so a valid answer that paraphrases, resolves coreference, or aggregates across
chunks can be marked ungrounded when it isn't. Fixture 04 is exactly that case on purpose: its
cited span changes one word of the chunk, and the gate rejects it because a paraphrase is not a
verbatim citation. That trade-off is deliberate: the gate won't try
to adjudicate semantic entailment, which is exactly where an LLM judge tends to hallucinate. Its
job is verbatim-span faithfulness and abstention discipline, the two properties a model-risk
auditor can check without trusting a model. Use it as a fail-closed floor, not as a replacement
for human review of paraphrase-heavy answers.

## Known limits

* Span matching is byte-exact: case and Unicode normalization (NFC vs NFD) are not folded, so an
  otherwise-correct citation can be marked ungrounded on that basis alone.
* Sentence boundaries for the attribution ratio are detected with a naive `[.!?]` regex. Numbers,
  abbreviations, and ellipses can inflate or deflate the sentence count and shift the ratio.
* `chunk_id` is restricted to a safe character set and cannot escape `chunks_dir`, but the gate
  still follows symlinks placed inside `chunks_dir`; treat that directory as trusted and
  locally-controlled, not as an untrusted upload target.
* Chunk files are read into memory in one call rather than streamed; there is no enforced maximum
  chunk size, so an unusually large chunk file is read whole.
* There is no semantic entailment check and no cross-chunk contradiction detection: the gate
  checks verbatim citation and abstention discipline only, not whether an answer's reasoning
  across multiple chunks is sound.
* Abstention is recognized only as the exact literal string `insufficient context`. Any other
  refusal wording counts as an answer, by design, so abstention stays machine-checkable.

## Deeper evaluation (not bundled)

Past the nine fixtures, the gate is run against a private suite of 20 planted anti-fact canaries
(fabricated entities, numbers, and dates confirmed absent from the corpus) and 20 real-shaped
negative controls (plausible questions on topics the corpus doesn't cover). Both require
abstention. The last recorded run (2026-09-12) has three receipts: the 20 canary rows with correct
answers pass (exit `0`); one planted leak in a canary answer fails the suite (exit `1`); one planted
leak in a negative-control answer fails the suite (exit `1`). A single non-abstaining answer flips
the suite's exit code. The corpus and the receipts are not shipped here, so treat this paragraph as
a description of method, not as evidence you can check from this repo. Point the gate at your own
chunk store instead: the nine fixtures show what it does on well-formed input; see
[Known limits](#known-limits) above for behavior outside that domain.

## License

MIT. See [LICENSE](LICENSE).
