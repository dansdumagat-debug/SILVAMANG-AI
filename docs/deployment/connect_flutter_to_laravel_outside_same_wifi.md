# Connect Flutter to Laravel Outside Same Wi-Fi

Use this when your Android phone cannot reach your laptop through the same local Wi-Fi. The public tunnel should expose Laravel only. Flutter should not connect directly to Python.

## Option 1 - ngrok

1. Start Laragon/MySQL.
2. Start Python AI service.
3. Start Laravel locally on `127.0.0.1:8000`.
4. Open a new terminal:

```powershell
ngrok http 8000
```

5. Copy the HTTPS forwarding URL.
6. Set Flutter API URL:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\set_flutter_api_url_custom.ps1
```

7. Enter:

```text
https://YOUR-NGROK-URL/api
```

8. Run Flutter on the Android phone.

## Option 2 - Cloudflare Tunnel

1. Start Laravel locally.
2. Run:

```powershell
cloudflared tunnel --url http://localhost:8000
```

3. Copy the HTTPS `trycloudflare.com` URL.
4. Set Flutter API URL to:

```text
https://YOUR-CLOUDFLARE-URL/api
```

## Important

- Flutter should connect to Laravel only.
- Flutter should not connect directly to Python.
- Laravel `.env` should keep:

```env
AI_SERVICE_URL=http://127.0.0.1:9000
```

- Do not use `127.0.0.1` in Flutter when testing on a physical phone unless the backend is running on the phone.
- Do not test offline ONNX on Chrome/Web.
