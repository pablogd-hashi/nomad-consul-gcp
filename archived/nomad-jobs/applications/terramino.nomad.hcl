variable "consul_domain" {
  description = "The consul domain for DNS. This is usually .consul in most configurations. Do not include the dot (.) in the value, just the name."
  default = "consul"
}

job "terramino" {
  datacenters = ["dc1"]
  type = "service"

  spread {
    attribute = "${node.datacenter}"
  }

  group "terramino-redis" {
    count = 1
    network {
      port "redis" {
        static = 6379
      }
    }

    service {
      name = "terramino-redis"
      port = "redis"

      check {
        name      = "Redis ready"
        type      = "tcp"
        port      = "redis"
        interval  = "5s"
        timeout   = "2s"
        on_update = "ignore_warnings"
      }
    }

    task "terramino-redis-task" {
      driver = "docker"

      config {
        image = "redis:alpine"
        ports = ["redis"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  group "terramino-backend" {
    count = 1
    network {
      port "backend" {
        static = 8100
      }
      dns {
        # Docker bridge
        servers = ["172.17.0.1"]
      }
    }

    service {
      name = "terramino-backend"
      port = "backend"

      check {
        type = "tcp"
        name = "terramino backend TCP"
        port = "backend"
        interval = "10s"
        timeout = "3s"
      }
    }

    task "terramino-backend-task" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["backend"]
      }
      
      env {
        REDIS_HOST = "terramino-redis.service.consul"
        REDIS_PORT = 6379
        TERRAMINO_PORT = 8100
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  group "terramino-frontend" {
    count = 1
    network {
      port "frontend" {
        static = 8101
        to = 8101
      }
      dns {
        servers = ["172.17.0.1"]
      }
    }

    service {
      name = "terramino-frontend"
      port = "frontend"

      check {
        type = "http"
        name = "terramino frontend Health"
        path = "/health"
        interval = "10s"
        timeout = "3s"
      }
    }

    task "terramino-frontend-task" {
      driver = "docker"

      # Create simple HTML content
      template {
        data = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Terramino - Demo Mode</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin: 50px; }
        .demo { background: #f0f0f0; padding: 20px; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="demo">
        <h1>🎮 Terramino Game</h1>
        <p>Demo deployment successful!</p>
        <p>Backend: <a href="/redis">Redis Connection</a></p>
        <p>Score API: <a href="/score">High Scores</a></p>
        <p>System Info: <a href="/info">Environment</a></p>
    </div>
</body>
</html>
EOF
        destination = "local/index.html"
      }

      config {
        image = "nginx:alpine"
        ports = ["frontend"]
        mount {
          type   = "bind"
          source = "local/index.html"
          target = "/usr/share/nginx/html/index.html"
        }
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }
      template {
        data        = <<EOF
          server {
            listen 8101;
            server_name {{ env "NOMAD_IP_frontend" }};

            # Add a health check endpoint that always returns OK
            location /health {
                access_log off;
                add_header Content-Type application/json;
                return 200 '{"status":"OK"}';
            }

            location / {
                root /usr/share/nginx/html;
                index index.html;
                try_files $uri $uri/ /index.html;
            }

            # Backend endpoints (temporarily disabled)
            location ~ ^/(redis|score|info|env) {
                default_type application/json;
                return 200 '{"status":"Demo mode - backend disabled"}';
            }
        } 
        EOF
        destination = "local/default.conf"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}