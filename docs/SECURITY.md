# Безпека BRAVO SYSTEM REPORT

## Чутливі дані

Звіт може містити:

- імена користувачів;
- домени та DNS suffix;
- IP-адреси та MAC-адреси;
- серійні номери обладнання;
- список локальних адміністраторів;
- список встановленого ПЗ;
- listening ports та процеси;
- фрагменти журналів подій.

## Правила

- Не комітити сформовані звіти в Git.
- Не публікувати HTML/JSON-звіти у відкритому доступі.
- Для передачі третім сторонам використовувати параметр `-Sanitize` (`-SanitizeLevel Basic|Strict`) — маскує computer name, user name, domain/DNS suffix, public IPv4, MAC-адреси, серійні номери, локальних адміністраторів, install paths; `Strict` додатково маскує приватні IPv4/gateway/DNS. Деталі: `CHANGELOG.md` P1/v0.4.3, `src/45-Sanitize.ps1`.
- Не збирати паролі, токени, private keys, cookies або browser credentials.
- Не експортувати секретні registry-гілки без явної потреби.

## Рекомендований режим GitHub

Для цього проекту рекомендовано приватний репозиторій.

## CI trust model

Проєкт використовує persistent self-hosted Windows runner `BRAVO-SYSTEM-REPORT-WIN`
(labels: `self-hosted, Windows, X64, bravo-system-report`).

Цей runner вважається **trusted execution environment**, бо він має:

- persistent filesystem між jobs;
- runner credentials;
- доступ до локальної мережі;
- можливі локальні credentials;
- потенціал для lateral movement і persistence.

### Чому untrusted PR не виконується на self-hosted runner

Код у pull request може бути надісланий будь-ким, зокрема з fork. Якщо такий код
збирається і виконується на self-hosted runner, автор PR фактично отримує remote code
execution на локальній Windows-машині. Відсутність GitHub secrets у fork PR цього не
компенсує: під загрозою сам host, а не тільки secrets.

Тому `.github/workflows/local-windows-validation.yml`:

- **не має** тригерів `pull_request` і `pull_request_target`;
- запускається лише на `push` у `main` / `bravo/integration/modular-build` та на
  `workflow_dispatch` — тобто на подіях, які вимагають write-доступу до репозиторію;
- має job-level gate `if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'`,
  тож job взагалі не потрапляє в чергу runner-а для іншої події;
- перед checkout виконує крок `Trust gate`, який ще раз перевіряє provenance події,
  щоб недовірений код не потрапив на persistent filesystem;
- робить checkout із `persist-credentials: false`, щоб job token не залишався у
  `.git/config` на постійній машині.

`pull_request_target` свідомо не використовується: у поєднанні з checkout-ом і
виконанням PR-коду він дав би недовіреному коду ще й write-контекст репозиторію.

### Які події запускають trusted Windows validation

| Подія | Windows validation |
|---|---|
| `push` у `main` | так |
| `push` у `bravo/integration/modular-build` | так |
| `workflow_dispatch` | так, на ревізії, яку обрав maintainer |
| `push` тега `v*` | так, через `release.yml` |
| будь-який `pull_request` | ні |

### Де проходять PR checks

`.github/workflows/pr-validation.yml` виконується на ephemeral GitHub-hosted runner
(`ubuntu-latest`). Він лише статично аналізує код PR — не збирає його і не запускає.
Окремий крок `Self-hosted runner trust guard` перевіряє, що жоден workflow у репозиторії
не поєднує `pull_request` / `pull_request_target` із self-hosted runner.

### Permissions

- `pr-validation.yml` — `contents: read`;
- `local-windows-validation.yml` — `contents: read`;
- `powershell-static-check.yml` — `contents: read`;
- `release.yml` — `contents: write` (потрібно для публікації GitHub Release).

### Обов'язкове налаштування репозиторію

Зміни у workflow закривають наявний execution path, але GitHub дозволяє pull request-у
приносити власні workflow-файли. Тому для публічного репозиторію в
**Settings → Actions → General → Fork pull request workflows from outside collaborators**
має бути вибрано **Require approval for all external contributors**.

Без цього налаштування зовнішній contributor, який уже має прийнятий PR, може додати
власний workflow із `runs-on: self-hosted` і обійти trust boundary, описану вище.
