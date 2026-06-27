#!/bin/bash

# ==================================================
# PTERODACTYL USER ID REORDER
# Mengurutkan ulang ID user menjadi 1,2,3,4,...
# Semua user tetap ada, ID diurutkan ulang
# ==================================================

PANEL="https://zzamofficial.webserverku.biz.id/api/application"
TOKEN="ptla_tDolBujfvDsTvY3s6kciCXSaige5HrYaipoj6szwXmc"

# ==================================================
# FUNGSI LOG
# ==================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ==================================================
# FUNGSI: AMBIL SEMUA USER (URUT BERDASARKAN ID LAMA)
# ==================================================
get_all_users() {
    curl -s -H "Authorization: Bearer $TOKEN" \
         -H "Accept: application/json" \
         "$PANEL/users?per_page=100" |
    jq -r '.data[].attributes | [.id, .email, .username] | @tsv' |
    sort -n  # Urutkan dari ID terkecil
}

# ==================================================
# FUNGSI: UPDATE USER ID
# ==================================================
update_user_id() {
    local old_id=$1
    local new_id=$2
    local email=$3
    local username=$4
    
    log "🔄 Mengubah ID $old_id → $new_id untuk $email ($username)"
    
    # Update user dengan ID baru
    curl -s -X PATCH \
         -H "Authorization: Bearer $TOKEN" \
         -H "Accept: application/json" \
         -H "Content-Type: application/json" \
         -d "{\"id\": $new_id, \"email\": \"$email\", \"username\": \"$username\"}" \
         "$PANEL/users/$old_id"
    
    sleep 0.35
}

# ==================================================
# EKSEKUSI UTAMA
# ==================================================
log "=========================================="
log "🔧 MEMULAI PROSES REORDER ID USER"
log "=========================================="

# Ambil semua user
log "📡 Mengambil daftar user saat ini..."
USERS=$(get_all_users)

if [[ -z "$USERS" ]]; then
    log "❌ Tidak ada user ditemukan atau gagal mengambil data."
    exit 1
fi

# Hitung total user
TOTAL=$(echo "$USERS" | wc -l)
log "📋 Total user: $TOTAL"

# Proses reorder
NEW_ID=1
DELETED_COUNT=0
REORDER_COUNT=0

log "🔄 Memulai reorder ID dari 1 hingga $TOTAL..."

echo "$USERS" | while IFS=$'\t' read -r OLD_ID EMAIL USERNAME; do
    # Lewati jika data kosong
    [[ -z "$OLD_ID" || -z "$EMAIL" ]] && continue
    
    # Jika ID sudah sesuai, skip
    if [[ "$OLD_ID" -eq "$NEW_ID" ]]; then
        log "✅ ID $OLD_ID sudah benar (${EMAIL})"
    else
        # Cek apakah ID baru sudah digunakan
        EXISTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
                      -H "Accept: application/json" \
                      "$PANEL/users/$NEW_ID" | jq -r '.data.id // 0')
        
        if [[ "$EXISTS" -eq 0 ]] || [[ "$EXISTS" == "null" ]]; then
            # ID baru kosong, langsung update
            update_user_id "$OLD_ID" "$NEW_ID" "$EMAIL" "$USERNAME"
            REORDER_COUNT=$((REORDER_COUNT + 1))
        else
            # ID baru sudah dipakai, kita lakukan swap
            log "⚠️  ID $NEW_ID sudah dipakai, melakukan swap..."
            
            # Pindahkan user di ID baru ke ID sementara (99999)
            TEMP_EMAIL=$(curl -s -H "Authorization: Bearer $TOKEN" \
                              -H "Accept: application/json" \
                              "$PANEL/users/$NEW_ID" | jq -r '.data.attributes.email')
            TEMP_USER=$(curl -s -H "Authorization: Bearer $TOKEN" \
                            -H "Accept: application/json" \
                            "$PANEL/users/$NEW_ID" | jq -r '.data.attributes.username')
            
            # Pindahkan user dari ID baru ke temporary
            update_user_id "$NEW_ID" 99999 "$TEMP_EMAIL" "$TEMP_USER"
            
            # Update user saat ini ke ID baru
            update_user_id "$OLD_ID" "$NEW_ID" "$EMAIL" "$USERNAME"
            
            # Kembalikan user temporary ke ID lama
            update_user_id 99999 "$OLD_ID" "$TEMP_EMAIL" "$TEMP_USER"
            
            REORDER_COUNT=$((REORDER_COUNT + 1))
        fi
    fi
    
    NEW_ID=$((NEW_ID + 1))
done

log "=========================================="
log "✅ PROSES REORDER SELESAI"
log "📊 Total user diproses: $TOTAL"
log "🔄 ID yang diubah: $REORDER_COUNT"
log "🗑️  User yang dihapus: $DELETED_COUNT"
log "=========================================="
