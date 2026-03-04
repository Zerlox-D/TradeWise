from rest_framework import serializers
from .models import User, Goal, TradeRequest, MentorLink, Holding
import datetime

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'date_of_birth', 'email', 'role', 'discipline_score', 'risk_profile']

class GoalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Goal
        fields = '__all__'
        read_only_fields = ['user']

class TradeRequestSerializer(serializers.ModelSerializer):
    goal_name = serializers.ReadOnlyField(source='goal.name')
    username = serializers.ReadOnlyField(source='user.username')
    
    class Meta:
        model = TradeRequest
        fields = [
            'id', 'user', 'username', 'goal', 'goal_name', 'symbol', 
            'transaction_type', 'quantity', 'price_at_request', 'total_amount',
            'justification', 'risk_level', 'status', 'loss_amount', 'mentor_comment', 
            'lock_expires_at', 'created_at'
        ]
        read_only_fields = [
            'user', 'price_at_request', 'total_amount', 'risk_level', 
            'status', 'loss_amount', 'mentor_comment', 'lock_expires_at'
        ]

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'date_of_birth', 'email', 'password', 'role']

    def create(self, validated_data):
        # password hashing
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            date_of_birth=validated_data.get('date_of_birth'),
            role=validated_data.get('role', 'INVESTOR')
        )
        return user
    
    def validate(self, data):
        """
        Check that the user is eligible for their selected role.
        """
        role = data.get('role', 'INVESTOR')
        dob = data.get('date_of_birth')

        if role == 'MENTOR' and dob:
            today = datetime.date.today()
            # Calculate Age
            age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
            
            if age < 21:
                raise serializers.ValidationError("You must be at least 21 years old to register as a Mentor.")
        
        return data
    
# 1. The "Business Card" for Search Results
class MentorSerializer(serializers.ModelSerializer):
    mentor_code = serializers.SerializerMethodField()
    class Meta:
        model = User
        fields = ['id', 'mentor_code', 'username', 'email', 'discipline_score', 'risk_profile']
    def get_mentor_code(self, obj):
        return 130200+obj.id

# 2. The "Contract" for the Link
class MentorLinkSerializer(serializers.ModelSerializer):
    student_name = serializers.ReadOnlyField(source='student.username')
    mentor_name = serializers.ReadOnlyField(source='mentor.username')

    class Meta:
        model = MentorLink
        fields = ['id', 'student', 'mentor', 'student_name', 'mentor_name', 'is_active', 'status', 'created_at']
        read_only_fields = ['student', 'is_active', 'status'] # Security: Student can't fake these

class HoldingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Holding
        fields = ['id', 'symbol', 'total_quantity', 'average_price']