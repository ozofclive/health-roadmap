# MASTER BUILD SPECIFICATION
# HEALTH ROADMAP
## Evidence-Based Preventive Health & Longevity Platform

You are the principal engineer and autonomous coding agent responsible for designing, building, testing and documenting a production-quality iOS application called **Health Roadmap**.

Your job is to build the actual working application, not merely plan it. Do not stop at wireframes, pseudocode, architecture descriptions, mock screens or scaffolding. Implement, compile, test, fix failures and continue autonomously through the build.

Use UK English for all patient-facing copy.

## 1. Product mission

Health Roadmap is an evidence-based preventive-health operating system for adults, initially focused on busy professionals aged 40+ in England. Its core question is:

> **What should I do next to protect my future health?**

The product combines personal health information, preventive screening, cardiovascular and metabolic health, vaccination, exercise, functional fitness, sleep, wearable data, nutrition, smoking, alcohol, mental wellbeing, social connection, dental health, vision, hearing, sexual health, menopause, selected advanced cardiovascular risk information and longitudinal health trends into a clear personal roadmap.

It should answer:

1. What matters now?
2. What am I due to do?
3. What am I up to date with?
4. What should I consider discussing with a healthcare professional?
5. What is not routinely recommended?
6. What should I track?
7. What is coming later in life?
8. How are my health behaviours and functional measures changing over time?

The product is **not** primarily a fitness tracker, generic health-data warehouse, laboratory marketplace, supplement app, symptom checker, AI doctor, calorie counter or biological-age calculator.

## 2. Clinical source of truth

Before doing anything else, follow `CODEX_RUN_INSTRUCTIONS.md` and run `bash scripts/prepare_clinical_content.sh`.

This reconstructs:

`clinical-content/UK_Preventive_Health_Evidence_Database_v6_Personalisation_Engine.xlsx`

Treat that workbook as the authoritative V1 clinical seed source.

It contains reviewed rules covering NHS prevention and screening, cardiovascular prevention, blood pressure, diabetes, cancer screening, vaccination, bone health, advanced cardiovascular prevention, laboratory testing, sleep, wearables, exercise, functional fitness, exercise safety, nutrition, mental/social wellbeing, smoking, alcohol, dental health, vision, hearing, sexual health, menopause, personalisation inputs, status logic, priority logic and clinical governance.

Do not replace workbook logic with your own web research. Do not invent medical thresholds or eligibility logic. If a technical interpretation would alter clinical meaning, preserve the workbook meaning and document the issue.

## 3. Evidence classes

The app and rules engine must clearly distinguish:

- **Recommended**: official national programme or strong guideline support for this user.
- **Consider**: evidence-supported but dependent on individual risk, circumstances or clinical discussion.
- **Track**: useful longitudinal lifestyle, functional or physiological information.
- **Not routinely recommended**: a test or intervention that should not be presented as routine screening.

Never visually or algorithmically conflate these categories. For example, NHS bowel screening may be Recommended, CAC may be Consider, sleep duration may be Track, and routine ECG in a low-risk asymptomatic adult may be Not routinely recommended.

Trust is a product feature. The app should sometimes explain why a test is not routinely necessary.

## 4. AI boundary

Clinical eligibility and safety must be deterministic. Do not use an LLM to determine screening, vaccination, diagnosis, treatment, medication, CAC eligibility, ECG need, laboratory abnormality or urgent-care need.

Architecture:

`User health data -> deterministic clinical rules engine -> approved HealthAction -> optional explanation`

Never:

`User data -> LLM -> clinical recommendation`

Any future generative explanation capability must be behind a feature flag and OFF by default.

## 5. Intended purpose and medical-device boundary

Create `docs/intended-purpose.md` containing a conservative draft, clearly marked for formal regulatory review:

> Health Roadmap is a preventive-health information and health-management application intended to help adult users organise selected health information, understand when evidence-based preventive health actions may apply to them, track lifestyle and wearable trends, and navigate recognised health guidance. It is not intended to diagnose disease, replace a healthcare professional, provide emergency care or autonomously prescribe treatment.

Keep informational functionality modularly separate from future validated calculators or clinician decision support. Do not implement QRISK3 calculation unless licensing, validation and regulatory implications have explicitly been resolved. Externally calculated scores may be recorded if appropriate.

