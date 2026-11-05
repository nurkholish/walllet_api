# ============================================================
# Wallet API — Makefile
# Auto-save token setelah login berhasil (.wallet_api_token)
# ============================================================

SHELL   := /bin/bash
BASE    ?= http://localhost:3000
DB_CTN  ?= wallet_db
APP_CTN ?= wallet_app
DB_USER ?= postgres
DB_NAME ?= wallet_api_development

TOKEN_FILE := .wallet_api_token
USER_FILE  := .wallet_api_user_id
EMAIL      ?= admin@example.com
PASSWORD   ?= password123

.DEFAULT_GOAL := help
.PHONY: help setup env chmod build up down reset restart logs ps \
        seed migrate db-shell rails-console \
        login logout _ensure_token _clear_token \
        verify verify-env verify-auth verify-wallets verify-credit-debit \
        verify-acid verify-balance verify-sti verify-lsp verify-polymorphism \
        verify-relationships verify-concurrency \
        prove test clean

help:
	@echo "Wallet API — available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

setup: env chmod build
env:
	@if [ ! -f .env ]; then cp .env.example .env; echo "✅ .env dibuat"; else echo "ℹ️  .env sudah ada"; fi
	@grep -q ".wallet_api_token" .gitignore 2>/dev/null || echo ".wallet_api_*" >> .gitignore
chmod:
	@chmod +x bin/rails bin/docker-entrypoint scripts/verify.sh 2>/dev/null || true
build:
	docker compose build --no-cache app

up:
	docker compose up -d
	@echo "⏳ Menunggu app listening..."
	@for i in $$(seq 1 60); do \
	  if curl -sf $(BASE)/health >/dev/null 2>&1; then echo "✅ App ready"; exit 0; fi; \
	  sleep 1; \
	done; \
	echo "❌ App tidak ready"; exit 1
down:
	docker compose down
reset:
	docker compose down -v
	docker compose build --no-cache app
	docker compose up -d
	@for i in $$(seq 1 90); do \
	  if curl -sf $(BASE)/health >/dev/null 2>&1; then break; fi; \
	  sleep 1; \
	done
	@rm -f $(TOKEN_FILE) $(USER_FILE)
	@$(MAKE) --no-print-directory login
restart:
	docker compose restart app
	@sleep 3
logs:
	docker compose logs -f app
ps:
	docker compose ps

seed:
	docker compose exec app bundle exec rails db:seed
migrate:
	docker compose exec app bundle exec rails db:migrate
db-shell:
	docker compose exec db psql -U $(DB_USER) -d $(DB_NAME)
rails-console:
	docker compose exec app bundle exec rails c

login:
	@echo "🔐 Login sebagai $(EMAIL)..."
	@RESP=$$(curl -s -X POST $(BASE)/sign_in \
	  -H 'Content-Type: application/json' \
	  -d '{"email":"$(EMAIL)","password":"$(PASSWORD)"}'); \
	TOKEN=$$(echo "$$RESP" | jq -r '.token // empty' 2>/dev/null); \
	UID_=$$(echo "$$RESP" | jq -r '.user.id // empty' 2>/dev/null); \
	EXP=$$(echo "$$RESP" | jq -r '.expires_at // empty' 2>/dev/null); \
	if [ -z "$$TOKEN" ]; then \
	  echo "❌ Login gagal"; echo "$$RESP"; exit 1; \
	fi; \
	echo "$$TOKEN" > $(TOKEN_FILE); \
	echo "$$UID_" > $(USER_FILE); \
	echo "✅ Login berhasil"; \
	echo "   user_id: $$UID_"; \
	echo "   token:   $${TOKEN:0:16}..."; \
	echo "   expires: $$EXP"
logout:
	@if [ -f $(TOKEN_FILE) ]; then \
	  TOKEN=$$(cat $(TOKEN_FILE)); \
	  curl -s -o /dev/null -X DELETE $(BASE)/sign_out -H "Authorization: Bearer $$TOKEN"; \
	  echo "✅ Session direvoke"; \
	fi
	@rm -f $(TOKEN_FILE) $(USER_FILE)
	@echo "✅ Token lokal dihapus"
