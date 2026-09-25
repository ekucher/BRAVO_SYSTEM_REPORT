# Правила проекту BRAVO SYSTEM REPORT

## Мова і стиль

- Усі відповіді, commit messages, PR descriptions, merge descriptions і документація ведуться українською мовою.
- Консольний вивід має бути простим і production-friendly.
- Для службового консольного виводу використовуються маркери:
  - `[INFO]`
  - `[OK]`
  - `[SUCCESS]`
  - `[ERROR]`

## Emoji

- У PowerShell-службових повідомленнях, логах і console contract output emoji не використовуються.
- HTML-звіт є винятком із правила: emoji дозволені як частина візуального оформлення звіту.
- Emoji в HTML не повинні впливати на JSON, CSV, логіку збору даних або консольний вивід.

## Git workflow

- Основна стабільна гілка: `main`; поточна лінія розробки — `developer`.
- Зміни виконуються через окремі гілки (feature/fix/release), PR у `developer` (не напряму в `main`).
- Перед merge потрібно перевіряти PR, diff і checks.
- Pull request перевіряється автоматично на GitHub-hosted runner: `.github/workflows/pr-validation.yml`
  (лише статичні перевірки, включно з guard проти self-hosted+`pull_request`) і
  `.github/workflows/powershell-static-check.yml` (Windows-незалежні перевірки — parser
  check, contract change guard, version consistency, parameter-surface guard). Обидва
  тригеряться на PR у `main`/`developer`/`release/**`.
- Windows integration validation на self-hosted runner (`.github/workflows/local-windows-validation.yml`,
  реальний runtime — Quick/Full/Deep, повний Pester) виконується тільки для trusted code:
  `push` у `main`/`developer`/`bravo/integration/modular-build`/`release/**`, `workflow_dispatch`
  і release/tag flow — ніколи для `pull_request`. Деталі — у `docs/SECURITY.md`.

## Branch protection (рекомендація, не застосована автоматично)

Repository rulesets/branch protection для `main` і `developer` наразі не
налаштовані (`main protected = false`, `developer protected = false`, станом
на 2026-09-25). Claude Code не змінює repository settings самостійно —
це задокументована рекомендація власнику репозиторію.

Для `main`:

- Require a pull request before merging.
- Require status checks to pass before merging:
  - `Validate modular build on local Windows runner` (workflow `Local Windows Validation`);
  - `Static validation (hosted, без Windows-only залежностей)` (workflow `PowerShell Static & Hosted Validation`);
  - `Static validation on GitHub-hosted runner` (workflow `PR Validation`).
- Block force pushes.
- Restrict deletions.
- Require conversation resolution before merging.

Для `developer`:

- Require a pull request before merging.
- Require status checks to pass before merging (ті самі три check, що й для `main`).
- Block force pushes.
