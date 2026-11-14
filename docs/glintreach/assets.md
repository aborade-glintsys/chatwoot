# GlintReach creative assets (Phase 05)

Campaign-owned images that can be attached, in order, to content variants.

## Model
| Table | Purpose |
| --- | --- |
| `glint_reach_assets` | One row per image: `account_id`, `campaign_id` (FK cascade), `uploaded_by_id`, cached `filename`, `content_type`, `byte_size`, `width`, `height`, `checksum`, optional `alt_text` (≤ 1,000). File in `has_one_attached :file` |
| `glint_reach_variant_assets` | `content_variant_id` + `asset_id` + `position`; unique pair; FKs cascade on both sides |

A link is valid only when the asset and the variant belong to the **same campaign**, so assets can
never be attached across campaigns or accounts. At most 10 assets per variant.

## Validation (server-side, from the bytes)
`GlintReach::AssetInspector` runs before anything is stored. The extension and the client MIME type are ignored.

| Check | Rule |
| --- | --- |
| Type | Marcel magic-byte sniffing must give `image/jpeg`, `image/png`, `image/webp` or `image/gif`. SVG, HTML and others are rejected |
| Size | 1 byte – 10 MB |
| Dimensions | ImageMagick `identify` on the first frame: each side 200–8,192 px, ≤ 40 megapixels (decompression-bomb guard). Undecodable files are rejected |
| Filename | Sanitized base name + the extension of the detected type |

Uploads are multipart requests to the authenticated GlintReach endpoint. The unauthenticated Rails
direct-upload route stays blocked (`config/initializers/active_storage.rb`).

## Storage and access
- Files go to the installation's existing Active Storage service (`ACTIVE_STORAGE_SERVICE`, `config/storage.yml`). No new credentials or buckets.
- Every request passes the GlintReach chain: authenticated account administrator, `glint_reach` flag, lookup through `Current.account.glint_reach_campaigns` → campaign → asset. Other accounts get `404`/`401`.
- The API returns `url` / `thumbnail_url` as **signed paths that expire after 5 minutes** (`expires_in` on the blob signed id). URLs are never stored. `<img>` tags cannot send API token headers, so anyone holding a URL can use it until it expires.
- Thumbnails are Active Storage variants (`resize_to_limit: [480, 480]`) generated on first request with the configured variant processor (libvips by default), the same as Chatwoot avatars.
- Replacing a file keeps variant links; Active Storage purges the previous blob after the save. Deleting an asset removes its links and purges the blob. A failed replacement leaves the original file untouched.
- Locked campaigns (completed/archived): assets can be read, not changed.
- Asset changes are audited (`Enterprise::Audit::GlintReach::Asset`).

Existing Chatwoot attachments, avatars and direct uploads are not changed.

## Image generation
Not implemented. No image-generation provider is configured and no licensing terms have been
agreed, so the UI offers upload only and does not suggest generation is available.