## 6. Platform and architecture

Build a native iOS application using current stable Swift, SwiftUI, HealthKit, HealthKitUI where appropriate, Apple Charts where useful, async/await and structured concurrency. Default to iOS 18+ unless a different target is technically justified. Document the choice.

Use modular clean architecture. Suggested feature/module boundaries:

- App
- Core
- DesignSystem
- Domain
- ClinicalRules
- ClinicalContent
- Onboarding
- Today
- Roadmap
- Prevention
- Evidence
- HealthData
- HealthKitIntegration
- Fitness
- Exercise
- Sleep
- Nutrition
- Labs
- Profile
- Authentication
- Persistence
- Networking
- Security
- Notifications
- Analytics
- DeveloperTools

Views must not contain clinical eligibility logic. Use:

`SwiftUI View -> feature state/view model -> use case/domain service -> rule engine/repository -> persistence/HealthKit/backend`

## 7. Typed domain models

Use explicit typed domain models rather than magic strings. At minimum support enums equivalent to:

- RecommendationClass: recommended, consider, track, notRoutinelyRecommended
- ActionStatus: safetyAlert, overdue, dueNow, dueSoon, upToDate, notYetEligible, available, consider, track, notRoutinelyRecommended, needsInformation, specialistPathway
- ClinicalImportance: critical, high, medium, low

Clinically important Boolean-like data must support true/false/unknown. Unknown must never silently become false or normal.

## 8. Clinical-content import pipeline

Create a reproducible importer for the workbook. Convert relevant sheets into validated machine-readable clinical assets such as JSON.

Preserve, where present:

- rule ID
- domain
- health action
- jurisdiction
- classification
- priority
- eligibility/trigger
- exclusions/caveats
- frequency
- patient-facing wording
- developer logic
- authority
- source URL
- evidence grade/status
- last checked/reviewed
- effective dates
- version
- review state

Importer requirements:

- validate required columns
- validate rule IDs
- reject duplicate IDs/version collisions
- validate classifications, priorities and dates
- syntactically validate URLs
- normalise whitespace only without changing meaning
- preserve provenance and source links
- reject malformed rows
- generate import report
- generate content manifest/hash
- fail CI when clinical content is structurally invalid

Do not scatter clinical thresholds throughout SwiftUI files.

## 9. Clinical rule versioning and auditability

Each rule must be versionable with rule_id, version, jurisdiction, effective_from/effective_to, authority, classification and source. Never overwrite old clinical versions.

Every recommendation shown must be reproducible. Store or log at minimum:

- rule ID
- rule version
- evaluation timestamp
- input snapshot
- eligibility result
- exclusion result
- status
- priority score
- display reason

The system should be able to answer: **Why did this user see this recommendation on this date?**

## 10. Deterministic rules engine

Implement a safe predicate DSL, never `eval` or arbitrary executable code. Support operators such as:

- eq, neq
- gt, gte, lt, lte
- in, notIn
- exists, unknown
- dateBefore, dateAfter
- all, any, not

Evaluation order must be:

1. jurisdiction
2. effective date
3. eligibility
4. exclusions
5. specialist-pathway override
6. status
7. clinical priority
8. HealthAction generation

Inject a Clock/DateProvider. Do not use `Date()` throughout business logic. Correctly handle birthdays, leap years, exact versus year-based eligibility, invitation windows, phased programmes and future effective dates. Never calculate age by dividing elapsed days by 365.

Each rule should declare dependencies so only affected rules reevaluate when relevant inputs change.

Missing information may itself generate a meaningful action. If prior screening history is unknown, use language like `Check your bowel-screening status` rather than falsely saying `Overdue`.

## 11. Local-first persistence and backend abstraction

The app must work before account creation and without network access. Onboard locally, evaluate rules locally and show a roadmap locally.

Create a secure backend abstraction for future/optional cloud functionality. A PostgreSQL/Supabase approach is acceptable if suitable, with UK/EU region preferred where configuration is available. Keep cloud access behind repository interfaces.

Suggested data concepts:

User, UserProfile, UserPreference, ClinicalCondition, FamilyHistory, GeneticRisk, ScreeningRecord, VaccinationRecord, BloodPressureRecord, LabResult, WearableDailyAggregate, SleepSummary, ExerciseSession, FunctionalMeasure, HealthAction, ActionCompletion, ActionSnooze, ClinicalRule, ClinicalRuleVersion, RuleEvaluation, EvidenceSource, ConsentRecord, AuditEvent.

Use row-level security, per-user isolation, migrations, least privilege and secure secrets. Never expose service-role credentials in the client.

Account creation must not be the first screen. Later support Sign in with Apple and email magic link for cloud backup/sync/subscription/export. Store tokens in Keychain, never UserDefaults.

## 12. Smooth onboarding

Target first personalised value within roughly 60 to 90 seconds. Do not present a large medical intake form.

Initial flow:

1. Welcome: `Your personal roadmap for staying healthier, longer.` CTA: `Build my roadmap`.
2. Date of birth.
3. Country / UK nation.
4. Sex assigned at birth, with a concise explanation that some screening programmes depend on anatomy/sex at birth, allow skip where clinically safe.
5. Major diagnosed conditions as large tap cards: heart disease, hypertension, diabetes, kidney disease, stroke/TIA, AF, none, unsure.
6. Smoking: never, former, current.
7. High-level family history: close relatives with premature heart disease or cancer, yes/no/unsure.
8. Goals: prevention, heart health, fitness, sleep, weight/metabolic health, everything.
9. Generate first roadmap.

UX requirements:

- one decision per screen
- large touch targets
- minimal typing
- back navigation
- `I'm not sure`
- skip when safe
- calm transitions
- subtle finite progress
- no account requirement
- no detailed sexual history or exhaustive medication/lab history during first run

Immediately deliver real rule-generated value. Do not hardcode counts.

After first value, progressively prompt: Apple Health connection, last blood pressure, screening history, vaccination history, recent bloods, family history, medications, height/weight/waist. Never block core use because the profile is incomplete.

An optional Health Profile completion percentage represents information completeness only. It is not a health, longevity or risk score.

## 13. Main navigation

Primary areas:

- Today
- Roadmap
- Prevention
- Fitness
- Sleep
- Profile/settings

If six persistent tabs are too crowded, keep five tabs and use an avatar/settings destination for Profile.

### Today

Today is the centre of the product. Do not make it a giant data dashboard. Show `Your 3 priorities`, maximum three primary actions. Each card must include title, status, short reason, CTA, `Why this?`, Evidence link and optional snooze where appropriate.

Do not put dozens of biomarkers above Top 3. Do not create an opaque biological age or generic health score.

### Safety layer

Evaluate safety before ordinary ranking. Safety alerts sit above Top 3 and do not compete by engagement score. Relevant exercise/falls red flags in the workbook must interrupt generic coaching.

### Roadmap

This is the signature feature. Generate a personalised vertical timeline from clinical rules: Now, next 12 months and future date/age milestones. Recompute when country, DOB, rule versions, diagnoses, family history, screening/vaccination completion or specialist-pathway state changes. Do not hardcode milestones in SwiftUI.

### Prevention

Group into Recommended, Due/Coming up, Up to date, Consider and Not routinely recommended. Keep evidence level visually clear. Explain negative recommendations calmly and distinguish population screening from individual clinical need.

### Evidence

Every clinical action must expose recommendation, why it matters, why it applies, classification, authority, guideline/programme, evidence grade, last reviewed and source link. No source means no production clinical recommendation. Never fabricate citations.

## 14. HealthKit and wearable architecture

Integrate HealthKit natively, initially read-only. Support relevant available types such as steps, activity/exercise, workouts, active energy, heart rate, resting HR, HRV, VO2 max, walking/mobility metrics, walking steadiness, sleep, respiratory rate, oxygen saturation, weight, height and blood pressure where supported.

Request permissions progressively, not all during onboarding. Ask for fitness-related permissions in Fitness and sleep permissions in Sleep. If denied, do not nag repeatedly. Missing or denied data is unavailable, never zero or normal.

Create a `HealthDataProvider` abstraction so Apple HealthKit is one implementation and future Health Connect can implement the same domain interface.

Prefer raw HealthKit samples -> on-device processing -> daily/weekly aggregates -> optional cloud sync. Do not upload raw continuous heart-rate data without a real product need.

