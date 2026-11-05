Rails.application.routes.draw do
  post   "/sign_in",  to: "sessions#create"
  delete "/sign_out", to: "sessions#destroy"

  get  "/wallets/:owner_type/:owner_id",        to: "wallets#show"
  post "/wallets/:owner_type/:owner_id/credit", to: "wallets#credit"
  post "/wallets/:owner_type/:owner_id/debit",  to: "wallets#debit"

  get  "/wallets/:owner_type/:owner_id/transactions", to: "transactions#index"
  post "/transfers",                                  to: "transactions#create"

  get "/stocks/price",     to: "stocks#price"
  get "/stocks/prices",    to: "stocks#prices"
  get "/stocks/price_all", to: "stocks#price_all"

  get "/health", to: proc { [200, { "Content-Type" => "application/json" }, ['{"status":"ok"}']] }
end