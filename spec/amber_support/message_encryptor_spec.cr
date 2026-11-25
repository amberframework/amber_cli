require "../spec_helper"

# Written by the OpenSSL implementation this CLI used up to 2.0.16, so the
# Beryl one is held to the same bytes.
private FIXTURE_KEY              = "k3y-for-the-amber-cli-encryptor-fixture-0123456789"
private FIXTURE_SEALED_MESSAGE   = "20Hz7pV7EFH1t0Y0XKPs13leMVnQliut4d0vtBQK/7KKQEoR2OOuQUHB3b+IlslPMi8AHjcsCgysoFX0deQ51ueWNsw/t35JaxTujQY0qa3GrAUTagIl5o2tENx49el1"
private FIXTURE_SHA1_SIGNATURE   = "c2lnbmVkIHZhbHVl--ts6zrxz5ZrggpZyTN0adTQ8s5Bg="
private FIXTURE_SHA256_SIGNATURE = "c2lnbmVkIHZhbHVl--Q+9gMng2g96RfMtAbZJyiV6UE5gBGHJkknL+SMDv89Q="

describe Amber::Support::MessageEncryptor do
  describe "#verify_and_decrypt" do
    it "opens a message the OpenSSL implementation sealed" do
      sealed = Base64.decode(FIXTURE_SEALED_MESSAGE)
      opened = Amber::Support::MessageEncryptor.new(FIXTURE_KEY).verify_and_decrypt(sealed)
      String.new(opened).should eq("database:\n  url: postgres://localhost/app\n")
    end

    it "refuses a message with a changed byte" do
      sealed = Base64.decode(FIXTURE_SEALED_MESSAGE)
      sealed[3] ^= 1_u8
      expect_raises(Exception, "Invalid Encryption!") do
        Amber::Support::MessageEncryptor.new(FIXTURE_KEY).verify_and_decrypt(sealed)
      end
    end
  end

  describe "#encrypt_and_sign" do
    it "round-trips with a fresh initialization vector each time" do
      encryptor = Amber::Support::MessageEncryptor.new(FIXTURE_KEY)
      first = encryptor.encrypt_and_sign("a credential")
      second = encryptor.encrypt_and_sign("a credential")
      first.should_not eq(second)
      String.new(encryptor.verify_and_decrypt(first)).should eq("a credential")
    end
  end
end

describe Amber::Support::MessageVerifier do
  describe "#generate" do
    it "signs as the OpenSSL implementation did" do
      Amber::Support::MessageVerifier.new(FIXTURE_KEY).generate("signed value").should eq(FIXTURE_SHA1_SIGNATURE)
      Amber::Support::MessageVerifier.new(FIXTURE_KEY, digest: :sha256).generate("signed value").should eq(FIXTURE_SHA256_SIGNATURE)
    end
  end

  describe "#verify" do
    it "accepts its own signature" do
      Amber::Support::MessageVerifier.new(FIXTURE_KEY, digest: :sha256).verify(FIXTURE_SHA256_SIGNATURE).should eq("signed value")
    end
  end
end
