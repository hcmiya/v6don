# frozen_string_literal: true

class Request
  REQUEST_TARGET = '(request-target)'

  include RoutingHelper

  def initialize(verb, url, **options)
    @verb    = verb
    @url     = Addressable::URI.parse(url).normalize
    @options = options.merge(Rails.configuration.x.http_client_proxy)
    @headers = {}

    set_common_headers!
    set_digest! if options.key?(:body)
  end

  def on_behalf_of(account, key_id_format = :acct)
    raise ArgumentError unless account.local?

    @account       = account
    @key_id_format = key_id_format

    self
  end

  def add_headers(new_headers)
    @headers.merge!(new_headers)
    self
  end

  def perform
    begin
      response = http_client.headers(headers).public_send(@verb, @url.to_s, @options)
    rescue => e
      raise e.class, "#{e.message} on #{@url}", e.backtrace[0]
    end

    begin
      yield response.extend(ClientLimit)
    ensure
      http_client.close
    end
  end

  def headers
    (@account ? @headers.merge('Signature' => signature) : @headers).without(REQUEST_TARGET)
  end

  private

  def set_common_headers!
    @headers[REQUEST_TARGET] = "#{@verb} #{@url.path}"
    @headers['User-Agent']   = user_agent
    @headers['Host']         = @url.host
    @headers['Date']         = Time.now.utc.httpdate
  end

  def set_digest!
    @headers['Digest'] = "SHA-256=#{Digest::SHA256.base64digest(@options[:body])}"
  end

  def signature
    algorithm = 'rsa-sha256'
    signature = Base64.strict_encode64(@account.keypair.sign(OpenSSL::Digest::SHA256.new, signed_string))

    "keyId=\"#{key_id}\",algorithm=\"#{algorithm}\",headers=\"#{signed_headers}\",signature=\"#{signature}\""
  end

  def signed_string
    @headers.map { |key, value| "#{key.downcase}: #{value}" }.join("\n")
  end

  def signed_headers
    @headers.keys.join(' ').downcase
  end

  def user_agent
    @user_agent ||= "curl/7.57.0"
  end

  def key_id
    case @key_id_format
    when :acct
      @account.to_webfinger_s
    when :uri
      [ActivityPub::TagManager.instance.uri_for(@account), '#main-key'].join
    end
  end

  def timeout
    { write: 20, connect: 15, read: 20 }
  end

  def http_client
    @http_client ||= HTTP.timeout(:per_operation, timeout).follow(max_hops: 2)
  end

  module ClientLimit
    def body_with_limit(limit = 1.megabyte)
      raise Mastodon::LengthValidationError if content_length.present? && content_length > limit

      if charset.nil?
        encoding = Encoding::BINARY
      else
        begin
          encoding = Encoding.find(charset)
        rescue ArgumentError
          encoding = Encoding::BINARY
        end
      end

      contents = String.new(encoding: encoding)

      while (chunk = readpartial)
        contents << chunk
        chunk.clear

        raise Mastodon::LengthValidationError if contents.bytesize > limit
      end

      contents
    end
  end

  class Socket < TCPSocket
  end

  private_constant :ClientLimit, :Socket
end
