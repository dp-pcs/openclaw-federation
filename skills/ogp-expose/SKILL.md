---
name: "ogp-expose"
description: "Expose your local OpenClaw gateway publicly for OGP (Open Gateway Protocol) federation using cloudflared or ngrok tunnels. Handles tunnel setup, config updates, and sharing your federation URL with peers."
---

# OGP Expose — Public Gateway Tunneling

Use this skill when a user wants to expose their local OpenClaw gateway so others can federate with them over the internet.

## What this does

When you run OpenClaw locally (like `http://localhost:18789`), other people can't connect to it for federation because it's not accessible from the internet. This skill:

1. Creates a secure tunnel using `cloudflared` or `ngrok` to expose your gateway publicly
2. Updates your OpenClaw config with the public URL
3. Gives you a shareable federation card URL to send to peers

**No manual port forwarding or router configuration needed.**

---

## Commands

### `ogp-expose setup`

**Full guided setup flow:**

1. **Check for tunnel tools**
   ```bash
   which cloudflared || which ngrok
   ```

   - If neither is installed → offer to install `cloudflared` (preferred: free, no account needed)
   - Installation command: `brew install cloudflared` (macOS) or `brew install ngrok/ngrok/ngrok` (for ngrok)

2. **Determine gateway port**
   ```bash
   # Try reading from openclaw.json (if it exists)
   jq -r '.gateway.port // 18789' ~/.openclaw/openclaw.json 2>/dev/null || echo "18789"
   ```
   Default: `18789` if no config found

3. **Start the tunnel** (choose one):

   **Cloudflared (recommended):**
   ```bash
   cloudflared tunnel --url http://localhost:18789 > ~/.openclaw/ogp-expose.log 2>&1 &
   echo $! > ~/.openclaw/ogp-expose.pid
   ```

   **Ngrok (alternative):**
   ```bash
   ngrok http 18789 --log ~/.openclaw/ogp-expose.log > /dev/null 2>&1 &
   echo $! > ~/.openclaw/ogp-expose.pid
   ```

4. **Capture the public URL**

   Wait 2-3 seconds for tunnel to establish, then:

   **For cloudflared:**
   ```bash
   # Parse from log file (cloudflared prints to stderr)
   grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' ~/.openclaw/ogp-expose.log | head -1
   ```

   **For ngrok:**
   ```bash
   # Query ngrok's local API
   curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'
   ```

5. **Update OpenClaw config**
   ```bash
   # Create config if it doesn't exist
   mkdir -p ~/.openclaw
   echo '{}' > ~/.openclaw/openclaw.json 2>/dev/null || true

   # Update gateway.remote.url using jq
   PUBLIC_URL="https://xyz-abc-def.trycloudflare.com"  # captured from step 4
   jq --arg url "$PUBLIC_URL" '.gateway.remote.url = $url' ~/.openclaw/openclaw.json > /tmp/openclaw.json.tmp && mv /tmp/openclaw.json.tmp ~/.openclaw/openclaw.json
   ```

6. **Restart gateway** (if running)
   ```bash
   # Check if gateway is running
   pgrep -f "openclaw gateway" && echo "Gateway running - restart needed" || echo "Gateway not running"
   ```

   Ask user: "Your gateway is running. Would you like me to restart it to apply the new URL? [Yes/No]"

   If yes:
   ```bash
   pkill -f "openclaw gateway"
   openclaw gateway start &
   ```

7. **Print success message**
   ```
   ✓ Tunnel started and gateway configured!

   Your public gateway URL: https://xyz-abc-def.trycloudflare.com
   Your federation card: https://xyz-abc-def.trycloudflare.com/.well-known/ogp

   Share this command with peers who want to connect:
   openclaw federation request --gateway https://xyz-abc-def.trycloudflare.com

   To stop the tunnel: ogp-expose stop
   ```

---

### `ogp-expose status`

**Check if tunnel is running:**

```bash
# Check if PID file exists
if [ -f ~/.openclaw/ogp-expose.pid ]; then
  PID=$(cat ~/.openclaw/ogp-expose.pid)

  # Check if process is still running
  if ps -p $PID > /dev/null 2>&1; then
    echo "Tunnel running (PID: $PID)"

    # Try to extract public URL
    if [ -f ~/.openclaw/ogp-expose.log ]; then
      PUBLIC_URL=$(grep -oE 'https://[a-z0-9-]+\.(trycloudflare\.com|ngrok-free\.app)' ~/.openclaw/ogp-expose.log | head -1)
      echo "Public URL: $PUBLIC_URL"
    fi
  else
    echo "Tunnel not running (stale PID file)"
  fi
else
  echo "No tunnel running"
fi
```

---

### `ogp-expose stop`

**Stop the tunnel and optionally clean up config:**

1. **Kill tunnel process**
   ```bash
   if [ -f ~/.openclaw/ogp-expose.pid ]; then
     PID=$(cat ~/.openclaw/ogp-expose.pid)
     kill $PID 2>/dev/null || echo "Process already stopped"
     rm ~/.openclaw/ogp-expose.pid
     echo "Tunnel stopped"
   else
     echo "No tunnel running"
   fi
   ```

