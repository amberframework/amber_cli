require "./coverage/covered"
require "./coverage/declined"
require "./coverage/failed"

module AmberLSP::Coverage
  alias Result = Covered | Declined | Failed
end
