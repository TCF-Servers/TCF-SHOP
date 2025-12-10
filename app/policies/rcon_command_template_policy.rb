# frozen_string_literal: true

class RconCommandTemplatePolicy < ApplicationPolicy
  def index?
    user.superadmin?
  end

  def show?
    user.superadmin?
  end

  def create?
    user.superadmin?
  end

  def update?
    user.superadmin?
  end

  def destroy?
    user.superadmin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.superadmin?
        scope.all
      else
        scope.none
      end
    end
  end
end
