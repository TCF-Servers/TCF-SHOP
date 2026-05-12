require "test_helper"
require "minitest/mock"
require "rcon" # le service le require déjà, mais on s'en assure pour les stubs ci-dessous

class RconDispatcherTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :commands

    def initialize(*)
      @commands = []
    end

    def authenticate!(*)
      true
    end

    def execute(command)
      @commands << command
      Struct.new(:body).new("OK")
    end

    def end_session!
      true
    end
  end

  class FailingClient
    def initialize(*); end

    def authenticate!(*)
      raise "connection refused"
    end

    def end_session!
      true
    end
  end

  test "port_for resolves the env var for a known map and falls back otherwise" do
    ENV["ISLAND_WP_RCON_PORT"] = "27001"
    ENV["RAGNAROK_WP_RCON_PORT"] = "27005"

    assert_equal 27005, RconDispatcher.port_for("Ragnarok_WP")
    assert_equal 27001, RconDispatcher.port_for("UnknownMap_WP")
  ensure
    ENV.delete("ISLAND_WP_RCON_PORT")
    ENV.delete("RAGNAROK_WP_RCON_PORT")
  end

  test "execute returns a successful Result carrying the response body" do
    fake = FakeClient.new
    Rcon::Client.stub :new, fake do
      result = RconDispatcher.execute("BanPlayer abc", port: 27001)

      assert result.success?
      assert_equal "OK", result.response
      assert_equal ["BanPlayer abc"], fake.commands
    end
  end

  test "execute never raises and reports the failure in the Result" do
    Rcon::Client.stub :new, FailingClient.new do
      result = RconDispatcher.execute("BanPlayer abc", port: 27001)

      refute result.success?
      assert_match(/connection refused/, result.error)
    end
  end

  test "execute_and_log records an RconExecution" do
    user = User.create!(email: "rcon-admin@example.com", password: "password123", role: :admin)
    fake = FakeClient.new

    assert_difference -> { RconExecution.count }, 1 do
      Rcon::Client.stub :new, fake do
        execution = RconDispatcher.execute_and_log("BanPlayer abc", map_name: "TheIsland_WP", user: user)

        assert execution.persisted?
        assert execution.success?
        assert_equal "BanPlayer abc", execution.full_command
        assert_equal "TheIsland_WP", execution.map
        assert_equal user, execution.user
      end
    end
  end
end
