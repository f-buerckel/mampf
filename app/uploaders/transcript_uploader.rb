class TranscriptUploader < Shrine
  # shrine plugins
  plugin :validation_helpers
  plugin :pretty_location

  Attacher.validate do
    validate_mime_type_inclusion ["text/vtt"], message: "must be a VTT file"
    validate_extension_inclusion ["vtt"], message: "must have .vtt extension"
  end
end
