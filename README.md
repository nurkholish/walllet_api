# Wallet API — Step-by-Step Verification

Panduan ini membuktikan **semua requirement terpenuhi** dengan perintah yang bisa
di-copy-paste. Setiap step punya perintah, output yang diharapkan, dan requirement
mana yang dibuktikan.

**Prasyarat:** stack running (`make up` sukses, `curl http://localhost:3000/health`
mengembalikan `{"status":"ok"}`).

---

## Daftar Isi

- [Quick Start](#quick-start)
- [Cara Auth Bekerja di Makefile](#cara-auth-bekerja-di-makefile)
- [Step 0 — Preflight](#step-0--preflight)
- [Step 1 — Requirement #1: Wallet per entity](#step-1--requirement-1-wallet-per-entity)
- [Step 2 — Requirement #2: Credit/Debit berbasis DB](#step-2--requirement-2-creditdebit-berbasis-db)
- [Step 3 — Requirement #3: Validasi source/target](#step-3--requirement-3-validasi-sourcetarget)
- [Step 4 — Requirement #4: ACID](#step-4--requirement-4-acid)
- [Step 5 — Requirement #5: Balance = SUM](#step-5--requirement-5-balance--sum)
- [Step 6 — Task #1: Generic wallet](#step-6--task-1-generic-wallet)
- [Step 7 — Task #2: Relationships & validations](#step-7--task-2-relationships--validations)
- [Step 8 — Task #3: STI](#step-8--task-3-sti)
- [Step 9 — Task #4: Sign-in tanpa gem](#step-9--task-4-sign-in-tanpa-gem)
- [Step 10 — Task #5: LatestStockPrice library](#step-10--task-5-lateststockprice-library)
- [Step 11 — Jalankan semua sekaligus](#step-11--jalankan-semua-sekaligus)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# 1. Setup (sekali)
make setup

# 2. Jalankan stack
make up

# 3. Login — token otomatis tersimpan di .wallet_api_token
make login

# 4. Jalankan bukti (token otomatis dipakai)
make verify-wallets
make verify-credit-debit
make verify-acid
make verify-balance
make verify-polymorphism
make verify-sti
make verify-auth
make verify-lsp

# 5. Semua sekaligus
make prove
```

---

## Cara Auth Bekerja di Makefile

Tidak perlu copy-paste token manual. Alurnya:

1. `make login` → POST `/sign_in` → simpan token ke file `.wallet_api_token`
2. Setiap target `verify-*` **otomatis** memanggil `_ensure_token` yang:
   - Cek file `.wallet_api_token`
   - Kalau kosong / tidak ada → jalankan `make login` otomatis
   - Inject token sebagai `Authorization: Bearer <token>`
3. `make logout` → hapus token file + revoke session di server

**File yang dibuat:**
- `.wallet_api_token` — berisi plaintext token (gitignore!)
- `.wallet_api_user_id` — berisi user ID

`.gitignore` sudah mencakup `.wallet_api_*`.

**Kalau token expired** (default 7 hari), `make login` otomatis refresh saat
menjalankan target berikutnya.

---

## Step 0 — Preflight

### 0.1 Cek stack

```bash
docker compose ps
```

**Diharapkan:**

```
NAME         STATUS
wallet_app   Up (healthy)
wallet_db    Up (healthy)
```

### 0.2 Cek health

```bash
curl -s http://localhost:3000/health
```

**Diharapkan:** `{"status":"ok"}`

### 0.3 Login

```bash
make login
```

**Diharapkan:**

```
✅ Login berhasil
   user_id: 1
   token:   xY7aBc... (disimpan di .wallet_api_token)
   expires: 2026-11-13T...
```

Setelah ini, semua target `verify-*` di bawah akan otomatis memakai token.

---

## Step 1 — Requirement #1: Wallet per entity

**Membuktikan:** User, Team, Stock masing-masing punya wallet sendiri.

```bash
make verify-wallets
```

**Diharapkan:**

```
=== R1.1 User wallet ===
{ "id": 1, "owner_type": "User",  "owner_id": 1, "balance_cents": 0, ... }
=== R1.2 Team wallet ===
{ "id": 2, "owner_type": "Team",  "owner_id": 1, "balance_cents": 0, ... }
=== R1.3 Stock wallet ===
{ "id": 3, "owner_type": "Stock", "owner_id": 1, "balance_cents": 0, ... }
```

**Bukti:** tiga wallet **berbeda** (`id` beda), `owner_type` sesuai kelas.

---

## Step 2 — Requirement #2: Credit/Debit berbasis DB

**Membuktikan:** credit/debit **menulis** ke `wallet_transactions`, saldo **tidak**
disimpan di kolom.

```bash
make verify-credit-debit
```

**Diharapkan:**

```
=== R2.1 Credit $100.00 ===
{ "id": 1, "type": "Credit", "amount_cents": 10000, "source_wallet_id": null, ... }

=== R2.2 Record Credit di DB ===
 id |  type  | amount_cents | source_wallet_id | target_wallet_id | reference
----+--------+--------------+------------------+------------------+-----------
  1 | Credit |        10000 |                  |                1 | make-credit

=== R2.3 Debit $25.50 ===
{ "id": 2, "type": "Debit", "amount_cents": 2550, "target_wallet_id": null, ... }

=== R2.4 Struktur tabel wallets (tidak ada kolom balance) ===
 column            | type
-------------------+------------------
 id                | bigint
 wallet_owner_type | character varying
 wallet_owner_id   | bigint
 currency          | character varying
 status            | character varying
 created_at        | timestamp
 updated_at        | timestamp
```

**Bukti:**
- Record Credit/Dehit ada di DB (Step 2.2).
- Tabel `wallets` **tidak** punya kolom `balance` (Step 2.4).
- Balance dihitung dari ledger.

---

## Step 3 — Requirement #3: Validasi source/target

**Membuktikan:** invariant "Credit → source NULL, Debit → target NULL" dijaga
di **model** dan **DB**.

```bash
make verify-credit-debit
```

(Step ini menggunakan data dari Step 2.)

**Diharapkan tambahan dari `verify-credit-debit`:**

```
=== R3.1 Model menolak Credit dengan source_wallet ===
REJECTED ✔
Errors: Source wallet must be blank for credit

=== R3.2 Model menolak Debit dengan target_wallet ===
REJECTED ✔
Errors: Target wallet must be blank for debit

=== R3.3 Amount negatif -> 422 ===
HTTP 422

=== R3.4 Amount nol -> 422 ===
HTTP 422

=== R3.5 Amount hilang -> 400 ===
HTTP 400
```

**Bukti:** invariant dijaga di dua lapis; input invalid ditolak dengan status HTTP tepat.

---

## Step 4 — Requirement #4: ACID

**Membuktikan:** atomik, konsisten, terisolasi, durable, dengan rollback yang benar.

```bash
make verify-acid
```

**Diharapkan:**

```
=== R4.1 Saldo sebelum transfer ===
User: 7450 cents
Team: 0 cents
Total: 7450 cents

=== R4.2 Transfer $10.00 ===
{ "debit":  { "type": "Debit",  "reference": "make-transfer-1234", ... },
  "credit": { "type": "Credit", "reference": "make-transfer-1234", ... } }

=== R4.3 Atomicity: 2 record dengan reference sama ===
  type  | source_wallet_id | target_wallet_id | amount_cents
--------+------------------+------------------+--------------
 Debit  |                1 |                  |         1000
 Credit |                  |                2 |         1000

=== R4.4 Konservasi saldo ===
User: 6450 cents
Team: 1000 cents
Total: 7450 cents
✔ Konservasi OK

=== R4.5 Rollback: transfer melebihi saldo ===
HTTP 422
{ "errors": ["wallet 1 insufficient funds"] }
Record tertinggal: 0

=== R4.6 Self-transfer ditolak ===
HTTP 422
```

**Bukti:**
- Atomicity: 2 record dengan reference sama (4.3).
- Consistency: konservasi saldo (4.4).
- Rollback: 0 record tertinggal (4.5).
- Guard: self-transfer ditolak (4.6).
- Isolation: `SELECT ... FOR UPDATE` di `WalletService`.

**Opsional — test concurrency (bukti row-lock):**

```bash
make verify-concurrency
```

**Diharapkan:**

```
=== R4.7 20 debit paralel $1 ===
     13 201
      7 422
=== Cek saldo negatif (harus 0 rows) ===
(0 rows)
```

---

## Step 5 — Requirement #5: Balance = SUM

**Membuktikan:** nilai `balance_cents` dari API **sama persis** dengan
`SUM(amount_cents)` di ledger.

```bash
make verify-balance
```

**Diharapkan:**

```
=== R5.1 Balance API == SQL SUM ===
✔ User#1   API=5450  SQL=5450
✔ Team#1   API=1000  SQL=1000
✔ Stock#1  API=0     SQL=0

=== R5.2 Ledger User#1 ===
[ { "id": ..., "type": "Credit", "amount_cents": 10000, ... },
  { "id": ..., "type": "Debit",  "amount_cents": 2550, ... },
  ... ]
```

**Bukti:** balance selalu konsisten dengan ledger — tidak ada cache yang bisa divergen.

---

## Step 6 — Task #1: Generic wallet

**Membuktikan:** kelas baru (mis. `Vehicle`) bisa langsung punya wallet **tanpa migrasi baru**.

```bash
make verify-polymorphism
```

**Diharapkan:**

```
=== T1.1 Buat kelas Vehicle dan beri wallet ===
Vehicle wallet created: id=X owner_type=Vehicle
✔ Polymorphism OK
```

**Bukti:** desain polymorphic benar-benar generik.

---

## Step 7 — Task #2: Relationships & validations

**Membuktikan:** relasi dan validasi aktif di model layer.

```bash
make verify-relationships
```

**Diharapkan:**

```
=== T2.1 Relasi antar model ===
User has_one wallet:      ✔
Team has_one wallet:      ✔
Stock has_one wallet:     ✔
Wallet belongs_to owner:  ✔
Wallet has_many ledger:   ✔
WalletTransaction↔wallet: ✔

=== T2.2 Validasi aktif ===
amount=0 ditolak:            ✔
amount=-100 ditolak:         ✔
currency mismatch ditolak:   ✔
duplicate wallet ditolak:    ✔
```

**Bukti:** relasi dan validasi tidak hanya di controller, tapi di model.

---

## Step 8 — Task #3: STI

**Membuktikan:** `WalletTransaction` memakai STI `Credit` / `Debit`.

```bash
make verify-sti
```

**Diharapkan:**

```
=== T3.1 Kolom 'type' di wallet_transactions ===
 column_name |     data_type
-------------+-------------------
 type        | character varying

=== T3.2 Nilai distinct type ===
Credit,Debit

=== T3.3 Hierarchy STI ===
Credit ancestors: Credit < WalletTransaction < ApplicationRecord
Debit ancestors:  Debit < WalletTransaction < ApplicationRecord
Credit.superclass == WalletTransaction: true
Debit.superclass  == WalletTransaction: true
```

**Bukti:** satu tabel, dua subclass, invariant berbeda per tipe.

---

## Step 9 — Task #4: Sign-in tanpa gem

**Membuktikan:** auth custom (Session + SHA256), tanpa Devise/JWT.

```bash
make verify-auth
```

**Diharapkan:**

```
=== T4.1 Login berhasil ===
{ "token": "...", "user": {...}, "expires_at": "..." }

=== T4.2 Password salah -> 401 ===
HTTP 401

=== T4.3 Tanpa token -> 401 ===
HTTP 401

=== T4.4 Dengan token -> 200 ===
HTTP 200

=== T4.5 Session digest 64 chars ===
 id | user_id | digest_len
----+---------+------------
  N |       1 |         64

=== T4.6 Sign-out revoke ===
Sebelum logout: HTTP 200
DELETE /sign_out: HTTP 204
Setelah logout: HTTP 401

=== T4.7 Gemfile tidak mengandung auth gem ===
gem "bcrypt", "~> 3.1"    (hanya untuk has_secure_password)
```

**Bukti:** auth lengkap tanpa gem eksternal.

---

## Step 10 — Task #5: LatestStockPrice library

**Membuktikan:** library gem-style di `lib/` dengan 3 endpoint + error handling.

```bash
make verify-lsp
```

**Diharapkan:**

```
=== T5.1 Library API lengkap ===
VERSION:              0.1.0
respond_to price:     true
respond_to prices:    true
respond_to price_all: true
configurable:         true

=== T5.2 GET /stocks/price?stock=AAPL ===
{ "symbol": "AAPL", "price": 189.43, "currency": "USD", ... }

=== T5.3 GET /stocks/prices?stocks=AAPL,MSFT,TSLA ===
[ { "symbol": "AAPL", ... }, { "symbol": "MSFT", ... }, { "symbol": "TSLA", ... } ]

=== T5.4 GET /stocks/price_all ===
[ {...}, {...}, {...} ]

=== T5.5 Symbol invalid -> 404 ===
HTTP 404
```

**Bukti:** library memenuhi permintaan `price`, `prices`, `price_all`, dengan
error handling yang tepat.

---

## Step 11 — Jalankan semua sekaligus

```bash
make prove
```

Ini menjalankan **semua target verify-*** secara berurutan dan mencetak
ringkasan di akhir:

```
╔══════════════════════════════════════════════════════════════╗
║  WALLET API — RUNTIME PROOF                                  ║
╚══════════════════════════════════════════════════════════════╝
✅ Semua bukti requirement selesai
```

**Untuk melaporkan hasil:** copy-paste seluruh output `make prove` ke dokumen
bukti. Setiap section menandai requirement yang dibuktikan.

---

## Troubleshooting

### `make login` gagal

```bash
docker compose logs app --tail 30
```

Cek user ter-seed:

```bash
docker compose exec app bundle exec rails db:seed
```

### Token expired saat menjalankan `verify-*`

Target `verify-*` akan otomatis memanggil `make login` bila token file kosong
atau expired. Untuk refresh manual:

```bash
make logout
make login
```

### `verify-*` 404 / 500

```bash
docker compose logs app --tail 50
```

Kemungkinan controller belum di-rebuild (image self-contained):

```bash
make reset
```

### `.wallet_api_token` ingin dihapus

```bash
make logout
# atau manual:
rm -f .wallet_api_token .wallet_api_user_id
```

### Reset total

```bash
make clean
make setup
make up
make login
make prove
```

---

## Ringkasan Makefile Targets

| Target | Fungsi |
|---|---|
| `make setup` | Persiapkan `.env`, chmod, build image |
| `make up` | Start stack, tunggu `/health` OK |
| `make login` | Login, simpan token ke `.wallet_api_token` |
| `make logout` | Revoke session + hapus token file |
| `make verify-wallets` | R1 |
| `make verify-credit-debit` | R2 + R3 |
| `make verify-acid` | R4 |
| `make verify-balance` | R5 |
| `make verify-polymorphism` | T1 |
| `make verify-relationships` | T2 |
| `make verify-sti` | T3 |
| `make verify-auth` | T4 |
| `make verify-lsp` | T5 |
| `make verify-concurrency` | R4 (opsional, concurrency) |
| `make prove` | Semua verify-* sekaligus |
| `make logs` | Tail log app |
| `make reset` | Hapus DB + rebuild + up + login |
| `make clean` | Hapus semua container + volume + image |