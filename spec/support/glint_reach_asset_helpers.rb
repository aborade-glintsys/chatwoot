require 'mini_magick'

# Builds real image files (via ImageMagick) or arbitrary bytes for GlintReach asset specs.
module GlintReachAssetHelpers
  def glint_reach_image_upload(width: 400, height: 300, format: 'png', filename: nil, content_type: nil)
    path = File.join(Dir.mktmpdir, "image.#{format}")
    MiniMagick::Tool::Convert.new do |convert|
      convert.size("#{width}x#{height}")
      convert << 'xc:#3366cc'
      convert << path
    end
    Rack::Test::UploadedFile.new(path, content_type || "image/#{format}", true, original_filename: filename || "creative.#{format}")
  end

  def glint_reach_bytes_upload(bytes, filename:, content_type:)
    path = File.join(Dir.mktmpdir, 'upload.bin')
    File.binwrite(path, bytes)
    Rack::Test::UploadedFile.new(path, content_type, true, original_filename: filename)
  end
end

RSpec.configure { |config| config.include GlintReachAssetHelpers }
