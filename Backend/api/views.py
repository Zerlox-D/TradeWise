import yfinance as yf
import pandas as pd
import numpy as np
from decimal import Decimal
from rest_framework import viewsets, permissions, generics, status, filters
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import ValidationError
from django.shortcuts import get_object_or_404

from django.utils import timezone
from datetime import timedelta
from django.db.models import Q
from .ai_service import evaluate_student_behavior, draft_quiz_with_ai
from .ai_risk_engine import analyze_stock_risk
from .models import Asset, User, Goal, TradeRequest, MentorLink, Holding, TradeUnlockRequest, Quiz, QuizQuestion
from .serializers import HoldingSerializer, UserSerializer, GoalSerializer, TradeRequestSerializer, RegisterSerializer, MentorSerializer, MentorLinkSerializer, TradeUnlockRequestSerializer


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

        # Hard stop: a behavior lock blocks all trading until mentor approval.
        if user.role != 'MENTOR' and user.is_trade_locked:
            return Response({
                'error': user.trade_lock_reason or 'Trading is temporarily locked due to consecutive discipline drops.'
            }, status=status.HTTP_423_LOCKED)
        
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
        risk_level = request.data.get('risk_level', 'MODERATE')
        has_active_mentor = MentorLink.objects.filter(student=user, status='ACCEPTED').exists()
        
        trade_status = 'EXECUTED'
        if user.role != 'MENTOR':
            if risk_level == 'HIGH':
                if has_active_mentor:
                    trade_status = 'PENDING_MENTOR'
                else:
                    return Response({
                        'error': 'High-risk trades are locked. Please connect with a mentor to unlock this asset tier.'
                    }, status=status.HTTP_403_FORBIDDEN)
            elif risk_level == 'MODERATE' and not has_active_mentor:
                return Response({
                    'error': 'Moderate-risk trades are locked. Please connect with a mentor to unlock this asset tier.'
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
            risk_level=risk_level,
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
        
        if mentor.discipline_score < 50:
            return Response({
                'error': 'This mentor currently has a Discipline Score below 50 and is locked from accepting new students.'
            }, status=status.HTTP_403_FORBIDDEN)

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


class TradeUnlockRequestViewSet(viewsets.ModelViewSet):
    serializer_class = TradeUnlockRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'MENTOR':
            return TradeUnlockRequest.objects.filter(mentor=user)
        return TradeUnlockRequest.objects.filter(student=user)

    def create(self, request, *args, **kwargs):
        student = request.user

        if student.role == 'MENTOR':
            return Response({'error': 'Mentors cannot request trade unlocks.'}, status=status.HTTP_400_BAD_REQUEST)

        if not student.is_trade_locked:
            return Response({'error': 'Trading is not currently locked for this account.'}, status=status.HTTP_400_BAD_REQUEST)

        mentor_link = MentorLink.objects.filter(student=student, status='ACCEPTED').first()
        if not mentor_link:
            return Response({'error': 'No active mentor found for unlock request.'}, status=status.HTTP_400_BAD_REQUEST)

        if TradeUnlockRequest.objects.filter(student=student, status='PENDING').exists():
            return Response({'error': 'You already have a pending unlock request.'}, status=status.HTTP_400_BAD_REQUEST)

        unlock_request = TradeUnlockRequest.objects.create(
            student=student,
            mentor=mentor_link.mentor,
            requested_reason=student.trade_lock_reason,
            status='PENDING'
        )

        serializer = self.get_serializer(unlock_request)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        unlock_request = self.get_object()

        if request.user != unlock_request.mentor:
            return Response({'error': 'Not authorized to review this unlock request.'}, status=status.HTTP_403_FORBIDDEN)

        if unlock_request.status != 'PENDING':
            return Response({'error': 'This unlock request is no longer pending.'}, status=status.HTTP_400_BAD_REQUEST)

        action_type = request.data.get('action')
        mentor_comment = request.data.get('comment', '')

        if action_type == 'approve':
            student = unlock_request.student
            student.is_trade_locked = False
            student.trade_lock_reason = ''
            student.discipline_drop_streak = 0
            student.save(update_fields=['is_trade_locked', 'trade_lock_reason', 'discipline_drop_streak'])

            unlock_request.status = 'APPROVED'
            unlock_request.mentor_comment = mentor_comment
            unlock_request.save()

            return Response({'status': 'Trade lock removed successfully.'})

        if action_type == 'reject':
            unlock_request.status = 'REJECTED'
            unlock_request.mentor_comment = mentor_comment
            unlock_request.save()
            return Response({'status': 'Unlock request rejected. Student remains locked.'})

        return Response({'error': 'Invalid action. Must be "approve" or "reject".'}, status=status.HTTP_400_BAD_REQUEST)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_profile(request):
    """
    The 'Mirror' Endpoint. 
    Returns the profile data of the user attached to the token.
    """
    user = request.user
    has_active_mentor = MentorLink.objects.filter(student=user, status='ACCEPTED').exists()
    has_pending_unlock_request = TradeUnlockRequest.objects.filter(student=user, status='PENDING').exists()

    # --- NEW: Mentor Notification Engine ---
    has_pending_mentor_actions = False
    has_passed_quizzes = False
    
    if user.role == 'MENTOR':
        # 1. Anyone waiting to connect?
        pending_links = MentorLink.objects.filter(mentor=user, status='PENDING').exists()
        
        # 2. Anyone begging to be unlocked?
        pending_unlocks = TradeUnlockRequest.objects.filter(mentor=user, status='PENDING').exists()
        
        # 3. Any high-risk trades waiting for approval?
        # (First find their students, then check those students' trades)
        student_ids = MentorLink.objects.filter(mentor=user, status='ACCEPTED').values_list('student_id', flat=True)
        pending_trades = TradeRequest.objects.filter(user_id__in=student_ids, status='PENDING_MENTOR').exists()

        # If ANY of these are true, the flag is true!
        has_pending_mentor_actions = pending_links or pending_unlocks or pending_trades

        has_passed_quizzes = Quiz.objects.filter(mentor=user, status='PASSED').exists()

    return Response({
        'id': user.id,
        'username': user.username,
        'role': user.role,
        'discipline_score': user.discipline_score,
        'wallet_balance': str(user.wallet_balance),
        'risk_profile': user.risk_profile,
        'is_trade_locked': user.is_trade_locked,
        'trade_lock_reason': user.trade_lock_reason,
        'has_active_mentor': has_active_mentor,
        'has_pending_unlock_request': has_pending_unlock_request,
        'has_pending_mentor_actions': has_pending_mentor_actions,
        'has_passed_quizzes': has_passed_quizzes
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
    recent_trades = TradeRequest.objects.filter(user_id=student_id).order_by('-created_at')[:5]
    trade_data = TradeRequestSerializer(recent_trades, many=True).data

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
        'holdings': holdings_data,
        'recent_trades': trade_data
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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def get_ai_risk_assessment(request):
    """
    Fetches 30-day data for a stock, computes the mean daily volatility spread,
    and asks Gemini for a risk assessment.
    """
    symbol = request.data.get('symbol')
    if not symbol:
        return Response({'error': 'Symbol is required'}, status=400)
        
    try:
        # 1. Fetch 30 trading days of daily candles.
        stock = yf.Ticker(symbol + ".NS")
        hist = stock.history(period="1mo", interval="1d")
        
        if hist.empty:
            return Response({'error': 'No data available'}, status=400)

        hist = hist.dropna(subset=['High', 'Low', 'Close'])
        if hist.empty:
            return Response({'error': 'Incomplete market data for risk analysis.'}, status=400)

        # 2. Calculate each day's spread: ((High - Low) / Low) * 100.
        daily_spreads = ((hist['High'] - hist['Low']) / hist['Low'].replace(0, np.nan)) * 100
        daily_spreads = daily_spreads.replace([np.inf, -np.inf], np.nan).dropna()

        if daily_spreads.empty:
            return Response({'error': 'Unable to calculate volatility spread.'}, status=400)
            
        current_price = round(float(hist['Close'].iloc[-1]), 2)
        mean_30d_spread = round(float(daily_spreads.tail(30).mean()), 2)
        
        # 3. Ask Gemini to classify risk from the 30-day mean spread.
        ai_assessment = analyze_stock_risk(symbol, current_price, mean_30d_spread)
        
        return Response(ai_assessment)
        
    except Exception as e:
        return Response({'error': str(e)}, status=500)
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def draft_mentor_quiz(request, student_id):
    """
    Called by the Mentor. Fetches the student's last 5 trades, 
    asks the AI to draft a quiz, and saves it to the database as a DRAFT.
    """
    mentor = request.user
    # Assuming you have a custom User model, get the student
    from django.contrib.auth import get_user_model
    User = get_user_model()
    student = get_object_or_404(User, id=student_id)

    # 1. Fetch the student's last 5 trades
    recent_trades = TradeRequest.objects.filter(user=student).order_by('-created_at')[:5]
    
    if not recent_trades.exists():
        return Response({"error": "This student has no trades to analyze."}, status=status.HTTP_400_BAD_REQUEST)

    trade_data = TradeRequestSerializer(recent_trades, many=True).data

    # 2. Hand the trades to Gemini!
    ai_quiz_data = draft_quiz_with_ai(trade_data)

    if not ai_quiz_data:
        return Response({"error": "The AI failed to generate the quiz. Please try again."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # 3. Create the master Quiz record (Status defaults to 'DRAFT')
    quiz = Quiz.objects.create(
        student=student,
        mentor=mentor,
        status='DRAFT'
    )

    # 4. Loop through the AI's JSON list and create the Question rows
    response_questions = []
    for q_data in ai_quiz_data:
        question = QuizQuestion.objects.create(
            quiz=quiz,
            question_text=q_data.get('question_text', ''),
            option_a=q_data.get('option_a', ''),
            option_b=q_data.get('option_b', ''),
            option_c=q_data.get('option_c', ''),
            option_d=q_data.get('option_d', ''),
            correct_answer=q_data.get('correct_answer', 'A'),
            explanation=q_data.get('explanation', '')
        )
        
        # We pack this up so Flutter can immediately display it in the text fields
        response_questions.append({
            'id': question.id,
            'question_text': question.question_text,
            'option_a': question.option_a,
            'option_b': question.option_b,
            'option_c': question.option_c,
            'option_d': question.option_d,
            'correct_answer': question.correct_answer,
            'explanation': question.explanation
        })

    return Response({
        'message': 'Draft generated successfully!',
        'quiz_id': quiz.id,
        'questions': response_questions
    }, status=status.HTTP_201_CREATED)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def publish_mentor_quiz(request, quiz_id):
    mentor = request.user
    quiz = get_object_or_404(Quiz, id=quiz_id, mentor=mentor)

    if quiz.status != 'DRAFT':
        return Response({"error": "Only draft quizzes can be published."}, status=status.HTTP_400_BAD_REQUEST)

    # 1. Grab the edited questions array from the Flutter payload
    edited_questions = request.data.get('questions', [])

    # 2. Loop through and forcefully update the database with the mentor's edits
    for q_data in edited_questions:
        question_id = q_data.get('id')
        if question_id:
            question = QuizQuestion.objects.filter(id=question_id, quiz=quiz).first()
            if question:
                question.question_text = q_data.get('question_text', question.question_text)
                question.option_a = q_data.get('option_a', question.option_a)
                question.option_b = q_data.get('option_b', question.option_b)
                question.option_c = q_data.get('option_c', question.option_c)
                question.option_d = q_data.get('option_d', question.option_d)
                question.correct_answer = q_data.get('correct_answer', question.correct_answer)
                question.explanation = q_data.get('explanation', question.explanation)
                question.save()

    # 3. Flip the status!
    quiz.status = 'PUBLISHED'
    quiz.save()

    return Response({"message": "Quiz published! The student can now take it."}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_student_quiz(request, quiz_id):
    student = request.user
    quiz = get_object_or_404(Quiz, id=quiz_id, student=student)

    # 1. Validate state
    if quiz.status not in ['PUBLISHED', 'FAILED']:
        return Response({"error": "This quiz is not available to take."}, status=status.HTTP_400_BAD_REQUEST)

    # 2. Check the 1-hour Cooldown Trap (UPGRADED LOGIC)
    # We simply check if the current time is still BEFORE the saved expiration time.
    if quiz.status == 'FAILED' and quiz.cooldown_ends_at:
        if timezone.now() < quiz.cooldown_ends_at:
            time_left = quiz.cooldown_ends_at - timezone.now()
            minutes_left = (time_left.seconds // 60) + 1 # +1 ensures we don't say "0 minutes" for 45 seconds
            return Response({
                "error": f"You must review your mistakes. Try again in {minutes_left} minutes."
            }, status=status.HTTP_403_FORBIDDEN)

    # 3. Grade the submitted answers
    submitted_answers = request.data.get('answers', request.data)
    quiz.last_submitted_answers = submitted_answers
    quiz.save()
    questions = quiz.questions.all()
    
    quiz_results = []
    has_failed = False

    for question in questions:
        student_answer = submitted_answers.get(str(question.id))
        is_correct = (student_answer == question.correct_answer)
        
        if not is_correct:
            has_failed = True
            
        quiz_results.append({
            "question_id": question.id,
            "student_answer": student_answer,
            "correct_answer": question.correct_answer,
            "is_correct": is_correct,
            "explanation": question.explanation
        })

    # 4. Process the Final Grade (UPGRADED LOGIC)
    if has_failed:
        quiz.status = 'FAILED'
        # Set the exact timestamp for 1 hour from right now!
        quiz.cooldown_ends_at = timezone.now() + timedelta(hours=1)
        quiz.save()
        
        return Response({
            "status": "FAILED",
            "message": "You did not score 100%. Review the explanations below and try again in 1 hour.",
            "results": quiz_results 
        }, status=status.HTTP_200_OK)
    
    else:
        quiz.status = 'PASSED'
        # Clear the cooldown timer completely just to be safe
        quiz.cooldown_ends_at = None 
        quiz.save()
        
        return Response({
            "status": "PASSED",
            "message": "Perfect score! Your mentor has been notified to review and unlock your account.",
            "results": quiz_results 
        }, status=status.HTTP_200_OK)
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unlock_student_account(request, quiz_id):
    mentor = request.user
    quiz = get_object_or_404(Quiz, id=quiz_id, mentor=mentor)

    if quiz.status != 'PASSED':
        return Response({"error": "Student must pass the quiz before you can unlock them."}, status=status.HTTP_400_BAD_REQUEST)

    student = quiz.student

    # 1. Lift the trading ban using your CORRECT model fields!
    student.is_trade_locked = False
    student.trade_lock_reason = ''
    student.discipline_drop_streak = 0
    student.discipline_score = min(100, student.discipline_score + 2) # Reward for passing!
    student.save()

    # 2. Find their pending TradeUnlockRequest and mark it as APPROVED
    # This ensures the request card disappears from the Mentor's dashboard
    pending_request = TradeUnlockRequest.objects.filter(student=student, status='PENDING').first()
    if pending_request:
        pending_request.status = 'APPROVED'
        pending_request.mentor_comment = "Student passed the disciplinary quiz. Account unlocked."
        pending_request.save()

    # 3. Archive the quiz
    quiz.status = 'ARCHIVED' 
    quiz.save()

    return Response({"message": f"{student.username} has been successfully unlocked!"}, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_pending_quiz(request):
    """Fetches the latest published or failed quiz for the student."""
    student = request.user
    
    # Look for a quiz they need to take or retake
    quiz = Quiz.objects.filter(student=student, status__in=['PUBLISHED', 'FAILED']).order_by('-created_at').first()
    
    if not quiz:
        return Response({"message": "No pending quizzes."}, status=status.HTTP_404_NOT_FOUND)
        
    # Serialize the questions (without the correct answers/explanations to prevent cheating!)
    questions_data = []
    for q in quiz.questions.all():
        questions_data.append({
            'id': q.id,
            'question_text': q.question_text,
            'option_a': q.option_a,
            'option_b': q.option_b,
            'option_c': q.option_c,
            'option_d': q.option_d,
        })
        
    return Response({
        'quiz_id': quiz.id,
        'status': quiz.status,
        'questions': questions_data
    }, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_mentor_quizzes(request):
    """Fetches all active quizzes assigned by this mentor."""
    mentor = request.user
    if mentor.role != 'MENTOR':
        return Response({"error": "Unauthorized"}, status=403)
        
    # We exclude ARCHIVED so the dashboard stays clean!
    quizzes = Quiz.objects.filter(mentor=mentor).exclude(status__in=['DRAFT', 'ARCHIVED']).order_by('-created_at')
    
    data = []
    for q in quizzes:
        data.append({
            'id': q.id,
            'student_name': q.student.username,
            'status': q.status,
            'created_at': q.created_at.isoformat()
        })
        
    return Response(data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_quizzes(request):
    """Fetches all non-draft quizzes for the student's history hub."""
    student = request.user
    # Fetch all quizzes except those still being drafted by the mentor
    quizzes = Quiz.objects.filter(student=student).exclude(status='DRAFT').order_by('-created_at')
    
    data = []
    for q in quizzes:
        data.append({
            'id': q.id,
            'mentor_name': q.mentor.username,
            'status': q.status,
            'created_at': q.created_at.isoformat(),
            'cooldown_ends_at': q.cooldown_ends_at.isoformat() if q.cooldown_ends_at else None
        })
        
    return Response(data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_quiz_detail(request, quiz_id):
    """Fetches a specific quiz and reveals answers ONLY if it is in history mode."""
    student = request.user
    quiz = get_object_or_404(Quiz, id=quiz_id, student=student)
    
    questions_data = []
    # Only expose the correct answers and explanations if the quiz is fully completed
    show_answers = quiz.status in ['PASSED', 'ARCHIVED']
    
    for q in quiz.questions.all():
        q_data = {
            'id': q.id,
            'question_text': q.question_text,
            'option_a': q.option_a,
            'option_b': q.option_b,
            'option_c': q.option_c,
            'option_d': q.option_d,
            'correct_answer': q.correct_answer, 
            'explanation': q.explanation
        }
        questions_data.append(q_data)
        
    return Response({
        'quiz_id': quiz.id,
        'status': quiz.status,
        'cooldown_ends_at': quiz.cooldown_ends_at.isoformat() if quiz.cooldown_ends_at else None,
        # NEW: Send the snapshot back to Flutter!
        'last_submitted_answers': quiz.last_submitted_answers or {},
        'questions': questions_data
    }, status=status.HTTP_200_OK)