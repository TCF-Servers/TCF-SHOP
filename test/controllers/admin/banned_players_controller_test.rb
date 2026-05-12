require "test_helper"
require "minitest/mock"

class Admin::BannedPlayersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EOS_ID = "00ff11aa22bb33cc44dd55ee66770088".freeze

  setup do
    @admin = User.create!(email: "admin@example.com", password: "password123", role: :admin)
    sign_in @admin
  end

  test "create bans an eos_id and broadcasts BanPlayer over RCON to all maps" do
    captured = {}
    all_ok = lambda do |command, **kwargs|
      captured[:command] = command
      captured.merge!(kwargs)
      { "TheIsland_WP" => RconDispatcher::Result.new(success: true), "Ragnarok_WP" => RconDispatcher::Result.new(success: true) }
    end

    RconDispatcher.stub :execute_and_log_all, all_ok do
      assert_difference -> { BannedPlayer.count }, 1 do
        post admin_banned_players_path, params: { banned_player: { eos_id: EOS_ID, reason: "tricheur" } }
      end
    end

    assert_redirected_to admin_banned_players_path
    assert_equal "BanPlayer #{EOS_ID}", captured[:command]
    assert_equal @admin, BannedPlayer.last.banned_by
    assert_nil captured[:player] # pas de Player en base, ça ban quand même
  end

  test "create passes the linked player to the dispatcher when one exists" do
    player = Player.create!(eos_id: EOS_ID, in_game_name: "Cheater")
    captured = {}

    stub = lambda do |command, **kwargs|
      captured.merge!(kwargs)
      { "TheIsland_WP" => RconDispatcher::Result.new(success: true) }
    end

    RconDispatcher.stub :execute_and_log_all, stub do
      post admin_banned_players_path, params: { banned_player: { eos_id: EOS_ID } }
    end

    assert_equal player, captured[:player]
  end

  test "partial RCON failure still bans and warns" do
    mixed = lambda do |_command, **_kwargs|
      { "TheIsland_WP" => RconDispatcher::Result.new(success: true),
        "Ragnarok_WP" => RconDispatcher::Result.new(success: false, error: "Timeout") }
    end

    RconDispatcher.stub :execute_and_log_all, mixed do
      assert_difference -> { BannedPlayer.count }, 1 do
        post admin_banned_players_path, params: { banned_player: { eos_id: EOS_ID } }
      end
    end

    assert flash[:alert].present?
    assert_nil flash[:notice]
  end

  test "destroy lifts the ban and broadcasts UnbanPlayer over RCON to all maps" do
    banned = BannedPlayer.create!(eos_id: EOS_ID, banned_by: @admin)
    captured = {}
    all_ok = lambda do |command, **kwargs|
      captured[:command] = command
      captured.merge!(kwargs)
      { "TheIsland_WP" => RconDispatcher::Result.new(success: true), "Ragnarok_WP" => RconDispatcher::Result.new(success: true) }
    end

    RconDispatcher.stub :execute_and_log_all, all_ok do
      assert_difference -> { BannedPlayer.count }, -1 do
        delete admin_banned_player_path(banned)
      end
    end

    assert_redirected_to admin_banned_players_path
    assert_equal "UnbanPlayer #{EOS_ID}", captured[:command]
    assert_equal @admin, captured[:user]
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
