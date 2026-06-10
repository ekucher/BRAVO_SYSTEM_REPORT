# Архітектура BRAVO SYSTEM REPORT

## Цільова модель

Скрипт має бути побудований як набір незалежних колекторів, які повертають структуровані об’єкти. Генерація звітів не повинна змішуватися зі збором даних.

## Основні блоки

```text
Parameters
    ↓
Initialize-AuditContext
    ↓
Collect-* functions
    ↓
Analyze-* functions
    ↓
Export-* functions
    ↓
Summary / ExitCode
```

## Рекомендована структура `$Report`

```powershell
$Report = [ordered]@{
    Meta = [ordered]@{}
    Summary = [ordered]@{}
    Health = [ordered]@{
        Score = 0
        Status = ''
        Findings = @()
    }
    OS = [ordered]@{}
    Hardware = [ordered]@{}
    Storage = [ordered]@{}
    Network = [ordered]@{}
    Security = [ordered]@{}
    Services = [ordered]@{}
    Processes = [ordered]@{}
    Software = [ordered]@{}
    Updates = [ordered]@{}
    EventLogs = [ordered]@{}
    CollectionErrors = @()
}
```

## Принципи

- Жодних порожніх `catch {}`.
- Кожен колектор має повертати дані або контрольовану помилку в `CollectionErrors`.
- Скрипт не має зупиняти весь аудит через помилку одного розділу.
- HTML/JSON/CSV/Markdown мають формуватися з одного `$Report`.
- Для старих Windows має бути fallback WMI, для нових — CIM.
- Чутливі дані мають маскуватися через `-Sanitize`.
