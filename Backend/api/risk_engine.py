def calculate_risk(symbol, quantity, user_profile):
    """
    Decides if a trade is GREEN, YELLOW, or RED.
    """
    symbol = symbol.upper()
    
    # 1. RED LIGHT (High Risk Assets)
    high_risk_keywords = ['CRYPTO', 'FUT', 'OPT', 'ADANI', 'PENNY']
    if any(keyword in symbol for keyword in high_risk_keywords):
        return 'RED'

    # 2. YELLOW LIGHT (Volume / Concentration Risk)
    # If they are putting too much money into one thing?
    # (For now, we'll keep it simple: Tech stocks are volatile)
    medium_risk_stocks = ['TESLA', 'ZOMATO', 'PAYTM', 'TATA']
    if symbol in medium_risk_stocks:
        return 'YELLOW'
        
    # 3. GREEN LIGHT (Safe bets)
    # Default everything else to Green for now
    return 'GREEN'