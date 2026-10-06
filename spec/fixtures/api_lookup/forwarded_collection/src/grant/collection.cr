class Grant::Collection(M)
  forward_missing_to collection

  private def collection : Array(M)
    [] of M
  end
end
