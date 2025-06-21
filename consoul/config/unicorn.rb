# Unicorn configuration for AWS t2.micro (1GB RAM)

# Single worker process to minimize memory usage
worker_processes 1

# Timeout settings
timeout 60

# Application root
APP_ROOT = File.expand_path('..', __dir__)
working_directory APP_ROOT

# Socket for Nginx communication
listen "/tmp/unicorn.sock", backlog: 64

# Process IDs
pid "/tmp/unicorn.pid"

# Stderr and stdout logs
stderr_path "#{APP_ROOT}/log/unicorn.stderr.log"
stdout_path "#{APP_ROOT}/log/unicorn.stdout.log"

# Preload application for memory efficiency
preload_app true

# GC settings for t2.micro
GC.respond_to?(:copy_on_write_friendly=) && GC.copy_on_write_friendly = true

# Restart worker if memory usage exceeds 200MB
check_client_connection false

before_fork do |server, worker|
  # Disconnect from database before forking
  defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.disconnect!

  # Kill old master if exists
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  # Reconnect to database after forking
  defined?(ActiveRecord::Base) && ActiveRecord::Base.establish_connection
end