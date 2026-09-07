from ninja import Schema
 
 
class EmailLoginSchema(Schema):
    email: str
    password: str
 
 
class GoogleLoginSchema(Schema):
    id_token: str  
 
 
class TokenSchema(Schema):
    token: str
 