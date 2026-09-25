# Evidence for the Test Ground CPU budget decision

`phone-subchecks.tar.gz` preserves the existing `candidate/` and `saturation/`
batches from source `f56b62b`: raw per-frame/per-tick CSVs, metadata, summaries,
captures, APK/source/save hashes, install/launch output, temperatures, logcat and
the **original 4/5 ms validation output**, including failures. Redundant transport
`results.tar` copies are excluded; their extracted contents are retained.
No samples, timing summaries or original verdicts were rewritten for 6/7 ms.

Archive SHA-256:
`f2e25b924c6536cf97014df13f96f5f3581d08ec64a35e899057ab3cf3f21c0c`.

Read `../m6w-budget-amendment-2026-09-25.md` for scope and limitations. These are
30-second, single-round 4x4 subchecks, not final acceptance or live driving.

From the project root, extract into a fresh temporary directory and validate:

```sh
wave_budget_evidence=$(mktemp -d /tmp/ridge-wave-budget-evidence.XXXXXX)
tar -xzf docs/notes/m6w-budget-amendment-data/phone-subchecks.tar.gz -C "$wave_budget_evidence"
python3 -B tools/check_wave_acceptance.py "$wave_budget_evidence/candidate/wave_acceptance_results/candidate"
python3 -B tools/check_wave_acceptance.py "$wave_budget_evidence/saturation/wave_acceptance_results/saturation"
python3 -B -m unittest discover -s tools -p test_check_wave_acceptance.py
```

Current checker output uses the explicitly labelled, owner-approved Test Ground
6/7 ms CPU policy. Archive `validation.txt` files use the original 4/5 policy.
The validator checks raw evidence integrity plus numeric CPU/frame subchecks;
it does not turn these short batches into a full GPU/soak/lifecycle/phone pass.
