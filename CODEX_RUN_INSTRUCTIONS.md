# Codex run instructions

This is a fresh repository for **Health Roadmap**. Do not import or depend on code from the old `health-insight-hub` repository. Build the product from scratch here.

## Required branch

Work on:

`codex/initial-build`

## Required startup sequence

1. Read `CODEX_TASK.md` completely before making architectural decisions.
2. Read `clinical-content/manifest.json`.
3. Run:

```bash
bash scripts/prepare_clinical_content.sh
```

4. Confirm the script reports `PASS` and verifies all of the following:
   - output file: `clinical-content/UK_Preventive_Health_Evidence_Database_v6_Personalisation_Engine.xlsx`
   - exact size: `81092` bytes
   - SHA-256: `89821567c8a49dd65f356141120138034b3be4b18783634d16c5c88d029f4048`
   - valid XLSX/ZIP structure
5. **Do not proceed with clinical implementation if any integrity check fails.** Fix the reconstruction problem first, never substitute invented or web-researched clinical logic.
6. Once validation passes, execute `CODEX_TASK.md` end-to-end.

## Execution expectations

Do not stop at planning, wireframes, architecture descriptions or scaffolding. Build the working product as far as the environment permits. Compile and test after each major phase, fix errors and failing tests, then continue.

The reconstructed workbook is the authoritative V1 seed clinical source of truth. Clinical eligibility, status, safety and prioritisation must be deterministic. Generative AI must not decide clinical eligibility or safety.

If your execution environment does not provide macOS, Xcode, iOS Simulator, Apple signing or a live HealthKit runtime, do not stop. Build the complete native iOS source/project structure, deterministic domain/rules code, import pipeline, mocks and abstractions, run every test that the environment can support, document the external limitation clearly, and continue through the remaining product work.

Use synthetic data for all demos and tests. Never add real personal health information to the repository.

## Final output

At completion, provide the implementation report required by `CODEX_TASK.md`, including what is genuinely implemented, test/build status, mocked integrations, known limitations, clinical/regulatory items for human review and exact run instructions.
