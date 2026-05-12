# frozen_string_literal: true

class BannedPlayerPolicy < ApplicationPolicy
  def index?
    user&.admin_or_above?
  end

  def create?
    user&.admin_or_above?
  end

  def destroy?
    user&.admin_or_above?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin_or_above? ? scope.all : scope.none
    end
  end
end
