def normalize_username(username):
    name = username.strip()
    if len(name) < 3:
        raise ValueError("username too short")
    if len(name) > 24:
        raise ValueError("username too long")
    return name.lower()
