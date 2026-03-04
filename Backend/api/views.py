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
from .ai_service import evaluate_student_behavior
from .risk_engine import calculate_risk
from .models import User, Goal, TradeRequest, MentorLink, Holding
from .serializers import HoldingSerializer, UserSerializer, GoalSerializer, TradeRequestSerializer, RegisterSerializer, MentorSerializer, MentorLinkSerializer

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
            return TradeRequest.objects.filter(user__id__in=student_ids)
        else:
            return TradeRequest.objects.filter(user=user)

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

        # --- 3. CHECK BALANCE (If Buying) ---
        if transaction_type == 'BUY':
            if user.wallet_balance < total_cost:
                return Response({'error': 'Insufficient Funds'}, status=status.HTTP_400_BAD_REQUEST)

        # --- 4. RISK ENGINE CHECK 🚦 ---
        risk_color = calculate_risk(symbol, quantity, user.risk_profile)
        has_active_mentor = MentorLink.objects.filter(student=user, status='ACCEPTED').exists()
        
        trade_status = 'EXECUTED' 
        if risk_color == 'RED':
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

            elif transaction_type == 'SELL':
                holding = Holding.objects.get(user=user, symbol=symbol)
                
                # Calculate Realized Profit/Loss
                buy_value = holding.average_price * quantity
                sell_value = current_price * quantity
                realized_pl = sell_value - buy_value
                
                # Add money back to wallet
                user.wallet_balance += sell_value
                user.save()
                
                # Remove shares from Holding
                holding.total_quantity -= quantity
                holding.save()
                
                # Update Goal Progress (Behavioral impact)
                if goal_instance:
                    # If they made profit, current_amount goes up. If loss, it goes down.
                    goal_instance.current_amount += realized_pl
                    
                    # Prevent goal progress from going below zero
                    if goal_instance.current_amount < 0:
                        goal_instance.current_amount = Decimal('0.00')
                    goal_instance.save()
                
                # Save the loss amount to the trade receipt for the mentor to see
                if realized_pl < 0:
                    trade.loss_amount = abs(realized_pl)
                    trade.save()

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
            # Important: We must check the balance AGAIN, just in case the student 
            # spent their money on a different green-tier stock while waiting for approval!
            if trade.transaction_type == 'BUY':
                if student.wallet_balance < trade.total_amount:
                    return Response({'error': 'Student no longer has enough funds for this trade.'}, status=status.HTTP_400_BAD_REQUEST)
                
                # Deduct Money & Update Holdings (Just like standard execution)
                student.wallet_balance -= trade.total_amount
                
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
                # Important: Check if they sold it somewhere else while waiting
                try:
                    holding = Holding.objects.get(user=student, symbol=trade.symbol)
                    if holding.total_quantity < trade.quantity:
                        return Response({'error': 'Student no longer owns enough shares.'}, status=status.HTTP_400_BAD_REQUEST)
                    
                    buy_value = holding.average_price * trade.quantity
                    sell_value = trade.price_at_request * trade.quantity
                    realized_pl = sell_value - buy_value
                    
                    student.wallet_balance += sell_value
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

    def perform_create(self, serializer):
        student = self.request.user

        # 1. Block the student if they already have ANY active or pending request
        if MentorLink.objects.filter(student=student, status__in=['PENDING', 'ACCEPTED']).exists():
            raise ValidationError({'error': 'You already have a pending or active mentor connection.'})

        # 2. If they don't have any existing requests, proceed normally
        serializer.save(student=student, status='PENDING', is_active=False)

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