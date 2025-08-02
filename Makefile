# UPS Monitor Daemon Makefile
# 用于安装和管理 UPS 监控守护进程

DAEMON_SCRIPT = ups_monitor_daemon.py
SERVICE_FILE = ups-monitor.service
SERVICE_NAME = ups-monitor

# 安装路径
SCRIPT_INSTALL_PATH = /usr/local/bin/$(DAEMON_SCRIPT)
SERVICE_INSTALL_PATH = /etc/systemd/system/$(SERVICE_FILE)

# 日志文件路径
LOG_FILE = /var/log/ups_monitor.log
EVENT_LOG_FILE = /var/log/ups_monitor_event.json

.PHONY: all install uninstall start stop restart status logs clean check

all: check

# 检查依赖
check:
	@echo "检查系统依赖..."
	@which python3 > /dev/null || (echo "错误: python3 未找到" && exit 1)
	@which systemctl > /dev/null || (echo "错误: systemctl 未找到, 需要 systemd 系统" && exit 1)
	@which pwrstat > /dev/null || (echo "警告: pwrstat 未找到, 请安装 CyberPower PowerPanel")
	@echo "依赖检查完成"

# 安装守护进程
install: check
	@echo "安装 UPS Monitor Daemon..."
	
	# 安装 Python 脚本
	cp $(DAEMON_SCRIPT) $(SCRIPT_INSTALL_PATH)
	chmod 755 $(SCRIPT_INSTALL_PATH)
	chown root:root $(SCRIPT_INSTALL_PATH)
	
	# 安装 systemd service
	cp $(SERVICE_FILE) $(SERVICE_INSTALL_PATH)
	chmod 644 $(SERVICE_INSTALL_PATH)
	chown root:root $(SERVICE_INSTALL_PATH)
	
	# 创建日志文件和目录
	touch $(LOG_FILE)
	touch $(EVENT_LOG_FILE)
	chmod 644 $(LOG_FILE) $(EVENT_LOG_FILE)
	chown root:root $(LOG_FILE) $(EVENT_LOG_FILE)
	
	# 重新載入 systemd
	systemctl daemon-reload
	
	@echo "安装完成!"
	@echo "使用以下命令启用并启动服务:"
	@echo "  make enable"
	@echo "  make start"

# 启用服务 (开机自启)
enable:
	systemctl enable $(SERVICE_NAME).service
	@echo "服务已设置为开机自启"

# 禁用服务 (取消开机自启)
disable:
	systemctl disable $(SERVICE_NAME).service
	@echo "服务已取消开机自启"

# 啟動服務
start:
	systemctl start $(SERVICE_NAME).service
	@echo "服務已啟動"

# 停止服務
stop:
	systemctl stop $(SERVICE_NAME).service
	@echo "服務已停止"

# 重啟服務
restart:
	systemctl restart $(SERVICE_NAME).service
	@echo "服務已重啟"

# 檢視服務狀態
status:
	systemctl status $(SERVICE_NAME).service

# 檢視即時日誌
logs:
	journalctl -u $(SERVICE_NAME).service -f

# 檢視最近的日誌
logs-recent:
	journalctl -u $(SERVICE_NAME).service -n 50

# 檢視應用日誌檔案
logs-file:
	tail -f $(LOG_FILE)

# 卸載守護程序
uninstall:
	@echo "卸載 UPS Monitor Daemon..."
	
	# 停止並禁用服務
	-systemctl stop $(SERVICE_NAME).service
	-systemctl disable $(SERVICE_NAME).service
	
	# 刪除檔案
	-rm -f $(SCRIPT_INSTALL_PATH)
	-rm -f $(SERVICE_INSTALL_PATH)
	
	# 重新載入 systemd
	systemctl daemon-reload
	
	@echo "卸載完成!"
	@echo "注意: 日誌檔案保留在 $(LOG_FILE) 和 $(EVENT_LOG_FILE)"

# 清理日誌檔案
clean-logs:
	rm -f $(LOG_FILE) $(EVENT_LOG_FILE)
	@echo "日誌檔案已清理"

# 完全清理 (包括日誌)
clean: uninstall clean-logs

# 顯示說明資訊
help:
	@echo "UPS Monitor Daemon Makefile"
	@echo ""
	@echo "可用命令:"
	@echo "  make check       - 檢查系統相依性"
	@echo "  make install     - 安裝守護程序"
	@echo "  make enable      - 啟用服務 (開機自啟)"
	@echo "  make disable     - 禁用服務"
	@echo "  make start       - 啟動服務"
	@echo "  make stop        - 停止服務"
	@echo "  make restart     - 重啟服務"
	@echo "  make status      - 檢視服務狀態"
	@echo "  make logs        - 檢視即時日誌"
	@echo "  make logs-recent - 檢視最近日誌"
	@echo "  make logs-file   - 檢視應用日誌檔案"
	@echo "  make uninstall   - 卸載守護程序"
	@echo "  make clean-logs  - 清理日誌檔案"
	@echo "  make clean       - 完全清理"
	@echo "  make help        - 顯示此說明資訊"
	@echo ""
	@echo "典型使用流程:"
	@echo "  make install && make enable && make start"