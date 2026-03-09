#!/bin/bash
LOCAL_FILE="modified/scheduler_output_processor_mixin.py"

SGLANG_PATH=$(python3 - <<'EOF'
import sglang, os
print(os.path.dirname(sglang.__file__))
EOF
)

TARGET_FILE="$SGLANG_PATH/srt/managers/scheduler_output_processor_mixin.py"
BACKUP_FILE="$TARGET_FILE.bak"

echo "Local file: $LOCAL_FILE"
echo "Sglang target file: $TARGET_FILE"

if [ ! -f "$LOCAL_FILE" ]; then
    echo "❌ Local file does not exist: $LOCAL_FILE"
    exit 1
fi
if [ ! -f "$TARGET_FILE" ]; then
    echo "❌ Sglang target file not found: $TARGET_FILE"
    exit 1
fi

if cmp -s "$LOCAL_FILE" "$TARGET_FILE"; then
    echo "✨ Files are identical. Skipping replacement."
else
    echo "Backing up target file to: $BACKUP_FILE"
    cp "$TARGET_FILE" "$BACKUP_FILE"
    cp "$LOCAL_FILE" "$TARGET_FILE"
    echo "✅ Replacement successful!"
fi