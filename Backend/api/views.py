import yfinance as yf
import pandas as pd
import numpy as np
from decimal import Decimal
from rest_framework import viewsets, permissions, generics, status, filters
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import ValidationError
from django.shortcuts import get_object_or_404
from django.db.models import Q
from .ai_service import evaluate_student_behavior
from .risk_engine import calculate_risk
from .models import Asset, User, Goal, TradeRequest, MentorLink, Holding
from .serializers import HoldingSerializer, UserSerializer, GoalSerializer, TradeRequestSerializer, RegisterSerializer, MentorSerializer, MentorLinkSerializer

def calculate_brokerage_fee(total_value, discipline_score):
    """
    Returns the fee amount and the label based on the user's discipline score.
    """
    if discipline_score >= 75:
        return Decimal('0.00'), "0% (Disciplined)"
    elif discipline_score >= 40:
        # 1% Standard Fee
        return total_value * Decimal('0.01'), "1% (Standard)"
    else:
        # 3% Impulse Penalty
        return total_value * Decimal('0.03'), "3% (Penalty)"

class UserViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to be viewed or edited.
    """
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

class GoalViewSet(viewsets.ModelViewSet):
    """
    API endpoint for managing financial goals.
    """
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Goal.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class TradeRequestViewSet(viewsets.ModelViewSet):
    """
    API endpoint for trade requests.
    """
    serializer_class = TradeRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Users see their own trades. Mentors see their students' trades.
        user = self.request.user
        if user.role == 'MENTOR':
            # Find all students linked to this mentor
            student_ids = MentorLink.objects.filter(
                mentor=user,
                status='ACCEPTED',
                ).values_list('student_id', flat=True)
            return TradeRequest.objects.filter(
                Q(user=user) | Q(user__id__in=student_ids, status='PENDING_MENTOR')
            ).order_by('-created_at')
        else:
            return TradeRequest.objects.filter(user=user).order_by('-created_at')

    def create(self, request, *args, **kwargs):
        user = request.user
        data = request.data.copy()
        
        symbol = data.get('symbol').upper()
        quantity = int(data.get('quantity'))
        transaction_type = data.get('transaction_type')
        
        # --- CAPTURE GOAL & JUSTIFICATION ---
        goal_id = data.get('goal')
        justification = data.get('justification', '')
        
        goal_instance = None
        if goal_id:
            try:
                goal_instance = Goal.objects.get(id=goal_id, user=user)
            except Goal.DoesNotExist:
                return Response({'error': 'Invalid Goal'}, status=status.HTTP_400_BAD_REQUEST)

        # --- 1. PRE-TRADE VALIDATION (BUY vs SELL) ---
        if transaction_type == 'SELL':
            # Do they actually own this stock?
            try:
                holding = Holding.objects.get(user=user, symbol=symbol)
                if holding.total_quantity < quantity:
                    return Response({'error': f'You only own {holding.total_quantity} shares.'}, status=status.HTTP_400_BAD_REQUEST)
            except Holding.DoesNotExist:
                return Response({'error': 'You do not own this stock.'}, status=status.HTTP_400_BAD_REQUEST)

        # --- 2. GET LIVE PRICE ---
        try:
            stock = yf.Ticker(symbol + ".NS") 
            current_price = stock.history(period="1d")['Close'].iloc[-1]
            current_price = Decimal(str(round(current_price, 2))) 
        except Exception as e:
            return Response({'error': 'Invalid Symbol or API Error'}, status=status.HTTP_400_BAD_REQUEST)

        total_cost = current_price * quantity

        fee_amount, fee_reason = calculate_brokerage_fee(total_cost, user.discipline_score)
        total_buy_cost = total_cost + fee_amount   # They pay the cost + the fee
        total_sell_profit = total_cost - fee_amount # They receive the profit - the fee

        # --- 3. CHECK BALANCE (If Buying) ---
        if transaction_type == 'BUY':
            if user.wallet_balance < total_cost:
                return Response({'error': 'Insufficient Funds'}, status=status.HTTP_400_BAD_REQUEST)

        # --- 4. RISK ENGINE CHECK 🚦 ---
        risk_color = calculate_risk(symbol, quantity, user.risk_profile)
        has_active_mentor = MentorLink.objects.filter(student=user, status='ACCEPTED').exists()
        
        trade_status = 'EXECUTED' 
        if risk_color == 'RED' and user.role!= 'MENTOR':
            if has_active_mentor:
                trade_status = 'PENDING_MENTOR'
            else:
                return Response({
                    'error': 'High-risk trades are locked. Please connect with a mentor to unlock this asset tier.'
                }, status=status.HTTP_403_FORBIDDEN)
            
        # --- 5. SAVE THE TRADE ---
        trade = TradeRequest.objects.create(
            user=user,
            goal=goal_instance,               
            symbol=symbol,
            quantity=quantity,
            transaction_type=transaction_type,
            price_at_request=current_price,   
            total_amount=total_cost,
            brokerage_fee=fee_amount,
            justification=justification,      
            risk_level=risk_color,
            status=trade_status
        )

        # --- 6. POST-EXECUTION (If Green/Yellow) ---
        if trade_status == 'EXECUTED':
            if transaction_type == 'BUY':
                # Deduct Money
                user.wallet_balance -= total_cost
                
                # Update Holdings
                holding, created = Holding.objects.get_or_create(
                    user=user, 
                    symbol=symbol,
                    defaults={'average_price': current_price, 'total_quantity': 0}
                )
                
                old_value = holding.total_quantity * holding.average_price
                new_value = quantity * current_price
                
                holding.total_quantity += quantity
                holding.average_price = (old_value + new_value) / holding.total_quantity
                holding.save()
                user.save()
                
                # Evaluate student behavior after BUY trade
                evaluate_student_behavior(user.id)

            elif transaction_type == 'SELL':
                holding = Holding.objects.get(user=user, symbol=symbol)
                
                # Calculate Realized Profit/Loss (Including the fee!)
                buy_value = holding.average_price * quantity
                realized_pl = total_sell_profit - buy_value 
                
                # Add money back to wallet (Minus the fee)
                user.wallet_balance += total_sell_profit
                user.save()
                
                # Remove shares from Holding
                holding.total_quantity -= quantity
                holding.save()
                
                # Update Goal Progress
                if goal_instance:
                    goal_instance.current_amount += realized_pl
                    if goal_instance.current_amount < 0:
                        goal_instance.current_amount = Decimal('0.00')
                    goal_instance.save()
                
                if realized_pl < 0:
                    trade.loss_amount = abs(realized_pl)
                    trade.save()

                # Evaluate student behavior after SELL trade (regardless of profit/loss)
                evaluate_student_behavior(user.id)

        serializer = self.get_serializer(trade)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        """
        Endpoint for Mentors to Approve or Reject a pending trade.
        """
        trade = self.get_object()
        mentor = request.user

        # --- 1. SECURITY CHECKS ---
        # Is the user actually a MENTOR?
        if mentor.role != 'MENTOR':
            return Response({'error': 'Only mentors can review trades.'}, status=status.HTTP_403_FORBIDDEN)

        # Is this mentor actually linked to the student who made the trade?
        is_linked = MentorLink.objects.filter(mentor=mentor, student=trade.user, is_active=True).exists()
        if not is_linked:
            return Response({'error': 'You are not linked to this student.'}, status=status.HTTP_403_FORBIDDEN)

        # Is the trade actually waiting for approval?
        if trade.status != 'PENDING_MENTOR':
            return Response({'error': 'This trade is not pending mentor approval.'}, status=status.HTTP_400_BAD_REQUEST)

        # --- 2. GET THE ACTION ---
        action_type = request.data.get('action') # Expecting 'approve' or 'reject'
        mentor_comment = request.data.get('comment', '') # Optional feedback for the student
        student = trade.user

        # --- 3. EXECUTE OR REJECT ---
        if action_type == 'approve':
            # Calculate the final costs using the fee that was saved during the initial request
            total_buy_cost = trade.total_amount + trade.brokerage_fee
            
            if trade.transaction_type == 'BUY':
                if student.wallet_balance < total_buy_cost:
                    return Response({'error': 'Student no longer has enough funds for this trade (including fees).'}, status=status.HTTP_400_BAD_REQUEST)
                
                # Deduct Money (Cost + Fee)
                student.wallet_balance -= total_buy_cost
                
                holding, created = Holding.objects.get_or_create(
                    user=student, 
                    symbol=trade.symbol,
                    defaults={'average_price': trade.price_at_request, 'total_quantity': 0}
                )
                
                old_value = holding.total_quantity * holding.average_price
                new_value = trade.quantity * trade.price_at_request
                
                holding.total_quantity += trade.quantity
                holding.average_price = (old_value + new_value) / holding.total_quantity
                holding.save()
                student.save()

            elif trade.transaction_type == 'SELL':
                try:
                    holding = Holding.objects.get(user=student, symbol=trade.symbol)
                    if holding.total_quantity < trade.quantity:
                        return Response({'error': 'Student no longer owns enough shares.'}, status=status.HTTP_400_BAD_REQUEST)
                    
                    buy_value = holding.average_price * trade.quantity
                    sell_value = trade.price_at_request * trade.quantity
                    
                    # Subtract the fee from their final payout
                    total_sell_profit = sell_value - trade.brokerage_fee
                    realized_pl = total_sell_profit - buy_value
                    
                    # Add money back to wallet (Profit - Fee)
                    student.wallet_balance += total_sell_profit
                    student.save()
                    
                    holding.total_quantity -= trade.quantity
                    holding.save()
                    
                    if trade.goal:
                        trade.goal.current_amount += realized_pl
                        if trade.goal.current_amount < 0:
                            trade.goal.current_amount = Decimal('0.00')
                        trade.goal.save()
                        
                    if realized_pl < 0:
                        trade.loss_amount = abs(realized_pl)
                        
                except Holding.DoesNotExist:
                    return Response({'error': 'Student does not own this stock.'}, status=status.HTTP_400_BAD_REQUEST)

            # Finalize Approval
            trade.status = 'EXECUTED'
            trade.mentor_comment = mentor_comment
            trade.save()

            evaluate_student_behavior(student.id)
            return Response({'status': 'Trade Approved and Executed'})

        elif action_type == 'reject':
            # If rejected, we don't touch the money or holdings. Just update the status.
            trade.status = 'REJECTED'
            trade.mentor_comment = mentor_comment
            trade.save()
            return Response({'status': 'Trade Rejected'})

        return Response({'error': 'Invalid action. Must be "approve" or "reject".'}, status=status.HTTP_400_BAD_REQUEST)

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

# 1. Search for Mentors (The "Phonebook")
class MentorListView(generics.ListAPIView):
    serializer_class = MentorSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        # Start with all Mentors
        queryset = User.objects.filter(role='MENTOR')
        
        code_param = self.request.query_params.get('code', None)
        
        if code_param is not None:
            try:
                search_code = int(code_param)
                real_id = search_code - 130200
                
                # Filter by the REAL database ID
                queryset = queryset.filter(id=real_id)
            except ValueError:
                # If they send "abc" or garbage, return nothing
                return queryset.none()
            
        return queryset

# 2. Manage Requests (The "Inbox")
class MentorLinkViewSet(viewsets.ModelViewSet):
    serializer_class = MentorLinkSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Mentors see requests sent TO them. Students see requests sent BY them.
        user = self.request.user
        if user.role == 'MENTOR':
            return MentorLink.objects.filter(mentor=user)
        else:
            return MentorLink.objects.filter(student=user)

    # --- REPLACE YOUR EXISTING perform_create WITH THESE TWO METHODS ---
    def create(self, request, *args, **kwargs):
        student = request.user
        mentor_id = request.data.get('mentor')

        # 1. Block if the student already has an active or pending request with ANY mentor
        if MentorLink.objects.filter(student=student, status__in=['PENDING', 'ACCEPTED']).exists():
            return Response({'error': 'You already have a pending or active mentor connection.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            mentor = User.objects.get(id=mentor_id, role='MENTOR')
        except User.DoesNotExist:
            return Response({'error': 'Mentor not found.'}, status=status.HTTP_404_NOT_FOUND)

        # 2. Check if a link already exists specifically between this student and this mentor
        link = MentorLink.objects.filter(student=student, mentor=mentor).first()

        if link:
            if link.status == 'REJECTED':
                # --- THE FIX: Reactivate the rejected request! ---
                link.status = 'PENDING'
                link.save()
                # We return 201 CREATED so Flutter treats it like a brand new successful request
                return Response({'message': 'Request sent again!'}, status=status.HTTP_201_CREATED)
        
        # 3. If no link exists at all, let Django handle creating a brand new row
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        # This is called by super().create() to attach the student and default status
        serializer.save(student=self.request.user, status='PENDING', is_active=False)

    # Custom Action for Mentors to "Accept" or "Reject"
    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        link = self.get_object()
        
        # Security Check: Are you really the mentor for this request?
        if request.user != link.mentor:
            return Response({'error': 'Not authorized'}, status=403)
            
        action = request.data.get('action') # 'accept' or 'reject'
        
        if action == 'accept':
            link.status = 'ACCEPTED'
            link.is_active = True
            link.save()
            return Response({'status': 'Mentorship Accepted'})
        elif action == 'reject':
            link.status = 'REJECTED'
            link.is_active = False
            link.save()
            return Response({'status': 'Mentorship Rejected'})
            
        return Response({'error': 'Invalid action'}, status=400)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_profile(request):
    """
    The 'Mirror' Endpoint. 
    Returns the profile data of the user attached to the token.
    """
    user = request.user
    return Response({
        'id': user.id,
        'username': user.username,
        'role': user.role,
        'discipline_score': user.discipline_score,
        'wallet_balance': str(user.wallet_balance),
        'risk_profile': user.risk_profile,
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_live_price(request, symbol):
    """
    Fetches the live price of an NSE stock for the Flutter UI preview.
    """
    try:
        # We append .NS just like your TradeRequest logic does
        stock = yf.Ticker(symbol.upper() + ".NS")
        current_price = stock.history(period="1d")['Close'].iloc[-1]
        
        return Response({
            'symbol': symbol.upper(),
            'price': round(current_price, 2)
        })
    except Exception as e:
        return Response({'error': 'Unable to fetch live price.'}, status=400)
    
class HoldingViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API endpoint for users to view their current portfolio holdings.
    """
    serializer_class = HoldingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Users can only see their own holdings
        return Holding.objects.filter(user=self.request.user)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_stock_history(request, symbol):
    """
    Fetches 30-day historical data and calculates moving averages using Pandas/NumPy.
    """
    try:
        # 1. Fetch data from Yahoo Finance
        stock = yf.Ticker(symbol.upper() + ".NS")
        hist = stock.history(period="1mo") # 1 month of data
        
        if hist.empty:
            return Response({'error': 'No data found for this symbol.'}, status=404)
            
        # 2. Clean the data with Pandas (drop any rows missing 'Close' prices)
        hist = hist.dropna(subset=['Close'])
        
        # 3. Calculate a 7-day Moving Average 
        hist['MA7'] = hist['Close'].rolling(window=7, min_periods=1).mean()
        
        # 4. Use NumPy to round the arrays and convert them to standard Python lists for JSON
        dates = hist.index.strftime('%b %d').tolist() # e.g., "Oct 12"
        prices = np.round(hist['Close'].values, 2).tolist()
        ma7 = np.round(hist['MA7'].values, 2).tolist()
        
        return Response({
            'symbol': symbol.upper(),
            'dates': dates,
            'prices': prices,
            'ma7': ma7,
            'min_price': min(prices), # Helps Flutter scale the chart Y-axis
            'max_price': max(prices)
        })
    except Exception as e:
        return Response({'error': 'Failed to process historical data.'}, status=400)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_portfolio(request, student_id):
    """
    Allows a Mentor to view a connected student's profile and holdings.
    """
    mentor = request.user

    # 1. Security Check: Are they a Mentor, and are they officially linked?
    if mentor.role != 'MENTOR':
        return Response({'error': 'Only mentors can view student portfolios.'}, status=status.HTTP_403_FORBIDDEN)

    is_linked = MentorLink.objects.filter(
        mentor=mentor, 
        student_id=student_id, 
        status='ACCEPTED'
    ).exists()
    
    if not is_linked:
        return Response({'error': 'You are not linked to this student.'}, status=status.HTTP_403_FORBIDDEN)

    # 2. Fetch the Data
    student = get_object_or_404(User, id=student_id)
    holdings = Holding.objects.filter(user=student, total_quantity__gt=0) # Only grab assets they actually own

    # 3. Format it for Flutter
    holdings_data = [
        {
            'symbol': h.symbol,
            'total_quantity': h.total_quantity,
            'average_price': str(h.average_price)
        } for h in holdings
    ]

    return Response({
        'student_name': student.username,
        'wallet_balance': str(student.wallet_balance),
        'discipline_score': student.discipline_score,
        'risk_profile': student.risk_profile,
        'holdings': holdings_data
    })

