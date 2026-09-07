from ninja.security import HttpBearer

from authentication.models import AuthToken

class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        try:
            auth_token = AuthToken.objects.select_related("user").get(key=token)
        except AuthToken.DoesNotExist:
            return None
        return auth_token.user