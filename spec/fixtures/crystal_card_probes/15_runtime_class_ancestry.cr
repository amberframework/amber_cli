class CardProbeBase; end

class CardProbeChild < CardProbeBase; end

instance = CardProbeChild.new
instance.is_a?(CardProbeBase)
