# Discord to Messages — `discord-to-msg`

Bring the messages of a Discord channel into a UnitySVC room. The [WebhookBridge](https://webhook-bridge.whop.site) Discord bot forwards each new message in a channel to a URL; pointed at this service, the gateway converts the event into the platform `msg` envelope and posts it into your room through one of the room's connectors. This is the reverse of `msg-to-discord`, which sends room and notification messages out to Discord.

## What the room receives

| `msg` field          | Source in the Discord event                                   |
| -------------------- | ------------------------------------------------------------- |
| `body`               | `message`, as written (Discord markdown)                      |
| `format`             | always `markdown`                                             |
| `type`               | `info`                                                        |
| `attachments`        | each `attachments[].url` as a link entry                      |
| `origin.service`     | `discord`                                                     |
| `origin.external_id` | `message_id` — also the idempotency key, so a redelivered event is posted once |
| `origin.author`      | `display_name`                                                |

Everything else in the event (`guild_id`, `channel_id`, `user_id`, `username`, `timestamp`) is dropped.

## Setup

1. **Add WebhookBridge to your Discord server** with its invite link, then run `/dashboard` in the channel you want to bridge (free plan: 2 channels, 2,000 messages a month).
2. **Get a room connector URL.** In UnitySVC open Rooms → the room → Delivery. Each connector shows a webhook URL of the form `https://api.unitysvc.com/rooms/<key>/<room id>/<connector>`. It contains your room-webhook key: treat it as a secret.
3. **Store it as a customer secret** named `DISCORD_TO_MSG_ROOM_URL` (Settings → Secrets).
4. **Give WebhookBridge the service URL** — the canonical address of this service — as the channel's destination.
5. Post in the Discord channel; the message appears in the room, attributed to the Discord author.

## Channels

|             | `gateway` — stored connector (free)             | `gateway-plus` — per-enrollment connectors ($0.001/message)   |
| ----------- | ----------------------------------------------- | ------------------------------------------------------------- |
| Destination | the `DISCORD_TO_MSG_ROOM_URL` secret            | a secret named by the enrollment's `room_url_secret` parameter |
| Reached at  | the canonical service URL                       | a unique `/e/<code>` URL per enrollment                        |

Use `gateway-plus` to bridge several Discord channels into different rooms: one enrollment per Discord channel, each with its own connector URL secret and its own `/e/<code>` destination in WebhookBridge.

## Troubleshooting

- **Nothing arrives in the room** — check that WebhookBridge reports the delivery in its dashboard (Metrics), and that `DISCORD_TO_MSG_ROOM_URL` is the connector's webhook URL, not the room page.
- **401 from the service** — the destination URL must carry your UnitySVC API key; WebhookBridge sends no headers of its own.
- **The same message twice** — only if the Discord message id changed; the room drops repeats of one id.
- **Attachments show as links** — by design: the room keeps Discord's CDN URL rather than copying the file.
