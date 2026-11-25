# :nodoc:
require "json"
require "beryl"
require "random/secure"
require "crypto/subtle"

require "./message_verifier"

module Amber::Support
  # Encrypts and signs a message: AES-256-CBC (the first 32 bytes of the
  # secret as the key), then the 16-byte initialization vector, then an HMAC
  # of both. Beryl does the cryptography, byte for byte as OpenSSL did.
  class MessageEncryptor
    KEY_BYTESIZE = 32

    getter verifier : MessageVerifier

    def initialize(@secret : String, @cipher_algorithm = "aes-256-cbc", @digest = :sha256)
      @verifier = MessageVerifier.new(@secret, digest: @digest)
      @block_size = 16
      @signature_size = 32
    end

    # Verify and Decrypt a message. We need to verify the message in order to
    # avoid padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
    def verify_and_decrypt(value : Bytes) : Bytes
      signature = value[value.size - @signature_size, @signature_size]
      data_iv = value[0, value.size - @signature_size]
      if Crypto::Subtle.constant_time_compare(sign_bytes(data_iv), signature)
        decrypt(data_iv)
      else
        raise "Invalid Encryption!"
      end
    end

    # Encrypt and sign a message. We need to sign the message in order to avoid
    # padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
    def encrypt_and_sign(value)
      encrypt(value, sign: true)
    end

    def encrypt(value, sign = false)
      iv = Random::Secure.random_bytes(@block_size)

      encrypted_data = IO::Memory.new
      encrypted_data.write(cipher.encrypt(value.to_slice, initialization_vector: iv))
      encrypted_data.write(iv)
      encrypted_data.write(sign_bytes(encrypted_data.to_slice)) if sign
      encrypted_data.to_slice
    end

    def decrypt(value : Bytes)
      data = value[0, value.size - @block_size]
      iv = value[value.size - @block_size, @block_size]

      cipher.decrypt(data, initialization_vector: iv) || raise "Invalid Encryption!"
    end

    private def cipher : Beryl::Crypto::Compatibility::AESCBC
      unless @cipher_algorithm.downcase == "aes-256-cbc"
        raise ArgumentError.new("Unsupported cipher #{@cipher_algorithm.inspect}: messages use aes-256-cbc")
      end
      raise ArgumentError.new("The encryption key must be at least #{KEY_BYTESIZE} bytes") if @secret.bytesize < KEY_BYTESIZE
      Beryl::Crypto::Compatibility::AESCBC.new(@secret.to_slice[0, KEY_BYTESIZE])
    end

    private def sign_bytes(data : Bytes)
      MessageVerifier.authentication_tag(@digest, @secret, data)
    end
  end
end
