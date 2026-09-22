require "test_helper"

class LlmTest < ActiveSupport::TestCase
  SCHEMA = { type: "object", properties: { ok: { type: "boolean" } }, required: %w[ ok ] }.freeze

  test "returns the parsed reply" do
    stub_llm ok: true

    assert_equal({ "ok" => true }, Llm.extract(instructions: "x", input: "y", schema: SCHEMA))
  end

  test "asks for the configured model with the schema" do
    stub_llm ok: true
    Llm.extract(instructions: "x", input: "y", schema: SCHEMA)

    assert_requested :post, LlmStubs::LLM_URL do |request|
      body = JSON.parse(request.body)
      body["model"] == "test-model" && body.dig("response_format", "json_schema", "schema", "required") == [ "ok" ]
    end
  end

  test "a reply cut off by the token limit is an error" do
    stub_request(:post, LlmStubs::LLM_URL).to_return(status: 200,
      body: { choices: [ { finish_reason: "length", message: { content: "{\"ok\":" } } ] }.to_json)

    assert_raises(Llm::Error) { Llm.extract(instructions: "x", input: "y", schema: SCHEMA) }
  end

  test "no model configured is an error" do
    Rails.configuration.x.llm.model = nil

    error = assert_raises(Llm::Error) { Llm.extract(instructions: "x", input: "y", schema: SCHEMA) }
    assert_equal "LLM_MODEL is not set", error.message
  end
end
