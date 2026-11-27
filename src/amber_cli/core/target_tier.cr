module AmberCLI
  # A named CPU target for `amber build`. The portable tier leaves the CPU to
  # crystal-alpha's default target; every other tier passes `--mcpu` (and
  # `--mattr` when the CPU name alone is not enough) for owners who know the
  # machine they deploy to.
  record TargetTier,
    tier_name : String,
    architecture : String?,
    mcpu : String?,
    mattr : String?,
    description : String do
    # Returns true when the tier keeps crystal-alpha's default target.
    def portable? : Bool
      mcpu.nil?
    end

    # Returns true when a binary for this tier can be built on a host with
    # the given architecture (`"x86_64"` or `"aarch64"`).
    def builds_on?(host_architecture : String) : Bool
      tier_architecture = architecture
      tier_architecture.nil? || tier_architecture == host_architecture
    end

    # Returns the compiler flags that select this tier's CPU.
    def list_of_compiler_flags : Array(String)
      list_of_flags = [] of String
      if cpu_name = mcpu
        list_of_flags << "--mcpu" << cpu_name
      end
      if attributes = mattr
        list_of_flags << "--mattr" << attributes
      end
      list_of_flags
    end
  end

  # Raised when `amber build --target-tier` names a tier that is not listed.
  class UnknownTargetTierError < Exception
  end

  # Raised when a tier's CPU belongs to a different architecture than the
  # machine running `amber build`.
  class TargetTierArchitectureError < Exception
  end

  DEFAULT_TARGET_TIER_NAME = "portable"

  # Every tier `amber build --target-tier` accepts. Each CPU name was checked
  # against crystal-alpha's LLVM (21) by compiling a program for it.
  TARGET_TIERS = [
    TargetTier.new("portable", nil, nil, nil,
      "Default. crystal-alpha's own target: runs on every supported chip and picks per-chip kernels at startup"),
    TargetTier.new("x86-64-v2", "x86_64", "x86-64-v2", nil,
      "Any x86-64 server with SSE4.2 and POPCNT: Intel Nehalem (2008) and later, AMD Bulldozer and later"),
    TargetTier.new("x86-64-v3", "x86_64", "x86-64-v3", nil,
      "x86-64 with AVX2, BMI2 and FMA: Intel Haswell (2013) and later, AMD Zen and later, nearly every cloud x86 instance"),
    TargetTier.new("x86-64-v4", "x86_64", "x86-64-v4", nil,
      "x86-64 with AVX-512 F/BW/DQ/VL: Intel Xeon Skylake-SP and later, AMD EPYC Zen 4 (Genoa) and later"),
    TargetTier.new("neoverse-v1", "aarch64", "neoverse-v1", nil,
      "Arm Neoverse V1 (SVE, no SVE2): AWS Graviton3 and Graviton3E"),
    TargetTier.new("neoverse-n2", "aarch64", "neoverse-n2", nil,
      "Arm Neoverse N2 (Armv9, SVE2): Azure Cobalt 100 and GitHub ubuntu-24.04-arm runners, Alibaba Yitian 710"),
    TargetTier.new("neoverse-v2", "aarch64", "neoverse-v2", nil,
      "Arm Neoverse V2 (Armv9, SVE2): AWS Graviton4, NVIDIA Grace, Google Axion"),
    TargetTier.new("apple-m1", "aarch64", "apple-m1", nil,
      "Apple M1 and every later Apple silicon Mac (M1, M2, M3, M4)"),
    TargetTier.new("apple-m4", "aarch64", "apple-m4", nil,
      "Apple M4 and later only (Armv9.2 with SME); M1 through M3 Macs cannot run it"),
  ]

  # Returns the tier named *tier_name*, or raises `UnknownTargetTierError`
  # with every valid tier name in the message.
  def self.find_target_tier!(tier_name : String) : TargetTier
    if tier = TARGET_TIERS.find { |candidate| candidate.tier_name == tier_name }
      return tier
    end

    list_of_tier_names = TARGET_TIERS.map(&.tier_name).join(", ")
    raise UnknownTargetTierError.new(
      "Unknown target tier '#{tier_name}'. Valid tiers: #{list_of_tier_names}. " \
      "Run `amber build --list-target-tiers` to see which machines each one fits.")
  end

  # Returns the tier table as `amber build --list-target-tiers` prints it.
  def self.target_tier_table : String
    name_width = TARGET_TIERS.max_of(&.tier_name.size)
    flag_width = TARGET_TIERS.max_of { |tier| tier_flag_summary(tier).size }

    String.build do |io|
      io << "Target tiers for `amber build --target-tier NAME`:\n"
      TARGET_TIERS.each do |tier|
        io << "  " << tier.tier_name.ljust(name_width)
        io << "  " << tier_flag_summary(tier).ljust(flag_width)
        io << "  " << tier.description << '\n'
      end
    end
  end

  private def self.tier_flag_summary(tier : TargetTier) : String
    list_of_flags = tier.list_of_compiler_flags
    list_of_flags.empty? ? "(default target)" : list_of_flags.join(" ")
  end
end
