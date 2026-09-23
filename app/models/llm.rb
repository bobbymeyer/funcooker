require "net/http"

# Structured extraction against the OpenAI-compatible endpoint in
# config.x.llm: the reply is constrained to a JSON schema, so it always parses
# into the shape asked for. An image, when given, goes with the input to the
# vision model.
class Llm
  class Error < StandardError; end
  class Refused < Error; end # the server answered, with an error

  VISION_HINT = "Images need a vision-capable model: load one in llama-swap with its --mmproj file, and set LLM_VISION_MODEL to its id."

  READ_TIMEOUT = 600 # the first request after idle waits for the model to load

  def self.extract(instructions:, input:, schema:, image: nil)
    new.extract(instructions:, input:, schema:, image:)
  end

  def initialize(config = Rails.configuration.x.llm)
    @base_url = config.base_url
    @model = config.model
    @vision_model = config.vision_model.presence || config.model
  end

  # image: { data: String, content_type: String }
  def extract(instructions:, input:, schema:, image: nil)
    model = image ? @vision_model : @model
    raise Error, "LLM_MODEL is not set" if model.blank?

    reply = complete(model:, image:, body: {
      model: model,
      temperature: 0,
      messages: [
        { role: "system", content: instructions },
        { role: "user", content: image ? [ { type: "text", text: input }, image_part(image) ] : input }
      ],
      response_format: { type: "json_schema", json_schema: { name: "extraction", strict: true, schema: schema } },
      chat_template_kwargs: { enable_thinking: false }
    })

    choice = reply.dig("choices", 0) or raise Error, "The model returned no choices"
    raise Error, "The model ran out of tokens before finishing" if choice["finish_reason"] == "length"

    JSON.parse(choice.dig("message", "content").to_s)
  rescue JSON::ParserError => e
    raise Error, "The model returned invalid JSON: #{e.message}"
  end

  private
    # A server that cannot take images refuses the request outright, so that
    # refusal says what is missing.
    def complete(model:, image:, body:)
      post("chat/completions", body)
    rescue Refused => e
      raise unless image

      raise Refused, "#{model} could not read the image. #{VISION_HINT} The server said: #{e.message}"
    end

    def image_part(image)
      { type: "image_url", image_url: { url: "data:#{image[:content_type]};base64,#{Base64.strict_encode64(image[:data])}" } }
    end

    def post(path, body)
      uri = URI.join(@base_url.chomp("/") + "/", path)
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request.body = body.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end
      raise Refused, "#{uri} answered #{response.code}: #{response.body.to_s.truncate(300)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Error, "Could not reach #{@base_url}: #{e.message}"
    end
end
