#!/bin/bash
set -e

# Template variables - exactly as passed from Terraform
echo "consul_version: ${consul_version}"
echo "nomad_version: ${nomad_version}"
echo "consul_datacenter: ${consul_datacenter}"
echo "nomad_datacenter: ${nomad_datacenter}"
echo "consul_encrypt_key: ${consul_encrypt_key}"
echo "consul_master_token: ${consul_master_token}"
echo "nomad_consul_token: ${nomad_consul_token}"
echo "nomad_server_token: ${nomad_server_token}"
echo "nomad_client_token: ${nomad_client_token}"
echo "consul_license: ${consul_license}"
echo "nomad_license: ${nomad_license}"
echo "server_index: ${server_index}"
echo "server_count: ${server_count}"
echo "ca_cert: ${ca_cert}"
echo "ca_key: ${ca_key}"
echo "subnet_cidr: ${subnet_cidr}"
echo "enable_acls: ${enable_acls}"
echo "enable_tls: ${enable_tls}"
echo "consul_log_level: ${consul_log_level}"
echo "nomad_log_level: ${nomad_log_level}"
echo "project_id: ${project_id}"

echo "Debug script completed successfully"
