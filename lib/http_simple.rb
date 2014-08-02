require 'net/http'
require 'openssl'
require 'uri'

module HTTPSimple

  class Bug < StandardError; end

  class HTTPException < StandardError
    def initialize report=nil
      @report = report
    end

    def report
      @report
    end
  end

  class ResponseException < HTTPException; end
  class NetworkException < HTTPException; end

  class NotFound < ResponseException; end
  class BadRequest < ResponseException; end
  class Forbidden < ResponseException; end
  class Unauthorized < ResponseException; end
  class ServiceUnavailable < ResponseException; end
  class InternalServerError < ResponseException; end
  class BadGateway < ResponseException; end
  class MethodNotAllowed < ResponseException; end

  def self.get uri_string, query:{}, headers:{}
    generic_http_exec :get, uri_string, query, nil, headers
  end

  def self.head uri_string, query:{}, headers:{}
    generic_http_exec :head, uri_string, query, nil, headers
  end

  def self.delete uri_string, query:{}, headers:{}
    generic_http_exec :delete, uri_string, query, nil, headers
  end

  def self.post uri_string, query:{}, body:'', headers:{}
    generic_http_exec :post, uri_string, query, body, headers
  end

  def self.put uri_string, query:{}, body:'', headers:{}
    generic_http_exec :put, uri_string, query, body, headers
  end

  private

  def self.generic_http_exec meth, uri_string, query, body, headers
    uri = assert_string_uri uri_string
    http = new_http(uri)
    response = rethrow_network_exceptions(uri, headers:headers, body:body) do 
      raw_uri = uri_query_to_s(uri, query)
      case meth
        when :get then http.get(raw_uri, headers)
        when :head then http.head(raw_uri, headers)
        when :delete then http.delete(raw_uri, headers)
        when :post then http.post(raw_uri, body, headers)
        when :put then http.put(raw_uri, body, headers)
        else raise Bug, "bad method #{meth.inspect}"
      end
    end
    assert_ok(response.code, {
      :method => meth,
      :uri => uri_string,
      :request_body => body,
      :headers => headers,
      :status => "#{response.code} #{response.message}",
      :response_body => response.body
    })
    response.body || ''
  end

  def self.assert_string_uri uri_string
    if !uri_string.is_a?(String)
      raise ArgumentError, "uri string expected, not #{uri_string.inspect}"
    end

    uri = URI.parse uri_string

    if uri.scheme !~ /^https?$/
      raise ArgumentError, "uri must use http:// or https://"
    end

    uri
  end

  def self.assert_ok code, error_report
    eclass = case code
      when /^2\d\d$/ then :none
      when '400' then BadRequest
      when '401' then Unauthorized
      when '403' then Forbidden
      when '404' then NotFound
      when '405' then MethodNotAllowed
      when '500' then InternalServerError
      when '502' then BadGateway
      when '503' then ServiceUnavailable
      else ResponseException
    end

    raise eclass.new(error_report), code if eclass != :none
  end

  def self.rethrow_network_exceptions uri, headers:{}, body:{}
    begin
      yield
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNREFUSED,
      Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError,
      EOFError, OpenSSL::SSL::SSLError => e
      report = {:uri => uri, :request_headers => headers, :request_body => body}
      raise NetworkException.new(report), e.inspect
    end
  end

  def self.uri_query_to_s uri, query
    if query.empty?
      uri.to_s
    elsif uri.query.nil?
      "#{uri.to_s}?#{URI.encode_www_form query}"
    else
      "#{uri.to_s}&#{URI.encode_www_form query}"
    end
  end

  def self.new_http uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end

end
