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

- Основна гілка: `main`.
- Зміни виконуються через patch-гілки.
- Перед merge потрібно перевіряти PR, diff і checks.
- GitHub Actions перевірка PowerShell тимчасово переведена в ручний режим до окремого налаштування runner/policy.