@echo off
setlocal enabledelayedexpansion

if "%FUNCTIONS%"=="" (
    echo ⚠️ No functions specified in FUNCTIONS variable. Exiting...
    exit /b 0
)

set FUNCTIONS_LIST=%FUNCTIONS%
set COUNT=0

REM Replace commas with spaces
set FUNCTIONS_LIST=%FUNCTIONS_LIST:,= %

for %%F in (%FUNCTIONS_LIST%) do (
    set /a COUNT+=1
    echo 🚀 Deploying function %%F

    gcloud functions deploy %%F ^
        --gen2 ^
        --runtime nodejs20 ^
        --region "%REGION%" ^
        --project "%PROJECT%" ^
        --trigger-http ^
        --allow-unauthenticated ^
        --entry-point helloHttp ^
        --source ./Function-1
)

echo ✅ Total functions deployed: %COUNT%
exit /b 0
