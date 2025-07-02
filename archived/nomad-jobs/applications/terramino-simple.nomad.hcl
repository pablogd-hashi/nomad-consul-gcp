job "terramino" {
  datacenters = ["dc1"]
  type        = "service"

  group "redis" {
    count = 1
    
    network {
      port "redis" {
        static = 6379
      }
    }

    service {
      name = "terramino-redis"
      port = "redis"
      tags = ["redis", "database"]

      check {
        name     = "Redis TCP"
        type     = "tcp"
        port     = "redis"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:7-alpine"
        ports = ["redis"]
        args  = ["redis-server", "--appendonly", "yes"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  group "backend" {
    count = 1
    
    network {
      port "backend" {
        static = 8082
      }
    }

    service {
      name = "terramino-backend"
      port = "backend"
      tags = ["backend", "api"]

      check {
        name     = "Backend HTTP"
        type     = "http"
        path     = "/"
        port     = "backend"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "backend" {
      driver = "docker"

      template {
        data = <<EOF
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"encoding/json"
	"context"
	"github.com/go-redis/redis/v8"
)

var rdb *redis.Client
var ctx = context.Background()

type Score struct {
	Name  string `json:"name"`
	Score int    `json:"score"`
}

func main() {
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		redisHost = "localhost"
	}
	redisPort := os.Getenv("REDIS_PORT")
	if redisPort == "" {
		redisPort = "6379"
	}

	rdb = redis.NewClient(&redis.Options{
		Addr: redisHost + ":" + redisPort,
	})

	_, err := rdb.Ping(ctx).Result()
	if err != nil {
		log.Printf("Redis connection failed: %v", err)
	} else {
		log.Println("Connected to Redis successfully")
	}

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/env", envHandler)
	http.HandleFunc("/redis", redisHandler)
	http.HandleFunc("/score", scoreHandler)
	http.HandleFunc("/health", healthHandler)

	port := os.Getenv("TERRAMINO_PORT")
	if port == "" {
		port = "8082"
	}

	log.Printf("Terramino backend starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"service": "Terramino Backend API",
		"status":  "running",
		"version": "1.0.0",
	})
}

func envHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	env := map[string]string{
		"REDIS_HOST":      os.Getenv("REDIS_HOST"),
		"REDIS_PORT":      os.Getenv("REDIS_PORT"),
		"TERRAMINO_PORT":  os.Getenv("TERRAMINO_PORT"),
		"NOMAD_ALLOC_ID":  os.Getenv("NOMAD_ALLOC_ID"),
		"NOMAD_JOB_NAME":  os.Getenv("NOMAD_JOB_NAME"),
	}
	json.NewEncoder(w).Encode(env)
}

func redisHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	if rdb == nil {
		json.NewEncoder(w).Encode(map[string]string{"error": "Redis not initialized"})
		return
	}

	pong, err := rdb.Ping(ctx).Result()
	status := map[string]interface{}{
		"redis_host": os.Getenv("REDIS_HOST"),
		"redis_port": os.Getenv("REDIS_PORT"),
		"ping":       pong,
		"connected":  err == nil,
	}
	
	if err != nil {
		status["error"] = err.Error()
	}
	
	json.NewEncoder(w).Encode(status)
}

func scoreHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	if rdb == nil {
		json.NewEncoder(w).Encode(map[string]string{"error": "Redis not available"})
		return
	}

	switch r.Method {
	case "GET":
		scores, err := rdb.ZRevRangeWithScores(ctx, "highscores", 0, 9).Result()
		if err != nil {
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		
		var highScores []Score
		for _, score := range scores {
			highScores = append(highScores, Score{
				Name:  score.Member.(string),
				Score: int(score.Score),
			})
		}
		json.NewEncoder(w).Encode(highScores)
		
	case "POST":
		var score Score
		if err := json.NewDecoder(r.Body).Decode(&score); err != nil {
			json.NewEncoder(w).Encode(map[string]string{"error": "Invalid JSON"})
			return
		}
		
		err := rdb.ZAdd(ctx, "highscores", &redis.Z{
			Score:  float64(score.Score),
			Member: score.Name,
		}).Err()
		
		if err != nil {
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		
		json.NewEncoder(w).Encode(map[string]string{"status": "Score added successfully"})
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}
EOF
        destination = "/tmp/main.go"
      }

      template {
        data = <<EOF
module terramino

go 1.22

require github.com/go-redis/redis/v8 v8.11.5

require (
	github.com/cespare/xxhash/v2 v2.1.2 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
)
EOF
        destination = "/tmp/go.mod"
      }

      config {
        image = "golang:1.22-alpine"
        ports = ["backend"]
        
        command = "sh"
        args = ["-c", "cd /tmp && go mod tidy && go run main.go"]
      }

      env {
        REDIS_HOST       = "terramino-redis.service.consul"
        REDIS_PORT       = "6379"
        TERRAMINO_PORT   = "8082"
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  group "frontend" {
    count = 1
    
    network {
      port "frontend" {
        static = 8081
      }
    }

    service {
      name = "terramino-frontend"
      port = "frontend"
      tags = ["frontend", "web", "urlprefix-/"]

      check {
        name     = "Frontend HTTP"
        type     = "http"
        path     = "/health"
        port     = "frontend"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "frontend" {
      driver = "docker"

      template {
        data = <<EOF
server {
    listen 8081;
    server_name _;

    location /health {
        access_log off;
        add_header Content-Type application/json;
        return 200 "{\"status\":\"OK\"}";
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location ~ ^/(redis|score|env)$ {
        proxy_pass http://terramino-backend.service.consul:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_connect_timeout 10s;
        proxy_read_timeout 10s;
        proxy_send_timeout 10s;
        proxy_intercept_errors on;
        error_page 502 503 504 = @backend_down;
    }

    location @backend_down {
        default_type application/json;
        return 503 "{\"error\":\"Backend service unavailable\"}";
    }
}
EOF
        destination = "local/nginx.conf"
      }

      template {
        data = <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terramino Game</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 {
            text-align: center;
            font-size: 3em;
            margin-bottom: 30px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .card {
            background: rgba(255,255,255,0.15);
            padding: 20px;
            border-radius: 10px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .card h3 {
            margin-top: 0;
            color: #ffd700;
        }
        a {
            color: #4CAF50;
            text-decoration: none;
            font-weight: bold;
        }
        a:hover {
            color: #45a049;
            text-decoration: underline;
        }
        .status {
            padding: 10px;
            margin: 10px 0;
            border-radius: 5px;
            background: rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎮 Terramino Game</h1>
        
        <div style="text-align: center; padding: 20px;">
            <p style="font-size: 1.2em;">HashiCorp Demo Application</p>
            <p>A Tetris-like game built with Go backend and Redis for high scores</p>
        </div>

        <div class="grid">
            <div class="card">
                <h3>🎯 Application Components</h3>
                <p>This is a demonstration of a multi-tier application running on Nomad:</p>
                <ul>
                    <li>🔴 Redis Database (port 6379)</li>
                    <li>🟡 Go Backend API (port 8080)</li>
                    <li>🔵 Nginx Frontend (port 8081)</li>
                </ul>
                <p>All services communicate via Consul service discovery.</p>
            </div>

            <div class="card">
                <h3>🔧 API Endpoints</h3>
                <p>Test the backend API directly:</p>
                <ul>
                    <li><a href="/redis" target="_blank">Redis Status</a> - Check database connection</li>
                    <li><a href="/score" target="_blank">High Scores</a> - View JSON scores data</li>
                    <li><a href="/env" target="_blank">Environment</a> - View runtime environment</li>
                </ul>
            </div>

            <div class="card">
                <h3>🏆 Score Management</h3>
                <p>Add scores via API:</p>
                <pre>
# Get scores
curl http://your-frontend:8081/score

# Add a score
curl -X POST http://your-frontend:8081/score \
  -H "Content-Type: application/json" \
  -d '{"name":"Player1","score":1000}'
                </pre>
            </div>

            <div class="card">
                <h3>📊 Health Checks</h3>
                <p>All services include health monitoring:</p>
                <ul>
                    <li>Frontend: <a href="/health">/health</a></li>
                    <li>Backend: HTTP checks on root endpoint</li>
                    <li>Redis: TCP connection checks</li>
                </ul>
            </div>
        </div>
    </div>
</body>
</html>
EOF
        destination = "local/index.html"
      }

      config {
        image = "nginx:alpine"
        ports = ["frontend"]
        
        volumes = [
          "local/nginx.conf:/etc/nginx/conf.d/default.conf",
          "local/index.html:/usr/share/nginx/html/index.html"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}