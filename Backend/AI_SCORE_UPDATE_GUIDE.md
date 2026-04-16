# TradeWise AI Discipline Score & Risk Profile Update Guide

## Fixed Issues

### 1. **JSON Parsing Robustness** ✅
- **Problem**: Gemini API response might be wrapped in markdown code blocks (```json...```), causing `json.loads()` to fail silently
- **Solution**: Added `_extract_json_from_response()` function to handle multiple response formats
- **Location**: `api/ai_service.py` (lines 27-40)

### 2. **Error Handling & Logging** ✅
- **Problem**: Errors were only printed to console and lost
- **Solution**: 
  - Implemented proper Python logging using `logging` module
  - Added error context for API calls, JSON parsing, data conversion, and database operations
  - All errors now logged with `logger.error()` for visibility
- **Location**: `api/ai_service.py` (lines 18-21, throughout function)

### 3. **Type Conversion** ✅
- **Problem**: Discipline score from Gemini might be a string, causing database update failures
- **Solution**: Explicit float conversion with validation:
  ```python
  new_discipline_score = float(ai_data.get('discipline_score', student.discipline_score))
  # Ensure valid range (0-100)
  if new_discipline_score < 0:
      new_discipline_score = 0.0
  elif new_discipline_score > 100:
      new_discipline_score = 100.0
  ```
- **Location**: `api/ai_service.py` (lines 99-105)

### 4. **Risk Profile Validation** ✅
- **Problem**: Gemini might return invalid risk profile values
- **Solution**: 
  - Validate against allowed values: `['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']`
  - Preserve existing profile if invalid response received
  - Convert to uppercase for consistency
- **Location**: `api/ai_service.py` (lines 107-113)

### 5. **Increased Update Frequency** ✅
- **Problem**: Discipline score only updated when losses occurred or mentor approved trades
- **Solution**: Now evaluates after:
  - ✅ **BUY trades execute** - evaluate after purchase
  - ✅ **SELL trades execute** - evaluate after sale (regardless of profit/loss)
  - ✅ **Mentor approval** - evaluate after mentor approves pending trades
- **Location**: `api/views.py` (lines 150, 186-187, 275)

### 6. **API Model Update** ✅
- **Problem**: Using deprecated Gemini model version
- **Solution**: Updated from `gemini-2.5-flash` to `gemini-2.0-flash`
- **Location**: `api/ai_service.py` (line 82)

---

## Conditions for Discipline Score Changes

### Score Range: **0 - 100** (Starting Default: 50)

#### Factors that **INCREASE** the score:
- ✅ **Profit-taking behavior**: Selling at gains or holding long positions
- ✅ **Calculated decisions**: Well-justified trades with clear goals
- ✅ **Low trading frequency**: Not over-trading or making impulsive decisions
- ✅ **Consistent wins**: Maintaining positive overall P&L
- ✅ **Asset diversification**: Trading multiple different stocks/sectors
- ✅ **Goal-aligned trades**: Linking trades to specific investment goals

#### Factors that **DECREASE** the score:
- ❌ **Frequent impulsive trading**: Rapid buy/sell cycles without justification
- ❌ **Consistent losses**: Repeatedly taking losses on trades
- ❌ **High-risk asset focus**: Solely trading volatile individual stocks
- ❌ **Lack of strategy**: Trading without clear justification or plan
- ❌ **Panic trading**: Making reactive trades during volatility
- ❌ **Ignoring goals**: Making trades unrelated to financial objectives

---

## Conditions for Risk Profile Changes

### Profile Options: **Conservative | Moderate | Aggressive**

#### **Conservative Profile** 🟢
- Characteristics:
  - Majority of holdings in blue-chip stocks (TCS, INFY, RELIANCE, etc.)
  - Prefers ETFs and low-volatility index funds
  - Low trading frequency
  - Focus on long-term stability
  - Minimal losses or risk tolerance
  
- Typical Discipline Score: 70-100

#### **Moderate Profile** 🟡
- Characteristics:
  - Balanced portfolio with 60% stable + 40% growth stocks
  - Mix of blue-chips and mid-cap companies
  - Occasional high-risk trades
  - Calculated risk-taking with clear rationale
  - Regular profit-taking behavior
  
- Typical Discipline Score: 40-75

#### **Aggressive Profile** 🔴
- Characteristics:
  - Heavy focus on volatile individual stocks (small-caps, penny stocks)
  - Frequent trading and rapid position changes
  - High-risk asset concentration
  - Limited use of diversification
  - Tolerance for significant losses
  
- Typical Discipline Score: 0-50

---

## Update Triggers & Timeline

### When Score/Profile Updates Occur:

```
User Action                          → AI Evaluation Called
─────────────────────────────────────┬──────────────────────
BUY trade executes (Green/Yellow)    → Immediate evaluation
SELL trade executes (any)            → Immediate evaluation  
Mentor approves pending trade        → Immediate evaluation
─────────────────────────────────────┴──────────────────────
```

### Frequency:
- Updates are **real-time** after each executed trade
- User can immediately see their updated discipline score via `GET /api/user/profile/`
- A student needs **at least 1 executed trade** for initial evaluation

---

## Technical Details

### Database Schema (No changes required)
```python
class User(AbstractUser):
    discipline_score = models.FloatField(default=50.0)  # 0-100
    risk_profile = models.CharField(max_length=20, default='MODERATE')
```

### API Endpoints Affected:
1. **GET** `/api/user/profile/` - Returns current discipline_score
2. **GET** `/api/students/{student_id}/portfolio/` - Mentor view includes discipline_score
3. **POST** `/api/trades/` - Triggers evaluation on trade execution
4. **POST** `/api/trades/{id}/respond/` - Mentor approval triggers evaluation

### Required Environment Variable:
```bash
GEMINI_API_KEY=your_api_key_here
```

---

## Testing the Fix

### Step 1: Verify API Key
```python
import os
print(os.environ.get('GEMINI_API_KEY'))  # Should not be None
```

### Step 2: Check Logs
```bash
# Django logs will now show AI evaluation results:
tail -f django_logs.log | grep "AI evaluation\|Updated user"
```

### Step 3: Test with a Trade
1. Create a BUY trade → Check discipline_score updates
2. Create a SELL trade with profit → Check discipline_score updates
3. Visit `/api/user/profile/` → Confirm new scores reflected

### Step 4: Monitor Errors
Watch for these log statements indicating issues:
- ⚠️ "GEMINI_API_KEY environment variable is not set"
- ⚠️ "Gemini API call failed"
- ⚠️ "Failed to parse JSON"
- ⚠️ "Invalid risk profile"

---

## File Changes Summary

| File | Changes | Lines |
|------|---------|-------|
| `api/ai_service.py` | Complete rewrite with robust error handling, logging, JSON parsing, type validation | All |
| `api/views.py` | Added evaluate_student_behavior() calls after BUY and SELL trades | 150, 186-187 |

---

## Debugging Checklist

- [ ] Environment variable `GEMINI_API_KEY` is set
- [ ] User has at least 1 EXECUTED trade
- [ ] Check Django logs for parsing errors
- [ ] Verify Gemini model `gemini-2.0-flash` is available in your API quota
- [ ] Confirm database field `discipline_score` accepts float values
- [ ] Test with a simple BUY then SELL trade sequence
