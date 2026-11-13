require 'mini_magick'

# Validates an uploaded creative from its bytes. The file extension and the client-supplied MIME type
# are ignored: the type comes from Marcel's magic-byte sniffing and the dimensions from ImageMagick.
# Returns the metadata needed to store the asset, or raises Invalid with an i18n message.
class GlintReach::AssetInspector
  class Invalid < StandardError; end

  ALLOWED_TYPES = {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif'
  }.freeze
  MAX_BYTES = 10.megabytes
  MIN_SIDE = 200
  MAX_SIDE = 8_192
  MAX_PIXELS = 40_000_000
  SNIFF_BYTES = 4_096

  Result = Data.define(:filename, :content_type, :byte_size, :width, :height, :path)

  def initialize(upload)
    @upload = upload
  end

  def inspect!
    path = upload_path
    byte_size = File.size(path)
    invalid!(:empty) if byte_size.zero?
    invalid!(:too_large, max_mb: MAX_BYTES / 1.megabyte) if byte_size > MAX_BYTES

    content_type = sniff(path)
    width, height = dimensions(path)
    Result.new(filename: safe_filename(content_type), content_type: content_type, byte_size: byte_size,
               width: width, height: height, path: path)
  end

  private

  def upload_path
    path = @upload.respond_to?(:path) ? @upload.path : nil
    invalid!(:missing) if path.blank? || !File.file?(path)
    path
  end

  def sniff(path)
    type = File.open(path, 'rb') { |io| Marcel::MimeType.for(StringIO.new(io.read(SNIFF_BYTES).to_s)) }
    invalid!(:unsupported_type) unless ALLOWED_TYPES.key?(type)
    type
  end

  def dimensions(path)
    # Only the first frame is inspected ([0]) so animated GIFs are not fully decoded.
    width, height = MiniMagick::Tool::Identify.new do |identify|
      identify.format('%w %h')
      identify << "#{path}[0]"
    end.split.map(&:to_i)
    invalid!(:unreadable) unless width.to_i.positive? && height.to_i.positive?
    check_dimensions!(width, height)
    [width, height]
  rescue MiniMagick::Error, MiniMagick::Invalid
    invalid!(:unreadable)
  end

  def check_dimensions!(width, height)
    invalid!(:too_small, min: MIN_SIDE) if [width, height].min < MIN_SIDE
    invalid!(:too_big, max: MAX_SIDE) if [width, height].max > MAX_SIDE
    invalid!(:too_many_pixels, max_mp: MAX_PIXELS / 1_000_000) if width * height > MAX_PIXELS
  end

  # Keeps the user's base name (sanitized) but always uses the extension of the detected type.
  def safe_filename(content_type)
    original = @upload.respond_to?(:original_filename) ? @upload.original_filename.to_s : ''
    base = ActiveStorage::Filename.new(File.basename(original, '.*')).sanitized.gsub(/[^\w.\- ]/, '_').strip
    base = 'asset' if base.blank?
    "#{base.first(200)}.#{ALLOWED_TYPES.fetch(content_type)}"
  end

  def invalid!(key, **)
    raise Invalid, I18n.t("errors.glint_reach.assets.#{key}", **)
  end
end
