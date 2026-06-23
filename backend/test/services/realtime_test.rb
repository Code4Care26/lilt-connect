require "test_helper"

class RealtimeTest < ActiveSupport::TestCase
  setup do
    @orig_url = ENV["SSE_PUBLISH_URL"]
    @orig_secret = ENV["SSE_PUBLISH_SECRET"]
  end

  teardown do
    restore_env("SSE_PUBLISH_URL", @orig_url)
    restore_env("SSE_PUBLISH_SECRET", @orig_secret)
    Realtime.transport = nil # back to the real HTTP poster
  end

  test "publish is a no-op (returns nil, no delivery) when SSE_PUBLISH_URL is unset" do
    ENV.delete("SSE_PUBLISH_URL")
    called = false
    Realtime.transport = ->(*) { called = true }

    assert_nil Realtime.publish(type: "events.changed", id: "e1")
    refute called, "transport must not be called when disabled"
  end

  test "publish POSTs the invalidation JSON to the configured endpoint with the secret" do
    ENV["SSE_PUBLISH_URL"] = "http://localhost:3002/publish"
    ENV["SSE_PUBLISH_SECRET"] = "s3cret"
    delivered = Queue.new
    Realtime.transport = ->(url, body, headers) { delivered.push([url, body, headers]) }

    returned = Realtime.publish(type: "events.changed", id: "e1")
    assert_equal({ type: "events.changed", id: "e1" }.to_json, returned)

    url, body, headers = delivered.pop # blocks until the detached thread delivers
    assert_equal "http://localhost:3002/publish", url
    assert_equal({ type: "events.changed", id: "e1" }.to_json, body)
    assert_equal "application/json", headers["Content-Type"]
    assert_equal "s3cret", headers["X-Sse-Secret"]
  end

  test "publish omits the secret header when SSE_PUBLISH_SECRET is unset" do
    ENV["SSE_PUBLISH_URL"] = "http://localhost:3002/publish"
    ENV.delete("SSE_PUBLISH_SECRET")
    delivered = Queue.new
    Realtime.transport = ->(_url, _body, headers) { delivered.push(headers) }

    Realtime.publish(type: "reset")
    assert_nil delivered.pop["X-Sse-Secret"]
  end

  test "delivery errors are swallowed (best-effort: never break the mutation)" do
    Realtime.transport = ->(*) { raise "gosse is down" }
    assert_nothing_raised do
      Realtime.send(:deliver, "http://localhost:3002/publish", "{}", {})
    end
  end

  private

  def restore_env(key, value)
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end
