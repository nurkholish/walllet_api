require "digest"

class Session < ApplicationRecord
  belongs_to :user

  TOKEN_TTL = 7.days

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.issue!(user:, ip: nil, user_agent: nil)
    plaintext = SecureRandom.urlsafe_base64(48)
    digest    = Digest::SHA256.hexdigest(plaintext)
    session   = create!(user: user, token_digest: digest,
                        expires_at: TOKEN_TTL.from_now, ip: ip, user_agent: user_agent)
    [session, plaintext]
  end

  def self.find_active_by_token(plaintext)
    return nil if plaintext.blank?
    digest = Digest::SHA256.hexdigest(plaintext)
    active.find_by(token_digest: digest)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end