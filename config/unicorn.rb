working_directory "/var/www/huddleapp"

# Unicorn PID file location
# pid "/path/to/pids/unicorn.pid"
pid "/var/www/huddleapp/pids/unicorn.pid"

# Path to logs
# stderr_path "/path/to/logs/unicorn.log"
# stdout_path "/path/to/logs/unicorn.log"
stderr_path "/var/www/huddleapp/logs/unicorn.log"
stdout_path "/var/www/huddleapp/logs/unicorn.log"

# Unicorn socket
# listen "/tmp/unicorn.[app name].sock"
listen "/tmp/unicorn.huddleapp.sock"

# Number of processes
# worker_processes 4
worker_processes 2

# Time-out
timeout 30
