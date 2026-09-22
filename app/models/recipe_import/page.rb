require "net/http"

# A fetched web page: its schema.org/Recipe JSON-LD, if it has one, and its
# readable text for when it does not.
class RecipeImport::Page
  MAX_REDIRECTS = 5
  MAX_TEXT = 30_000 # characters of page text sent to the model
  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
    "Accept" => "text/html,application/xhtml+xml"
  }.freeze
  NOISE = "script, style, noscript, template, svg, iframe, nav, header, footer, aside, form"

  def self.fetch(url, redirects: MAX_REDIRECTS)
    uri = URI(url)
    raise RecipeImport::Error, "Only http and https URLs can be imported" unless uri.is_a?(URI::HTTP)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
      http.get(uri.request_uri, HEADERS)
    end

    case response
    when Net::HTTPSuccess
      new(response.body.to_s.dup.force_encoding(Encoding::UTF_8).scrub)
    when Net::HTTPRedirection
      raise RecipeImport::Error, "Too many redirects from #{url}" if redirects.zero?

      fetch(URI.join(url, response["location"]).to_s, redirects: redirects - 1)
    else
      raise RecipeImport::Error, "#{url} answered #{response.code}"
    end
  rescue URI::InvalidURIError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    raise RecipeImport::Error, "Could not fetch #{url}: #{e.message}"
  end

  def initialize(html)
    @document = Nokogiri::HTML(html)
  end

  def json_ld_recipe
    @document.css('script[type="application/ld+json"]').each do |script|
      recipe = find_recipe(JSON.parse(script.text)) rescue nil
      return recipe if recipe
    end
    nil
  end

  def text
    body = (@document.at("body") || @document).dup
    body.css(NOISE).remove
    body.text.squish.truncate(MAX_TEXT, omission: "")
  end

  private
    def find_recipe(node)
      case node
      when Array
        node.lazy.filter_map { |item| find_recipe(item) }.first
      when Hash
        return node if Array(node["@type"]).include?("Recipe")

        find_recipe(node["@graph"]) || find_recipe(node["mainEntity"])
      end
    end
end
