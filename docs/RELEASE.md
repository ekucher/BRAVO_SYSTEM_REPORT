# Реліз BRAVO SYSTEM REPORT

Опис процесу створення й перевірки release package — і локально, і через CI
(`.github/workflows/release.yml`).

## Передумови

- Усі потрібні PR змержено в `developer`, `developer` змержено в `main` (див.
  git-workflow у `docs/PROJECT_RULES.md`).
- `CHANGELOG.md` має заголовок конкретного релізу у форматі `## vX.Y.Z — ...`
  (поки що більшість записів мають вигляд `## Unreleased — ...` — перед
  тегуванням релізу найновіший розділ треба перейменувати на `## vX.Y.Z`).
- `$ScriptVersion` у `src/90-Main.ps1` **точно** відповідає версії в
  `CHANGELOG.md` — CI (`release.yml`, крок "Resolve version") звіряє їх і
  падає з помилкою при розбіжності, так само як і назву git-тега (`vX.Y.Z`)
  для tag-push сценарію.

## Локальна перевірка перед релізом

```powershell
# 1. Зібрати модульний runtime + sha512
.\Build-BRAVO-SystemReport.ps1 -CreateSha512

# 2. Прогнати весь тестовий набір (Pester)
Invoke-Pester -Path tests

# 3. Зібрати release package (ZIP + sha256) у ./artifacts
.\tools\New-ReleasePackage.ps1

# 4. Наскрізна перевірка самого пакета: розпакування в temp +
#    запуск BRAVO-SystemReport-Quick.bat --nopause з розпакованої копії +
#    перевірка, що JSON/HTML справді створюються.
#    Покрито Pester-тестом tests/ReleasePackage.Tests.ps1 — входить у
#    Invoke-Pester -Path tests з кроку 2, окремо повторювати не треба.
```

`tools/New-ReleasePackage.ps1` сам звіряє `dist/Get-BravoSystemReport.ps1`
проти `dist/Get-BravoSystemReport.ps1.sha512` перед пакуванням і падає з
помилкою, якщо вони розійшлися (тобто крок 1 пропустити не можна).

Версія пакета визначається автоматично з `src/90-Main.ps1`
(`$ScriptVersion`); передати іншу можна через `-Version`. За замовчуванням
результат — `./artifacts/BRAVO_SYSTEM_REPORT_v<version>.zip` (+ `.sha256`).

## Автоматичний реліз через CI

Workflow `.github/workflows/release.yml` запускається:

- **push тега** `v*` — повний прогін: build → quick runtime test → package →
  verify package content → publish GitHub Release (реліз публікується
  автоматично, без ручного підтвердження);
- **вручну** (`workflow_dispatch`) — за замовчуванням **dry run**: пакет
  збирається й перевіряється, викладається як workflow artifact, але GitHub
  Release НЕ публікується. Щоб опублікувати з ручного запуску, увімкнути
  input `publish_release: true` — тег `vX.Y.Z` GitHub створить сам на тому
  commit, з якого запущено workflow.

Кроки workflow (у порядку виконання):

1. **Resolve version** — читає `$ScriptVersion` з `src/90-Main.ps1` і
   версію з найновішого `## vX.Y.Z` заголовка `CHANGELOG.md`, звіряє між
   собою (і з git-тегом для tag-push сценарію) — падає при розбіжності.
2. **Build modular monolith** — `Build-BRAVO-SystemReport.ps1 -Clean -CreateSha512`.
3. **Quick runtime test** — `dist/Get-BravoSystemReport.ps1 -Profile Quick`
   на runner'і, перевіряє exit code 0.
4. **Build release package** — `tools/New-ReleasePackage.ps1 -Version <resolved>`.
5. **Verify package content** — розпаковує ZIP в окрему директорію,
   перевіряє наявність `dist/Get-BravoSystemReport.ps1` (+ `.sha512`,
   звіряє хеш), `Get-BravoSystemReport.ps1`, `MANIFEST.txt`, парситься без
   синтаксичних помилок, версія в runtime збігається з очікуваною.
6. **Upload workflow artifact** — ZIP + sha256 як artifact, доступний навіть
   у dry run.
7. **Publish GitHub Release** (лише за push тега або `publish_release: true`)
   — текст релізу береться з відповідного розділу `CHANGELOG.md`; якщо
   реліз з таким тегом вже існує — падає з помилкою (без перезапису).

## Публікація вручну (без CI)

Для сценаріїв без self-hosted runner — після кроків "Локальна перевірка"
вище:

```powershell
gh release create v<version> `
  ./artifacts/BRAVO_SYSTEM_REPORT_v<version>.zip `
  ./artifacts/BRAVO_SYSTEM_REPORT_v<version>.zip.sha256 `
  --title "BRAVO SYSTEM REPORT v<version>" `
  --notes-file <файл з витягом з CHANGELOG.md>
```

## Типові причини падіння релізу

| Крок | Причина | Виправлення |
|---|---|---|
| Resolve version | `CHANGELOG.md` не має `## vX.Y.Z`-заголовка (лише `## Unreleased`) | Перейменувати найновіший розділ на `## vX.Y.Z — ...` перед тегуванням |
| Resolve version | `$ScriptVersion` ≠ версія в `CHANGELOG.md` | Синхронізувати вручну |
| Build release package | `dist/*.sha512` не відповідає `dist/*.ps1` | Перезібрати: `.\Build-BRAVO-SystemReport.ps1 -CreateSha512` |
| Publish GitHub Release | Реліз з таким тегом вже існує | Використати нову версію або видалити помилковий реліз вручну |
