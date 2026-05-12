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

  test "all_map_ports only includes maps with a configured port" do
    saved = RconDispatcher::MAP_PORT_ENVS.values.index_with { |k| ENV[k] }
    RconDispatcher::MAP_PORT_ENVS.each_value { |k| ENV.delete(k) }
    ENV["ISLAND_WP_RCON_PORT"] = "27001"
    ENV["RAGNAROK_WP_RCON_PORT"] = "27005"

    assert_equal({ "TheIsland_WP" => 27001, "Ragnarok_WP" => 27005 }, RconDispatcher.all_map_ports)
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
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

  test "execute_on_all_maps runs the command on every configured port" do
    ports = { "TheIsland_WP" => 1, "Ragnarok_WP" => 2, "Extinction_WP" => 3 }
    mutex = Mutex.new
    calls = []

    RconDispatcher.stub :all_map_ports, ports do
      run_one = lambda do |command, **kwargs|
        mutex.synchronize { calls << [command, kwargs[:port]] }
        RconDispatcher::Result.new(success: true, response: "OK")
      end
      RconDispatcher.stub :execute, run_one do
        results = RconDispatcher.execute_on_all_maps("BanPlayer abc")

        assert_equal ports.keys.sort, results.keys.sort
        assert results.values.all?(&:success?)
      end
    end

    assert_equal ports.values.sort, calls.map(&:last).sort
    assert(calls.all? { |c| c.first == "BanPlayer abc" })
  end

  test "execute_and_log records a single map RconExecution" do
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

  test "execute_and_log_all logs one aggregated RconExecution and returns the per-map results" do
    user = User.create!(email: "rcon-admin2@example.com", password: "password123", role: :admin)
    results_stub = {
      "TheIsland_WP" => RconDispatcher::Result.new(success: true, response: "OK"),
      "Ragnarok_WP" => RconDispatcher::Result.new(success: false, error: "Timeout"),
    }

    execution = nil
    assert_difference -> { RconExecution.count }, 1 do
      RconDispatcher.stub :execute_on_all_maps, results_stub do
        returned = RconDispatcher.execute_and_log_all("BanPlayer abc", user: user)
        assert_equal results_stub, returned
      end
      execution = RconExecution.last
    end

    assert_equal RconDispatcher::ALL_MAPS_LABEL, execution.map
    assert_equal "BanPlayer abc", execution.full_command
    refute execution.success? # une map a échoué => agrégat en échec
    assert_match(/TheIsland_WP: OK/, execution.response)
    assert_match(/Ragnarok_WP: Timeout/, execution.response)
  end
end
