class BannedPlayer < ApplicationRecord
  # Le ban est identifié par son EOS ID : un joueur banni n'est pas forcément
  # présent dans la table players (on ne connaît parfois que son eos_id).
  # Le player associé est optionnel et rempli quand on le connaît.
  belongs_to :banned_by, class_name: "User", optional: true
  belongs_to :player, optional: true

  # EOS ID = 32 caractères hexadécimaux
  EOS_ID_FORMAT = /\A[0-9a-f]{32}\z/i

  before_validation :normalize_eos_id
  before_validation :link_player, on: :create

  validates :eos_id, presence: true,
                     uniqueness: true,
                     format: { with: EOS_ID_FORMAT, message: "n'est pas valide (32 caractères hexadécimaux attendus)" }
  validate :expires_at_in_future, on: :create

  scope :active,  -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
  scope :recent,  -> { order(created_at: :desc) }

  def permanent?
    expires_at.nil?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def display_name
    player&.in_game_name.presence || eos_id
  end

  private

  def normalize_eos_id
    self.eos_id = eos_id.to_s.strip.downcase.presence
  end

  def link_player
    self.player ||= Player.find_by(eos_id: eos_id) if eos_id.present?
  end

  def expires_at_in_future
    errors.add(:expires_at, "doit être dans le futur") if expires_at.present? && expires_at <= Time.current
  end
end
