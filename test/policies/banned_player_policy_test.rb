require "test_helper"

class BannedPlayerPolicyTest < ActiveSupport::TestCase
  EOS_ID = "00ff11aa22bb33cc44dd55ee66770088".freeze

  ACTIONS = %i[index? create? destroy?].freeze

  def policy_for(user)
    BannedPlayerPolicy.new(user, BannedPlayer.new)
  end

  test "anonymous (no user) cannot do anything on the banlist" do
    ACTIONS.each do |action|
      refute policy_for(nil).public_send(action), "anonyme ne devrait pas pouvoir #{action}"
    end
  end

  test "a plain user cannot manage the banlist" do
    ACTIONS.each do |action|
      refute policy_for(User.new(role: :user)).public_send(action), "user ne devrait pas pouvoir #{action}"
    end
  end

  test "an admin can manage the banlist" do
    ACTIONS.each do |action|
      assert policy_for(User.new(role: :admin)).public_send(action), "admin devrait pouvoir #{action}"
    end
  end

  test "a superadmin can manage the banlist" do
    ACTIONS.each do |action|
      assert policy_for(User.new(role: :superadmin)).public_send(action), "superadmin devrait pouvoir #{action}"
    end
  end

  test "show / update / edit stay denied by default even for a superadmin" do
    # (new? délègue volontairement à create? côté ApplicationPolicy — c'est attendu)
    %i[show? update? edit?].each do |action|
      refute policy_for(User.new(role: :superadmin)).public_send(action), "#{action} ne devrait pas être ouvert"
    end
  end

  test "scope is empty for anonymous and plain users, full for admin and above" do
    BannedPlayer.create!(eos_id: EOS_ID)

    assert_equal 0, BannedPlayerPolicy::Scope.new(nil, BannedPlayer).resolve.count
    assert_equal 0, BannedPlayerPolicy::Scope.new(User.new(role: :user), BannedPlayer).resolve.count
    assert_equal 1, BannedPlayerPolicy::Scope.new(User.new(role: :admin), BannedPlayer).resolve.count
    assert_equal 1, BannedPlayerPolicy::Scope.new(User.new(role: :superadmin), BannedPlayer).resolve.count
  end
end
