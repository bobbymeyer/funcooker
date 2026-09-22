ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module LlmStubs
  LLM_URL = "https://llm.test/v1/chat/completions"

  def stub_llm(*replies)
    stub_request(:post, LLM_URL).to_return(*replies.map { |reply| llm_response(reply) })
  end

  def llm_response(reply)
    body = { choices: [ { finish_reason: "stop", message: { role: "assistant", content: reply.to_json } } ] }
    { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end
end

class ActiveSupport::TestCase
  include LlmStubs

  setup do
    Rails.configuration.x.llm.base_url = "https://llm.test/v1"
    Rails.configuration.x.llm.model = "test-model"
  end
end
