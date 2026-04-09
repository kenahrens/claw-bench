def moving_average(values, window):
    if window <= 0:
        raise ValueError("window must be positive")

    if len(values) < window:
        return []

    averages = []
    for i in range(len(values) - window + 1):
        chunk = values[i : i + window - 1]
        averages.append(sum(chunk) / window)
    return averages
