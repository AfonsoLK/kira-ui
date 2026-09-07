from ninja import Router
from ninja.errors import HttpError
from django.shortcuts import get_object_or_404
from django.contrib.auth.hashers import make_password
from uuid import UUID
from typing import List
 
from authentication.auth import AuthBearer
from users.models import User
from users.schemas import (
    UserSchema,
    UserCreateSchema,
    UserUpdateSchema,
    UserDeleteResponseSchema,
)
 
api = Router()
auth = AuthBearer()

def check_modifier(request, user_id: UUID):
    if not (request.auth.is_staff or str(request.auth.id) == str(user_id)):
        raise HttpError(403, "Você não tem permissão para acessar este recurso.")

@api.get("/get-users", response=List[UserSchema], auth=auth)
def get_users(request):
    if not request.auth.is_staff:
        raise HttpError(403, "Apenas staff pode listar todos os usuários.")
    return User.objects.all()
 
 
@api.get("/get-user/{user_id}", response=UserSchema, auth=auth)
def get_user(request, user_id: UUID):
    check_modifier(request, user_id)
    user = get_object_or_404(User, id=user_id)
    return user
 
 
@api.delete("/delete-user/{user_id}", response=UserDeleteResponseSchema, auth=auth)
def delete_user(request, user_id: UUID):
    check_modifier(request, user_id)
    user = get_object_or_404(User, id=user_id)
    user.delete()
    return UserDeleteResponseSchema(message="User deleted successfully")
 
 
@api.put("/update-user/{user_id}", response=UserSchema, auth=auth)
def update_user(request, user_id: UUID, payload: UserUpdateSchema):
    check_modifier(request, user_id)
    user = get_object_or_404(User, id=user_id)
 
    data = payload.dict(exclude_unset=True)
    if "password" in data:
        data["password"] = make_password(data["password"])
 
    for field, value in data.items():
        setattr(user, field, value)
    user.save()
 
    return user
 
 
@api.post("/create-user", response=UserSchema)
def create_user(request, payload: UserCreateSchema):
    data = payload.dict()
    data["password"] = make_password(data["password"])
    user = User.objects.create(**data)
    return user

