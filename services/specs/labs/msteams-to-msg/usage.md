# Microsoft Teams to Messages — `msteams-to-msg`

Bring Microsoft Teams messages into a UnitySVC room. A Teams **outgoing webhook**, which a team owner creates in a few clicks, sends a message to a URL each time someone @mentions it in a channel; pointed at this service, the gateway converts the message into the platform `msg` envelope and posts it into your room through the room connector named in the URL. This is the reverse of `msg-to-msteams`, which sends room and notification messages out to a Teams channel.

An outgoing webhook sees only messages that @mention it, and only in standard **public channels** of the team it was created in: not private or shared channels, group chats or 1:1 chats. A member chooses what goes to the room by writing, for example, “@UnitySVC hello”.

## What the room receives

| `msg` field          | Source in the Teams activity                                                       |
| -------------------- | ---------------------------------------------------------------------------------- |
| `body`               | `text`, with the webhook's own @mention removed and the HTML converted to plain text |
| `format`             | always `text`                                                                      |
| `type`               | `info`                                                                             |
| `origin.service`     | `msteams`                                                                          |
| `origin.external_id` | `id`, the Teams activity id, also the idempotency key, so a redelivered message is posted once |
| `origin.author`      | `from.name`, the Teams user's display name                                         |

Everything else in the activity (`conversation`, `channelData`, `attachments`, `entities`, …) is dropped; pictures and files in the Teams message do not come across. Other people @mentioned after the webhook's mention stay as their names. The message is posted as you (the connector's member) and shown in the room under the connector's name. The Teams author is stored as `origin_author`, readable through the API and SDK; the room view does not show it. A message whose first line starts with `!` is taken as a private room command, not posted as chat.

Teams shows the service's answer as a reply in the message's thread: **“Sent to the room.”** when the message was posted. When the room refuses it (for example a message that is only the @mention, with nothing after it), Teams shows that the webhook did not respond properly instead.

## Setup

You need to be an owner of the team.

1. **Pick the connector the messages come in through.** In UnitySVC open the room → **Configure** → **Notifications**. Under **Your notifications**, use a connector card (or **Add connector**). Set **Inbound** to **Through a converter service…** and type `labs/msteams-to-msg`. The card then shows its **Inbound URL**: `https://api.svcpass.com/webhook/<KEY>/labs/msteams-to-msg/<connector id>`.
2. **Create the outgoing webhook.** In Teams, open the team → **•••** → **Manage team** → **Apps** → **Create an outgoing webhook** (at the bottom right). Give it a **Name**, the name people will @mention (for example `UnitySVC`), paste the connector's Inbound URL as the **Callback URL**, add a description and optionally a picture, and select **Create**. Teams then shows a security token for signing its requests. This service does not check the signature (see below), so you need not store the token.
3. **Talk to it.** In any public channel of the team, write a message that starts with the @mention, for example “@UnitySVC hello”. The service removes the first @mention in the message, taking it to be the webhook's; in “@Bob have a look @UnitySVC” it would remove Bob's instead, and the room would get “have a look UnitySVC”. The message appears in the room under the connector's name, and Teams replies “Sent to the room.” in its thread.
4. **Send the room back to the channel (optional).** In the channel, choose **•••** → **Workflows** and add the **Send webhook alerts to a channel** workflow, store the webhook URL Teams shows, whole, as `MSTEAMS_WEBHOOK_URL`, and set the same connector's notify to `labs/msg-to-msteams`. Messages the room sends there do not come back: Teams never passes other apps' posts to an outgoing webhook.

Several teams into several rooms: one connector and one outgoing webhook per team, since an outgoing webhook belongs to the team it was created in. All the public channels of one team reach the same connector.

## How the URL works

Teams signs each request with an HMAC of the body in the `Authorization` header, so the key rides in the URL: the platform's ingress replaces that header and turns `/webhook/<KEY>/labs/msteams-to-msg/<connector id>` into an ordinary keyed request to `/labs/msteams-to-msg/<connector id>`. The HMAC is therefore not checked; the key in the URL authenticates the sender. A client that can set headers may call that path directly with `Authorization: Bearer <key>`; with no connector id the message lands in your own `me` room. Treat the URL as a secret: it carries a key that may post into the room.

## Troubleshooting

- **Nothing happens when you write in the channel** — the message must @mention the webhook (pick it from the @ list so Teams makes it a mention, not plain text), and the channel must be a standard public channel of the team the webhook was created in.
- **Teams says the webhook did not respond, or shows an error** — check the callback URL is the connector's Inbound URL from Configure → Notifications, copied whole. A message that is only the @mention has nothing to post and gets this too.
- **401 from the service** — the URL is not a connector's Inbound URL, or its key was replaced: copy the current URL from Configure → Notifications, then remove the outgoing webhook and create it again with that URL (Manage team → Apps).
- **The same message twice** — only if Teams gave it a new activity id; the room drops repeats of one id.