Every imported metric preserves provider, device, timestamp, unit, source and raw/derived provenance.

Never use health data for advertising, behavioural targeting, data brokerage or marketing segmentation. Do not put health values into generic analytics, crash breadcrumbs, debug logs or sensitive lock-screen notifications.

## 15. Physical longevity and exercise

Use the workbook exercise library and safety logic. Core domains: aerobic activity, strength, balance, daily movement and functional fitness.

Use accessible progressions, for example chair sit-to-stand -> supported mini-squat -> bodyweight squat -> progressive squat -> loaded/goblet squat; wall press-up -> incline -> floor; supported balance -> tandem -> single-leg/dynamic; short walk -> walk-rest intervals -> comfortable/brisk/longer aerobic work.

Allow `Too difficult`, `About right`, `Too easy` and regress/progress safely.

Each exercise preserves name, level, setup, instruction, starting dose, progression, regression, purpose, evidence status, safety notes and source.

Never claim a particular exercise independently extends lifespan. Explain that exercise patterns deliver guideline-supported strength, aerobic and functional training.

Evaluate safety gates before exercise, including falls, loss of consciousness, serious fall injury, inability to get up, frailty, recent operation/heart attack, active injury, pregnancy/postpartum where relevant, pain, medical uncertainty and concerning exertional symptoms. Replace generic programmes with governed professional-review/safety pathways when appropriate.

Support functional measures from the workbook, including chair stand, five-times chair stand, gait speed, grip strength, Timed Up and Go, staged balance and VO2 max. Preserve protocol and source. Do not combine them into a proprietary biological age in V1.

## 16. Sleep

Display average duration, regularity, timing, rolling 7/28/90-day trends, relevant symptoms and selected wearable context. Do not overreact to one bad night. Consumer REM/deep sleep are estimates, not clinical sleep studies.

Do not diagnose OSA from snoring alone, SpO2, respiratory rate, sleep score or sleep stages. Use deterministic symptom logic from the workbook.

## 17. Nutrition, body composition and weight

Use workbook evidence. Support fruit/vegetables, fibre, salt, free sugars, saturated-fat substitution, fish where eaten, waist-to-height ratio, weight management, vitamin D and protein context.

Do not create supplement stacks, detox programmes, pseudo-scientific UPF toxicity scores, universal fasting prescriptions or extreme unsupervised calorie restriction.

Use non-judgemental weight language.

## 18. Labs and advanced prevention

Support structured manual entry initially for workbook-approved core values such as total cholesterol, HDL, LDL, non-HDL, triglycerides, HbA1c, fasting glucose, ApoB and Lp(a). Store value, unit, date, source/lab and reference range if supplied. Do not assume universal reference ranges or diagnose disease from a single import unless explicit validated logic exists.

Allow longitudinal charts with units, dates and source.

Lp(a): preserve original units, never use a fixed mg/dL <-> nmol/L conversion. ApoB: track if present, do not imply routine annual NHS testing. CAC: Consider only where conventional risk logic supports discussion, never `required because over 40`. ECG: never create universal `ECG due` for asymptomatic adults.

## 19. Broader prevention

Use workbook logic for mental wellbeing, stress, social connection, smoking, alcohol, dental, vision, hearing, sexual health and menopause.

Do not universally psychiatric-screen every user. Do not assign simplistic social scores. Prioritise smoking cessation non-judgementally. Keep alcohol assessment validated/risk-based. Use risk-based dental recall, symptom-led hearing pathways where appropriate, private and behaviour-based sexual-health logic, and evidence-controlled menopause pathways. Do not infer risk solely from identity. Do not recommend routine menopause hormone panels or HRT as a generic longevity treatment where unsupported.

## 20. Priority engine and Top 3

Implement deterministic scoring plus explicit tier barriers. Clinical importance dominates engagement. Use workbook priority logic. If code needs a configurable initial numeric model, keep it centralised and transparent.

Explicit tiers:

- Tier 0: Safety
- Tier 1: high/medium clinically recommended overdue/due actions
- Tier 2: other clinically recommended actions
- Tier 3: high-value missing information
- Tier 4: Consider/risk-dependent actions
- Tier 5: lifestyle Track actions

