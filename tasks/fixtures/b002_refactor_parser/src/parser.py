def parse_csv_ints(value):
    pieces = value.split(",")
    cleaned = []
    for piece in pieces:
        token = piece.strip()
        if token == "":
            continue
        if token[0] == "+":
            token = token[1:]
        cleaned.append(int(token))
    return cleaned


def parse_pipe_ints(value):
    pieces = value.split("|")
    cleaned = []
    for piece in pieces:
        token = piece.strip()
        if token == "":
            continue
        if token[0] == "+":
            token = token[1:]
        cleaned.append(int(token))
    return cleaned
