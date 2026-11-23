"""Fetch public Roblox avatar models after verifying that Roblox created them."""

import base64
import concurrent.futures
import gzip
import json
import re
import sys
import urllib.request


def load(url):
    with urllib.request.urlopen(url, timeout=20) as response:
        payload = response.read()
    return gzip.decompress(payload) if payload.startswith(b"\x1f\x8b") else payload


def fetch(argument):
    asset_id, expected = map(int, argument.split(":"))
    metadata = json.loads(load(f"https://economy.roblox.com/v2/assets/{asset_id}/details"))
    if metadata["Creator"]["Id"] != 1 or metadata["AssetTypeId"] != expected:
        raise ValueError(f"{asset_id} is not the expected official Roblox item")
    model = load(f"https://assetdelivery.roblox.com/v1/asset/?id={asset_id}")
    if model.lstrip().startswith(b"<roblox"):
        model = re.sub(rb'<string name="MaterialVariant"[^>]*>.*?</string>', b'', model, flags=re.DOTALL)
    if expected == 18:
        # Classic faces carry a texture ID in their Decal. Keep the reference on Roblox.
        face = re.search(rb'<url>\s*(?:https?://[^<]*?[?&]id=|rbxassetid://)(\d+)\s*</url>', model)
        if not face or b'class="Decal"' not in model:
            raise ValueError(f"{asset_id} is missing its classic face decal")
        model = model[:face.start()] + b"<url>rbxassetid://" + face[1] + b"</url>" + model[face.end():]
    return str(asset_id), base64.b64encode(model).decode("ascii")


if __name__ == "__main__":
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        print(json.dumps(dict(pool.map(fetch, sys.argv[1:]))))
