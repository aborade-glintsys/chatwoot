require 'rails_helper'

RSpec.describe GlintReach::AssetInspector do
  def inspect_upload(upload)
    described_class.new(upload).inspect!
  end

  %w[png jpeg gif webp].each do |format|
    it "accepts a valid #{format} and reads its real dimensions" do
      result = inspect_upload(glint_reach_image_upload(width: 640, height: 360, format: format))

      expect(result).to have_attributes(content_type: "image/#{format}", width: 640, height: 360)
      expect(result.byte_size).to be_positive
    end
  end

  it 'uses the sniffed type, not the extension or client MIME' do
    upload = glint_reach_image_upload(format: 'jpeg', filename: 'photo.png', content_type: 'image/png')
    result = inspect_upload(upload)

    expect(result.content_type).to eq('image/jpeg')
    expect(result.filename).to eq('photo.jpg')
  end

  it 'rejects HTML disguised as a PNG' do
    upload = glint_reach_bytes_upload('<html><script>alert(1)</script></html>', filename: 'evil.png', content_type: 'image/png')
    expect { inspect_upload(upload) }.to raise_error(described_class::Invalid, /not a JPEG, PNG, WebP or GIF/)
  end

  it 'rejects SVG even when labelled as an image' do
    svg = '<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg" width="400" height="400"></svg>'
    upload = glint_reach_bytes_upload(svg, filename: 'logo.svg', content_type: 'image/svg+xml')
    expect { inspect_upload(upload) }.to raise_error(described_class::Invalid)
  end

  it 'rejects a corrupt image with a valid header' do
    png_header = "\x89PNG\r\n\x1A\n".b + ('x' * 200)
    upload = glint_reach_bytes_upload(png_header, filename: 'broken.png', content_type: 'image/png')
    expect { inspect_upload(upload) }.to raise_error(described_class::Invalid, /could not be read/)
  end

  it 'rejects empty files' do
    upload = glint_reach_bytes_upload('', filename: 'empty.png', content_type: 'image/png')
    expect { inspect_upload(upload) }.to raise_error(described_class::Invalid, /empty/)
  end

  it 'rejects files over 10 MB' do
    upload = glint_reach_image_upload
    allow(File).to receive(:size).and_call_original
    allow(File).to receive(:size).with(upload.path).and_return(described_class::MAX_BYTES + 1)
    expect { inspect_upload(upload) }.to raise_error(described_class::Invalid, /larger than 10 MB/)
  end

  it 'rejects images that are too small' do
    expect { inspect_upload(glint_reach_image_upload(width: 199, height: 400)) }
      .to raise_error(described_class::Invalid, /at least 200 pixels/)
  end

  it 'rejects images with a side over 8192 px' do
    expect { inspect_upload(glint_reach_image_upload(width: 8193, height: 200)) }
      .to raise_error(described_class::Invalid, /at most 8192 pixels/)
  end

  it 'rejects images over 40 megapixels' do
    expect { inspect_upload(glint_reach_image_upload(width: 8000, height: 5001)) }
      .to raise_error(described_class::Invalid, /40 megapixels/)
  end

  it 'rejects a missing upload' do
    expect { inspect_upload(nil) }.to raise_error(described_class::Invalid, /Choose a file/)
  end

  it 'sanitizes file names' do
    result = inspect_upload(glint_reach_image_upload(filename: '../../etc/pa<ss>wd.png'))
    expect(result.filename).not_to include('/', '<', '>')
    expect(result.filename).to end_with('.png')
  end
end