2. **Ask user about config cleanup**
   ```
   Remove gateway.remote.url from config? [Yes/No]
   ```

   If yes:
   ```bash
   jq 'del(.gateway.remote.url)' ~/.openclaw/openclaw.json > /tmp/openclaw.json.tmp && mv /tmp/openclaw.json.tmp ~/.openclaw/openclaw.json
   echo "Config cleaned up"
   ```

3. **Optionally remove log file**
   ```bash
   rm ~/.openclaw/ogp-expose.log
   ```

---

## Troubleshooting

### "Port already in use"

**Symptom:** Tunnel fails to start with error about port 18789 being in use.

**Solution:** Your OpenClaw gateway might not be running. Start it first:
```bash
openclaw gateway start
```

Then retry `ogp-expose setup`.

---

### "Tunnel URL not appearing"

**Symptom:** Step 4 (capturing public URL) returns empty or fails.

**Possible causes:**
- Tunnel still starting up (wait 5 seconds and retry)
- Log file permissions issue
- Network connectivity problem

**Debug steps:**
```bash
# Check if tunnel process is running
ps aux | grep -E 'cloudflared|ngrok'

# Check log file
tail -20 ~/.openclaw/ogp-expose.log

# For cloudflared, look for "Your quick Tunnel has been created!" message
# For ngrok, look for "started tunnel" and URL
```

---

### "Config update failed"

**Symptom:** `jq` command fails or config looks malformed.

**Solution:** Ensure `jq` is installed:
```bash
brew install jq  # macOS
```

If `openclaw.json` is corrupted, back it up and create fresh:
```bash
mv ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup
echo '{"gateway": {"port": 18789}}' > ~/.openclaw/openclaw.json
```

---

### "Federation card not accessible"

**Symptom:** Visiting `https://<tunnel-url>/.well-known/ogp` returns 404 or error.

**Possible causes:**
- Gateway not running
- Gateway not configured to serve federation endpoint
- Tunnel pointing to wrong port

**Debug steps:**
```bash
# Test locally first
curl http://localhost:18789/.well-known/ogp

# If local works but public doesn't, check tunnel port
ps aux | grep -E 'cloudflared|ngrok' | grep 18789
```

---

## Security Notes

- **Tunnel URLs are public:** Anyone with your tunnel URL can attempt to send federation requests. Use OpenClaw's built-in approval flow to control who can federate.
- **Free cloudflared URLs expire:** Cloudflare's quick tunnels (*.trycloudflare.com) expire after inactivity. For permanent tunnels, set up a named cloudflared tunnel with a custom domain.
- **Ngrok free tier limitations:** Ngrok free tier has session limits and different URL each time. Consider upgrading for stable URLs.
- **Don't commit tunnel URLs:** Never commit your `openclaw.json` with a tunnel URL to version control — it's ephemeral.

---

## Files Created/Modified

- `~/.openclaw/ogp-expose.pid` — Process ID of running tunnel
- `~/.openclaw/ogp-expose.log` — Tunnel output for URL capture
- `~/.openclaw/openclaw.json` — Updated with `gateway.remote.url`

---

## Implementation Notes for Agents

### When to use this skill

Trigger this skill when:
- User says "expose my gateway", "make my gateway public", "share my gateway"
- User wants to "federate with someone" and their gateway is on localhost
- User asks "how do I let others connect to my gateway"

### Language to use

Keep it **simple and clear**:
- ✅ "I'll set up a secure tunnel so others can connect to your gateway"
- ✅ "This creates a public URL — no router configuration needed"
- ❌ "Implementing NAT traversal via cloudflared ingress controller"
- ❌ "Establishing reverse proxy tunnel with TLS termination"

### What users don't need to know

- Don't explain what cloudflared is unless asked
- Don't mention "reverse proxy" or "NAT traversal" terminology
- Don't explain Ed25519 keypairs or OGP internals
- Focus on: "here's your URL, share this command with peers"

### Error handling

If any step fails:
1. Show exactly which command failed
2. Check the log file and show relevant errors
3. Suggest the troubleshooting section
4. Don't try to fix issues beyond this skill's scope (e.g., network configuration)

---

## Example Session

```
User: I want to expose my gateway so my friend can federate with me

Agent: I'll set up a secure tunnel so your friend can connect to your OpenClaw gateway.

[Checks for cloudflared]
Found cloudflared installed.

[Reads gateway port from config]
Gateway port: 18789

[Starts tunnel]
Starting cloudflared tunnel...
✓ Tunnel established

[Captures public URL]
Public URL: https://abc-def-ghi.trycloudflare.com

[Updates config]
✓ Updated ~/.openclaw/openclaw.json with gateway.remote.url

[Checks gateway status]
Gateway is running. Restarting to apply new URL...
✓ Gateway restarted

---

✓ Your gateway is now publicly accessible!

Federation card: https://abc-def-ghi.trycloudflare.com/.well-known/ogp

Share this command with your friend:
openclaw federation request --gateway https://abc-def-ghi.trycloudflare.com

The tunnel will stay active until you run: ogp-expose stop
```
