import logging
import json
from google import genai
from google.genai import types
from .models import TradeRequest, User

client = genai.Client()
logger = logging.getLogger(__name__)

def evaluate_student_behavior(student_id):
    """
    Analyzes a student's trading history and strictly adjusts their Discipline Score.
    """
    try:
        student = User.objects.get(id=student_id)
        previous_score = student.discipline_score
        
        recent_trades = TradeRequest.objects.filter(
            user=student, 
            status='EXECUTED'
        ).order_by('-created_at')[:5]

        if not recent_trades:
            return {"status": "skipped", "message": "Not enough data yet."}

        trade_history_text = "Recent Trades:\n"
        for trade in recent_trades:
            trade_history_text += f"- {trade.transaction_type} {trade.quantity} shares of {trade.symbol}. (Risk at execution: {trade.risk_level})\n"

        prompt = f"""
        You are an expert financial behavioral analyst grading a student's trading simulator performance.
        
        Review the student's recent trades below. Your goal is to determine a SINGLE net adjustment to their discipline score based on their recent behavior.
        
        Apply these strict rules to determine the adjustment:
        - Reward (+2 to +5) for making LOW risk trades or holding safely.
        - Penalize slightly (-2 to -5) for rapid/frequent MODERATE risk trades.
        - Penalize heavily (-10 to -15) for executing HIGH risk trades.
        
        CRITICAL RULES:
        - The absolute maximum reward is +5.
        - The absolute maximum penalty is -15.
        - Do not calculate the final score. ONLY return the adjustment integer.
        
        Return ONLY a JSON object perfectly matching this structure:
        {{
            "score_adjustment": -12, 
            "reasoning": "A brief, 1-sentence explanation of why you chose this adjustment based on the trades."
        }}

        {trade_history_text}
        """

        response = client.models.generate_content(
            model='gemini-2.5-flash', 
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        
        ai_data = json.loads(response.text)

        adjustment = ai_data.get('score_adjustment', 0)

        adjustment = max(-15, min(5, adjustment))

        raw_new_score = previous_score + adjustment

        new_score = max(0, min(100, raw_new_score))

        logger.info(
            "AI Adjustment: %s | Reason: %s",
            adjustment,
            ai_data.get('reasoning', 'None'),
        )

        if new_score < previous_score:
            student.discipline_drop_streak += 1
        else:
            student.discipline_drop_streak = 0

        lock_reason = None
        if student.discipline_drop_streak >= 5:
            lock_reason = 'consecutive_drops'
        elif new_score < 15:
            lock_reason = 'low_discipline_score'
        
        if lock_reason:
            student.is_trade_locked = True
            if lock_reason == 'consecutive_drops':
                student.trade_lock_reason = (
                    'Trading locked because discipline score decreased consecutively for 5 trades. '
                )
            elif lock_reason == 'low_discipline_score':
                student.trade_lock_reason = (
                    'Trading locked because discipline score fell below 15. '
                )

        if new_score >= 75:
            new_profile = 'Conservative'
        elif new_score >= 40:
            new_profile = 'Moderate'
        else:
            new_profile = 'Aggressive'
        
        student.discipline_score = new_score
        student.risk_profile = new_profile
        student.save()

        return {
            "status": "success", 
            "new_score": student.discipline_score, 
            "new_profile": student.risk_profile,
            "drop_streak": student.discipline_drop_streak,
            "is_trade_locked": student.is_trade_locked,
        }

    except Exception as e:
        logger.exception("AI evaluation error")
        return {"status": "error", "message": str(e)}
    
def draft_quiz_with_ai(recent_trades_data):
    """
    Takes a list of trade dictionaries and asks Gemini to draft a 5-question 
    behavioral finance quiz based on the student's recent activity.
    """
    
    trade_summary = ""
    for i, trade in enumerate(recent_trades_data, 1):
        symbol = trade.get('symbol', 'UNKNOWN')
        t_type = trade.get('transaction_type', 'TRADE')
        qty = trade.get('quantity', 0)
        price = trade.get('price_at_request', 0.0)
        status = trade.get('status', 'EXECUTED')
        
        trade_summary += f"{i}. {t_type} {qty}x {symbol} @ â‚¹{price} (Status: {status})\n"

    prompt = f"""
    You are an expert financial trading mentor and behavioral finance professor. 
    Your student has been locked out of their trading account due to reckless behavior, poor risk management, and a dropping discipline score.
    
    Review the student's last 5 trades below to understand their recent behavior:
    {trade_summary}

    Your task is to generate exactly 5 multiple-choice questions focused on:
    1. Behavioral finance and emotional regulation.
    2. Risk management and discipline.
    3. The specific patterns or mistakes implied by their recent trades.

    Make the questions challenging but highly educational. The goal is to correct their mindset.

    You must respond ONLY with a strict JSON array containing 5 objects. Do not include markdown formatting blocks like ```json.
    Each object must perfectly match this structure:
    {{
        "question_text": "The question string",
        "option_a": "First choice",
        "option_b": "Second choice",
        "option_c": "Third choice",
        "option_d": "Fourth choice",
        "correct_answer": "A", // Must be exactly A, B, C, or D
        "explanation": "A detailed explanation of why this is correct and the financial psychology behind it."
    }}
    """

    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash-lite', 
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.4,
            ),
        )
        
        quiz_data = json.loads(response.text)
        return quiz_data
        
    except json.JSONDecodeError as e:
        logger.warning("AI returned invalid JSON: %s", e)
        return None
    except Exception as e:
        logger.exception("AI engine error while drafting quiz")
        return None
