# Discord to Messages — `discord-to-msg`

Bring the messages of a Discord channel into a UnitySVC room. The [WebhookBridge](https://webhook-bridge.whop.site) Discord bot forwards each new message in a channel to a URL; pointed at this service, the gateway converts the event into the platform `msg` envelope and posts it into your room through the room connector named in the URL. This is the reverse of `msg-to-discord`, which sends room and notification messages out to Discord.

## What the room receives

| `msg` field          | Source in the Discord event                                   |
| -------------------- | ------------------------------------------------------------- |
| `body`               | `message`, as written (Discord markdown)                      |
| `format`             | always `markdown`                                             |
| `type`               | `info`                                                        |
| `attachments`        | each `attachments[].url` as a URL attachment                      |
| `origin.service`     | `discord`                                                     |
| `origin.external_id` | `message_id` — also the idempotency key, so a redelivered event is posted once |
| `origin.author`      | `display_name`                                                |

Everything else in the event (`guild_id`, `channel_id`, `user_id`, `username`, `timestamp`) is dropped. The message is posted as you (the connector's member), attributed to the connector, with the Discord author shown as its origin.

## Setup

1. **Add WebhookBridge to your Discord server** with its invite link, then run `/dashboard` in the channel you want to bridge (free plan: 2 channels, 2,000 messages a month).
2. **Pick the connector the messages come in through.** In UnitySVC open Rooms → the room → Delivery. Add a connector for Discord (or use `main`) and choose **Discord to Messages** as its inbound service. The connector then shows its webhook URL: `https://api.svcpass.com/webhook/<KEY>/labs/discord-to-msg/<connector id>`.
3. **Give WebhookBridge that URL** as the channel's destination. It carries a key that may post into the room, so treat it as a secret; rotating the connector's key invalidates the old URL.
4. Post in the Discord channel; the message appears in the room, attributed to the Discord author.

Several Discord channels into several rooms: one connector per Discord channel, each with its own URL. Nothing else to configure — no secrets, no enrollment.

## How the URL works

WebhookBridge sends no headers, so the key rides in the URL: the platform's ingress turns `/webhook/<KEY>/labs/discord-to-msg/<connector id>` into an ordinary keyed request to `/labs/discord-to-msg/<connector id>`. A client that can set headers may call that path directly with `Authorization: Bearer <key>`; with no connector id the message lands in your own `me` room.

## Troubleshooting

- **Nothing arrives in the room** — check that WebhookBridge reports the delivery in its dashboard (Metrics), and that the destination is the connector's webhook URL from Delivery, not the room page.
- **401 from the service** — the URL is not a connector's webhook URL, or its key was rotated: copy the current URL from Delivery.
- **403 from the service** — the connector belongs to another account than the key's: copy the URL from the room's own Delivery page.
- **The same message twice** — only if the Discord message id changed; the room drops repeats of one id.
- **Images stop loading later** — the room keeps Discord's CDN URL rather than copying the file; the URL can expire at Discord.

## Two-way room connectors and echo refusal

The paired `labs/msg-to-discord` service formats room-delivery usernames as
`<author> - <room name> (<connector_id[:6]>)`, for example
`Bo Peng - Test Room (a1b2c3)`. WebhookBridge preserves this username in
`display_name`; this service maps it **unchanged** into `origin.author` for
`rooms://post`, together with `origin.service = discord` and the original
Discord `message_id` in `origin.external_id`. No new secret or enrollment
parameter is required. Neither `user_id` nor a human-readable connector name
is used to recognize the marker.

Echo refusal belongs to the backend, after authenticating the incoming post
and resolving the target room. The required backend contract is: check the
exact terminal ` (xxxxxx)` suffix (six lowercase hexadecimal characters)
against the first six hex characters of **any connector UUID in that room**,
not just the inbound connector. A matching connector-originated Discord post
is acknowledged with 2xx and discarded before normal room posting, attention,
or forwarding. Ordinary browser/SDK posts are unaffected. Similar readable
names without that marker must not be discarded. Six characters are a
loop-prevention convention, not authenticated identity; copying a matching
marker can cause a user's own message to be discarded.

This service intentionally performs no gateway-side filtering or name
rewriting. The backend check is a deployment prerequisite, and is not
implemented by this service spec or backend metadata PR #2944. Until that
check is deployed and verified, a marked post is still an ordinary room post.
Do not enable the paired plain-message rollout on production until the
backend check is in place and both same-connector and split-connector round
trips pass on staging. Keep legitimate human messages and URL images in that
verification. An intentionally relayed message into another room is not an
echo unless its marker matches a connector of that target room.
