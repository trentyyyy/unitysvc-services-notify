# Discord service regression checks

With Docker and `usvc_seller` installed, run from this checkout:

```sh
GATEWAY_SRC=/absolute/path/to/apisix-gateways/src bash tests/run_discord_marker.sh
```

The test expands the real service and runs both channel mappings and the Lua
body template in the APISIX runtime. It covers protected markers, Unicode
length, reserved words, missing/invalid metadata, private-field removal,
disabled mention parsing, and text/image/image-only messages. It makes no
network calls or deliveries. Use gateway code containing #91 (and preferably
#95); it exercises the normalizer's exported UTF-8 truncation helper.

`discord-body.lua` is the readable runtime template. Its base64 companion is
embedded in the offering with `template_is_base64`: this avoids interpreting
Lua's `{% ... %}` delimiters as backend Jinja. After editing the source, run:

```sh
python3 - <<'PY'
import base64
from pathlib import Path
root = Path('services/templates/msg-to-discord')
(root / 'discord-body.base64').write_text(
    base64.b64encode((root / 'discord-body.lua').read_bytes()).decode() + '\n'
)
PY
```

The runner checks that the encoded template matches the readable source.
Backend echo refusal and real Discord round trips are separate deployment
checks, not claimed by these transformation tests.
