Clear-Host
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "    ML-Agents Training Menu" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Cyan
# Выбор yaml файла
Write-Host ""
Write-Host "Available YAML Configs:" -ForegroundColor Yellow
$configs = Get-ChildItem -Path "N:\ml-agents-develop\config\ppo\" -Filter *.yaml | Select-Object -ExpandProperty Name
$configs | ForEach-Object { Write-Host $_ -ForegroundColor DarkCyan }
Write-Host ""
$config_name = Read-Host "Введите имя yaml config файла (без .yaml)"
# Ввод имени run
$run_id = Read-Host "Введите имя run (название обучения)"
# Ввод пути сохранения
$save_path = Read-Host "Введите путь для сохранения результатов (например: N:\ml-agents-develop\results)"
# Подтверждение
Write-Host ""
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host "Config: $config_name.yaml" -ForegroundColor Green
Write-Host "Run-id: $run_id" -ForegroundColor Green
Write-Host "Save path: $save_path" -ForegroundColor Green
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host ""
# Проверка существования пути
if (!(Test-Path $save_path)) {
    Write-Host "Путь $save_path не существует. Создаю..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $save_path | Out-Null
}

# Типичные пути к Conda
$condaPaths = @(
    "C:\ProgramData\Anaconda3",
    "C:\ProgramData\miniconda3",
    "C:\Users\$env:USERNAME\Anaconda3",
    "C:\Users\$env:USERNAME\miniconda3",
    "$env:USERPROFILE\Anaconda3",
    "$env:USERPROFILE\miniconda3"
)

# Проверка, существует ли Conda скрипт по одному из путей
$condaPath = $null
foreach ($path in $condaPaths) {
    if (Test-Path "$path\Scripts\activate.bat") {
        $condaPath = "$path\Scripts\activate.bat"
        break
    }
}

# Запуск обучения
Write-Host "Запуск обучения..." -ForegroundColor Cyan

if ($condaPath) {
    Write-Host "Найден Conda по пути: $condaPath" -ForegroundColor Green
    # Изменено - убран аргумент --output-dir
    $commandLine = "`"$condaPath`" ML_Agents && cd /d N:\ml-agents-develop\ml-agents && mlagents-learn ..\config\ppo\$config_name.yaml --run-id=$run_id --time-scale=20 --force"
    Write-Host "Выполняется команда: $commandLine" -ForegroundColor Yellow
    Start-Process cmd -ArgumentList "/K", $commandLine
} else {
    Write-Host "Не удалось найти Conda на этом компьютере. Укажите путь к файлу activate.bat:" -ForegroundColor Red
    $customCondaPath = Read-Host "Введите полный путь к файлу activate.bat (например, C:\ProgramData\Anaconda3\Scripts\activate.bat)"
    
    if (Test-Path $customCondaPath) {
        # Изменено - убран аргумент --output-dir
        Start-Process cmd -ArgumentList "/K", "`"$customCondaPath`" deep_rl && cd /d N:\ml-agents-develop\ml-agents && mlagents-learn ..\config\ppo\$config_name.yaml --run-id=$run_id --time-scale=20 --force"
    } else {
        Write-Host "Указанный путь не существует. Попробуйте запустить скрипт вручную из Anaconda Prompt." -ForegroundColor Red
    }
}

Pause