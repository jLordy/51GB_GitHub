"""OpenAPI request body examples for POST /api/register."""

REGISTER_REQUEST_EXAMPLES: dict = {
    "default": {
        "summary": "Standard registration",
        "value": {
            "email": "user@example.com",
            "password": "securepassword",
            "display_name": "Jane Doe",
        },
    },
}
