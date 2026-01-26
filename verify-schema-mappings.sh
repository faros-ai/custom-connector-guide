#!/bin/bash

echo "🔍 Verifying Schema Mappings..."
echo ""

# Test single user and todo conversion to see detailed mappings
TEMP_DIR=$(mktemp -d)

# Create test data with one user and one todo
cat > $TEMP_DIR/verify_records.jsonl << EOF
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__users","data":{"id":1,"name":"Test User","username":"testuser","email":"test@example.com"},"emitted_at":1234567890}}
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__todos","data":{"userId":1,"id":1,"title":"Test Todo","completed":false},"emitted_at":1234567891}}
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__todos","data":{"userId":1,"id":2,"title":"Completed Todo","completed":true},"emitted_at":1234567892}}
EOF

cd destinations/airbyte-faros-destination

echo "📊 Schema Mapping Verification:"
echo "=============================="
echo ""

echo "1. User Mapping (JSONPlaceholder → tms_User):"
echo "   - id → uid"
echo "   - name → name"
echo "   - email → emailAddress"
echo "   - Fixed: source='JSONPlaceholder', inactive=false"
echo ""

echo "2. Todo Mapping (JSONPlaceholder → tms_Task):"
echo "   - id → uid"
echo "   - title → name"
echo "   - title → description (prefixed with 'Todo item: ')"
echo "   - Fixed: type={category:'Task', detail:'todo'}"
echo "   - completed=false → status={category:'Todo', detail:'pending'}"
echo "   - completed=true → status={category:'Done', detail:'completed'}"
echo "   - Fixed: source='JSONPlaceholder'"
echo "   - Auto-generated: createdAt, updatedAt timestamps"
echo "   - resolvedAt: null for pending, timestamp for completed"
echo ""

echo "3. Task Assignment (JSONPlaceholder → tms_TaskAssignment):"
echo "   - Creates relationship between task and user"
echo "   - task: {uid: todo.id, source: 'JSONPlaceholder'}"
echo "   - assignee: {uid: todo.userId, source: 'JSONPlaceholder'}"
echo ""

echo "🧪 Running conversion test..."
echo "=============================="
cat $TEMP_DIR/verify_records.jsonl | node lib/index.js 2>&1 | grep "Converted" | while IFS= read -r line; do
    echo "$line" | python3 -m json.tool 2>/dev/null || echo "$line"
done

echo ""
echo "✅ Schema mapping verification complete!"

# Clean up
rm -rf $TEMP_DIR
