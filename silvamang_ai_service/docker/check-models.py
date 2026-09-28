"""Release gate: liveness alone does not prove models are ready."""
import json
import urllib.request

with urllib.request.urlopen('http://127.0.0.1:9000/ai/health', timeout=300) as response:
    status = json.load(response)
print(json.dumps(status, indent=2))
raise SystemExit(0 if status.get('ready') else 1)