Do not allow optional advanced testing to outrank important guideline-backed prevention merely through arithmetic. Normally show no more than two lifestyle Track actions and avoid duplicates such as steps + walking + aerobic exercise as all three priorities. Clinical urgency overrides diversity. User goals are tie-breakers only and never alter eligibility/safety.

On action completion: save completion, reevaluate affected rules, update roadmap and show restrained confirmation. No confetti for medical screening.

Support governed snooze for non-urgent tasks. Safety alerts are not ordinary snoozable reminders.

## 21. Notifications

Do not request notification permission during onboarding. Ask after roadmap creation. Keep notifications sparse and neutral. Never put sensitive diagnosis details on the lock screen.

## 22. Design system

The product should feel like premium private healthcare, not an NHS portal, gym game, crypto dashboard or generic template.

Desired qualities: calm, precise, modern, premium, intelligent, trustworthy, human.

Use generous whitespace, SF typography, clear hierarchy, restrained cards/shadows, system light/dark mode, Dynamic Type, VoiceOver, accessible contrast and large touch targets.

Colour semantics: subtle positive for recommended/complete, restrained amber for due, purple/secondary for Consider, blue/neutral for Track, grey for Not routinely recommended, red only for genuine safety. Never use colour alone.

Patient copy is plain, calm, evidence-based, non-judgemental, non-alarmist and concise. UK English only.

Do not create a generic Health Score, Longevity Score or Biological Age in V1. Show interpretable health domains instead.

## 23. Privacy, security and analytics

Create an accessible Privacy & Data area showing connected sources, permissions, what is stored/on-device, cloud-sync state, export, account deletion, health-data deletion, privacy policy, intended purpose and evidence/content version.

Prepare JSON/CSV export for profile, screening, vaccinations, BP, labs, actions/completions and selected wearable summaries.

Security requirements: TLS, Keychain, row-level security where cloud is used, least privilege, secret management, input validation, secure local storage/data-protection classes, redacted logs and database constraints. No secrets in Git. No advertising SDKs or third-party marketing trackers.

Generic analytics may contain privacy-safe product events such as onboarding_started/completed, roadmap_viewed, healthkit_connect_tapped or evidence_opened. Do not send diagnoses, age, screening status, blood values, medications, sexual-health information, wearable values or exact health-action titles into generic analytics.

## 24. Offline-first and clinical updates

Bundle an approved rules snapshot so the core roadmap works offline. Network failure must not remove previously available guidance.

Future remote clinical updates must be signed/validated, schema checked, version checked and effective-date checked before activation. Never execute arbitrary downloaded rules.

## 25. Clinical Inspector and debugging

Create a developer-only Clinical Inspector showing rule ID/version, jurisdiction, dependencies, inputs, eligibility, exclusions, status, priority, display reason and source. Generate machine-readable evaluation traces for clinical QA. Do not expose these internals to ordinary users.

## 26. Required governance and engineering documentation

Create and maintain:

- README.md
- ARCHITECTURE.md
- CLINICAL_GOVERNANCE.md
- PRIVACY_ARCHITECTURE.md
- SECURITY.md
- TESTING.md
- CONTRIBUTING.md
- docs/intended-purpose.md
- docs/clinical-safety/clinical-risk-management-plan.md
- docs/clinical-safety/hazard-log.csv
- docs/clinical-safety/safety-case-outline.md
- docs/clinical-safety/rule-change-log.md

Seed the hazard log with at least: wrong jurisdiction, incorrect age calculation, stale clinical content, future rule activated early, unknown treated as false, missing wearable data treated as zero, incorrect screening status, high-risk user routed to average-risk pathway, safety alert suppressed, optional test presented as mandatory, wrong unit interpretation/Lp(a) conversion, cross-user data access, analytics leakage, stale vaccination rules, rule overwritten without history and incorrect anatomy assumptions.

Do not claim these starter artefacts constitute formal certification.

## 27. Golden clinical tests

Clinical tests are as important as UI tests. Build unit, rule-engine, date-boundary, jurisdiction, unknown-data, priority, safety, HealthKit-adapter, persistence, onboarding UI, roadmap, evidence, backend/RLS and content-import tests.

Create synthetic golden personas at minimum for:

