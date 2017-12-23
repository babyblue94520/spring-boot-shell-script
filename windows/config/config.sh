#!/bin/sh
# 參數設定檔
# ANSI Colors
format="==================== %s \n"
formatRed="\e[0;31m==================== %s \e[0m\n"
formatGreen="\e[0;32m==================== %s \e[0m\n"
formatYellow="\e[0;33m==================== %s \e[0m\n"
println() { printf "$format" "$1"; }
printlnRed() { printf "$formatRed" "$1"; }
printlnGreen() { printf "$formatGreen" "$1"; }
printlnYellow() { printf "$formatYellow" "$1"; }
# jar 名稱
JAR_NAME=""
# 服務名稱
SERVICE_NAME="$JAR_NAME"
# 資料的原始檔
SOURCE_FOLDER="$PWD/source"
# 運行的目錄
RUN_FOLDER="$PWD/running"
# log目錄
LOG_PATH="$RUN_FOLDER/temp/logs"
# log檔
LOG_FILE="$LOG_PATH/$JAR_NAME.log"
# 備份目錄
BACKUP_FOLDER="$PWD/backup"
# 備份時忽略的檔案
BACKUP_IGONRE="$PWD/bin/config/backup-exclude-list.txt"
# 備份檔時間
BACKUP_DATE=$(date +"%Y%m%d%H%M")
# 同步到運行目錄忽略的檔案
RUN_IGONRE="$PWD/bin/config/run-exclude-list.txt"
# 備份目錄數量
BACKUP_COUNT=5
# PID File
PID_FILE="$PWD/$JAR_NAME.pid"
# startup log
STARTUP_LOG="$PWD/startup.log"
#JAR_FILE
JAR_FILE="$RUN_FOLDER/$JAR_NAME.jar"
#JAR_CONF
JAR_CONF="$RUN_FOLDER/$JAR_NAME.conf"
#START_WAIT_TIME
START_WAIT_TIME=20
#STOP_WAIT_TIME
STOP_WAIT_TIME=60

# 暫時運行目錄
TEMP_RUN_FOLDER="$PWD/temp_running"
# 暫時運行PID
TEMP_PID_FILE="$TEMP_RUN_FOLDER/$JAR_NAME.pid"
# 暫時運行 startup log
TEMP_STARTUP_LOG="$TEMP_RUN_FOLDER/startup.log"
#JAR_FILE
TEMP_JAR_FILE="$TEMP_RUN_FOLDER/$JAR_NAME.jar"
#JAR_CONF
TEMP_JAR_CONF="$TEMP_RUN_FOLDER/$JAR_NAME.conf"