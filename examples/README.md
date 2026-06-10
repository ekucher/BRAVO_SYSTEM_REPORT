# Приклади запуску

## Базовий запуск

```powershell
.\Get-BravoSystemReport.ps1
```

## JSON + HTML + CSV + ZIP

```powershell
.\Get-BravoSystemReport.ps1 -CSV -Zip
```

## Без паузи після завершення

```powershell
.\Get-BravoSystemReport.ps1 -CSV -Zip -NoPause
```

## Без emoji для старих консолей

```powershell
.\Get-BravoSystemReport.ps1 -CSV -Zip -NoEmoji
```

## Лише JSON

```powershell
.\Get-BravoSystemReport.ps1 -JSONOnly
```
