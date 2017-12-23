# SpringBoot Shell Script

## 前言
Spring-Boot預設的Linux啟動腳本有些問題，以及一些特殊需求。  
1. 啟動過程的log跟專案的log是分開的，很難管理外，也會無限成長。
2. 啟動成功與否的判斷是假的。
3. Linux部屬設定過程需要sudo權限，像我們渣渣工程師怎會有sudo權限呢！
4. 環境很赤裸裸的，備份復原都得自己來。
5. Java更新重啟會中斷服務，除了需要一些不中斷服務的手段外，更新失敗還要趕快復原。

## 說明
* linux：已經移除了window開發時的\\r。
* windows：在windows底下開發的原始檔。

* config：
  * config.sh：參數設定。
  * backup-exclude-list.txt：備份時，排除不同步的檔案。
  * run-exclude-list.txt：同步到執行目錄時，排除不同步的檔案。
* action.sh  
指令說明
  * start：啟動服務。
  * stop：停止服務。
  * restart：重新啟動服務。
  * status：服務狀態。
  * update：備份running，再將source目錄產生或同步到running並重啟動服務。。
  * updateStatic：備份running，只同步source靜態資料到running。
  * cleanbackup：清除備份檔。
  * restore：還原指定的順序備份檔到running並重新啟動。

		//還原最新備份
       	action.sh restore 1 

  * backup：備份running，最多保留5個備份檔
  * log：tail log
* temp.sh  
  或許覺得這個很蠢，但是只有一台機器又要做到更新不中斷服務，為何不用nginx等等的服務做load balance?很難去解釋線上有些request失敗是因為更新過程中，極少數的request訪問到死掉的服務，就連iptable提供的load balance再關閉其中一個服務，都會有1~3%的請求失敗。
  * start：複製running到temp並依指定的port啟動服務
  * stop：停止temp 服務
  * redirect：利用iptable重新定向 

  		temp.sh redirect 80 9081
  * cleanRedirect：清除重新定向  

  		temp.sh cleanRedirect 80 9081
  * createTemp：建立running目錄的備份暫時目錄
  * cleanTemp：清除暫時目錄
		
## 使用說明
* 初始Linux目錄結構：
	* service
		* bin：shell script放這裡面。
		* source：你的JAR放這裡面。
* config設定：
	
    	# jar 名稱
        JAR_NAME="這麼多參數裡面，你只要設定jar名稱就好了"
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

* 起手式：  
這樣就會自動幫你把source同步到running，然後啟動服務。

		sh demo/bin/action.sh update
## 注意
* *.conf 也需要小心windows \\\r的問題。