class AuthenticationLog < ApplicationRecord
  belongs_to :user, optional: true

  enum :authentication_type, { 
    uae_pass: 0, 
    email: 1, 
    api_token: 2 
  }

  enum :status, { 
    success: 0, 
    failure: 1, 
    locked: 2 
  }

  validates :authentication_type, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where(status: [:failure, :locked]) }
  scope :successful, -> { where(status: :success) }
end
