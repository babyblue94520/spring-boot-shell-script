#!/bin/sh
# 處理整個服務以下動作：
# 啟動
# 停止
# 備份
# 清除
# 還原

# 進入到Service根目錄
cd $(dirname $0)/..
# 載入設定檔
. $PWD/bin/config/config.sh

#服務是否執行
isRunning() {
	ps -p "$1" &> /dev/null
}

#查看log
log(){
	printlnYellow "tail -f $LOG_FILE"
	tail -f $LOG_FILE
}

#啟動服務
start(){
	if [[ -f "$PID_FILE" ]]; then
		pid=$(cat "$PID_FILE")
		isRunning "$pid" && { printlnYellow "$SERVICE_NAME Already running [$pid]"; return 0; }
	fi
	
	if [ -d "$RUN_FOLDER" ]; then
		doStart "$@"
	else
		update "$@"
	fi
}

doStart(){
	#載入CONF
	[[ -r "$JAR_CONF" ]] && source "$JAR_CONF"
	port=${1:-$SERVER_PORT}
	shift
	printlnRed "$port"
	if [ -z "$port" ]; then
		printlnRed "Please enter service listen port";
		return 1	
	fi
	printlnYellow "$SERVICE_NAME start..."
	working_dir=$(dirname "$JAR_FILE")
  	pushd $working_dir > /dev/null 2>&1
	arguments=(-Dsun.misc.URLClassPath.disableJarChecking=true -server $JAVA_OPTS -jar "$JAR_FILE" $RUN_ARGS --server.port=$port "$@")
	
	# Find Java
	if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
	    javaexe="$JAVA_HOME/bin/java"
	elif type -p java > /dev/null 2>&1; then
	    javaexe=$(type -p java)
	elif [[ -x "/usr/bin/java" ]];  then
	    javaexe="/usr/bin/java"
	else
	    printlnRed "Unable to find Java"
	    return 1
	fi
		
	"$javaexe" "${arguments[@]}" >> "$STARTUP_LOG" 2>&1 &
    pid=$!
    run_user=$(ls -ld "$SOURCE_FOLDER/$JAR_NAME.jar" | awk '{print $3}')
    chown $run_user "$STARTUP_LOG"
    
    disown $pid
    echo "$pid" > "$PID_FILE"
    chown $run_user "$PID_FILE"
    
    trackStart "$port"&
    popd > /dev/null 2>&1
	return 0
}

#追蹤服務啟動是否成功
trackStart(){
	tail -f "$STARTUP_LOG" &
	tail_pid="$!"
	
	# 檢查log輸出停止了
	until curl "http://localhost:$port" &> /dev/null
	do
		isRunning "$pid" || break
		sleep 5
		printlnYellow "start check..."
	done
	
	kill -9 $tail_pid
	#確認服務是否啟動成功
	pid=$(cat "$PID_FILE")
	isRunning "$pid"
	run="$?"
	if [ "0" != "$run" ]; then
		printlnRed "$SERVICE_NAME start fail [$pid]"
	else
		printlnGreen "$SERVICE_NAME start success [$pid]"
		rm -f "$STARTUP_LOG"
	fi
}

#停止服務
stop(){
	[[ -f $PID_FILE ]] || { printlnYellow "$SERVICE_NAME Not running (pidfile not found)"; return 0; }
	pid=$(cat "$PID_FILE")
	isRunning "$pid" || { printlnYellow "$SERVICE_NAME Not running (process ${pid}). Removing stale pid file."; rm -f "$pid_file"; return 0; }
	doStop "$pid" "$PID_FILE"
}

doStop(){
	printlnYellow "$SERVICE_NAME stop..."
	kill "$1" &> /dev/null || { printlnRed "Unable to kill process $1"; return 1; }
  	for i in $(seq 1 $STOP_WAIT_TIME); do
    	isRunning "$1" || { printlnGreen "Stopped [$1]"; rm -f "$2"; return 0; }
    	[[ $i -eq STOP_WAIT_TIME/2 ]] && kill "$1" &> /dev/null
    	sleep 1
  	done
  	printlnRed "Unable to kill process $1";
  	return 1;
}

#重啟服務
restart(){
	stop && start
}

#服務狀態
status() {
  [[ -f "$PID_FILE" ]] || { printlnRed "$SERVICE_NAME Not running"; return 3; }
  pid=$(cat "$PID_FILE")
  isRunning "$pid" || { printlnRed "$SERVICE_NAME Not running (process ${pid} not found)"; return 1; }
  printlnGreen "$SERVICE_NAME Running [$pid]"
  return 0
}

