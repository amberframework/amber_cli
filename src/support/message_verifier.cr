# :nodoc:
require "beryl"
require "crypto/subtle"
require "base64"

module Amber::Support
  class MessageVerifier
    def initialize(@secret : String, @digest = :sha1)
    end

    def valid_message?(data, digest)
      data.size > 0 && digest.size > 0 && Crypto::Subtle.constant_time_compare(digest, generate_digest(data))
    end

    def verified(signed_message : String)
      data, digest = signed_message.split("--")
      if valid_message?(data, digest)
        String.new(decode(data))
      end
    rescue argument_error : ArgumentError
      return if argument_error.message =~ %r{invalid base64}
      raise argument_error
    end

    def verify(signed_message) : String
      verified(signed_message) || raise(Exceptions::InvalidSignature.new)
    end

    def verify_raw(signed_message : String) : Bytes
      data, digest = signed_message.split("--")
      if valid_message?(data, digest)
        decode(data)
      else
        raise(Exceptions::InvalidSignature.new)
      end
    end

    def generate(value : String | Bytes)
      data = encode(value)
      "#{data}--#{generate_digest(data)}"
    end

    # Returns the HMAC tag of *data* under *secret* with *digest* (`:sha1`,
    # `:sha256`, `:sha384` or `:sha512`), computed by Beryl.
    def self.authentication_tag(digest : Symbol, secret : String, data : String | Bytes) : Bytes
      case digest
      when :sha1   then Beryl::Crypto::V1::HMAC(Beryl::Crypto::Compatibility::SHA1).authenticate(data, key: secret)
      when :sha256 then Beryl::Crypto::V1::HMAC(Beryl::Crypto::V1::SHA256).authenticate(data, key: secret)
      when :sha384 then Beryl::Crypto::V1::HMAC(Beryl::Crypto::V1::SHA384).authenticate(data, key: secret)
      when :sha512 then Beryl::Crypto::V1::HMAC(Beryl::Crypto::V1::SHA512).authenticate(data, key: secret)
      else              raise ArgumentError.new("Unsupported digest #{digest.inspect}: use :sha1, :sha256, :sha384 or :sha512")
      end
    end

    private def encode(data)
      ::Base64.strict_encode(data)
    end

    private def decode(data)
      ::Base64.decode(data)
    end

    private def generate_digest(data)
      encode(self.class.authentication_tag(@digest, @secret, data))
    end
  end
end
