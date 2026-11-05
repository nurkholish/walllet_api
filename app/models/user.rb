class User < ApplicationRecord
  include WalletOwner

  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :owned_teams, class_name: "Team", foreign_key: :owner_id, dependent: :nullify

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  before_validation { self.email = email.to_s.strip.downcase }
end