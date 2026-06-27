#!/bin/bash

# ==================================================
# PTERODACTYL AUTO GUARDIAN
# Memantau & menghapus server offline / CPU overlimit
# ==================================================

# --- KONFIGURASI ---
API_KEY="ptla_tDolBujfvDsTvY3s6kciCXSaige5HrYaipoj6szwXmc"
PANEL_URL="https://zzamofficial.webserverku.biz.id"
CPU_THRESHOLD=80
LOG_FILE="/var/log/pterodactyl_guard.log"

# --- FUNGSI: LOG ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# --- FUNGSI: Ambil semua server ---
get_servers() {
    curl -s -X GET "$PANEL_URL/api/application/servers" \
         -H "Authorization: Bearer $API_KEY" \
         -H "Accept: application/json" | jq -r '.data[] | {
             id: .attributes.id,
             name: .attributes.name,
             uuid: .attributes.uuid,
             status: .attributes.status // "unknown"
         } | @base64'
}

# --- FUNGSI: Ambil status & CPU dari server ---
get_server_status() {
    local uuid=$1
    curl -s -X GET "$PANEL_URL/api/client/servers/$uuid/resources" \
         -H "Authorization: Bearer $API_KEY" \
         -H "Accept: application/json" 2>/dev/null
}

# --- FUNGSI: Hapus server ---
delete_server() {
    local id=$1
    local name=$2
    local reason=$3
    
    log "🗑️  MENGHAPUS: $name (ID: $id) - Alasan: $reason"
    
    response=$(curl -s -X DELETE "$PANEL_URL/api/application/servers/$id" \
                -H "Authorization: Bearer $API_KEY" \
                -H "Accept: application/json")
    
    if [ $? -eq 0 ]; then
        log "✅ Berhasil menghapus server: $name"
    else
        log "❌ Gagal menghapus server: $name - $response"
    fi
}

# ==================================================
# --- EKSEKUSI UTAMA ---
# ==================================================

log "=========================================="
log "🔍 Memulai pemantauan Pterodactyl"
log "📊 Batas CPU: ${CPU_THRESHOLD}%"
log "=========================================="

# Ambil daftar server
server_list=$(get_servers)

if [ -z "$server_list" ] || [ "$server_list" = "null" ]; then
    log "❌ Gagal mengambil daftar server. Periksa API Key atau koneksi."
    exit 1
fi

# Loop setiap server
echo "$server_list" | while read server_encoded; do
    # Decode data server
    server_json=$(echo "$server_encoded" | base64 -d 2>/dev/null)
    
    if [ -z "$server_json" ] || [ "$server_json" = "null" ]; then
        continue
    fi
    
    server_id=$(echo "$server_json" | jq -r '.id')
    server_name=$(echo "$server_json" | jq -r '.name')
    server_uuid=$(echo "$server_json" | jq -r '.uuid')
    server_status=$(echo "$server_json" | jq -r '.status')
    
    log "📡 Memeriksa: $server_name (Status: $server_status)"
    
    # ==========================================
    # CEK 1: Server OFFLINE
    # ==========================================
    if [ "$server_status" = "offline" ]; then
        log "⚠️  Server OFFLINE terdeteksi: $server_name"
        delete_server "$server_id" "$server_name" "Server offline"
        continue
    fi
    
    # ==========================================
    # CEK 2: Server ONLINE, cek CPU usage
    # ==========================================
    if [ "$server_status" = "running" ] || [ "$server_status" = "starting" ]; then
        # Ambil resource
        resources=$(get_server_status "$server_uuid")
        
        if [ -n "$resources" ] && [ "$resources" != "null" ]; then
            cpu_usage=$(echo "$resources" | jq -r '.attributes.resources.cpu_absolute // 0')
            memory_usage=$(echo "$resources" | jq -r '.attributes.resources.memory_bytes // 0')
            
            log "📊 $server_name - CPU: ${cpu_usage}% | Memory: $((memory_usage/1024/1024))MB"
            
            # Jika CPU melebihi threshold
            if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
                log "🔥 CPU overlimit! $server_name menggunakan ${cpu_usage}%"
                delete_server "$server_id" "$server_name" "CPU melebihi ${CPU_THRESHOLD}% (${cpu_usage}%)"
            fi
        else
            log "⚠️  Gagal mengambil resource untuk $server_name"
        fi
    fi
    
    # Delay kecil agar tidak banjir request
    sleep 1
done

log "✅ Pemantauan selesai"
log "=========================================="
