@echo off
setlocal

:: Check if parameter is provided
if "%~1"=="" (
    echo Usage: fetch_logs.bat ^<algorithm_name^>
    echo Example: fetch_logs.bat kem_mlkem512_sig_falcon512
    exit /b 1
)

:: Set the algorithm name from the passed argument
set ALG_NAME=%1

:: Define remote user and IPs
set USER=sanzida
set SERVER1=192.168.255.134
set SERVER2=192.168.255.135

:: Define remote paths
set SERVER_LOGS_PATH=/home/%USER%/Downloads/boringssl/build/server_logs/
set CLIENT_LOGS_PATH=/home/%USER%/Downloads/boringssl/build/client_logs/
set PCAPS_PATH=/home/%USER%/Downloads/boringssl/build/pcaps/


:: Download Server Logs
echo Fetching Server Logs...
scp -r %USER%@%SERVER1%:%SERVER_LOGS_PATH%%ALG_NAME%* ./

for /D %%G in (%ALG_NAME%*) do (
    pushd %%G

    echo 🔍 Inside folder: %%G
	:: Download PCAP Files
	echo Fetching PCAP Files...
	scp %USER%@%SERVER2%:%PCAPS_PATH%%ALG_NAME%* ./

	:: Download Client Logs
	echo Fetching Client Logs...
	scp -r %USER%@%SERVER2%:%CLIENT_LOGS_PATH%%ALG_NAME%* ./

	popd
)

echo All files for %ALG_NAME% downloaded successfully!
exit /b 0
