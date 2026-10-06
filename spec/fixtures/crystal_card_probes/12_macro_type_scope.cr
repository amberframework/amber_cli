class CardProbeFields
  @value : String

  macro first_ivar_name
 {{ @type.instance_vars.first.name.stringify }}; end

  def initialize(@value : String); end

  def name : String
    first_ivar_name
  end
end

CardProbeFields.new("value").name
