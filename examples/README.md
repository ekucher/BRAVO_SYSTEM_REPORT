# Приклади запуску

## Базовий запуск

JSON + HTML + ZIP створюються за замовчуванням (`-Zip` увімкнено за замовчуванням).

```powershell
.\Get-BravoSystemReport.ps1
```

## Додатково CSV

```powershell
.\Get-BravoSystemReport.ps1 -CSV
```

## Без ZIP

```powershell
.\Get-BravoSystemReport.ps1 -NoZip
```

## Без паузи після завершення

```powershell
.\Get-BravoSystemReport.ps1 -CSV -NoPause
```

## Без emoji для старих консолей

```powershell
.\Get-BravoSystemReport.ps1 -CSV -NoEmoji
```

## Лише JSON (без HTML)

`-JSONOnly` пропускає лише HTML-файл; ZIP і далі створюється за замовчуванням — додайте `-NoZip`, якщо потрібен суто JSON-файл без обгортки.

```powershell
.\Get-BravoSystemReport.ps1 -JSONOnly -NoZip
```
