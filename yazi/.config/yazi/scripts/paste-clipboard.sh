#!/bin/bash
# Paste files from the macOS system pasteboard (e.g. copied from Finder)
# into the directory passed as $1 (defaults to $PWD).
set -e
DEST="${1:-$PWD}"

files=$(/usr/bin/osascript -l JavaScript <<'JXA' 2>/dev/null
ObjC.import('AppKit');
const pb = $.NSPasteboard.generalPasteboard;
const list = ObjC.deepUnwrap(pb.propertyListForType("NSFilenamesPboardType"));
(list || []).join("\n");
JXA
)

if [ -z "$files" ]; then
  echo "Clipboard has no file references" >&2
  exit 1
fi

echo "$files" | while IFS= read -r f; do
  [ -n "$f" ] && cp -R "$f" "$DEST/"
done
