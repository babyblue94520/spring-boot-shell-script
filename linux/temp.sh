#!/bin/sh
# 處理整個服務以下動作：
# 將原本運行的服務複製出來運行，再轉發到暫時運行的系統
# 啟動
# 停止
# 轉發
# 清除轉發
# 產生暫存執行目錄
# 清除暫存執行目錄

# 進入到Service根目錄
cd $(dirname $0)/..
# 載入設定檔
. $PWD/bin/config/config.sh

#服務是否執行
isRunning() {
	ps -p "$1" &> /dev/null
}

start(){
	port=$1
	shift
	if [ -z $port ]; then
		printlnRed "Please enter start port"
		return 1;
	fi
	
	if ! [[ -d "$TEMP_RUN_FOLDER" ]]; then
		createTemp
	fi
	
	stop
	
	#載入CONF
	[[ -r "$TEMP_JAR_CONF" ]] && source "$TEMP_JAR_CONF"
	arguments=(-Dsun.misc.URLClassPath.disableJarChecking=true -server $JAVA_OPTS -jar "$TEMP_JAR_FILE" $RUN_ARGS "--server.port=$port" "$@")
	
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
	
	printlnYellow "Temp $SERVICE_NAME start..."
	working_dir=$(dirname "$TEMP_JAR_FILE")
  	pushd $working_dir > /dev/null 2>&1
  	echo "$javaexe ${arguments[@]}"
	"$javaexe" "${arguments[@]}" >> "$TEMP_STARTUP_LOG" 2>&1 &
    pid=$!
    disown $pid
    echo "$pid" > "$TEMP_PID_FILE"
    trackStart &
    popd > /dev/null 2>&1
	return 0
}

#追蹤服務啟動是否成功
trackStart(){
	tail -f "$TEMP_STARTUP_LOG" &
	tail_pid="$!"
	
	sleep 3
	for i in {1..40};
	# 檢查log輸出停止了
	do
		curl "http://localhost:$port" &> /dev/null && break
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
		printlnRed "Temp $SERVICE_NAME start fail [$pid]"
	else
		printlnGreen "Temp $SERVICE_NAME start success [$pid]"
		rm -f "$TEMP_STARTUP_LOG"
	fi
}

# 停止服務並清除所有資料
stop(){
	[[ -f $TEMP_PID_FILE ]] || { printlnYellow "Temp $SERVICE_NAME Not running (pidfile not found)"; return 0; }
	pid=$(cat "$TEMP_PID_FILE")
	isRunning "$pid" || { printlnYellow "Temp $SERVICE_NAME Not running (process ${pid}). Removing stale temp_running folder."; return 0; }
	doStop "$pid" "$TEMP_PID_FILE"
}

doStop(){
	pid=$1
	pidfile=$2
	if [ -z $pid ]; then
		printlnRed "Please enter pid"
		return 1;
	fi
	printlnYellow "$SERVICE_NAME stop..."
	kill "$pid" &> /dev/null || { printlnRed "Unable to kill process $pid"; return 1; }
  	for i in $(seq 1 $STOP_WAIT_TIME); do
    	isRunning "$pid" || { printlnGreen "Stopped [$pid]"; rm -f "$pidfile"; return 0; }
    	[[ $i -eq STOP_WAIT_TIME/2 ]] && kill "$pid" &> /dev/null
    	sleep 1
  	done
  	printlnRed "Unable to kill process $pid";
  	return 1;
}

#服務狀態
status() {
  [[ -f "$TEMP_PID_FILE" ]] || { printlnRed "$SERVICE_NAME Not running"; return 3; }
  pid=$(cat "$TEMP_PID_FILE")
  isRunning "$pid" || { printlnRed "$SERVICE_NAME Not running (process ${pid} not found)"; return 1; }
  printlnGreen "$SERVICE_NAME Running [$pid]"
  return 0
}

# 轉發
redirect() {
	sport=$1
	tport=$2
	if [ -z $sport ]; then
		printlnRed "Please enter source port"
		return 1;
	fi
	if [ -z $tport ]; then
		printlnRed "Please enter target port"
		return 1;
	fi
	sudo /sbin/iptables -t nat -I PREROUTING -p tcp -m tcp --dport $sport -j DNAT --to-destination :$tport
	sudo /sbin/iptables -L -t nat
	return 0
}
# 清除轉發規則
cleanRedirect() {
	sport=$1
	tport=$2
	if [ -z $sport ]; then
		printlnRed "Please enter source port"
		return 1;
	fi
	if [ -z $tport ]; then
		printlnRed "Please enter target port"
		return 1;
	fi
	sudo /sbin/iptables -t nat -D PREROUTING -p tcp -m tcp --dport $sport -j DNAT --to-destination :$tport
	sudo /sbin/iptables -L -t nat
	return 0
}

# 產生暫時的服務目錄
createTemp() {
	if ! [[ -d "$RUN_FOLDER" ]]; then
		printlnRed "No $RUN_FOLDER"
		return 1;
	fi
	# 同步更新資料
	printlnYellow "rsync..."
	rsync -auvz "$RUN_FOLDER/" "$TEMP_RUN_FOLDER/" --exclude-from $RUN_IGONRE
	return 0
}

# 清除暫時的服務目錄
cleanTemp() {
	if [ -e "$TEMP_RUN_FOLDER" ]; then
		rm -rf "$TEMP_RUN_FOLDER"
	fi
	return 0
}

action="$1"
shift

case "$action" in
	start)
	start "$@"; exit $?;;
	stop)
	stop "$@"; exit $?;;
	status)
	status "$@"; exit $?;;
	createTemp)
	createTemp "$@"; exit $?;;
	cleanTemp)
	cleanTemp "$@"; exit $?;;
	redirect)
	redirect "$@"; exit $?;;
	cleanRedirect)
	cleanRedirect "$@"; exit $?;;
	*)
 	printlnGreen "Usage: $0 {start|stop|redirect|cleanRedirect|createTemp|cleanTemp}"
 	printlnGreen "start 9081 :start runing temp service and listen 9081 port"
	printlnGreen "stop:stop runing temp service"
	printlnGreen "redirect: redirect port ex:temp.sh redirect 80 9081"
	printlnGreen "cleanRedirect: clean redirect rule ex:temp.sh cleanRedirect 80 9081"
	printlnGreen "createTemp: create runing temp folder"
	printlnGreen "cleanTemp: clean runing temp folder"
	exit 1;
esac
exit 0