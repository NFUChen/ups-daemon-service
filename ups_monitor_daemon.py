#!/usr/bin/env python3
"""
CyberPower UPS Monitor Daemon
持續監控UPS的lastPowerEvent變動並記錄日誌
"""

import json
import re
import subprocess
import os
import time
from datetime import datetime

EVENT_LOG_FILE = "/var/log/ups_monitor_event.json"
LOG_OUTPUT_FILE = "/var/log/ups_monitor.log"
CHECK_INTERVAL_SECONDS = 60

def to_camel_case(s):
    """將字串轉換為駝峰命名"""
    parts = re.split(r'\s+', s.strip())
    return parts[0].lower() + ''.join(word.capitalize() for word in parts[1:])

def parse_pwrstat_output(output):
    """解析pwrstat命令的輸出"""
    data = {}
    if "The UPS information shows as following:" in output:
        output = output.split("The UPS information shows as following:", 1)[1]
    
    sections = re.split(r'\n\s*\n', output.strip())
    for section in sections:
        lines = section.strip().splitlines()
        if not lines:
            continue
            
        header = lines[0]
        section_key = to_camel_case(header.strip(':'))
        section_data = {}
        
        for line in lines[1:]:
            if '...' not in line:
                continue
            parts = re.split(r'\.+', line.strip(), maxsplit=1)
            if len(parts) >= 2:
                key, value = parts[0], parts[1]
                camel_key = to_camel_case(key)
                section_data[camel_key] = value.strip()
        
        if section_data:
            data[section_key] = section_data
    
    return data

def get_pwrstat_status():
    """獲取UPS狀態"""
    try:
        result = subprocess.run(['pwrstat', '-status'], capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Failed to run pwrstat: {result.stderr}")
        return result.stdout
    except FileNotFoundError:
        raise RuntimeError("pwrstat command not found. Please install CyberPower PowerPanel")

def load_last_event():
    """從檔案載入上次記錄的事件"""
    if not os.path.exists(EVENT_LOG_FILE):
        return None
    try:
        with open(EVENT_LOG_FILE, 'r') as f:
            return json.load(f).get("lastPowerEvent")
    except (json.JSONDecodeError, IOError):
        return None

def save_last_event(event_str):
    """儲存最新事件到檔案"""
    try:
        os.makedirs(os.path.dirname(EVENT_LOG_FILE), exist_ok=True)
        with open(EVENT_LOG_FILE, 'w') as f:
            json.dump({"lastPowerEvent": event_str}, f)
    except IOError as e:
        log_message(f"Failed to save event to {EVENT_LOG_FILE}: {e}")

def log_message(message):
    """記錄日誌訊息"""
    timestamp = datetime.now().isoformat()
    try:
        os.makedirs(os.path.dirname(LOG_OUTPUT_FILE), exist_ok=True)
        with open(LOG_OUTPUT_FILE, 'a') as f:
            f.write(f"[{timestamp}] {message}\n")
    except IOError:
        # 如果無法寫入檔案，至少輸出到stderr
        print(f"[{timestamp}] {message}")

def log_event_change(new_event):
    """記錄事件變更日誌"""
    log_message(f"Detected new lastPowerEvent: {new_event}")

def main_loop():
    """主監控迴圈"""
    log_message("UPS Monitor Daemon started")
    
    while True:
        try:
            raw_output = get_pwrstat_status()
            parsed_data = parse_pwrstat_output(raw_output)
            current_event = parsed_data.get("currentUpsStatus", {}).get("lastPowerEvent")

            if current_event:
                previous_event = load_last_event()
                if previous_event != current_event:
                    log_event_change(current_event)
                    save_last_event(current_event)
                    
        except Exception as e:
            log_message(f"Error: {e}")

        time.sleep(CHECK_INTERVAL_SECONDS)

if __name__ == "__main__":
    try:
        main_loop()
    except KeyboardInterrupt:
        log_message("UPS Monitor Daemon stopped by user")
    except Exception as e:
        log_message(f"UPS Monitor Daemon crashed: {e}")
        exit(1)