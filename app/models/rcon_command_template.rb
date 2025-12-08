class RconCommandTemplate < ApplicationRecord
  enum required_role: { admin: 1, superadmin: 2 }

  has_many :rcon_executions, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :command_template, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :for_role, ->(role) { where(required_role: ..User.roles[role]) }

  def extract_placeholders
    command_template.scan(/\{(\w+)\}/).flatten
  end

  def build_command(params = {})
    result = command_template.dup
    extract_placeholders.each do |placeholder|
      result.gsub!("{#{placeholder}}", params[placeholder.to_sym].to_s)
    end
    result
  end
end