_ensure_token:
	@if [ ! -f $(TOKEN_FILE) ] || [ -z "$$(cat $(TOKEN_FILE) 2>/dev/null)" ]; then \
	  $(MAKE) --no-print-directory login; \
	fi
	@if [ ! -f $(USER_FILE) ] || [ -z "$$(cat $(USER_FILE) 2>/dev/null)" ]; then \
	  $(MAKE) --no-print-directory login; \
	fi
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	CODE=$$(curl -s -o /dev/null -w "%{http_code}" $(BASE)/wallets/User/$$USER_ID -H "Authorization: Bearer $$TOKEN"); \
	if [ "$$CODE" = "401" ]; then \
	  echo "⚠️  Token expired, login ulang"; \
	  $(MAKE) --no-print-directory login; \
	fi
_clear_token:
	@rm -f $(TOKEN_FILE) $(USER_FILE)

verify:
	@$(MAKE) --no-print-directory _ensure_token
	@bash scripts/verify.sh
verify-env:
	@echo "=== Environment ==="
	@docker compose exec app printenv RAILS_ENV
	@echo "=== Health ==="
	@curl -s $(BASE)/health | jq . || echo "FAIL"
verify-auth: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	echo "=== T4.1 Sign-in ==="; \
	curl -s -X POST $(BASE)/sign_in -H 'Content-Type: application/json' \
	  -d '{"email":"$(EMAIL)","password":"$(PASSWORD)"}' | jq .; \
	echo "=== T4.2 Password salah -> 401 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $(BASE)/sign_in \
	  -H 'Content-Type: application/json' -d '{"email":"$(EMAIL)","password":"wrong"}'; \
	echo "=== T4.3 Tanpa token -> 401 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" $(BASE)/wallets/User/$$USER_ID; \
	echo "=== T4.4 Dengan token -> 200 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" $(BASE)/wallets/User/$$USER_ID -H "Authorization: Bearer $$TOKEN"; \
	echo "=== T4.5 Session digest ==="; \
	docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -c \
	  "SELECT id, user_id, length(token_digest) AS digest_len FROM sessions ORDER BY id DESC LIMIT 3;"
verify-wallets: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	TEAM_ID=$$(docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT id FROM teams LIMIT 1" | tr -d '[:space:]'); \
	STOCK_ID=$$(docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT id FROM stocks LIMIT 1" | tr -d '[:space:]'); \
	echo "=== R1.1 User wallet (User/$$USER_ID) ==="; \
	curl -s "$(BASE)/wallets/User/$$USER_ID" -H "Authorization: Bearer $$TOKEN" | jq .; \
	echo "=== R1.2 Team wallet (Team/$$TEAM_ID) ==="; \
	curl -s "$(BASE)/wallets/Team/$$TEAM_ID" -H "Authorization: Bearer $$TOKEN" | jq .; \
	echo "=== R1.3 Stock wallet (Stock/$$STOCK_ID) ==="; \
	curl -s "$(BASE)/wallets/Stock/$$STOCK_ID" -H "Authorization: Bearer $$TOKEN" | jq .
