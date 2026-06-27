#!/bin/bash
PANEL="https://zzamofficial.webserverku.biz.id/api/application"
TOKEN="ptla_tDolBujfvDsTvY3s6kciCXSaige5HrYaipoj6szwXmc"

# ✅ ID YANG TETAP DIAMANKAN — TIDAK DIHAPUS
AMAN=(1 193)

# Ambil → URUTKAN BERDASARKAN ID KECIL → BESAR
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "$PANEL/users?per_page=100" |
jq -r '.data[].attributes | [.id, .email, .username] | @tsv' |
sort -n  # ✅ DIURUTKAN: 1 → 2 → 3 → 4 ... seterusnya
while read ID EMAIL USER; do
  # Cek apakah masuk daftar aman
  SKIP=0
  for A in "${AMAN[@]}"; do
    [[ "$ID" -eq "$A" ]] && { SKIP=1; break; }
  done

  if [[ $SKIP -eq 1 ]]; then
    echo "⏭️ AMAN: ID $ID | $EMAIL | $USER"
    continue
  fi

  echo "🗑️ HAPUS: ID $ID | $EMAIL | $USER"
  curl -s -X DELETE -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "$PANEL/users/$ID"
  sleep 0.35 # jeda aman biar gak kena batasan
done

echo "✅ SELESAI — dibersihkan berurutan dari kecil ke besar"