# --- ADD THIS TO THE BOTTOM OF YOUR views.py ---

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_market_overview(request):
    """
    Fetches 24-hour intraday data for the home page, calculates P&L, 
    and identifies the Top Gainer and Top Loser.
    """
    # Our core list of simulator assets
    db_assets = Asset.objects.filter(is_active=True)
    market_data = []

    for asset in db_assets:
        symbol = asset.symbol
        try:
            stock = yf.Ticker(symbol + ".NS")
            
            # Fetch the last trading day's data in 15-minute intervals
            hist = stock.history(period="1d", interval="15m")
            
            if hist.empty:
                continue
                
            hist = hist.dropna(subset=['Close'])
            
            # Compare the very first opening price to the most recent closing price
            first_price = float(hist['Open'].iloc[0])
            last_price = float(hist['Close'].iloc[-1])
            
            # The Math: (New - Old) / Old * 100
            pct_change = ((last_price - first_price) / first_price) * 100
            
            # Extract the raw prices for the Flutter fl_chart
            sparkline = np.round(hist['Close'].values, 2).tolist()
            
            market_data.append({
                'symbol': symbol,
                'name': asset.name,
                'current_price': round(last_price, 2),
                'pct_change': round(pct_change, 2),
                'is_positive': pct_change >= 0,
                'sparkline': sparkline,
                'min_price': min(sparkline),
                'max_price': max(sparkline),
            })
        except Exception as e:
            print(f"Skipping {symbol} due to error: {e}")
            continue

    if not market_data:
        return Response({'error': 'Market data unavailable at this time.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # Sort the entire list from highest profit to highest loss
    market_data.sort(key=lambda x: x['pct_change'], reverse=True)

    # The magic: market_data[0] is the biggest winner, market_data[-1] is the biggest loser
    return Response({
        'top_gainer': market_data[0],     
        'top_loser': market_data[-1],     
        'assets': market_data             
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_assets(request):
    """
    Returns a lightweight list of all active assets for dropdown menus.
    """
    # .values() is super fast and returns a list of dictionaries directly!
    assets = Asset.objects.filter(is_active=True).values('symbol', 'name')
    return Response(list(assets))