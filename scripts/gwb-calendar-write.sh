#!/bin/bash
# OGP calendar-write handler for Gateway B (Apple Calendar via AppleScript)
# Usage: gwb-calendar-write.sh <start_iso> <end_iso> <title> <attendee_email> <attendee_name>
# Returns: JSON with event status

START="${1:-2026-03-23T11:00:00-06:00}"
END="${2:-2026-03-23T11:30:00-06:00}"
TITLE="${3:-Meeting}"
ATTENDEE_EMAIL="${4:-}"
ATTENDEE_NAME="${5:-Guest}"

# Parse date components from ISO8601
YEAR=$(echo "$START" | cut -c1-4)
MONTH=$(echo "$START" | cut -c6-7 | sed 's/^0//')
DAY=$(echo "$START" | cut -c9-10 | sed 's/^0//')
HOUR=$(echo "$START" | cut -c12-13 | sed 's/^0//')
MIN=$(echo "$START" | cut -c15-16 | sed 's/^0//')

END_HOUR=$(echo "$END" | cut -c12-13 | sed 's/^0//')
END_MIN=$(echo "$END" | cut -c15-16 | sed 's/^0//')

# Build AppleScript
if [ -n "$ATTENDEE_EMAIL" ]; then
    ATTENDEE_SCRIPT="
    tell newEvent
        make new attendee at end of attendees with properties {email:\"$ATTENDEE_EMAIL\", display name:\"$ATTENDEE_NAME\"}
    end tell"
else
    ATTENDEE_SCRIPT=""
fi

RESULT=$(osascript << OSASCRIPT
tell application "Calendar"
    set targetCal to first calendar whose name is "Calendar"
    
    set startDate to current date
    set year of startDate to $YEAR
    set month of startDate to $MONTH
    set day of startDate to $DAY
    set hours of startDate to $HOUR
    set minutes of startDate to $MIN
    set seconds of startDate to 0
    
    set endDate to current date
    set year of endDate to $YEAR
    set month of endDate to $MONTH
    set day of endDate to $DAY
    set hours of endDate to $END_HOUR
    set minutes of endDate to $END_MIN
    set seconds of endDate to 0
    
    set newEvent to make new event at end of events of targetCal with properties {summary:"$TITLE", start date:startDate, end date:endDate, description:"Scheduled via OGP - Open Gateway Protocol"}
    $ATTENDEE_SCRIPT
    
    return "ok"
end tell
OSASCRIPT
)

if [ "$RESULT" = "ok" ]; then
    python3 -c "
import json
print(json.dumps({
    'status': 'created',
    'title': '$TITLE',
    'start': '$START',
    'end': '$END',
    'attendee': '$ATTENDEE_EMAIL',
    'calendar': 'Calendar (Apple)',
    'note': 'Calendar invite sent to $ATTENDEE_EMAIL'
}))
"
else
    python3 -c "
import json
print(json.dumps({
    'status': 'error',
    'error': '$RESULT'
}))
"
fi
