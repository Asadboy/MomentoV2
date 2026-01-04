lane :setup_match do
  api_key = app_store_connect_api_key(
    key_id: "ZPWYQC3TN3",
    issuer_id: "6555c846-269e-4790-96ec-2574330dc6ad",
    key_filepath: File.expand_path("~/Documents/AuthKey_ZPWYQC3TN3.p8")
  )

  match(
    type: "appstore",
    readonly: false,
    api_key: api_key
  )
end
