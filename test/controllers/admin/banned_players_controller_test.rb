require "test_helper"
require "minitest/mock"

class Admin::BannedPlayersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EOS_ID = "00ff11aa22bb33cc44dd55ee66770088".freeze

  setup do
    @admin = User.create!(email: "admin@example.com", password: "password123", role: :admin)
    sign_in @admin
  end

  test "create bans an eos_id and skips RCON when the player is offline / unknown" do
    assert_no_difference -> { RconExecution.count } do
      assert_difference -> { BannedPlayer.count }, 1 do
        post admin_banned_players_path, params: { banned_player: { eos_id: EOS_ID, reason: "tricheur" } }
      end
    end

    assert_redirected_to admin_banned_players_path
    assert_equal @admin, BannedPlayer.last.banned_by
  end

  test "create dispatches BanPlayer over RCON when the player is online" do
    player = Player.create!(eos_id: EOS_ID, in_game_name: "Cheater")
    player.create_game_session!(map_name: "Ragnarok_WP", online: true)

    captured = {}
    fake_execution = RconExecution.new(success: true)
    stub = lambda do |command, **kwargs|
      captured[:command] = command
      captured.merge!(kwargs)
      fake_execution
    end

    RconDispatcher.stub :execute_and_log, stub do
      assert_difference -> { BannedPlayer.count }, 1 do
        post admin_banned_players_path, params: { banned_player: { eos_id: EOS_ID } }
      end
    end

    assert_redirected_to admin_banned_players_path
    assert_equal "BanPlayer #{EOS_ID}", captured[:command]
    assert_equal "Ragnarok_WP", captured[:map_name]
    assert_equal player, captured[:player]
  end

  test "non-admin cannot ban" do
    sign_out @admin
    sign_in User.create!(email: "joe@example.com", password: "password123", role: :user)

    assert_no_difference -> { BannedPlayer.count } do
      post admin_banned_players_path, params: { banned_player: { eos_id: EOS_ID } }
    end
    assert_redirected_to root_path
  end
end
