partition "k8s-west" {
  policy = "write"
}

namespace_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

key_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}

event_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy = "write"
}

operator = "write"

mesh = "write"

peering = "write"