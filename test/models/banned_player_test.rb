require "test_helper"

class BannedPlayerTest < ActiveSupport::TestCase
  VALID_EOS_ID = "00ff11aa22bb33cc44dd55ee66770088".freeze

  test "is valid with a 32-char hex eos_id" do
    assert BannedPlayer.new(eos_id: VALID_EOS_ID).valid?
  end

  test "normalizes eos_id (trim + downcase) before validation" do
    banned = BannedPlayer.create!(eos_id: "  00FF11AA22BB33CC44DD55EE66770088  ")
    assert_equal VALID_EOS_ID, banned.eos_id
  end

  test "rejects a malformed eos_id" do
    refute BannedPlayer.new(eos_id: "not-an-eos-id").valid?
    refute BannedPlayer.new(eos_id: "").valid?
  end

  test "eos_id must be unique" do
    BannedPlayer.create!(eos_id: VALID_EOS_ID)
    duplicate = BannedPlayer.new(eos_id: VALID_EOS_ID.upcase)
    refute duplicate.valid?
    assert_includes duplicate.errors[:eos_id], "has already been taken"
  end

  test "expires_at must be in the future when set" do
    refute BannedPlayer.new(eos_id: VALID_EOS_ID, expires_at: 1.hour.ago).valid?
    assert BannedPlayer.new(eos_id: VALID_EOS_ID, expires_at: 1.hour.from_now).valid?
    assert BannedPlayer.new(eos_id: VALID_EOS_ID, expires_at: nil).valid?
  end

  test "links an existing player by eos_id on create" do
    player = Player.create!(eos_id: VALID_EOS_ID, in_game_name: "Banni")
    banned = BannedPlayer.create!(eos_id: VALID_EOS_ID)
    assert_equal player, banned.player
  end

  test "does not require a matching player" do
    banned = BannedPlayer.create!(eos_id: VALID_EOS_ID)
    assert_nil banned.player
  end

  test "permanent? and expired? helpers" do
    permanent = BannedPlayer.new(eos_id: VALID_EOS_ID)
    assert permanent.permanent?
    refute permanent.expired?

    temporary = BannedPlayer.new(eos_id: VALID_EOS_ID, expires_at: 1.day.from_now)
    refute temporary.permanent?
    refute temporary.expired?

    elapsed = BannedPlayer.new(eos_id: VALID_EOS_ID)
    elapsed.expires_at = 1.day.ago
    assert elapsed.expired?
  end

  test "active scope excludes expired bans" do
    active_perm = BannedPlayer.create!(eos_id: VALID_EOS_ID)
    active_temp = BannedPlayer.create!(eos_id: "11ff11aa22bb33cc44dd55ee66770088", expires_at: 1.day.from_now)
    expired = BannedPlayer.create!(eos_id: "22ff11aa22bb33cc44dd55ee66770088")
    expired.update_column(:expires_at, 1.day.ago)

    assert_equal [active_perm, active_temp].sort_by(&:id), BannedPlayer.active.order(:id).to_a
    assert_equal [expired], BannedPlayer.expired.to_a
  end
end
