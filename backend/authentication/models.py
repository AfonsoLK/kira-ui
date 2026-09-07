import secrets

from django.db import models
from django.conf import settings



class UserAuthentication(models.Model):
    class Provider(models.TextChoices):
        EMAIL = "email"
        GOOGLE = "google"
        APPLE = "apple"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="authentications")
    provider = models.CharField(max_length=20, choices=Provider.choices)
    provider_id = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["provider", "provider_id"],
                name="unique_authentication"
            )
        ]

class AuthToken(models.Model):
    key = models.CharField(max_length=64, unique=True, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="auth_tokens")
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.key:
            self.key = secrets.token_hex(32)
        super().save(*args, **kwargs)
