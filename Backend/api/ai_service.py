import os
import json
from google import genai
from google.genai import types
from .models import TradeRequest, User

# The client automatically picks up GEMINI_API_KEY from your environment!
client = genai.Client()

def evaluate_student_behavior(student_id):
    """
    Analyzes a student's trading history and strictly adjusts their Discipline Score.
    """
    try:
        student = User.objects.get(id=student_id)
        
        # 1. Gather ONLY the last 5 executed trades to judge immediate behavior
        recent_trades = TradeRequest.objects.filter(
            user=student, 
            status='EXECUTED'
        ).order_by('-created_at')[:5]

        if not recent_trades:
            return {"status": "skipped", "message": "Not enough data yet."}

        # 2. Format the data
        trade_history_text = "Recent Trades:\n"
        for trade in recent_trades:
            trade_history_text += f"- {trade.transaction_type} {trade.quantity} shares of {trade.symbol}. (Risk at execution: {trade.risk_level})\n"

        # 3. The Adjustment Prompt
        prompt = f"""
        You are an expert financial behavioral analyst grading a student's trading simulator performance.
        
        The student's CURRENT Discipline Score is: {student.discipline_score}/100.
        
        Analyze their recent trades and ADJUST their current score up or down using these strict rules:
        - Reward (+2 to +5 points) for making LOW risk trades or holding.
        - Penalize slightly (-2 to -5 points) for rapid/frequent MODERATE risk trades.
        - Penalize heavily (-10 to -15 points) for executing HIGH risk trades.
        - The absolute maximum score is 100, and the minimum is 0.
        
        Return ONLY the newly calculated score in this exact JSON format. Do not include any other keys:
        {{"discipline_score": 78}}

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
        
        # 5. Parse the JSON
        ai_data = json.loads(response.text)
        new_score = ai_data.get('discipline_score', student.discipline_score)

        # 6. Safety Net: Ensure the AI didn't hallucinate a number over 100 or under 0
        new_score = max(0, min(100, new_score))

        # 7. --- THE PYTHON RISK PROFILE ENGINE ---
        if new_score >= 75:
            new_profile = 'Conservative'
        elif new_score >= 40:
            new_profile = 'Moderate'
        else:
            new_profile = 'Aggressive'
        
        # 8. Save to database
        student.discipline_score = new_score
        student.risk_profile = new_profile
        student.save()

        return {
            "status": "success", 
            "new_score": student.discipline_score, 
            "new_profile": student.risk_profile
        }

    except Exception as e:
        print(f"AI Evaluation Error: {e}")
        return {"status": "error", "message": str(e)}