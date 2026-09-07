from ninja import NinjaAPI
from scalar_ninja import ScalarConfig, ScalarViewer
from users.api import api as users_api
from authentication.api import api as authentication_api
from posts.api import api as posts_api

scalar_config = ScalarConfig(
    force_dark_mode_state="dark",
)

api = NinjaAPI(docs=ScalarViewer(scalar_config))


api.add_router("users", users_api)
api.add_router("authentication", authentication_api)
api.add_router("posts", posts_api)