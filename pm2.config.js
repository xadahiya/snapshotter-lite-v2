// this means if app restart {MAX_RESTART} times in 1 min then it stops
const NODE_ENV = process.env.NODE_ENV || 'development';
const CRON_RESTART = process.env.CRON_RESTART || 'false';
const MAX_RESTART = 3;
const MIN_UPTIME = 60000;


module.exports = {
  apps : [
    {
      name   : "snapshotter-lite",
      script : `poetry run python -m snapshotter.system_event_detector`,
      max_restarts: MAX_RESTART,
      min_uptime: MIN_UPTIME,
      error_file: "/dev/null",
      out_file: "/dev/null",
      env: {
        NODE_ENV: NODE_ENV,
      },
      cron_restart: "0 * * * *", // Restarts the process every hour at minute 0 (e.g. 1:00, 2:00, 3:00, etc)
      autorestart: true,
      kill_timeout: 5000,
      stop_exit_codes: [0, 143],
      treekill: true,
      listen_timeout: 10000,
    },
  ]
}

