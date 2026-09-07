from ninja import Router

api = Router()

@api.get("/")
def hello_world(request):
    return {"message": "Hello, posts!"}