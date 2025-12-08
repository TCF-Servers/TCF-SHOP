# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  def index?
    user&.admin_or_above?
  end
end
