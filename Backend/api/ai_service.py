import os
import json
from google import genai
from google.genai import types
from .models import TradeRequest, User # Adjust based on your app name

# The client automatically picks up GEMINI_API_KEY from your environment!
client = genai.Client()

def evaluate_student_behavior(student_id):
    """
    Analyzes a student's trading history and updates their Discipline Score and Risk Profile.
    """
    try:
        student = User.objects.get(id=student_id)
        
        # 1. Gather the last 20 executed trades
        recent_trades = TradeRequest.objects.filter(
            user=student, 
            status='EXECUTED'
        ).order_by('-created_at')[:20]

        if not recent_trades:
            return {"status": "skipped", "message": "Not enough data yet."}

        # 2. Format the data into text
        trade_history_text = "Recent Trades:\n"
        for trade in recent_trades:
            trade_history_text += f"- {trade.transaction_type} {trade.quantity} shares of {trade.symbol} at ₹{trade.price_at_request}. P&L: ₹{trade.loss_amount if trade.loss_amount else 'Profit/Hold'}\n"

        # 3. Define the Prompt & Rules
        prompt = f"""
        You are an expert financial behavioral analyst evaluating a student's trading simulator performance.
        Analyze the following trade history and assign a Discipline Score (0-100) and a Risk Profile (Conservative, Moderate, or Aggressive).
        
        Rules for Discipline Score:
        - Frequent, impulsive buying/selling lowers the score.
        - Heavy losses or constantly trading highly volatile/risky assets lowers the score.
        - Holding assets and making calculated moves increases the score.
        
        Rules for Risk Profile:
        - Conservative: Prefers ETFs and blue-chip stocks.
        - Moderate: Mixed portfolio, occasional risk.
        - Aggressive: Heavy focus on volatile individual stocks, frequent trading.

        Return the results in this example JSON format:
        {{"discipline_score": 30, "risk_profile": "Aggressive"}}

        Follow the example format and return data according to the results of your analysis. Do not include any explanations, only the JSON.

        {trade_history_text}
        """

        # 4. Call the NEW Gemini SDK
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        
        # 5. Parse the JSON and update the database
        ai_data = json.loads(response.text)
        
        student.discipline_score = ai_data.get('discipline_score', student.discipline_score)
        student.risk_profile = ai_data.get('risk_profile', student.risk_profile)
        student.save()

        return {
            "status": "success", 
            "new_score": student.discipline_score, 
            "new_profile": student.risk_profile
        }

    except Exception as e:
        print(f"AI Evaluation Error: {e}")
        return {"status": "error", "message": str(e)}