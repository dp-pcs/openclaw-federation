#!/bin/bash
# OGP calendar-read handler for Gateway B (Apple Calendar)
# Usage: gwb-calendar-read.sh <start_date> <end_date> <duration_min>
# Returns: JSON with available slots

START_DT="${1:-2026-03-23T11:00:00-06:00}"
END_DT="${2:-2026-03-23T13:00:00-06:00}"
DURATION="${3:-30}"
TZ="${4:-America/Denver}"

# Get busy events from Apple Calendar
START_DATE=$(echo "$START_DT" | cut -c1-10)
END_DATE=$(echo "$END_DT" | cut -c1-10)
START_TIME=$(echo "$START_DT" | cut -c12-16)
END_TIME=$(echo "$END_DT" | cut -c12-16)

EVENTS=$(icalBuddy -f -ea -b "EVENT:" \
  eventsFrom:"$START_DATE $START_TIME" to:"$END_DATE $END_TIME" 2>/dev/null)

python3 << PYEOF
import json, re
from datetime import datetime, timedelta

start = datetime.fromisoformat('$START_DT')
end = datetime.fromisoformat('$END_DT')
duration = int('$DURATION')

# Parse busy periods from icalBuddy output
events_raw = """$EVENTS"""
busy_periods = []
for line in events_raw.split('\n'):
    # Match time patterns like "1:00 PM - 2:00 PM"
    m = re.search(r'(\d+:\d+ [AP]M) - (\d+:\d+ [AP]M)', line)
    if m:
        date_str = '$START_DATE'
        try:
            bs = datetime.strptime(f'{date_str} {m.group(1)}', '%Y-%m-%d %I:%M %p').replace(
                tzinfo=start.tzinfo)
            be = datetime.strptime(f'{date_str} {m.group(2)}', '%Y-%m-%d %I:%M %p').replace(
                tzinfo=start.tzinfo)
            busy_periods.append((bs, be))
        except: pass

# Find free slots
slots = []
current = start
while current + timedelta(minutes=duration) <= end:
    slot_end = current + timedelta(minutes=duration)
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
