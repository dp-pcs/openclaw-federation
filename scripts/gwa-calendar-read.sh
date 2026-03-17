#!/bin/bash
# OGP calendar-read handler for Gateway A (Google Calendar)
# Usage: gwa-calendar-read.sh <start_iso> <end_iso> <duration_min> <window_start> <window_end> <tz>
# Returns: JSON with available slots

START="${1:-2026-03-23T09:00:00-06:00}"
END="${2:-2026-03-23T11:30:00-06:00}"
DURATION="${3:-30}"
WIN_START="${4:-09:00}"
WIN_END="${5:-11:30}"
TZ="${6:-America/Denver}"

GWS="$HOME/.nvm/versions/node/v22.22.0/bin/gws"

# Get busy periods from Google Calendar
BUSY=$($GWS calendar freeBusy query \
  --json "{\"timeMin\":\"$START\",\"timeMax\":\"$END\",\"items\":[{\"id\":\"primary\"}]}" \
  2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
busy = d.get('calendars',{}).get('primary',{}).get('busy',[])
print(json.dumps(busy))
" 2>/dev/null)

# Generate available slots
python3 << PYEOF
import json
from datetime import datetime, timedelta
import sys

start = datetime.fromisoformat('$START')
end = datetime.fromisoformat('$END')
duration = int('$DURATION')
busy = json.loads('''$BUSY''' if '''$BUSY''' else '[]')

# Parse busy periods
busy_periods = []
for b in busy:
    bs = datetime.fromisoformat(b['start'].replace('Z','+00:00'))
    be = datetime.fromisoformat(b['end'].replace('Z','+00:00'))
    busy_periods.append((bs, be))

# Find free slots
slots = []
current = start
while current + timedelta(minutes=duration) <= end:
    slot_end = current + timedelta(minutes=duration)
    # Check not busy
    is_busy = any(bs < slot_end and be > current for bs, be in busy_periods)
    if not is_busy:
        slots.append({
            'start': current.isoformat(),
            'end': slot_end.isoformat(),
            'duration': duration
        })
    current += timedelta(minutes=30)

print(json.dumps({'available': slots, 'timezone': '$TZ', 'count': len(slots)}))
PYEOF
