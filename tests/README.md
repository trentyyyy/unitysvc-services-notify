# Discord inbound regression checks

With Docker installed, run:

```sh
GATEWAY_SRC=/absolute/path/to/apisix-gateways/src bash tests/run_discord_inbound_marker.sh
```

Use a gateway checkout containing #91/#95. The checks exercise the actual
service field mapping through the APISIX msg normalizer: marked display names
arrive unchanged in `origin.author`, normal/similar names are also preserved,
Discord message IDs remain available for idempotency, and image URLs survive.
No real messages are sent. Backend marker detection is a separate dependency;
this test does not claim that a matching incoming post is discarded.
