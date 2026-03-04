import os
import json
import google.generativeai as genai
from django.conf import settings
from .models import TradeRequest, User # Adjust imports based on your app name

# Configure the API key
genai.configure(api_key=os.environ.get('GEMINI_API_KEY'))

def evaluate_student_behavior(student_id):
    """
    Analyzes a student's trading history and updates their Discipline Score and Risk Profile.
    """
    try:
        student = User.objects.get(id=student_id)
        
        # 1. Gather the last 20 executed trades for this student
        recent_trades = TradeRequest.objects.filter(
            user=student, 
            status='EXECUTED'
        ).order_by('-created_at')[:20]

        if not recent_trades:
            return {"status": "skipped", "message": "Not enough data yet."}

        # 2. Format the data into a readable string for the AI
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

        Return EXACTLY this JSON format:
        {"discipline_score": 85, "risk_profile": "Moderate"}

        {trade_history_text}
        """

        # 4. Call Gemini (Forcing JSON Output)
        model = genai.GenerativeModel(
            'gemini-2.5-flash',
            generation_config={"response_mime_type": "application/json"}
        )
        
        response = model.generate_content(prompt)
        
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