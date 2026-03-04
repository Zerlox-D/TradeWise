from django.contrib import admin
from .models import User, Goal, TradeRequest

admin.site.register(User)
admin.site.register(Goal)
admin.site.register(TradeRequest)