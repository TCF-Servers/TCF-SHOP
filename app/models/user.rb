class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attribute :role, :integer, default: 0
  enum role: { user: 0, admin: 1, superadmin: 2 }

  belongs_to :player, optional: true
  has_many :rcon_executions, dependent: :nullify

  validates :player_id, uniqueness: true, allow_nil: true

  attr_accessor :in_game_name

  before_validation :link_player_from_in_game_name, on: :create

  def admin_or_above?
    admin? || superadmin?
  end

  private

  def link_player_from_in_game_name
    return if in_game_name.blank? || player.present?

    candidate = Player.find_by_flexible_name(in_game_name.strip)
    self.player = candidate if candidate && candidate.user.nil?
  end
end
