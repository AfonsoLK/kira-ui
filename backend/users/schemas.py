from ninja import Schema 
from uuid import UUID
from datetime import datetime



class UserSchema(Schema):
    id: UUID
    username: str
    email: str
    password: str
    created_at: datetime
    updated_at: datetime

class UserCreateSchema(Schema):
    username: str
    email: str | None = None
    password: str | None = None

class UserUpdateSchema(Schema):
    username: str | None = None
    email: str | None = None
    password: str | None = None

class UserDeleteSchema(Schema):
    id: UUID

class UserDeleteResponseSchema(Schema):
    message: str = "User deleted successfully"