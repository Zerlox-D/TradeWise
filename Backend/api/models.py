from django.conf import settings
from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """
    Custom User model that replaces the default Django User.
    Stores specific behavior metrics for TradeWise.
    """
    ROLE_CHOICES = (
        ('INVESTOR', 'Investor'),
        ('MENTOR', 'Mentor'),
    )
    
    # Basic fields
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='INVESTOR')
    
    # Gamification & Metrics (The "Behavior-First" logic)
    discipline_score = models.IntegerField(default=50)  # Starts at 50/100
    risk_profile = models.CharField(max_length=20, default='MODERATE')
    discipline_drop_streak = models.IntegerField(default=0)
    is_trade_locked = models.BooleanField(default=False)
    trade_lock_reason = models.TextField(blank=True, default='')

    date_of_birth = models.DateField(null=True, blank=True)

    wallet_balance = models.DecimalField(max_digits=12, decimal_places=2, default=50000.00)
    
    def __str__(self):
        return self.username


class Goal(models.Model):
    """
    Goal-Based Investing: Users must link trades to these goals.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='goals')
    name = models.CharField(max_length=100)  # e.g., "Education Fund"
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    current_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    deadline_date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class TradeRequest(models.Model):
    """
    The 'Intentional Friction' Layer. 
    Trades go here first before being executed.
    """
    TRANSACTION_TYPES = (('BUY', 'Buy'), ('SELL', 'Sell'))
    STATUS_CHOICES = (
        ('EXECUTED', 'Executed'),
        ('PENDING_MENTOR', 'Pending Mentor'),
        ('LOCKED_BY_LOSS', 'Locked (Loss Limit)'),
        ('REJECTED', 'Rejected'),
        ('QUIZ_REQUIRED', 'Quiz Required'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    goal = models.ForeignKey(Goal, on_delete=models.SET_NULL, null=True) # Link to goal
    
    symbol = models.CharField(max_length=10) # e.g., RELIANCE
    transaction_type = models.CharField(max_length=4, choices=TRANSACTION_TYPES)
    quantity = models.IntegerField()
    price_at_request = models.DecimalField(max_digits=10, decimal_places=2)
    
    # The Friction Mechanism
    justification = models.TextField(blank=True) # User must explain "Why?"
    lock_expires_at = models.DateTimeField(null=True, blank=True) # The Timer
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='EXECUTED')

    loss_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00) # Track loss on this trade
    brokerage_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00) # Track brokerage fee for this trade
    mentor_comment = models.TextField(blank=True, null=True) # Reason for locking/rejecting

    total_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True) # Total Bill
    
    created_at = models.DateTimeField(auto_now_add=True)

    RISK_CHOICES=(
        ('LOW', 'Low Risk'),
        ('MODERATE', 'Moderate Risk'),
        ('HIGH', 'High Risk'),
    )
    risk_level = models.CharField(max_length=10, choices=RISK_CHOICES, default='LOW')

    def __str__(self):
        return f"{self.transaction_type} {self.symbol} - {self.status}"
    

class MentorLink(models.Model):
    # Matches "student_id" and "mentor_id" from report
    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='mentorship_requests')
    mentor = models.ForeignKey(User, on_delete=models.CASCADE, related_name='student_requests')
    
    # Matches "is_active" from report 
    is_active = models.BooleanField(default=False) # Default False because it starts as a Request
    
    # Matches "permissions" from report 
    permissions = models.JSONField(default=dict) # defaults to {}

    # 👇 Added this to handle the "Request System"
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('ACCEPTED', 'Accepted'),
        ('REJECTED', 'Rejected'),
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('student', 'mentor') # Prevent duplicate requests

    def __str__(self):
        return f"{self.student.username} -> {self.mentor.username} ({self.status})"


class TradeUnlockRequest(models.Model):
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
    )

    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='trade_unlock_requests')
    mentor = models.ForeignKey(User, on_delete=models.CASCADE, related_name='trade_unlock_reviews')
    requested_reason = models.TextField(blank=True, default='')
    mentor_comment = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Unlock request: {self.student.username} -> {self.mentor.username} ({self.status})"
    

class Holding(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='holdings')
    symbol = models.CharField(max_length=20)
    total_quantity = models.IntegerField(default=0)
    average_price = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        unique_together = ('user', 'symbol') # A user should only have one holding row per stock symbol

    def __str__(self):
        return f"{self.user.username} - {self.symbol} ({self.total_quantity})"


class Asset(models.Model):
    symbol = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True) # Allows you to easily hide broken stocks later!

    def __str__(self):
        return f"{self.symbol} - {self.name}"


class Quiz(models.Model):
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),             # AI generated it, Mentor is reviewing/editing
        ('PUBLISHED', 'Published'),     # Mentor approved it, Student is locked and must take it
        ('PASSED', 'Passed'),           # Student scored 100%, waiting for Mentor to unlock them
        ('FAILED', 'Failed'),           # Student failed, sitting in the 1-hour cooldown
        ('ARCHIVED', 'Archived'),       # Old quizzes we want to keep for records but not show in the UI
    ]
    
    student = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='quizzes_taken', on_delete=models.CASCADE)
    mentor = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='quizzes_assigned', on_delete=models.CASCADE)
    
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    # We use this to enforce the 1-hour cooldown hurdle we discussed!
    last_attempt_at = models.DateTimeField(null=True, blank=True)
    last_submitted_answers = models.JSONField(null=True, blank=True, default=dict)
    cooldown_ends_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Quiz for {self.student.username} by {self.mentor.username} - {self.status}"


class QuizQuestion(models.Model):
    ANSWER_CHOICES = [
        ('A', 'A'), ('B', 'B'), ('C', 'C'), ('D', 'D')
    ]
    
    # related_name='questions' allows us to easily fetch all questions for a quiz using quiz.questions.all()
    quiz = models.ForeignKey(Quiz, related_name='questions', on_delete=models.CASCADE)
    
    question_text = models.TextField()
    option_a = models.CharField(max_length=255)
    option_b = models.CharField(max_length=255)
    option_c = models.CharField(max_length=255)
    option_d = models.CharField(max_length=255)
    
    correct_answer = models.CharField(max_length=1, choices=ANSWER_CHOICES)
    
    # Crucial for the learning loop: shown to the student ONLY if they fail
    explanation = models.TextField() 

    def __str__(self):
        return f"Question for Quiz {self.quiz.id}"