# Plain messages to Discord

Create a webhook in the destination channel under **Settings → Integrations →
Webhooks**. Store its full URL as the customer secret `DISCORD_WEBHOOK_URL`.
Invoke the free `gateway` channel using your UnitySVC API key. For an additional
destination, enroll in `gateway-plus` and set `webhook_url_secret` to the name
of the customer secret containing that destination's webhook URL.

Send the unified `msg` format to the service, rather than Discord's native
payload:

```json
{
  "title": "Alice - Help desk",
  "body": "Your issue is resolved. **Thank you!**",
  "format": "markdown",
  "links": ["https://unitysvc.com"]
}
```

`title` becomes the per-message Discord username; `body` becomes plain content,
not an embed. An optional `avatar_url` selects a publicly accessible HTTPS
raster image; omit it to keep the webhook's avatar. Discord still shows its
APP badge. Room delivery supplies its own sender/room title; this service does
not infer identity or look up a person's profile picture.

Names longer than 80 Unicode codepoints and content longer than 2000 are
truncated with a final ellipsis. A title containing `discord` or `clyde`, in any
ASCII letter case, is omitted so Discord uses its configured webhook name.
An absent or empty title also keeps that name. Non-HTTPS avatar URLs are
omitted, keeping the configured avatar. Links fold into the content before
truncation and count toward its limit. Overlong messages are truncated, not
split into multiple posts.

The first image attachment appears below the plain text in an image-only
embed. For example, add `"attachment": [{"url": "https://example.com/photo.png",
"filename": "photo.png", "type": "image/png"}]` to the request. Room delivery
supplies the attachment URL and MIME type automatically. With no image, no
embed is sent. Text-only messages keep their plain appearance.

Only the first image is shown. Additional images and non-image files are not
mapped to Discord file uploads; include their URLs in `links` when they need
to reach the recipient as download links. Keep signed URL query strings intact.
Discord must be able to fetch the image URL when the message is delivered.
The message needs text, a link or an image. Inbound Discord
messages use the separate `labs/discord-to-msg` service.

Deployment requires the gateway changes from `unitysvc/apisix-gateways#91` to
be promoted before this service revision is uploaded or activated. The same
normalizer and mapping apply to both `gateway` and `gateway-plus`.
