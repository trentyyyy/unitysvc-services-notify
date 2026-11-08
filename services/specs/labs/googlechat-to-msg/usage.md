# Google Chat to Messages — `googlechat-to-msg`

Bring Google Chat messages into a UnitySVC room. A Google Chat app that you create in your own Google Cloud project sends an event to a URL each time someone messages it; pointed at this service, the gateway converts the event into the platform `msg` envelope and posts it into your room through the room connector named in the URL. This is the reverse of `msg-to-googlechat`, which sends room and notification messages out to a Google Chat space.

A Chat app sees only messages addressed to it: direct messages to the app, and messages in a space that @mention it. To bridge a space both ways, add the app to the space and @mention it to send into the room; room messages come back through `msg-to-googlechat` on the same connector.

## What the room receives

| `msg` field          | Source in the Google Chat event                                        |
| -------------------- | ---------------------------------------------------------------------- |
| `body`               | `message.argumentText`: the text with the app's @mention removed      |
| `format`             | always `text`                                                          |
| `type`               | `info`                                                                 |
| `origin.service`     | `googlechat`                                                           |
| `origin.external_id` | `message.name` (`spaces/…/messages/…`), also the idempotency key, so a redelivered event is posted once |
| `origin.author`      | `message.sender.displayName`                                           |

Everything else in the event (`space`, `user`, `eventTime`, `message.text`, annotations, attachments) is dropped. The message is posted as you (the connector's member), attributed to the connector, with the Google Chat author shown as its origin. Events that carry no message, such as the app being added to a space, post nothing.

## Setup

You need a Google Workspace account (Business or Enterprise) whose admin allows users to install Chat apps.

1. **Pick the connector the messages come in through.** In UnitySVC open Rooms → the room → Delivery. Add a connector for Google Chat (or use `main`) and choose **Google Chat to Messages** as its inbound service. The connector then shows its webhook URL: `https://api.svcpass.com/webhook/<KEY>/labs/googlechat-to-msg/<connector id>`.
2. **Create the Chat app.** In the Google Cloud console, create or pick a project and enable the **Google Chat API**. Open Google Chat API → **Configuration**: give the app a name, avatar URL and description; under Interactive features turn on **Join spaces and group conversations**; under Connection settings choose **HTTP endpoint URL** and paste the connector's webhook URL; under Visibility add yourself (or your domain). Save.
3. **Talk to it.** In Google Chat, open a direct message with the app, or add it to a space and @mention it. The message appears in the room, attributed to the Google Chat author.
4. **Send the room back to the space (optional).** Create an incoming webhook in the space, store its URL as `GOOGLECHAT_WEBHOOK_URL`, and set the same connector's notify to `labs/msg-to-googlechat`.

Several spaces into several rooms: one connector per space, each with its own URL, all pointing at one Chat app or one app each.

## How the URL works

Google Chat sends its own token in the `Authorization` header, so the key rides in the URL: the platform's ingress replaces that header and turns `/webhook/<KEY>/labs/googlechat-to-msg/<connector id>` into an ordinary keyed request to `/labs/googlechat-to-msg/<connector id>`. A client that can set headers may call that path directly with `Authorization: Bearer <key>`; with no connector id the message lands in your own `me` room. Treat the URL as a secret: it carries a key that may post into the room.

## Troubleshooting

- **The app says it is not responding** — check the HTTP endpoint URL is the connector's webhook URL from Delivery, copied whole.
- **Nothing arrives in the room** — in a space the app only receives messages that @mention it; a plain message in the space is not sent to the app.
- **401 from the service** — the URL is not a connector's webhook URL, or its key was replaced: copy the current URL from Delivery.
- **The same message twice** — only if Google gave it a new message name; the room drops repeats of one name.