verify-credit-debit: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	echo "=== R2.1 Credit \$10.00 ==="; \
	TX=$$(curl -s -X POST $(BASE)/wallets/User/$$USER_ID/credit \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' \
	  -d '{"amount":"10.00","reference":"make-credit"}'); \
	echo "$$TX" | jq .; \
	TX_ID=$$(echo "$$TX" | jq -r .id); \
	echo "=== R2.2 Record di DB ==="; \
	docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -c \
	  "SELECT id, type, amount_cents, source_wallet_id, target_wallet_id, reference FROM wallet_transactions WHERE id=$$TX_ID;"; \
	echo "=== R2.3 Debit \$3.50 ==="; \
	DTX=$$(curl -s -X POST $(BASE)/wallets/User/$$USER_ID/debit \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' \
	  -d '{"amount":"3.50","reference":"make-debit"}'); \
	echo "$$DTX" | jq .; \
	echo "=== R3.1 Credit normalize: source dipaksa nil ==="; \
	docker exec $(APP_CTN) bundle exec rails runner " \
	  w = Wallet.first; \
	  tx = Credit.new(amount_cents: 100, currency: w.currency, source_wallet_id: w.id, target_wallet_id: w.id); \
	  tx.valid?; \
	  puts tx.source_wallet_id.nil? ? 'OK source dipaksa nil' : 'FAIL source tidak dinormalisasi'"; \
	echo "=== R3.2 Debit normalize: target dipaksa nil ==="; \
	docker exec $(APP_CTN) bundle exec rails runner " \
	  w = Wallet.first; \
	  tx = Debit.new(amount_cents: 100, currency: w.currency, source_wallet_id: w.id, target_wallet_id: w.id); \
	  tx.valid?; \
	  puts tx.target_wallet_id.nil? ? 'OK target dipaksa nil' : 'FAIL target tidak dinormalisasi'"; \
	echo "=== R3.3 Amount negatif -> 422 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $(BASE)/wallets/User/$$USER_ID/credit \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' -d '{"amount":"-5.00"}'; \
	echo "=== R3.4 Amount nol -> 422 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $(BASE)/wallets/User/$$USER_ID/credit \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' -d '{"amount":"0"}'; \
	echo "=== R3.5 Amount hilang -> 400 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $(BASE)/wallets/User/$$USER_ID/credit \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' -d '{}'
