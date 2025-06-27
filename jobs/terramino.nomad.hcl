# jobs/terramino.nomad.hcl
job "terramino" {
  datacenters = ["dc1"]
  type = "service"

  group "terramino" {
    count = 2

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "terramino"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.terramino.rule=Host(`terramino.hashistack.local`)",
        "traefik.http.routers.terramino.service=terramino",
        "traefik.http.services.terramino.loadbalancer.server.port=80"
      ]
      port = "http"
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "terramino-app" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
        
        volumes = [
          "local/app:/usr/share/nginx/html",
          "local/nginx.conf:/etc/nginx/conf.d/default.conf"
        ]
      }

      template {
        data = <<EOF
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF
        destination = "local/nginx.conf"
      }

      artifact {
        source = "https://github.com/hashicorp-education/learn-terramino/archive/refs/heads/main.zip"
        destination = "local/"
        mode = "any"
      }

      template {
        data = <<EOF
#!/bin/bash
cd /local
unzip -o main.zip
cp -r learn-terramino-main/* app/
rm -rf learn-terramino-main main.zip
EOF
        destination = "local/setup.sh"
        perms = "755"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "setup" {
      driver = "raw_exec"
      
      config {
        command = "/bin/bash"
        args = ["local/setup.sh"]
      }

      lifecycle {
        hook = "prestart"
        sidecar = false
      }
    }
  }
}