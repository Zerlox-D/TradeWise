from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework.authtoken.views import obtain_auth_token
from .views import MentorLinkViewSet, MentorListView, UserViewSet, GoalViewSet, TradeRequestViewSet, RegisterView, HoldingViewSet, TradeUnlockRequestViewSet
from . import views

router = DefaultRouter()

router.register(r'users', UserViewSet) # No basename needed for UserViewSet because queryset is defined
router.register(r'goals', GoalViewSet, basename='goal')
router.register(r'trades', TradeRequestViewSet, basename='traderequest')
router.register(r'mentor-links', MentorLinkViewSet, basename='mentor-links')
router.register(r'holdings', views.HoldingViewSet, basename='holdings')
router.register(r'trade-unlock-requests', TradeUnlockRequestViewSet, basename='trade-unlock-requests')

urlpatterns = [
    path('', include(router.urls)),
    path('register/', RegisterView.as_view(), name='register'),
    path('mentors/', MentorListView.as_view(), name='mentor-list'),
    path('login/', obtain_auth_token, name='api_token_auth'),
    path('profile/me/', views.get_user_profile, name='profile-me'),
    path('stock-price/<str:symbol>/', views.get_live_price, name='stock-price'),
    path('stock-history/<str:symbol>/', views.get_stock_history, name='stock-history'),
    path('student-portfolio/<int:student_id>/', views.get_student_portfolio, name='student-portfolio'),
    path('market-overview/', views.get_market_overview, name='market-overview'),
    path('assets/', views.get_assets, name='assets'),
    path('ai-risk-assessment/', views.get_ai_risk_assessment, name='ai-risk-assessment'),
    path('quiz/draft/<int:student_id>/', views.draft_mentor_quiz, name='draft-mentor-quiz'),
    path('quiz/publish/<int:quiz_id>/', views.publish_mentor_quiz, name='publish_mentor_quiz'),
    path('quiz/submit/<int:quiz_id>/', views.submit_student_quiz, name='submit_student_quiz'),
    path('quiz/unlock/<int:quiz_id>/', views.unlock_student_account, name='unlock_student_account'),
    path('quiz/pending/', views.get_pending_quiz, name='pending-quiz'),
    path('quiz/mentor/', views.get_mentor_quizzes, name='mentor-quizzes'),
    path('quiz/mentor/<int:quiz_id>/', views.get_mentor_quiz_detail, name='mentor-quiz-detail'),
    path('quiz/student/', views.get_student_quizzes, name='student-quizzes'),
    path('quiz/student/<int:quiz_id>/', views.get_student_quiz_detail, name='student-quiz-detail'),
]