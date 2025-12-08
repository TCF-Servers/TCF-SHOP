class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { user: 0, admin: 1, superadmin: 2 }

  has_many :rcon_executions, dependent: :nullify

  def admin_or_above?
    admin? || superadmin?
  end
end
