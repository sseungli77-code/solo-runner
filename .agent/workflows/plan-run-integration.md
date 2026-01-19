---
description: Plan-Run Integration Implementation
---

# Plan-Run Integration Features

## Feature 1: Plan Progress Tracking

### Changes Needed:
1. **Data Structure Update**
   - Add `completedCount` to each week in plan
   - Track individual run completion status

2. **Run Completion Handler**
   - After saving run, update corresponding plan item
   - Mark run as completed
   - Update week completion count

3. **Long Press Manual Input**
   - Add LongPressGesture to run cards
   - Show dialog with distance/time input
   - Mark as completed manually

4. **Progress Display**
   - Show "X/Y 완료" badge on week cards
   - Color-code completed runs (green checkmark)
   - Progress bar for week completion

## Feature 2: Run Tab ↔ Plan Integration

### Changes Needed:
1. **Today's Training Widget** (Run Tab)
   - Add "오늘의 훈련" card at top of Run page
   - Show: distance, target pace, type
   - Quick start button

2. **Plan Item Click Handler**
   - Tap on plan run → navigate to Run tab
   - Set `_currentRun` with target data
   - Display target info on Run screen

3. **Active Training Indicator**
   - Highlight selected training in plan
   - Show target pace during run
   - Compare actual vs target pace

## Implementation Steps:

1. Update data structures (State variables)
2. Add run completion logic
3. Create manual input dialog
4. Update Plan UI with progress
5. Add Today's Training widget to Run tab
6. Implement plan item click handler
7. Add active training display on Run screen

## Testing Checklist:
- [ ] Complete a run → Plan updates
- [ ] Long press run → Manual input works
- [ ] Progress shows correctly (1/3, 2/3, etc.)
- [ ] Click plan item → Goes to Run tab with target set
- [ ] Today's training shows on Run tab
- [ ] Actual vs target pace comparison works
