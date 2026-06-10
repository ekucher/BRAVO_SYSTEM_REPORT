# Журнал змін

## 0.2.0 — 2026-06-10

### Додано

- Додано профілі аудиту `Quick`, `Full`, `Deep`, `Forensic`.
- Додано параметри `-OutputPath`, `-NoOpenFolder`, `-EventLogDays`.
- Додано `Health.Score`, `Health.Status`, `Health.Findings`.
- Додано `CollectionErrors` для фіксації помилок збору даних.
- Додано детальніші блоки RAM-модулів, фізичних дисків, мережевих адаптерів, listening TCP-портів, зупинених автоматичних служб.

### Виправлено

- Виправлено конфлікт змінних іконок `$cpu` / `$disk` з об'єктами CPU/дисків.
- Виправлено обчислення часу виконання скрипта.
- Прибрано порожні `catch {}` у ключових секціях.
- Виправлено helper `tools/Publish-ToGitHub.ps1`, щоб уникнути проблем із кодуванням у Windows PowerShell.

## 0.1.0 — 2026-06-10

### Додано

- Ініціалізовано проект **BRAVO SYSTEM REPORT**.
- Додано стартовий скрипт `src/Get-BravoSystemReport.ps1` на основі наданого `Get-SystemAudit.ps1`.
- Додано README, roadmap, архітектурні нотатки, правила безпеки та `.gitignore`.
- Додано базовий GitHub Actions workflow для перевірки PowerShell-скриптів через PSScriptAnalyzer.

### Заплановано

- Рефакторинг скрипта на функції.
- Додавання профілів аудиту `Quick`, `Full`, `Deep`, `Forensic`.
- Додавання `Health Score`, `Findings`, `CollectionErrors`.
- Розширення HTML-звіту.

### Правила проекту

- Зафіксовано українську мову для відповідей, commit messages, PR/merge-описів, документації, логів і консольних повідомлень.
- Прибрано emoji з PowerShell-скриптів.
- Уніфіковано консольний вивід: секції `=== ... ===`, маркери `[INFO]`, `[OK]`, `[SUCCESS]`, `[ERROR]`.
- Додано `.editorconfig` для фіксації кодування PowerShell-скриптів у UTF-8 з BOM.