verify-acid: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	TEAM_ID=$$(docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT id FROM teams LIMIT 1" | tr -d '[:space:]'); \
	UB=$$(curl -s "$(BASE)/wallets/User/$$USER_ID" -H "Authorization: Bearer $$TOKEN" | jq -r .balance_cents); \
	TB=$$(curl -s "$(BASE)/wallets/Team/$$TEAM_ID" -H "Authorization: Bearer $$TOKEN" | jq -r .balance_cents); \
	echo "=== R4.1 Saldo sebelum: User=$$UB Team=$$TB Total=$$((UB + TB)) ==="; \
	REF="make-transfer-$$(date +%s)"; \
	echo "=== R4.2 Transfer \$1.00 (ref=$$REF) ==="; \
	curl -s -X POST $(BASE)/transfers -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' \
	  -d "{\"from\":{\"type\":\"User\",\"id\":$$USER_ID},\"to\":{\"type\":\"Team\",\"id\":$$TEAM_ID},\"amount\":\"1.00\",\"reference\":\"$$REF\"}" | jq .; \
	echo "=== R4.3 2 record dengan reference sama ==="; \
	docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -c \
	  "SELECT type, source_wallet_id, target_wallet_id, amount_cents FROM wallet_transactions WHERE reference='$$REF' ORDER BY id;"; \
	UA=$$(curl -s "$(BASE)/wallets/User/$$USER_ID" -H "Authorization: Bearer $$TOKEN" | jq -r .balance_cents); \
	TA=$$(curl -s "$(BASE)/wallets/Team/$$TEAM_ID" -H "Authorization: Bearer $$TOKEN" | jq -r .balance_cents); \
	echo "=== R4.4 Setelah: User=$$UA Team=$$TA Total=$$((UA + TA)) ==="; \
	echo "   Delta User = $$((UA - UB)) (harus -100)"; \
	echo "   Delta Team = $$((TA - TB)) (harus +100)"; \
	if [ $$((UB + TB)) -eq $$((UA + TA)) ]; then echo "✔ Konservasi OK"; else echo "✘ Saldo berubah"; fi; \
	echo "=== R4.5 Transfer melebihi saldo ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $(BASE)/transfers \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' \
	  -d "{\"from\":{\"type\":\"User\",\"id\":$$USER_ID},\"to\":{\"type\":\"Team\",\"id\":$$TEAM_ID},\"amount\":\"999999.00\",\"reference\":\"make-big-fail-$$(date +%s)\"}"; \
	echo "=== R4.6 Self-transfer ditolak ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST $(BASE)/transfers \
	  -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' \
	  -d "{\"from\":{\"type\":\"User\",\"id\":$$USER_ID},\"to\":{\"type\":\"User\",\"id\":$$USER_ID},\"amount\":\"1.00\"}"
verify-balance: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	TEAM_ID=$$(docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT id FROM teams LIMIT 1" | tr -d '[:space:]'); \
	STOCK_ID=$$(docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT id FROM stocks LIMIT 1" | tr -d '[:space:]'); \
	echo "=== R5.1 Balance API == SQL SUM ==="; \
	for PAIR in "User:$$USER_ID" "Team:$$TEAM_ID" "Stock:$$STOCK_ID"; do \
	  OT=$${PAIR%%:*}; OID=$${PAIR##*:}; \
	  API=$$(curl -s "$(BASE)/wallets/$$OT/$$OID" -H "Authorization: Bearer $$TOKEN" | jq -r .balance_cents); \
	  SQL=$$(docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT COALESCE(SUM(CASE WHEN t.type='Credit' THEN t.amount_cents ELSE -t.amount_cents END),0) FROM wallet_transactions t JOIN wallets w ON w.id=t.wallet_id WHERE w.wallet_owner_type='$$OT' AND w.wallet_owner_id=$$OID" | tr -d '[:space:]'); \
	  if [ "$$API" = "$$SQL" ]; then echo "✔ $$OT#$$OID API=$$API SQL=$$SQL"; else echo "✘ $$OT#$$OID API=$$API SQL=$$SQL"; fi; \
	done
verify-sti:
	@echo "=== T3.1 Kolom type ==="
	@docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -c \
	  "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='wallet_transactions' AND column_name='type';"
	@echo "=== T3.2 Nilai distinct ==="
	@docker exec $(DB_CTN) psql -U $(DB_USER) -d $(DB_NAME) -tAc "SELECT string_agg(DISTINCT type, ',') FROM wallet_transactions;"
	@echo "=== T3.3 Hierarchy ==="
	@docker exec $(APP_CTN) bundle exec rails runner " \
	  puts 'Credit superclass: ' + Credit.superclass.name; \
	  puts 'Debit superclass:  ' + Debit.superclass.name; \
	  puts Credit.superclass == WalletTransaction ? 'OK Credit < WalletTransaction' : 'FAIL'; \
	  puts Debit.superclass == WalletTransaction ? 'OK Debit < WalletTransaction' : 'FAIL'"
verify-polymorphism:
	@echo "=== T1.1 Vehicle bisa punya wallet ==="
	@docker exec $(APP_CTN) bundle exec rails runner " \
	  class Vehicle < ApplicationRecord; \
	    self.table_name = 'users'; include WalletOwner; \
	    def self.name; 'Vehicle'; end; \
	  end; \
	  u = User.first; v = Vehicle.find(u.id); w = v.wallet!; \
	  puts 'Vehicle wallet: id=' + w.id.to_s + ' owner_type=' + w.wallet_owner_type; \
	  puts w.wallet_owner_type == 'Vehicle' ? 'OK Polymorphism' : 'FAIL'"
verify-relationships:
	@echo "=== T2.1 Relasi ==="
	@docker exec $(APP_CTN) bundle exec rails runner " \
	  puts 'User has_one wallet: ' + (User.reflect_on_association(:wallet) ? 'OK' : 'FAIL'); \
	  puts 'Team has_one wallet: ' + (Team.reflect_on_association(:wallet) ? 'OK' : 'FAIL'); \
	  puts 'Stock has_one wallet: ' + (Stock.reflect_on_association(:wallet) ? 'OK' : 'FAIL'); \
	  puts 'Wallet belongs_to owner: ' + (Wallet.reflect_on_association(:wallet_owner) ? 'OK' : 'FAIL'); \
	  puts 'Wallet has_many ledger: ' + (Wallet.reflect_on_association(:ledger_entries) ? 'OK' : 'FAIL')"
	@echo "=== T2.2 Validasi ==="
	@docker exec $(APP_CTN) bundle exec rails runner " \
	  w = Wallet.first; \
	  puts 'amount=0 ditolak: ' + (Credit.new(amount_cents: 0, currency: w.currency, target_wallet: w).valid? ? 'FAIL' : 'OK'); \
	  puts 'amount=-100 ditolak: ' + (Credit.new(amount_cents: -100, currency: w.currency, target_wallet: w).valid? ? 'FAIL' : 'OK')"
verify-lsp: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	echo "=== T5.1 Library API ==="; \
	docker exec $(APP_CTN) bundle exec rails runner " \
	  puts 'VERSION: ' + LatestStockPrice::VERSION; \
	  puts 'price? ' + LatestStockPrice.respond_to?(:price).to_s; \
	  puts 'prices? ' + LatestStockPrice.respond_to?(:prices).to_s; \
	  puts 'price_all? ' + LatestStockPrice.respond_to?(:price_all).to_s"; \
	echo "=== T5.2 GET /stocks/price?stock=AAPL ==="; \
	curl -s "$(BASE)/stocks/price?stock=AAPL" -H "Authorization: Bearer $$TOKEN" | jq .; \
	echo "=== T5.3 GET /stocks/prices?stocks=AAPL,MSFT,TSLA ==="; \
	curl -s "$(BASE)/stocks/prices?stocks=AAPL,MSFT,TSLA" -H "Authorization: Bearer $$TOKEN" | jq .; \
	echo "=== T5.4 GET /stocks/price_all ==="; \
	curl -s "$(BASE)/stocks/price_all" -H "Authorization: Bearer $$TOKEN" | jq 'if type == "array" then .[0:3] else . end'; \
	echo "=== T5.5 Invalid -> 404 ==="; \
	curl -s -o /dev/null -w "HTTP %{http_code}\n" "$(BASE)/stocks/price?stock=ZZZZ" -H "Authorization: Bearer $$TOKEN"
verify-concurrency: _ensure_token
	@TOKEN=$$(cat $(TOKEN_FILE)); \
	USER_ID=$$(cat $(USER_FILE)); \
	echo "=== R4.7 20 debit paralel \$1 ==="; \
	for i in $$(seq 1 20); do \
	  curl -s -o /dev/null -w "%{http_code}\n" -X POST $(BASE)/wallets/User/$$USER_ID/debit \
	    -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' -d '{"amount":"1.00"}' & \
	done | sort | uniq -c; \
	wait 2>/dev/null || true

prove:
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║  WALLET API — RUNTIME PROOF                                  ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@$(MAKE) --no-print-directory _ensure_token
	@$(MAKE) --no-print-directory verify-env
	@$(MAKE) --no-print-directory verify-auth
	@$(MAKE) --no-print-directory verify-wallets
	@$(MAKE) --no-print-directory verify-credit-debit
	@$(MAKE) --no-print-directory verify-acid
	@$(MAKE) --no-print-directory verify-balance
	@$(MAKE) --no-print-directory verify-sti
	@$(MAKE) --no-print-directory verify-lsp
	@$(MAKE) --no-print-directory verify-polymorphism
	@$(MAKE) --no-print-directory verify-relationships
	@echo ""
	@echo "✅ Semua bukti requirement selesai"

test: prove
clean:
	docker compose down -v
	docker image rm wallet_api-app 2>/dev/null || true
	docker builder prune -f
	@rm -f $(TOKEN_FILE) $(USER_FILE)
	@echo "✅ Bersih"
