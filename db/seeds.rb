email    = ENV.fetch("SEED_USER_EMAIL", "admin@example.com")
password = ENV.fetch("SEED_USER_PASSWORD", "password123")

user = User.find_or_initialize_by(email: email)
user.name                  = "Admin User"
user.password              = password
user.password_confirmation = password
user.save!

user.wallet!

team = Team.find_or_create_by!(slug: "engineering") { |t| t.name = "Engineering"; t.owner = user }
team.wallet!

stock = Stock.find_or_create_by!(symbol: "AAPL") { |s| s.name = "Apple Inc."; s.last_price_cents = 17_500 }
stock.wallet!

puts "Seeded user=#{user.email} password=#{password}"