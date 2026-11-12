# Slack to Messages — `slack-to-msg`

Bring the messages of a Slack channel into a UnitySVC room. Slack's **Outgoing WebHooks** integration sends each new message in a channel to a URL; pointed at this service, the gateway converts the message into the platform `msg` envelope and posts it into your room through the room connector named in the URL. This is the reverse of `msg-to-slack`, which sends room and notification messages out to a Slack channel.

Outgoing WebHooks is a legacy Slack integration. It works in **public channels** only, sends about one message a second, and is unavailable in workspaces whose admins block legacy custom integrations. Slack has announced no end date for it but may remove it.

## What the room receives

| `msg` field          | Source in the Slack form                                                          |
| -------------------- | --------------------------------------------------------------------------------- |
| `body`               | `text`, as written (Slack mrkdwn)                                                 |
| `format`             | always `markdown`                                                                 |
| `type`               | `info`                                                                            |
| `origin.service`     | `slack`                                                                           |
| `origin.external_id` | `timestamp`, also the idempotency key, so a redelivered message is posted once    |
| `origin.author`      | `user_name`, the Slack user's name                                                |

Everything else in the form (`team_id`, `team_domain`, `channel_id`, `channel_name`, `user_id`, `trigger_word`) is dropped; files in the Slack message do not come across. Slack writes links as `<https://example.com|label>` and mentions as `<@U123>`, and they arrive in that form. The message is posted as you (the connector's member) and shown in the room under the connector's name. The Slack author is stored as `origin_author`, readable through the API and SDK; the room view does not show it. A message whose first line starts with `!` is taken as a private room command, not posted as chat.

The service answers Slack with an empty `200`, so it never posts a reply into the channel.

## Setup

1. **Pick the connector the messages come in through.** In UnitySVC open the room → **Configure** → **Notifications**. Under **Your notifications**, use a connector card (or **Add connector**). Set **Inbound** to **Through a converter service…** and type `labs/slack-to-msg`. The card then shows its **Inbound URL**: `https://api.svcpass.com/webhook/<KEY>/labs/slack-to-msg/<connector id>`.
2. **Add the integration in Slack.** Open **Apps**, search for **Outgoing WebHooks**, and choose **Add to Slack** → **Add Outgoing WebHooks integration**. Under **Integration Settings** pick the **Channel** to bridge (or leave it on any channel and set **Trigger Word(s)**), and paste the connector's Inbound URL into **URL(s)**.
3. **Store the token.** The same page shows a **Token**. Save it in UnitySVC as the customer secret `SLACK_OUTGOING_TOKEN`, then select **Save Settings** in Slack. Without the secret the service refuses every post.
4. **Talk.** Write in the Slack channel. The message appears in the room under the connector's name.
5. **Send the room back to the channel (optional).** Create a Slack incoming webhook for the same channel, store its three path segments as `SLACK_TOKEN_A`, `SLACK_TOKEN_B` and `SLACK_TOKEN_C`, and set the same connector's notify to `labs/msg-to-slack`.

### Several Slack channels or workspaces

Each Outgoing WebHooks integration has its own token, and the free channel checks one: `SLACK_OUTGOING_TOKEN`. For a second Slack channel or workspace, store its token in a secret of your own naming, enroll in this service's **gateway-plus** channel ($0.001 / message) and set its `token_secret` parameter to that secret's name. Choose the enrollment as the connector's inbound service; its Inbound URL then reads `https://api.svcpass.com/webhook/<KEY>/e/<CODE>/<connector id>`.

## What is refused or dropped

- **A wrong or missing token** is answered `401` (header `X-UnitySVC-Rule: bad-token`) and nothing is posted. The URL's key already limits who can post; the token also proves the post came from your Slack integration.
- **A post from `slackbot` or one carrying a `bot_id`** is answered `204` (header `X-UnitySVC-Rule: own-echo`) and nothing is posted. This keeps what the room sends to the channel through `msg-to-slack` from coming back as new messages. Other bots' posts in the channel are dropped the same way.

Both answers are free of charge.

## How the URL works

Slack can only be given a URL, so the key rides in it: the platform's ingress turns `/webhook/<KEY>/labs/slack-to-msg/<connector id>` into an ordinary keyed request to `/labs/slack-to-msg/<connector id>`. A client that can set headers may call that path directly with `Authorization: Bearer <key>` and a form body; with no connector id the message lands in your own `me` room. Treat the URL as a secret: it carries a key that may post into the room.

## Troubleshooting

- **Nothing arrives in the room** — the channel must be public and be the one picked in the integration, or the message must start with one of its trigger words. Check that the URL in the integration is the connector's Inbound URL, copied whole.
- **401 with `X-UnitySVC-Rule: bad-token`** — `SLACK_OUTGOING_TOKEN` differs from the integration's token. Slack makes a new token when you regenerate it or add the integration again: copy the current one into the secret.
- **401 without that header** — the URL is not a connector's Inbound URL, or its key was replaced: copy the current URL from Configure → Notifications into the integration.
- **The service refuses every post and no token was stored** — set the `SLACK_OUTGOING_TOKEN` secret (Setup step 3).
- **Outgoing WebHooks is missing from Apps** — your workspace blocks legacy custom integrations; ask a workspace admin.
- **The same message twice** — only if Slack sent it with a new timestamp; the room drops repeats of one timestamp.
