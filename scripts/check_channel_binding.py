#!/usr/bin/env python3
"""Render every service and check how its upstream channels bind (issue #52).

The catalog's "Directly Usable" badge comes from each channel's derived type
(unitysvc ``app/core/channel_classification.py``): a channel is ``unbound``
unless it references ``{{ params.* }}`` / ``{{ enrollment.* }}`` or a
``${ customer_secrets.X }`` the customer must supply (no default, or an empty
``??``; ``_``-prefixed seller-only names don't count). A defaulted host or a
literal demo credential silently makes a channel look directly usable, so this
check fails when:

1. a channel renders ``unbound`` but is not in ``ALLOWED_UNBOUND``;
2. a secret whose name comes from an enrollment parameter carries a default —
   ``${ customer_secrets.{{ params.X }} ?? … }`` makes a missing secret look
   present;
3. an ``Authorization`` header is a literal instead of a secret reference;
4. a ``${ customer_secrets.X }`` name is missing from ``seller.secrets.txt``;
5. a channel declares required enrollment parameters (``params.schema``,
   unitysvc/unitysvc#2726) but is not ``enrollable``, so the enrollment lands
   on a channel that never reads them;
6. a channel's required enrollment parameter is not read by that channel;
7. an ``enrollable`` channel reads a customer secret by its fixed name (one the
   customer must supply, not ``_``-prefixed or defaulted): it then reaches the
   free channel's destination instead of the enrollment's own.

Run from the repo root:  uv run --with unitysvc-sellers scripts/check_channel_binding.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from unitysvc_sellers.params_render import materialized_param_specs

SERVICES = Path(__file__).resolve().parent.parent / "services"

# Channels that are genuinely usable with no customer setup: the customer's
# own credential travels in the native payload they POST, and the default host
# is the provider's real public API.
ALLOWED_UNBOUND = {
    f"{svc}@{ch}"
    for svc in (
        "freemobile-relay",
        "misskey-relay",
        "pushplus-relay",
        "streamlabs-relay",
        "vonage-sms-relay",
        "prowl-relay",
        "pushsafer-relay",
    )
    for ch in ("byok", "plus")
}

REF = re.compile(
    r"\$\{\s*customer_secrets\.(\{\{[^}]*\}\}|[A-Za-z0-9_]+)\s*(\?\?\s*([^}]*?))?\s*\}"
)
ENROLLMENT = re.compile(r"\{\{\s*(params|enrollment)\.")
PARAM = re.compile(r"\{\{\s*params\.([A-Za-z0-9_]+)")


def fixed_secrets(cfg: dict) -> list[str]:
    """Customer secrets the channel reads by a fixed name the customer must supply."""
    names = []
    for m in REF.finditer(json.dumps(cfg)):
        name, has_default, default = m.group(1), m.group(2), (m.group(3) or "").strip()
        if name.startswith(("{{", "_")) or (has_default and default):
            continue
        names.append(name)
    return sorted(set(names))


def required_params(cfg: dict) -> list[str]:
    """Required enrollment parameters the channel declares in ``params.schema``."""
    schema = (cfg.get("params") or {}).get("schema") or {}
    return sorted(schema.get("required") or [])


def channel_body(cfg: dict) -> dict:
    """The channel config the gateway renders; its ``params`` declaration reads nothing."""
    return {k: v for k, v in cfg.items() if k != "params"}


def channel_type(cfg: dict) -> str:
    text = json.dumps(cfg)
    if ENROLLMENT.search(text):
        return "enrollable"
    for m in REF.finditer(text):
        name, has_default, default = m.group(1), m.group(2), (m.group(3) or "").strip()
        if (not has_default or not default) and not name.startswith("_"):
            return "secret_bound"
    return "unbound"


def auth_headers(cfg: dict) -> list[str]:
    raw = cfg.get("raw", {}).get("request_transformer", {})
    headers = raw.get("proxy_rewrite", {}).get("headers", {}).get("set", {})
    return [v for k, v in headers.items() if k.lower() == "authorization"]


def main() -> int:
    manifest = set(
        re.findall(r"^export ([A-Za-z0-9_]+)=", (SERVICES / "seller.secrets.txt").read_text(), re.M)
    )
    errors: list[str] = []
    seen_unbound: set[str] = set()
    with materialized_param_specs(SERVICES) as _:
        for offering_path in sorted(Path("specs").glob("*/*/offering.json")):
            svc = offering_path.parent.name
            offering = json.loads(offering_path.read_text())
            if offering.get("status") == "deprecated":
                continue  # no longer offered, so never shown as Directly Usable
            active = {
                ch: cfg
                for ch, cfg in offering.get("upstream_access_config", {}).items()
                if cfg.get("is_active") is not False
            }
            channels = {ch: channel_body(cfg) for ch, cfg in active.items()}
            enrollable = {ch: cfg for ch, cfg in channels.items() if channel_type(cfg) == "enrollable"}
            for ch, cfg in active.items():
                required = required_params(cfg)
                if required and ch not in enrollable:
                    errors.append(
                        f"{svc}@{ch}: declares required enrollment parameters {required} "
                        "but reads none of them, so the enrollment lands on a channel that ignores them"
                    )
                    continue
                used = set(PARAM.findall(json.dumps(channels[ch])))
                for param in sorted(set(required) - used):
                    errors.append(f"{svc}@{ch}: required parameter {param} is not read by the channel")
            for ch, cfg in enrollable.items():
                for name in fixed_secrets(cfg):
                    errors.append(
                        f"{svc}@{ch}: enrollable channel reads customer secret {name} by its fixed name, "
                        "so it reaches the free channel's destination"
                    )
            for ch, cfg in channels.items():
                key = f"{svc}@{ch}"
                if channel_type(cfg) == "unbound":
                    seen_unbound.add(key)
                    if key not in ALLOWED_UNBOUND:
                        errors.append(f"{key}: unbound (shown as Directly Usable) but needs customer setup?")
                for m in REF.finditer(json.dumps(cfg)):
                    name, has_default = m.group(1), m.group(2)
                    if name.startswith("{{") and has_default:
                        errors.append(f"{key}: {m.group(0)} — a param-named secret must not have a default")
                    if not name.startswith("{{") and not name.startswith("__") and name not in manifest:
                        errors.append(f"{key}: customer secret {name} missing from seller.secrets.txt")
                for value in auth_headers(cfg):
                    if "${" not in value:
                        errors.append(f"{key}: literal Authorization header {value!r}")
    for stale in sorted(ALLOWED_UNBOUND - seen_unbound):
        errors.append(f"{stale}: in ALLOWED_UNBOUND but no longer unbound — drop it from the list")
    for e in errors:
        print(f"::error::{e}")
    print(f"checked channel binding: {len(errors)} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
