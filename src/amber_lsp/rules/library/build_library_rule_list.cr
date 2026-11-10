module AmberLSP::Rules::Library
  # Builds independent rule instances for one library check.
  class BuildLibraryRuleList
    # Initializes the list builder with *project_root*.
    def initialize(@project_root : String)
    end

    # Builds this command's isolated library rule instances.
    # Builds this command's isolated library rule instances.
    def perform : Support::ListOfLibraryRules
      [
        TypedRaise.new,
        EnvironmentRead.new,
        StdlibReopen.new,
        LogSetup.new,
        ProcessOutput.new,
        SwallowedRescue.new,
        UncheckedCast.new,
        UnsynchronizedClassVariable.new,
        DisabledCertificateVerification.new,
        PublicReturnType.new,
        VagueInternalName.new,
        CollaredSpec.new,
        PublicMethodHasSpec.new(@project_root),
        SpecWithoutAssertion.new,
        ChangedMethodCollar.new,
      ] of AmberLSP::Rules::BaseRule
    end
  end
end
