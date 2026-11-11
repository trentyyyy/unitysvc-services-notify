# Telegram to Messages — `telegram-to-msg`

Bring Telegram messages into a UnitySVC room. Telegram sends every update your bot receives to one URL, its **webhook**; pointed at this service, the gateway converts each text message into the platform `msg` envelope and posts it into your room through the room connector named in the URL. This is the reverse of `msg-to-telegram`, which sends room and notification messages out through the same kind of bot.

You bring your own bot: one you create with @BotFather in a minute, or the one you already set up for `msg-to-telegram`. It sees messages in the groups you add it to and in private chats with it.

## What the room receives

| `msg` field          | Source in the Telegram update                                           |
| -------------------- | ----------------------------------------------------------------------- |
| `body`               | `message.text`                                                          |
| `format`             | always `text`                                                           |
| `type`               | `info`                                                                  |
| `origin.service`     | `telegram`                                                              |
| `origin.external_id` | `update_id`, also the idempotency key, so a redelivered update is posted once |
| `origin.author`      | `message.from.first_name`                                               |

Everything else in the update (`chat`, `message_id`, the last name and username, entities, reply context) is dropped. The message is posted as you (the connector's member) and shown in the room under the connector's name. The Telegram author is stored as `origin_author`, readable through the API and SDK; the room view does not show it. A message whose first line starts with `!` is taken as a private room command, not posted as chat.

These are answered `200` and posted nowhere, so Telegram does not keep retrying them:

- updates with no text: edited messages, members joining or leaving, photos, stickers and voice messages without text, polls, channel posts, the bot being added or removed;
- messages from other bots (Telegram rarely sends these to a bot anyway).

A photo's caption is not posted yet; only `message.text` is.

## Setup

1. **Pick the connector the messages come in through.** In UnitySVC open the room → **Configure** → **Notifications**. Under **Your notifications**, use a connector card (or **Add connector**). Set **Inbound** to **Through a converter service…** and type `labs/telegram-to-msg`. The card then shows its **Inbound URL**: `https://api.svcpass.com/webhook/<KEY>/labs/telegram-to-msg/<connector id>`.
2. **Get a bot token.** In Telegram, open **@BotFather**, send `/newbot`, and follow the prompts; it replies with a token like `123456789:AA…`. If you already use `msg-to-telegram`, reuse that bot and its `TELEGRAM_BOT_TOKEN`: then the room's messages go out and the group's messages come in through one bot.
3. **Point the bot's webhook at the connector.** Open this address in a browser, with your token and the Inbound URL filled in:

   ```
   https://api.telegram.org/bot<TOKEN>/setWebhook?url=<Inbound URL>
   ```

   Telegram answers `{"ok":true,"result":true,"description":"Webhook was set"}`. A bot has one webhook, so this replaces any earlier one.
4. **Let the bot see the group.** Add the bot to the group. By default a bot is in **privacy mode**: in a group it only receives commands, replies to its own messages, and messages that @mention it. To bridge every message, send `/setprivacy` to @BotFather, choose the bot, and select **Disable**, then remove the bot from the group and add it again (Telegram applies the change when the bot joins). Making the bot a group admin also lets it see every message. In a private chat with the bot, it sees everything.
5. **Talk.** Write in the group. The message appears in the room under the connector's name.
6. **Send the room back to the group (optional).** Store the bot's token as `TELEGRAM_BOT_TOKEN` and the group's chat id as `TELEGRAM_CHAT_ID`, and set the same connector's notify to `labs/msg-to-telegram`. A bot never receives its own messages, so what the room sends there does not come back.

One bot feeds one connector, since a bot has one webhook. Several groups with the same bot all reach that connector's room; to bring groups into different rooms, use one bot per room.

## How the URL works

Telegram can only be given a URL, so the key rides in it: the platform's ingress turns `/webhook/<KEY>/labs/telegram-to-msg/<connector id>` into an ordinary keyed request to `/labs/telegram-to-msg/<connector id>`. A client that can set headers may call that path directly with `Authorization: Bearer <key>`; with no connector id the message lands in your own `me` room. Treat the URL as a secret: it carries a key that may post into the room. A `secret_token` you pass to `setWebhook` is accepted but not checked; the key in the URL authenticates the sender.

## Troubleshooting

Check the webhook first: `https://api.telegram.org/bot<TOKEN>/getWebhookInfo` shows the URL Telegram calls, how many updates are waiting (`pending_update_count`) and the last error (`last_error_message`).

- **Nothing arrives from a group** — the bot is in privacy mode: disable it with `/setprivacy` and add the bot to the group again, or make it an admin. Commands and @mentions of the bot still come through in privacy mode.
- **`last_error_message` mentions 401** — the URL is not a connector's Inbound URL, or its key was replaced: copy the current URL from Configure → Notifications and run `setWebhook` again.
- **`last_error_message` mentions 404 or a wrong URL** — run `setWebhook` again with the Inbound URL copied whole.
- **A message shows up twice** — only if Telegram sent it as a new update; the room drops repeats of one `update_id`.
- **Messages stopped after you used another tool with the bot** — a bot has one webhook; another tool (or a `getUpdates` poller) may have replaced or removed it. Run `setWebhook` again.
