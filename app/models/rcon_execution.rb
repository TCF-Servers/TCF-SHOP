class RconExecution < ApplicationRecord
  belongs_to :user
  belongs_to :player, optional: true
  belongs_to :rcon_command_template, optional: true

  validates :map, presence: true
  validates :full_command, presence: true
  validates :success, inclusion: { in: [true, false] }

  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :recent, -> { order(created_at: :desc) }
end
