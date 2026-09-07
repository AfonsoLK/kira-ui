from django.contrib.auth import authenticate, get_user_model
from ninja import Router
from ninja.errors import HttpError
 
from authentication.auth import AuthBearer
from authentication.models import AuthToken, UserAuthentication
from authentication.schemas import EmailLoginSchema, GoogleLoginSchema, TokenSchema
 
User = get_user_model()
api = Router()
auth = AuthBearer()


@api.post("/login/email", response=TokenSchema)
def login_email(request, payload: EmailLoginSchema):
    user = authenticate(request, email=payload.email, password=payload.password )

    if user is None:
        raise HttpError(401, "Email ou senha inválidos")

    UserAuthentication.objects.get_or_create(
        user=user,
        provider=UserAuthentication.provider.EMAIL,
        provider_id=payload.email
    )

    token = AuthToken.objects.create(user=user)

    return TokenSchema(token=token.key)


@api.post("/logout", auth=auth)
def logout(request):
    token_key = request.hearders.get("Authorization", "").removeprefix("Bearer").strip()
    AuthToken.objects.filter(key=token_key).delete()
    return {"message": "Logout realizado com sucesso"}