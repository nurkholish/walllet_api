class Team < ApplicationRecord
  include WalletOwner

  belongs_to :owner, class_name: "User", optional: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-_]+\z/ }

  before_validation { self.slug = slug.to_s.strip.downcase }
end