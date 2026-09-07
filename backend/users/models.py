from django.db import models
from django.contrib.auth.models import AbstractUser
import uuid
# Create your models here.
class Role(models.TextChoices):
    USER = "user"
    ADMIN = "admin"

class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    profile_picture = models.ImageField(upload_to="profile_pictures/", null=True, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.USER)