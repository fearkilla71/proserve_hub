# ProServe Hub — Quick Setup Guide

## 🎯 What You Need Before Testing AI Estimate

### 1. Enable Firebase Storage (Cloud Console)
- Go to: https://console.firebase.google.com/project/proserve-hub-ada0e/storage
- Click **"Get Started"** and follow the prompts
- Once enabled, deploy storage rules:
  ```bash
  firebase deploy --only storage
  ```

### 2. Seed Pricing Data
Run the seed script to create `pricing_rules` and `zip_costs`:

```bash
cd functions
node seed.js
```

This creates:
- `pricing_rules/painting` (baseRate: 2.5/sqft, min: $150, max: $1500)
- `pricing_rules/drywall` (baseRate: 3.0/sqft, min: $200, max: $2000)
- `pricing_rules/plumbing` (baseRate: 95/hour, min: $120, max: $800)
- 10 sample `zip_costs` entries (Houston area)

### 3. Set OpenAI Key (for AI Estimate)

**Option A: Cloud Function env var (for deployed functions)**
- Go to: https://console.cloud.google.com/functions/list?project=proserve-hub-ada0e
- Click `estimateJobFromImages` → **Edit**
- Under **Runtime, build, connections, and security** → **Runtime environment variables**
- Add: `OPENAI_API_KEY` = `<your key>`
- Save/redeploy

**Option B: Local emulator (for testing locally)**
```bash
# Windows PowerShell
$env:OPENAI_API_KEY="your-key-here"

# Then start emulators
firebase emulators:start --only auth,firestore,functions,storage
```

---

## 🚀 Running the App

### Option 1: Cloud Mode (default)
```bash
flutter run -d windows
```
Uses your live Firebase project.

### Option 2: Emulator Mode (local testing)
```bash
# Start emulators (separate terminal)
firebase emulators:start --only auth,firestore,functions,storage

# Run Flutter app against emulators
flutter run -d windows --dart-define=USE_FIREBASE_EMULATORS=true
```

---

## 📸 Testing AI Estimate

1. Create a job (painting or drywall)
2. After submission, you'll see the **"Top Recommended Pros"** screen
3. At the top: **"AI Estimate (Photos)"** card
4. Click **"Upload Photos"** (pick 1–10 images)
5. Click **"Generate Estimate"**
6. AI analyzes photos and returns Budget / Recommended / Premium prices

---

## 🛠 Troubleshooting

**"Pricing not configured"**
→ Run `node seed.js` from `functions/` directory

**"Upload failed: object-not-found"**
→ Enable Firebase Storage in console, then `firebase deploy --only storage`

**"OpenAI key is not configured"**
→ Set `OPENAI_API_KEY` env var (see step 3 above)

**"No contractors found"**
→ This is expected if you haven't added any contractors yet. The AI estimate works independently.