#備份 >停止服務 >更新 >啟動服務
update(){
	printlnYellow "$SERVICE_NAME update..."
	backup;
	# 停止服務
	stop
	# 同步更新資料
	printlnYellow "rsync..."
	
	if ! [[ -r "$SOURCE_FOLDER/$JAR_NAME.conf" ]]; then
		chmod 755 "$SOURCE_FOLDER/$JAR_NAME.jar"
		chmod 755 "$SOURCE_FOLDER/$JAR_NAME.conf"	
	fi
	rsync -auvz --delete "$SOURCE_FOLDER/" "$RUN_FOLDER/" --exclude-from $RUN_IGONRE
	if ! [[ -e "$LOG_PATH" ]] ; then
		mkdir -pv "$LOG_PATH"
		run_user=$(ls -ld "$SOURCE_FOLDER/$JAR_NAME.jar" | awk '{print $3}')
		chown $run_user "$LOG_PATH"
	fi
	# 啟動服務
	start "$@"
	return 0
}

#備份 >停止服務 >更新 >啟動服務
updateStatic(){
	printlnYellow "$SERVICE_NAME update static file..."
	backup "$@";
	rsync -auvz "$SOURCE_FOLDER/" "$RUN_FOLDER/" --exclude '*.jar'
}

#備份
backup(){
	printlnYellow "$SERVICE_NAME backup ..."
	# 檢查是否需要備份目前版本
	if [ -e "$RUN_FOLDER" ]; then
		printlnYellow "$RUN_FOLDER backup..."
		rsync -auvz --delete "$RUN_FOLDER/" "$BACKUP_FOLDER-$BACKUP_DATE/" --exclude-from $BACKUP_IGONRE
		TOPBACKUP=$(find "$PWD/" -maxdepth 1 -type d -name "backup*" -printf "%f\n" | sort -n -r | head -$BACKUP_COUNT)
		TOPBACKUP=$(printf "! -name \"%s\" " $TOPBACKUP)
		eval find \"$PWD/\" -maxdepth 1 -type d -name \"backup*\" $TOPBACKUP -exec rm -rf {} \\\;
		printlnGreen "backup to $BACKUP_FOLDER-$BACKUP_DATE success"
	else
		printlnGreen "No backup required"
	fi
	return 0
}

#清除所有備份
cleanbackup(){
	printlnYellow "$SERVICE_NAME clean all backup..."
	# 移除備份
	find "$PWD/" -maxdepth 1 -type d -name "backup*" -exec rm -rf {} \;
	return 0
}

#還原第幾個備份目錄
restore(){
	# 還原第幾個備份目錄
	TOP=${1:-1}
	# 還原的備份目錄
	BACKUP=$(find $PWD -maxdepth 1 -type d -name "backup*" | sort -n -r | head -$TOP)
	
	if ! [[ -d $BACKUP ]]; then
		printlnRed "No backup"
		return 1
	fi
	
	printlnYellow "$SERVICE_NAME restore..."
	stop
	
	printlnYellow "remove $RUN_FOLDER"
	rm -rf $RUN_FOLDER
	
	printlnYellow "rsync $BACKUP to $RUN_FOLDER/"
	rsync -auvz --delete "$BACKUP/" "$RUN_FOLDER/"
	shift
	start "$@"
	return 0
}

action="$1"
shift

case "$action" in
	start)
	start "$@"; exit $?;;
	stop)
	stop "$@"; exit $?;;
	restart)
	restart "$@"; exit $?;;
	status)
	status "$@"; exit $?;;
	update)
	update "$@"; exit $?;;
	updateStatic)
	updateStatic "$@"; exit $?;;
	cleanbackup)
	cleanbackup "$@"; exit $?;;
	restore)
	restore "$@"; exit $?;;
	backup)
	backup "$@"; exit $?;;
	log)
	log "$@"; exit $?;;
	*)
 	printlnGreen "Usage: $0 {start|stop|restart|update|updateStatic|cleanbackup|restore|backup|log}"
 	printlnGreen "start 80 :start service and listen 80 port"
	printlnGreen "stop:stop service"
	printlnGreen "restart:restart service"
	printlnGreen "status:service status "
	printlnGreen "update 80 :update service and restart service and listen 80 port"
	printlnGreen "updateStatic:update static file and not restart service"
	printlnGreen "cleanbackup:clean all backup。"
	printlnGreen "restore 1~5 80:restore for number and listen 80 port"
	printlnGreen "backup:backup service"
	printlnGreen "log: tail -f log"
	exit 1;
esac
exit 0