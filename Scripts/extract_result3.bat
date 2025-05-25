@echo off
setlocal EnableDelayedExpansion

REM Step 1: Set working directory
REM cd /d "C:\Users\sanzi\Downloads\data5_9_10"
cd /d "%~dp0"
echo [INFO] Working directory set to %CD%

REM Step 2: Prepare output
set "header=Folder"
echo. > structured_results1.csv
if exist _temp_extract rd /s /q _temp_extract
mkdir _temp_extract >nul 2>&1

REM Step 3: Read each entry from Command_Combinations.csv (skip header)
echo [INFO] Reading folder names from Command_Combinations.csv...

for /f "skip=1 tokens=1 delims=," %%F in (Command_Combinations.csv) do (
    echo -----------------------------------------
    echo [INFO] Looking for folder starting with: %%F*

    for /d %%D in ("%%F*") do (
        call set "folder_name=%%D"
        call set "row=%%D"
        echo [INFO] Processing folder: !folder_name!

        del /q _temp_extract\current_metrics.txt >nul 2>&1

        REM === Server log ===
        if exist "%%D\all_values_server.txt" (
            echo [INFO] Found server log: %%D\all_values_server.txt
            for /f "tokens=1,* delims=:" %%A in ('type "%%D\all_values_server.txt" ^| findstr ":"') do (
                set "key=%%A"
                set "value=%%B"
                call :clean_key "!key!" key_clean
                >> _temp_extract\current_metrics.txt echo !key_clean!=!value!
            )
        ) else (
            echo [WARN] Server log missing for: %%D
        )

        REM === Client log ===
REM === Client log parser: Structured key-value extraction ===
for /d %%C in ("%%D\%%F*") do (
    if exist "%%C\all_values_client.log" (
        echo [INFO] Found client log: %%C\all_values_client.log

        set "TLSLatency="
        set "Bandwidth="
        set "RTT="
        set "TotalPackets="
        set "Retransmissions="
        set "readBandwidth=0"

        for /f "usebackq tokens=* delims=" %%L in ("%%C\all_values_client.log") do (
            set "line=%%L"

            REM Clean emojis
            for %%X in ("📌" "📈" "📊" "📦" "🔁" "✅" "🚨" "🔐") do (
                call set "line=%%line:%%~X=%%"
            )



            if "!readBandwidth!"=="1" (
                REM Bandwidth line follows previous
                set "Bandwidth=!line!"
                set "readBandwidth=0"
            ) 
            echo !line! | findstr /c:"Average TLS Handshake Latency:" >nul
            if !errorlevel! == 0 (
                for /f "tokens=1,* delims=:" %%a in ("!line!") do set "tempLine=%%b"
                if defined tempLine call set "TLSLatency=!tempLine:~1!"
            )

            echo !line! | findstr /c:"Bandwidth:" >nul
            if !errorlevel! == 0 (
                set "readBandwidth=1"
            )

            echo !line! | findstr /c:"RTT Min:" >nul
            if !errorlevel! == 0 (
                for /f "tokens=1,* delims=:" %%a in ("!line!") do set "tempLine=%%b"
                if defined tempLine call set "RTT=!tempLine:~1!"
            )

            echo !line! | findstr /c:"Total Packets:" >nul
            if !errorlevel! == 0 (
                for /f "tokens=1,* delims=:" %%a in ("!line!") do set "tempLine=%%b"
                if defined tempLine call set "TotalPackets=!tempLine:~1!"
            )

            echo !line! | findstr /c:"Retransmissions:" >nul
            if !errorlevel! == 0 (
                for /f "tokens=1,* delims=:" %%a in ("!line!") do set "tempLine=%%b"
                if defined tempLine call set "Retransmissions=!tempLine:~1!"
            )

            REM Skip command-like lines
            echo !line! | findstr /c:"Ciphers Observed" /c:"TLS Versions" /c:"Packet Size Distribution" >nul
            )
        
 

        REM Append structured key-value pairs
        >> _temp_extract\current_metrics.txt echo Average TLS Handshake Latency=!TLSLatency!
        >> _temp_extract\current_metrics.txt echo Bandwidth=!Bandwidth!
        >> _temp_extract\current_metrics.txt echo RTT=!RTT!
        >> _temp_extract\current_metrics.txt echo Total Packets=!TotalPackets!
        >> _temp_extract\current_metrics.txt echo Retransmissions=!Retransmissions!
    ) else (
        echo [WARN] No client log in: %%C
    )
)

        REM === Build row from metrics ===
        for /f "tokens=1,* delims==" %%K in (_temp_extract\current_metrics.txt) do (
            set "k=%%K"
            set "v=%%L"
            echo !header! | findstr /i /c:",!k!" >nul || (
                echo [INFO] New header key added: !k!
                set "header=!header!,!k!"
            )
            set "row=!row!,!v!"
        )

        echo !row!>> structured_results1.csv
    )
)

REM Step 4: Final output
echo [INFO] Writing final structured_results1.csv...

(for %%H in ("!header!") do (
    echo %%~H
    type structured_results1.csv | findstr /v /c:"Folder"
)) > temp_final.csv

move /y temp_final.csv structured_results1.csv >nul
rd /s /q _temp_extract >nul

echo [SUCCESS] Structured results saved in structured_results1.csv
pause
exit /b

REM -------- CLEANING FUNCTION ----------
:clean_key
set "%~2=%~1"
for %%C in ("📌" "📈" "📊" "📦" "🔁" "✅" "🚨" "🔐") do (
    set "%~2=!%~2:%%~C=!"
)
set "%~2=!%~2:~1!"
exit /b
