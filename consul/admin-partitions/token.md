consul acl token create -description "Admin Token" -role-name "admin" | tee /root/consul/tokens/create-admin-token.txt
consul acl token create -description "Frontend Developer Token" -role-name "frontend-developer" | tee /root/consul/tokens/create-frontend-developer-token.txt
consul acl token create -description "Backend Developer Token" -role-name "backend-developer" | tee /root/consul/tokens/create-backend-developer-token.txt
consul acl token create -description "Finance Token" -role-name "finance" | tee /root/consul/tokens/create-finance-token.txt
#Retrieve tokens

cat /root/consul/tokens/create-admin-token.txt | grep SecretID | awk '{print $2}' > /root/consul/tokens/admin-token.txt
cat /root/consul/tokens/create-frontend-developer-token.txt | grep SecretID | awk '{print $2}' > /root/consul/tokens/frontend-developer-token.txt
cat /root/consul/tokens/create-backend-developer-token.txt | grep SecretID | awk '{print $2}' > /root/consul/tokens/backend-developer-token.txt
cat /root/consul/tokens/create-finance-token.txt | grep SecretID | awk '{print $2}' > /root/consul/tokens/finance-token.txt
