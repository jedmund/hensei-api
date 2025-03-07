# Fetch environment variables with defaults if not set
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost')
redis_port = ENV.fetch('REDISPORT', '6379')

# Combine URL and port (adjust the path/DB as needed)
full_redis_url = "#{redis_url}/0"

# Initialize Redis using the constructed URL
$redis = Redis.new(url: full_redis_url)