- healthy England age 42
- age 50 bowel-screening pathway
- newly breast-screening-eligible person without false overdue status
- ever-smoker age 60, lung-screening assessment not automatic CT
- AAA-eligible user
- qualifying BRCA2 targeted prostate pathway
- immunocompetent phased shingles user
- severely immunosuppressed shingles user
- high-risk RSV age 65-74 before 1 Sep 2026, should be Upcoming
- same user after 1 Sep 2026, should be Eligible/Due
- known CVD, inappropriate NHS Health Check excluded
- current smoker, cessation prioritised
- falls red flags, generic exercise overridden
- low-risk asymptomatic adult, routine ECG negative recommendation
- moderate cardiovascular risk where CAC may appear as Consider
- unknown hypertension remains unknown

Use fixed dates through injected Clock/DateProvider.

## 28. CI

CI should run build, unit tests, clinical-rule tests, workbook/content import validation, schema validation, duplicate ID detection, invalid date checks, malformed URL checks, linting if used and secret scanning where available. Fail CI for invalid clinical content.

Use small focused types, dependency injection, typed errors, minimal global state and no forced unwraps in production paths. Do not over-engineer simple views or under-engineer the rule engine.

## 29. Demo mode and feature flags

Create synthetic demo profiles for screenshots, product demos, clinical QA and App Store demonstrations. Never use real health data in fixtures.

Create feature flags for at least:

- advancedCardiovascular
- labInterpretation
- aiExplanation
- cloudSync
- subscriptions
- remoteClinicalContent
- clinicianMode

Higher-risk experimental functions OFF by default.

## 30. Do not build in V1

Do not build an AI doctor, broad symptom checker, prescribing, supplement marketplace, whole-body MRI marketplace, blood-test marketplace, insurance scoring, employer medical dashboard, social network, calorie-obsession tracker, unvalidated biological age, chatbot-first navigation or advertising.

## 31. Implementation order

Proceed approximately in this order and keep moving unless genuinely blocked:

1. inspect fresh repository and establish project structure
2. design system and app foundation
3. reconstruct and import clinical workbook
4. domain models
5. deterministic rules engine
6. golden clinical tests
7. local persistence
8. onboarding
9. Today
10. Top 3 engine
11. Roadmap
12. Prevention
13. Evidence views
14. Profile editing
15. Fitness/exercise library
16. exercise safety
17. functional measures
18. HealthKit abstraction and integration
19. Sleep
20. manual BP
21. labs
22. Nutrition
23. Notifications
24. optional auth/cloud sync if configuration is available
25. Privacy centre
26. Clinical Inspector
27. accessibility audit
28. security review
29. CI
30. final polish

Do not begin with AI, subscriptions or elaborate animation. Get the clinical foundation correct first.

## 32. Definition of done

The MVP is done when the iOS app compiles and launches; clinical workbook import succeeds; deterministic rules engine works; golden personas pass; onboarding is polished; Today generates real Top 3 actions; Roadmap produces personalised future milestones; Prevention/evidence tiers work; profile changes trigger reevaluation; exercise progressions/regressions and safety gates work; HealthKit works or has a complete mock if external constraints prevent real access; sleep trends work; manual BP/core lab entry works; local persistence works; privacy controls, audit traces and demo mode exist; no critical tests fail; and documentation is complete.

The UI must feel like a real premium consumer health product, not an engineering demo or spreadsheet viewer. A busy professional should understand their next health priority in roughly ten seconds.

## 33. Decision hierarchy

When trade-offs occur, prioritise in this order:

1. Clinical safety
2. Evidence fidelity
3. User privacy
4. Clarity
5. Accessibility
6. User value
7. Simplicity
8. Performance
9. Visual polish
10. Growth mechanics

Never sacrifice the first four for engagement.

## 34. Final expectation

Do not finish by describing what should be built. Actually build it. Continuously compile and test. Fix failures. Validate clinical content. Exercise demo personas. Be explicit where an integration is mocked.

At completion provide a concise implementation report covering:

- implemented features
- architecture
- clinical-content import/versioning
- rule engine
- HealthKit status
- backend/cloud status
- privacy/security
- test status
- feature flags
- known limitations
- human review required
- exact run instructions
- next recommended development
