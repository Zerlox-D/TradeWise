import os
import json
from google import genai
from google.genai import types


## The client automatically picks up GEMINI_API_KEY from your environment!
client = genai.Client()

def analyze_stock_risk(symbol, current_price, high_24h, low_24h):
    """
    Uses Gemini to dynamically assess trading risk based on real-time volatility.
    """
    try:
        # 1. Let Python do the math so the AI doesn't hallucinate!
        spread_pct = 0
        if low_24h > 0:
            spread_pct = round(((high_24h - low_24h) / low_24h) * 100, 2)

        prompt = f"""
        You are an expert financial risk analyst for a student trading simulator. 
        Analyze the 24-hour volatility for the Indian asset: {symbol}.
        - Current Price: ₹{current_price}
        - 24h High: ₹{high_24h}
        - 24h Low: ₹{low_24h}
        - Calculated 24h Volatility Spread: {spread_pct}%

        STRICT SIMULATOR RISK RULES (Evaluate in this exact order):
        1. HIGH RISK: If {symbol} is exactly one of [ADANIENT, SUZLON, YESBANK, PAYTM, ZOMATO], OR if the Volatility Spread is strictly strictly greater than 2.5%.
        2. LOW RISK: If {symbol} is an ETF (like GOLDBEES, NIFTYBEES, SILVERBEES, BANKBEES, MON100) OR if the Volatility Spread is strictly less than 1.0%.
        3. MODERATE RISK: All other scenarios.
        
        Based strictly on this price action and your general knowledge of this asset's typical behavior, categorize the current trading risk.
        Respond ONLY in valid JSON format with exactly two keys:
        "risk_level": (Must be exactly "LOW", "MODERATE", or "HIGH")
        "reasoning": (A crisp, 1-sentence explanation of why, explicitly mentioning the {spread_pct}% spread or the asset's historical reputation without mentioning anything about simulator rules, tailored for a student trader learning about risk.)
        """
        
        # Call the NEW Gemini SDK
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        
        # Since we enforced JSON mime_type, we can parse it directly!
        risk_data = json.loads(response.text)
        
        # Map the AI's risk level to the exact colors your Flutter frontend expects
        color_map = {'LOW': '#69F0AE', 'MODERATE': '#FFD740', 'HIGH': '#FF5252'}
        risk_data['risk_color'] = color_map.get(risk_data.get('risk_level', 'MODERATE'), '#FFD740')
        
        return risk_data

    except Exception as e:
        print(f"AI Engine Error: {e}")
        # A safe fallback just in case the API call fails or times out
        return {
            "risk_level": "MODERATE", 
            "risk_color": "#FFD740", 
            "reasoning": "Standard market risk. AI assessment temporarily unavailable."
        }