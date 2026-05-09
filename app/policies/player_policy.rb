# frozen_string_literal: true

class PlayerPolicy < ApplicationPolicy
  def index?
    user&.admin_or_above?
  end

  def edit?
    user&.admin_or_above?
  end

  def update?
    user&.admin_or_above?
  end

  def destroy?
    user&.admin_or_above?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin_or_above?
        scope.all
      else
        scope.none
      end
    end
  end
end
