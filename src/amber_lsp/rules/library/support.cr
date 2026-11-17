# :nodoc:
require "compiler/crystal/syntax"
require "set"

module AmberLSP::Rules::Library::Support
  alias ListOfDiagnostics = Array(AmberLSP::Rules::Diagnostic)
  alias ListOfPublicMethods = Array(Crystal::Def)
  alias ListOfVagueNameFindings = Array(Tuple(Crystal::ASTNode, String))
  alias ListOfCoreTypeReopens = Array(Tuple(Crystal::ASTNode, String))
  alias ListOfRescueClauses = Array(Crystal::Rescue)
  alias ListOfTypeCasts = Array(Crystal::Cast)
  alias ListOfCrystalPaths = Array(Crystal::Path)
  alias ListOfCrystalCalls = Array(Crystal::Call)
  alias ListOfASTNodes = Array(Crystal::ASTNode)
  alias ListOfStrings = Array(String)
  alias ListOfLibraryRules = Array(AmberLSP::Rules::BaseRule)
  alias ListOfBehaviorDescribes = Array(BehaviorDescribe)
  alias SetOfMethodDescribeSelectors = Set(String)
end
