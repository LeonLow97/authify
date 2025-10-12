#!/bin/bash

source .env
PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)

set -e  # Exit on command failure
set -u  # Treat unset variables as an error
set -o pipefail  # Catch pipeline errors

############### START OF DEPLOYMENT ###############
echo "Starting Deployment of IMS to AWS EC2..."

#### STEP 1: Create a VPC, Public and Private Subnets, Internet Gateways, Route Table
# Create VPC
echo "Creating VPC..."
VpcId=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text) || {
  echo "❌ Failed to create VPC";
  exit 1;
}
echo "✅ VPC created: VpcId=$VpcId"
echo "VpcId=$VpcId" >> variables.txt

# Create 2 Public Subnets and 2 Private Subnets in VPC
# For high availability, we created them in multiple Availability Zones (for ALB to distribute incoming requests). 
echo "Creating Public & Private Subnets..."
PUBLIC_SUBNET_AZ1_ID=$(aws ec2 create-subnet --vpc-id "$VpcId" --cidr-block 10.0.1.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text) || { echo "❌ Failed to create Public Subnet AZ1"; exit 1; }
PUBLIC_SUBNET_AZ2_ID=$(aws ec2 create-subnet --vpc-id "$VpcId" --cidr-block 10.0.2.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text) || { echo "❌ Failed to create Public Subnet AZ2"; exit 1; }
PRIVATE_SUBNET_AZ1_ID=$(aws ec2 create-subnet --vpc-id "$VpcId" --cidr-block 10.0.3.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text) || { echo "❌ Failed to create Private Subnet AZ1"; exit 1; }
PRIVATE_SUBNET_AZ2_ID=$(aws ec2 create-subnet --vpc-id "$VpcId" --cidr-block 10.0.4.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text) || { echo "❌ Failed to create Private Subnet AZ2"; exit 1; }
PRIVATE_RDS_SUBNET_AZ1_ID=$(aws ec2 create-subnet --vpc-id "$VpcId" --cidr-block 10.0.5.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text) || { echo "❌ Failed to create Private RDS Subnet AZ1"; exit 1; }
PRIVATE_RDS_SUBNET_AZ2_ID=$(aws ec2 create-subnet --vpc-id "$VpcId" --cidr-block 10.0.6.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text) || { echo "❌ Failed to create Private RDS Subnet AZ2"; exit 1; }
echo "✅ Subnets created:"
echo "\t- PUBLIC_SUBNET_AZ1_ID=$PUBLIC_SUBNET_AZ1_ID"
echo "\t- PUBLIC_SUBNET_AZ2_ID=$PUBLIC_SUBNET_AZ2_ID"
echo "\t- PRIVATE_SUBNET_AZ1_ID=$PRIVATE_SUBNET_AZ1_ID"
echo "\t- PRIVATE_SUBNET_AZ2_ID=$PRIVATE_SUBNET_AZ2_ID"
echo "\t- PRIVATE_RDS_SUBNET_AZ1_ID=$PRIVATE_RDS_SUBNET_AZ1_ID"
echo "\t- PRIVATE_RDS_SUBNET_AZ2_ID=$PRIVATE_RDS_SUBNET_AZ2_ID"
echo "PUBLIC_SUBNET_AZ1_ID=$PUBLIC_SUBNET_AZ1_ID" >> variables.txt
echo "PUBLIC_SUBNET_AZ2_ID=$PUBLIC_SUBNET_AZ2_ID" >> variables.txt
echo "PRIVATE_SUBNET_AZ1_ID=$PRIVATE_SUBNET_AZ1_ID" >> variables.txt
echo "PRIVATE_SUBNET_AZ2_ID=$PRIVATE_SUBNET_AZ2_ID" >> variables.txt
echo "PRIVATE_RDS_SUBNET_AZ1_ID=$PRIVATE_RDS_SUBNET_AZ1_ID" >> variables.txt
echo "PRIVATE_RDS_SUBNET_AZ2_ID=$PRIVATE_RDS_SUBNET_AZ2_ID" >> variables.txt

# Create Internet Gateway (connects VPC to Internet) and attach it to the VPC
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text) || {
  echo "❌ Failed to create Internet Gateway";
  exit 1;
}
echo "✅ Internet Gateway created: $IGW_ID"
echo "IGW_ID=$IGW_ID" >> variables.txt

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VpcId || {
  echo "❌ Failed to attach Internet Gateway to VPC";
  exit 1;
}
echo "✅ Internet Gateway attached to VPC: $VpcId"

# Find Default Route Table ID
echo "🔍 Finding Default Route Table in VPC..."
DEFAULT_RTB_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VpcId" \
  --query 'RouteTables[?Associations[?Main==`true`]].RouteTableId' \
  --output text) || {
  echo "❌ Failed to find Default Route Table";
  exit 1;
}
echo "✅ Default Route Table found: $DEFAULT_RTB_ID"
echo "DEFAULT_RTB_ID=$DEFAULT_RTB_ID" >> variables.txt

# Create a new Route Table (for Public Subnets) and associate it with the IGW
echo "Creating a new Route Table for Public Subnets..."
PUBLIC_RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VpcId \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text) || {
  echo "❌ Failed to create Route Table";
  exit 1;
}
echo "✅ Route Table created: $PUBLIC_RTB_ID"
echo "PUBLIC_RTB_ID=$PUBLIC_RTB_ID" >> variables.txt

# Add a route to the Internet Gateway (0.0.0.0 <-> IGW)
echo "Creating Route for Internet Gateway in Route Table..."
aws ec2 create-route \
  --route-table-id $PUBLIC_RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION >/dev/null 2>&1 || {
  echo "❌ Failed to create route to Internet Gateway";
  exit 1;
}
echo "✅ Route to IGW added successfully."

# Associate the Route Table with Public Subnets
echo "Associating Route Table with Public Subnets..."
for SUBNET in "$PUBLIC_SUBNET_AZ1_ID" "$PUBLIC_SUBNET_AZ2_ID"; do
  aws ec2 associate-route-table \
    --route-table-id "$PUBLIC_RTB_ID" \
    --subnet-id "$SUBNET" \
    --region "$REGION" >/dev/null 2>&1 || {
    echo "❌ Failed to associate Route Table $PUBLIC_RTB_ID with Subnet $SUBNET";
    exit 1;
  }
done
echo "✅ Successfully associated Route Table with Public Subnets."

##### STEP 2: Create Security Groups and setting inbound rules in SG
echo "Creating Security Groups..."
ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name ALB-SG \
  --description "Security group for ALB" \
  --vpc-id $VpcId --region $REGION \
  --query 'GroupId' --output text) || { echo "❌ Failed to create security group: ALB-SG"; exit 1; }
API_GATEWAY_SG_ID=$(aws ec2 create-security-group \
  --group-name API-Gateway-SG \
  --description "Security group for API Gateway" \
  --vpc-id $VpcId --region $REGION \
  --query 'GroupId' --output text) || { echo "❌ Failed to create security group: API-Gateway-SG"; exit 1; }
AUTH_SG_ID=$(aws ec2 create-security-group \
  --group-name Auth-Service-SG \
  --description "Security group for authentication microservice" \
  --vpc-id $VpcId --region $REGION \
  --query 'GroupId' --output text) || { echo "❌ Failed to create security group: Auth-Service-SG"; exit 1; }
BASTION_SG_ID=$(aws ec2 create-security-group \
  --group-name Bastion-SG \
  --description "Security group for Bastion Host" \
  --vpc-id $VpcId --region $REGION \
  --query 'GroupId' --output text) || { echo "❌ Failed to create security group: Bastion-SG"; exit 1; }
DB_SG_ID=$(aws ec2 create-security-group \
  --group-name DB-SG \
  --description "Security group for RDS Instance" \
  --vpc-id $VpcId --region $REGION \
  --query 'GroupId' --output text) || { echo "❌ Failed to create security group: DB-SG"; exit 1; }
echo "✅ Successfully created all security groups."
echo "\t- ALB_SG_ID=$ALB_SG_ID"
echo "\t- API_GATEWAY_SG_ID=$API_GATEWAY_SG_ID"
echo "\t- AUTH_SG_ID=$AUTH_SG_ID"
echo "\t- BASTION_SG_ID=$BASTION_SG_ID"
echo "\t- DB_SG_ID=$DB_SG_ID"
echo "ALB_SG_ID=$ALB_SG_ID" >> variables.txt
echo "API_GATEWAY_SG_ID=$API_GATEWAY_SG_ID" >> variables.txt
echo "AUTH_SG_ID=$AUTH_SG_ID" >> variables.txt
echo "BASTION_SG_ID=$BASTION_SG_ID" >> variables.txt
echo "DB_SG_ID=$DB_SG_ID" >> variables.txt

# Setting Inbound Rules for Security Groups
echo "Setting Inbound Rules for Security Groups..."
echo "Setting inbound rules for Application Load Balancer ($ALB_SG_ID)"
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --region $REGION \
  --ip-permissions '[
    {"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]},
    {"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
  ]' >/dev/null 2>&1 || { echo "❌ Failed to set inbound rules for $ALB_SG_ID"; exit 1; } &

echo "Setting inbound rules for API Gateway ($API_GATEWAY_SG_ID)"
aws ec2 authorize-security-group-ingress --group-id $API_GATEWAY_SG_ID \
  --ip-permissions '[
    {"IpProtocol": "tcp", "FromPort": '"$PORT_API_GATEWAY"', "ToPort": '"$PORT_API_GATEWAY"', "UserIdGroupPairs": [{"GroupId": "'"$ALB_SG_ID"'"}]},
    {"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "UserIdGroupPairs": [{"GroupId": "'"$BASTION_SG_ID"'"}]},
    {"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "UserIdGroupPairs": [{"GroupId": "'"$BASTION_SG_ID"'"}]},
    {"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "UserIdGroupPairs": [{"GroupId": "'"$BASTION_SG_ID"'"}]}
  ]' >/dev/null 2>&1 || { echo "❌ Failed to set rules for API Gateway"; exit 1; } &

echo "Setting inbound rules for Authentication Microservice ($AUTH_SG_ID)"
aws ec2 authorize-security-group-ingress --group-id $AUTH_SG_ID \
  --ip-permissions '[
    {"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "UserIdGroupPairs": [{"GroupId": "'"$BASTION_SG_ID"'"}]},
    {"IpProtocol": "tcp", "FromPort": '"$PORT_AUTH_SERVICE"',"ToPort": '"$PORT_AUTH_SERVICE"',"UserIdGroupPairs": [{"GroupId": "'"$API_GATEWAY_SG_ID"'"}]},
    {"IpProtocol": "tcp", "FromPort": '"$PORT_POSTGRESQL"',"ToPort": '"$PORT_POSTGRESQL"',"UserIdGroupPairs": [{"GroupId": "'"$AUTH_SG_ID"'"}]}
  ]' >/dev/null 2>&1 || { echo "❌ Failed to set rules for Authentication Microservice"; exit 1; } &

echo "Setting inbound rules for Bastion Host ($BASTION_SG_ID)"
aws ec2 authorize-security-group-ingress --group-id $BASTION_SG_ID \
  --protocol tcp --port 22 --cidr $PUBLIC_IP/32 >/dev/null 2>&1 || { echo "❌ Failed to set rules for Bastion Host"; exit 1; } &

echo "Setting Inbound Rules for PostgreSQL RDS ($DB_SG_ID)"
aws ec2 authorize-security-group-ingress --group-id "$DB_SG_ID" --region "$REGION" \
  --ip-permissions '[
    {"IpProtocol": "tcp", "FromPort": 5432, "ToPort": 5432, "IpRanges": [{"CidrIp": "10.0.3.0/24"}]},
    {"IpProtocol": "tcp", "FromPort": 5432, "ToPort": 5432, "IpRanges": [{"CidrIp": "10.0.4.0/24"}]},
    {"IpProtocol": "tcp", "FromPort": 5432, "ToPort": 5432, "UserIdGroupPairs": [{"GroupId": "'"$BASTION_SG_ID"'"}]}
  ]' >/dev/null 2>&1 || { echo "❌ Failed to set rules for DB Security Group"; exit 1; } &

wait
echo "✅ Successfully set inbound rules for all security groups."

##### STEP 3: Create RDS Subnet Group and RDS Instance
echo "Creating RDS Subnet Groups in VPC Private Subnets: $PRIVATE_RDS_SUBNET_AZ1_ID, $PRIVATE_RDS_SUBNET_AZ2_ID..."
aws rds create-db-subnet-group \
  --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
  --db-subnet-group-description "Subnet group for RDS in VPC ($VpcId) Private Subnets ($PRIVATE_RDS_SUBNET_AZ1_ID and $PRIVATE_RDS_SUBNET_AZ2_ID)" \
  --subnet-ids $PRIVATE_RDS_SUBNET_AZ1_ID $PRIVATE_RDS_SUBNET_AZ2_ID \
  --region $REGION >/dev/null 2>&1 || { echo "❌ Failed to create RDS Subnet Group"; exit 1; }
echo "✅ Successfully created RDS Subnet Group."

echo "Enabling DNS Resolution and DNS Hostnames enabled in VPC..."
aws ec2 modify-vpc-attribute \
  --vpc-id $VpcId \
  --enable-dns-support
aws ec2 modify-vpc-attribute \
  --vpc-id $VpcId \
  --enable-dns-hostnames
echo "✅ Successfully enabled DNS Resolution and Hostnames in VPC."

echo "Creating RDS Instance..."
aws rds create-db-instance \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --db-instance-class $DB_INSTANCE_CLASS \
  --engine $DB_ENGINE \
  --engine-version $DB_ENGINE_VERSION \
  --allocated-storage $DB_STORAGE \
  --master-username $DB_MASTER_USERNAME \
  --master-user-password $DB_MASTER_PASSWORD \
  --vpc-security-group-ids $DB_SG_ID \
  --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
  --multi-az \
  --publicly-accessible \
  --backup-retention-period $DB_BACKUP_RETENTION_PERIOD \
  --storage-type gp2 \
  --no-deletion-protection \
  --no-cli-pager \
  --db-parameter-group-name $DB_PARAMETER_GROUP_NAME \
  --region $REGION >/dev/null 2>&1
echo "✅ Successfully created RDS Instance."

echo "Waiting for RDS Instance to be in 'available' state..."
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_IDENTIFIER --region $REGION || { echo "❌ RDS Instance failed to become available"; exit 1; }
echo "✅ RDS Instance is currently in AVAILABLE state."

echo "Retrieving RDS Endpoint..."
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_IDENTIFIER --query 'DBInstances[0].Endpoint.Address' --output text --region $REGION)
if [[ "$RDS_ENDPOINT" == "None" ]]; then
  echo "❌ Failed to retrieve RDS endpoint"; exit 1
fi
echo "✅ RDS Endpoint: $RDS_ENDPOINT"
echo "psql -h $RDS_ENDPOINT -U $DB_MASTER_USERNAME -d $IMS_DB_NAME"
echo "RDS_ENDPOINT=$RDS_ENDPOINT" >> variables.txt

echo "Adding Public IP to RDS Security Group Inbound Rules to allow 'psql' commands..."
aws ec2 authorize-security-group-ingress --group-id "$DB_SG_ID" \
  --protocol tcp --port 5432 --cidr "$PUBLIC_IP/32" --region "$REGION" >/dev/null 2>&1 \
  || { echo "❌ Failed to set inbound rules for $DB_SG_ID"; exit 1; }
echo "✅ Successfully added Public IP to RDS security group inbound rules."

echo "Inserting RDS configurations into System Manager Parameter Store..."
aws ssm put-parameter --name "/ims/db/hostname" --value $RDS_ENDPOINT --type "String" --overwrite --region $REGION >/dev/null 2>&1
aws ssm put-parameter --name "/ims/db/master-username" --value $DB_MASTER_USERNAME --type "String" --overwrite --region $REGION >/dev/null 2>&1
aws ssm put-parameter --name "/ims/db/master-password" --value $DB_MASTER_PASSWORD --type "String" --overwrite --region $REGION >/dev/null 2>&1
aws ssm put-parameter --name "/ims/db/db-name" --value $IMS_DB_NAME --type "String" --overwrite --region $REGION >/dev/null 2>&1
echo "✅ Successfully inserted RDS parameters into SSM Parameter Store."

echo "Database setup completed successfully!"

##### STEP 3: Create NAT Gateway
# Allocate two Elastic IPs (one for each NAT Gateway)
echo "Allocating Elastic IPs for NAT Gateways..."
EIP_AZ1=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text) || { echo "❌ Failed to allocate Elastic IP for AZ1"; exit 1; }
EIP_AZ2=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text) || { echo "❌ Failed to allocate Elastic IP for AZ2"; exit 1; }
wait
echo "✅ Successfully allocated Elastic IPs."
echo "\t- EIP_AZ1=$EIP_AZ1"
echo "\t- EIP_AZ2=$EIP_AZ2"
echo "EIP_AZ1=$EIP_AZ1" >> variables.txt
echo "EIP_AZ2=$EIP_AZ2" >> variables.txt

# Create NAT Gateways in both public subnets with different Elastic IPs
echo "Creating NAT Gateways..."
NAT_GATEWAY_ID_AZ1=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_AZ1_ID --allocation-id $EIP_AZ1 --query "NatGateway.NatGatewayId" --output text) || { echo "❌ Failed to create NAT Gateway in AZ1"; exit 1; }
NAT_GATEWAY_ID_AZ2=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_AZ2_ID --allocation-id $EIP_AZ2 --query "NatGateway.NatGatewayId" --output text) || { echo "❌ Failed to create NAT Gateway in AZ2"; exit 1; }
wait
echo "✅ Successfully created NAT Gateways."
echo "\t- NAT_GATEWAY_ID_AZ1=$NAT_GATEWAY_ID_AZ1"
echo "\t- NAT_GATEWAY_ID_AZ2=$NAT_GATEWAY_ID_AZ2"
echo "NAT_GATEWAY_ID_AZ1=$NAT_GATEWAY_ID_AZ1" >> variables.txt
echo "NAT_GATEWAY_ID_AZ2=$NAT_GATEWAY_ID_AZ2" >> variables.txt

# Wait for both NAT Gateways to become available
echo "Waiting for NAT Gateways to become available..."
wait_for_nat_gateway() {
    local NAT_ID=$1
    while [ "$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_ID --query "NatGateways[0].State" --output text)" != "available" ]; do
        sleep 10
    done
    echo "✅ NAT Gateway $NAT_ID is now available."
}
wait_for_nat_gateway $NAT_GATEWAY_ID_AZ1 &
wait_for_nat_gateway $NAT_GATEWAY_ID_AZ2 &
wait
echo "✅ Both NAT Gateways are available. Proceeding with the next step."

# Create a new Route Table (for Private Subnets)
# Create Route Tables for each AZ
echo "Creating Route Tables for AZ1 and AZ2..."
PRIVATE_RTB_AZ1_ID=$(aws ec2 create-route-table --vpc-id $VpcId --region $REGION --query 'RouteTable.RouteTableId' --output text) || {
  echo "❌ Failed to create Route Table for AZ1";
  exit 1;
}
PRIVATE_RTB_AZ2_ID=$(aws ec2 create-route-table --vpc-id $VpcId --region $REGION --query 'RouteTable.RouteTableId' --output text) || {
  echo "❌ Failed to create Route Table for AZ2";
  exit 1;
}
echo "✅ Route Tables created: $PRIVATE_RTB_AZ1_ID and $PRIVATE_RTB_AZ2_ID"
echo "PRIVATE_RTB_AZ1_ID=$PRIVATE_RTB_AZ1_ID" >> variables.txt
echo "PRIVATE_RTB_AZ2_ID=$PRIVATE_RTB_AZ2_ID" >> variables.txt

# Create NAT Gateway routes for AZ1 and AZ2
echo "Creating routes to NAT Gateways for AZ1 and AZ2..."
aws ec2 create-route --route-table-id $PRIVATE_RTB_AZ1_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GATEWAY_ID_AZ1 >/dev/null 2>&1 || { echo "❌ Failed to create route to NAT Gateway for AZ1"; exit 1; }
aws ec2 create-route --route-table-id $PRIVATE_RTB_AZ2_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GATEWAY_ID_AZ2 >/dev/null 2>&1 || { echo "❌ Failed to create route to NAT Gateway for AZ2"; exit 1; }
echo "✅ Successfully created routes to NAT Gateways for AZ1 and AZ2"

# Associate Route Tables with Private Subnets
echo "Associating route tables with private subnets..."
aws ec2 associate-route-table --route-table-id $PRIVATE_RTB_AZ1_ID --subnet-id $PRIVATE_SUBNET_AZ1_ID >/dev/null 2>&1 || { echo "❌ Failed to associate route table with AZ1 private subnet"; exit 1; }
aws ec2 associate-route-table --route-table-id $PRIVATE_RTB_AZ2_ID --subnet-id $PRIVATE_SUBNET_AZ2_ID >/dev/null 2>&1 || { echo "❌ Failed to associate route table with AZ2 private subnet"; exit 1; }
echo "✅ Successfully associated route tables with private subnets."

##### STEP 4: Launch EC2 Instances
# Creating EC2 Instances Key Pairs for SSH
echo "Creating Key Pairs for EC2 Instances..."
echo "Creating key pair for API Gateway ($EC2_API_GATEWAY_KEY_NAME_AZ1) and ($EC2_API_GATEWAY_KEY_NAME_AZ1)"
aws ec2 create-key-pair --key-name $EC2_API_GATEWAY_KEY_NAME_AZ1 --query 'KeyMaterial' --output text > $EC2_API_GATEWAY_KEY_NAME_AZ1.pem || { echo "❌ Failed to create key pair for API Gateway AZ1"; exit 1; }
aws ec2 create-key-pair --key-name $EC2_API_GATEWAY_KEY_NAME_AZ2 --query 'KeyMaterial' --output text > $EC2_API_GATEWAY_KEY_NAME_AZ2.pem || { echo "❌ Failed to create key pair for API Gateway AZ2"; exit 1; }

echo "Creating key pair for Authentication Microservice ($EC2_AUTH_MICROSERVICE_KEY_NAME_AZ1) and ($EC2_AUTH_MICROSERVICE_KEY_NAME_AZ2)"
aws ec2 create-key-pair --key-name $EC2_AUTH_MICROSERVICE_KEY_NAME_AZ1 --query 'KeyMaterial' --output text > $EC2_AUTH_MICROSERVICE_KEY_NAME_AZ1.pem || { echo "❌ Failed to create key pair for Authentication Microservice AZ1"; exit 1; }
aws ec2 create-key-pair --key-name $EC2_AUTH_MICROSERVICE_KEY_NAME_AZ2 --query 'KeyMaterial' --output text > $EC2_AUTH_MICROSERVICE_KEY_NAME_AZ2.pem || { echo "❌ Failed to create key pair for Authentication Microservice AZ2"; exit 1; }

echo "Creating key pair for Bastion Host ($EC2_BASTION_HOST_KEY_NAME_AZ1) and ($EC2_BASTION_HOST_KEY_NAME_AZ2)"
aws ec2 create-key-pair --key-name $EC2_BASTION_HOST_KEY_NAME_AZ1 --query 'KeyMaterial' --output text > $EC2_BASTION_HOST_KEY_NAME_AZ1.pem || { echo "❌ Failed to create key pair for Bastion Host AZ1"; exit 1; }
aws ec2 create-key-pair --key-name $EC2_BASTION_HOST_KEY_NAME_AZ2 --query 'KeyMaterial' --output text > $EC2_BASTION_HOST_KEY_NAME_AZ2.pem || { echo "❌ Failed to create key pair for Bastion Host AZ2"; exit 1; }
echo "✅ Successfully created key pairs for EC2 instances."

chmod 400 IMS*.pem

echo "EC2_API_GATEWAY_KEY_NAME_AZ1=$EC2_API_GATEWAY_KEY_NAME_AZ1" >> variables.txt
echo "EC2_API_GATEWAY_KEY_NAME_AZ2=$EC2_API_GATEWAY_KEY_NAME_AZ2" >> variables.txt
echo "EC2_AUTH_MICROSERVICE_KEY_NAME_AZ1=$EC2_AUTH_MICROSERVICE_KEY_NAME_AZ1" >> variables.txt
echo "EC2_AUTH_MICROSERVICE_KEY_NAME_AZ2=$EC2_AUTH_MICROSERVICE_KEY_NAME_AZ2" >> variables.txt
echo "EC2_BASTION_HOST_KEY_NAME_AZ1=$EC2_BASTION_HOST_KEY_NAME_AZ1" >> variables.txt
echo "EC2_BASTION_HOST_KEY_NAME_AZ2=$EC2_BASTION_HOST_KEY_NAME_AZ2" >> variables.txt

# Launch Bastion Host EC2 instances in both AZ1 and AZ2
echo "Launching Bastion Host EC2 instance in AZ1..."
BASTION_INSTANCE_ID_AZ1=$(aws ec2 run-instances \
  --image-id ami-06661384e66f2da0e \
  --count 1 \
  --instance-type t2.nano \
  --key-name $EC2_BASTION_HOST_KEY_NAME_AZ1 \
  --security-group-ids $BASTION_SG_ID \
  --subnet-id $PUBLIC_SUBNET_AZ1_ID \
  --associate-public-ip-address \
  --user-data file://deployment/ec2/bastion-script.sh \
  --query 'Instances[0].InstanceId' \
  --output text) || { echo "❌ Failed to launch Bastion Host instance in AZ1"; exit 1; }

echo "Launching Bastion Host EC2 instance in AZ2..."
BASTION_INSTANCE_ID_AZ2=$(aws ec2 run-instances \
  --image-id ami-06661384e66f2da0e \
  --count 1 \
  --instance-type t2.nano \
  --key-name $EC2_BASTION_HOST_KEY_NAME_AZ2 \
  --security-group-ids $BASTION_SG_ID \
  --subnet-id $PUBLIC_SUBNET_AZ2_ID \
  --associate-public-ip-address \
  --user-data file://deployment/ec2/bastion-script.sh \
  --query 'Instances[0].InstanceId' \
  --output text) || { echo "❌ Failed to launch Bastion Host instance in AZ2"; exit 1; }

echo "\t- BASTION_INSTANCE_ID_AZ1=$BASTION_INSTANCE_ID_AZ1"
echo "\t- BASTION_INSTANCE_ID_AZ2=$BASTION_INSTANCE_ID_AZ2"
echo "BASTION_INSTANCE_ID_AZ1=$BASTION_INSTANCE_ID_AZ1" >> variables.txt
echo "BASTION_INSTANCE_ID_AZ2=$BASTION_INSTANCE_ID_AZ2" >> variables.txt

echo "Waiting for Bastion Host EC2 instances to become running..."
aws ec2 wait instance-running --instance-ids $BASTION_INSTANCE_ID_AZ1 || { echo "❌ Bastion Host instance failed to start in AZ1"; exit 1; }
aws ec2 wait instance-running --instance-ids $BASTION_INSTANCE_ID_AZ1 || { echo "❌ Bastion Host instance failed to start in AZ2"; exit 1; }
aws ec2 wait instance-status-ok --instance-ids $BASTION_INSTANCE_ID_AZ1 || { echo "❌ Bastion Host instance failed to reach status OK in AZ1"; exit 1; }
aws ec2 wait instance-status-ok --instance-ids $BASTION_INSTANCE_ID_AZ1 || { echo "❌ Bastion Host instance failed to reach status OK in AZ2"; exit 1; }
echo "✅ Bastion Host EC2 instances are running and ready."

echo "Retrieving the public IPv4 address of the Bastion Host EC2 instance..."
BASTION_PUBLIC_IP_AZ1=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE_ID_AZ1 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text) || { echo "❌ Failed to retrieve public IP for Bastion instance in AZ1"; exit 1; }
BASTION_PUBLIC_IP_AZ2=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE_ID_AZ2 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text) || { echo "❌ Failed to retrieve public IP for Bastion instance in AZ2"; exit 1; }

echo "\t- Bastion Public IP (AZ1): $BASTION_PUBLIC_IP_AZ1"
echo "\t- Bastion Public IP (AZ2): $BASTION_PUBLIC_IP_AZ2"
echo "BASTION_PUBLIC_IP_AZ1=$BASTION_PUBLIC_IP_AZ1" >> variables.txt
echo "BASTION_PUBLIC_IP_AZ2=$BASTION_PUBLIC_IP_AZ2" >> variables.txt

echo "Starting SSH into Bastion Host EC2 instance to access authentication postgres database..."
./deployment/ec2/bastion-run.sh
echo "\n✅ Successfully completed SSH into Bastion Host EC2 instance to grant privileges in authentication postgres database."

# Launch Authentication Microservice EC2 instances in both AZ1 and AZ2
echo "Launching Authentication Microservice EC2 instances..."
AUTH_SERVICE_INSTANCE_ID_AZ1=$(aws ec2 run-instances \
  --image-id ami-06661384e66f2da0e \
  --count 1 \
  --instance-type t3.micro \
  --key-name $EC2_AUTH_MICROSERVICE_KEY_NAME_AZ1 \
  --security-group-ids $AUTH_SG_ID \
  --subnet-id $PRIVATE_SUBNET_AZ1_ID \
  --user-data file://deployment/ec2/authentication-script.sh \
  --iam-instance-profile Name=$EC2_IAM_ROLE \
  --query 'Instances[0].InstanceId' \
  --output text) || { echo "❌ Failed to launch Authentication Microservice instance in AZ1"; exit 1; }

AUTH_SERVICE_INSTANCE_ID_AZ2=$(aws ec2 run-instances \
  --image-id ami-06661384e66f2da0e \
  --count 1 \
  --instance-type t3.micro \
  --key-name $EC2_AUTH_MICROSERVICE_KEY_NAME_AZ2 \
  --security-group-ids $AUTH_SG_ID \
  --subnet-id $PRIVATE_SUBNET_AZ2_ID \
  --user-data file://deployment/ec2/authentication-script.sh \
  --iam-instance-profile Name=$EC2_IAM_ROLE \
  --query 'Instances[0].InstanceId' \
  --output text) || { echo "❌ Failed to launch Authentication Microservice instance in AZ2"; exit 1; }
echo "AUTH_SERVICE_INSTANCE_ID_AZ1=$AUTH_SERVICE_INSTANCE_ID_AZ1" >> variables.txt
echo "AUTH_SERVICE_INSTANCE_ID_AZ2=$AUTH_SERVICE_INSTANCE_ID_AZ2" >> variables.txt
echo "\t- AUTH_SERVICE_INSTANCE_ID_AZ1=$AUTH_SERVICE_INSTANCE_ID_AZ1"
echo "\t- AUTH_SERVICE_INSTANCE_ID_AZ2=$AUTH_SERVICE_INSTANCE_ID_AZ2"

echo "Waiting for Authentication Microservice EC2 instances to become running..."
aws ec2 wait instance-status-ok --instance-ids $AUTH_SERVICE_INSTANCE_ID_AZ1 || { echo "❌ Authentication Microservice instance failed to reach status OK in AZ1"; exit 1; }
aws ec2 wait instance-status-ok --instance-ids $AUTH_SERVICE_INSTANCE_ID_AZ2 || { echo "❌ Authentication Microservice instance failed to reach status OK in AZ2"; exit 1; }
aws ec2 wait instance-running --instance-ids $AUTH_SERVICE_INSTANCE_ID_AZ1 || { echo "❌ Authentication Microservice instance failed to start in AZ1"; exit 1; }
aws ec2 wait instance-running --instance-ids $AUTH_SERVICE_INSTANCE_ID_AZ2 || { echo "❌ Authentication Microservice instance failed to start in AZ2"; exit 1; }
echo "✅ Authentication Microservice EC2 instances are running and ready."

# Launch API Gateway EC2 instances in both AZ1 and AZ2
echo "Launching API Gateway EC2 instances..."
API_GATEWAY_INSTANCE_ID_AZ1=$(aws ec2 run-instances \
  --image-id ami-06661384e66f2da0e \
  --count 1 \
  --instance-type t3.micro \
  --key-name $EC2_API_GATEWAY_KEY_NAME_AZ1 \
  --security-group-ids $API_GATEWAY_SG_ID \
  --subnet-id $PRIVATE_SUBNET_AZ1_ID \
  --user-data file://deployment/ec2/api-gateway-script.sh \
  --iam-instance-profile Name=$EC2_IAM_ROLE \
  --query 'Instances[0].InstanceId' \
  --output text) || { echo "❌ Failed to launch API Gateway instance in AZ1"; exit 1; }

API_GATEWAY_INSTANCE_ID_AZ2=$(aws ec2 run-instances \
  --image-id ami-06661384e66f2da0e \
  --count 1 \
  --instance-type t3.micro \
  --key-name $EC2_API_GATEWAY_KEY_NAME_AZ2 \
  --security-group-ids $API_GATEWAY_SG_ID \
  --subnet-id $PRIVATE_SUBNET_AZ2_ID \
  --user-data file://deployment/ec2/api-gateway-script.sh \
  --iam-instance-profile Name=$EC2_IAM_ROLE \
  --query 'Instances[0].InstanceId' \
  --output text) || { echo "❌ Failed to launch API Gateway instance in AZ2"; exit 1; }
echo "\t- API_GATEWAY_INSTANCE_ID_AZ1=$API_GATEWAY_INSTANCE_ID_AZ1"
echo "\t- API_GATEWAY_INSTANCE_ID_AZ2=$API_GATEWAY_INSTANCE_ID_AZ2"
echo "API_GATEWAY_INSTANCE_ID_AZ1=$API_GATEWAY_INSTANCE_ID_AZ1" >> variables.txt
echo "API_GATEWAY_INSTANCE_ID_AZ2=$API_GATEWAY_INSTANCE_ID_AZ2" >> variables.txt

echo "Waiting for API Gateway EC2 instances to become running..."
aws ec2 wait instance-running --instance-ids $API_GATEWAY_INSTANCE_ID_AZ1 || { echo "❌ API Gateway instance failed to start in AZ1"; exit 1; }
aws ec2 wait instance-running --instance-ids $API_GATEWAY_INSTANCE_ID_AZ2 || { echo "❌ API Gateway instance failed to start in AZ2"; exit 1; }
aws ec2 wait instance-status-ok --instance-ids $API_GATEWAY_INSTANCE_ID_AZ1 || { echo "❌ API Gateway instance failed to reach status OK in AZ1"; exit 1; }
aws ec2 wait instance-status-ok --instance-ids $API_GATEWAY_INSTANCE_ID_AZ2 || { echo "❌ API Gateway instance failed to reach status OK in AZ2"; exit 1; }
echo "✅ API Gateway EC2 instances are running and ready."

echo "✅ Launched EC2 Instances."

# Get the private IPv4 address of the newly launched EC2 instance
echo "Retrieving the private IPv4 address of the API Gateway EC2 instance..."
API_GATEWAY_PRIVATE_IP_AZ1=$(aws ec2 describe-instances \
  --instance-ids $API_GATEWAY_INSTANCE_ID_AZ1 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text) || { echo "❌ Failed to retrieve private IP for API Gateway instance in AZ1"; exit 1; }
API_GATEWAY_PRIVATE_IP_AZ2=$(aws ec2 describe-instances \
  --instance-ids $API_GATEWAY_INSTANCE_ID_AZ2 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text) || { echo "❌ Failed to retrieve private IP for API Gateway instance in AZ2"; exit 1; }

echo "Retrieving the private IPv4 address of the Authentication Microservice EC2 instance..."
AUTH_SERVICE_PRIVATE_IP_AZ1=$(aws ec2 describe-instances \
  --instance-ids $AUTH_SERVICE_INSTANCE_ID_AZ1 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text) || { echo "❌ Failed to retrieve private IP for Authentication Microservice instance in AZ1"; exit 1; }
AUTH_SERVICE_PRIVATE_IP_AZ2=$(aws ec2 describe-instances \
  --instance-ids $AUTH_SERVICE_INSTANCE_ID_AZ2 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text) || { echo "❌ Failed to retrieve private IP for Authentication Microservice instance in AZ2"; exit 1; }

# Fix the echo output
echo "✅ IP Addresses:"
echo "\t- API Gateway Private IP (AZ1): $API_GATEWAY_PRIVATE_IP_AZ1"
echo "\t- API Gateway Private IP (AZ2): $API_GATEWAY_PRIVATE_IP_AZ2"
echo "\t- Authentication Service Private IP (AZ1): $AUTH_SERVICE_PRIVATE_IP_AZ1"
echo "\t- Authentication Service Private IP (AZ2): $AUTH_SERVICE_PRIVATE_IP_AZ2"
echo "API_GATEWAY_PRIVATE_IP_AZ1=$API_GATEWAY_PRIVATE_IP_AZ1" >> variables.txt
echo "API_GATEWAY_PRIVATE_IP_AZ2=$API_GATEWAY_PRIVATE_IP_AZ2" >> variables.txt
echo "AUTH_SERVICE_PRIVATE_IP_AZ1=$AUTH_SERVICE_PRIVATE_IP_AZ1" >> variables.txt
echo "AUTH_SERVICE_PRIVATE_IP_AZ2=$AUTH_SERVICE_PRIVATE_IP_AZ2" >> variables.txt

# Save to a new or existing file
echo "\nRun the following commands in order to SSH into API Gateway EC2 Instance in AZ1:" > ssh_commands.txt
echo "scp -i IMS_BASTION_AZ1.pem IMS_API_GATEWAY_KEY_PAIR_AZ1.pem ec2-user@$BASTION_PUBLIC_IP_AZ1:~" >> ssh_commands.txt
echo "ssh -i IMS_BASTION_AZ1.pem ec2-user@$BASTION_PUBLIC_IP_AZ1" >> ssh_commands.txt
echo "ssh -i IMS_API_GATEWAY_KEY_PAIR_AZ1.pem ec2-user@$API_GATEWAY_PRIVATE_IP_AZ1" >> ssh_commands.txt

echo "\nRun the following commands in order to SSH into API Gateway EC2 Instance in AZ2:" >> ssh_commands.txt
echo "scp -i IMS_BASTION_AZ2.pem IMS_API_GATEWAY_KEY_PAIR_AZ2.pem ec2-user@$BASTION_PUBLIC_IP_AZ2:~" >> ssh_commands.txt
echo "ssh -i IMS_BASTION_AZ2.pem ec2-user@$BASTION_PUBLIC_IP_AZ2" >> ssh_commands.txt
echo "ssh -i IMS_API_GATEWAY_KEY_PAIR_AZ2.pem ec2-user@$API_GATEWAY_PRIVATE_IP_AZ2" >> ssh_commands.txt

echo "\nRun the following commands in order to SSH into Authentication Microservice EC2 Instance in AZ1:" >> ssh_commands.txt
echo "scp -i IMS_BASTION_AZ1.pem IMS_AUTH_SERVICE_KEY_PAIR_AZ1.pem ec2-user@$BASTION_PUBLIC_IP_AZ1:~" >> ssh_commands.txt
echo "ssh -i IMS_BASTION_AZ1.pem ec2-user@$BASTION_PUBLIC_IP_AZ1" >> ssh_commands.txt
echo "ssh -i IMS_AUTH_SERVICE_KEY_PAIR_AZ1.pem ec2-user@$AUTH_SERVICE_PRIVATE_IP_AZ1" >> ssh_commands.txt

echo "\nRun the following commands in order to SSH into Authentication Microservice EC2 Instance in AZ2:" >> ssh_commands.txt
echo "scp -i IMS_BASTION_AZ2.pem IMS_AUTH_SERVICE_KEY_PAIR_AZ2.pem ec2-user@$BASTION_PUBLIC_IP_AZ2:~" >> ssh_commands.txt
echo "ssh -i IMS_BASTION_AZ2.pem ec2-user@$BASTION_PUBLIC_IP_AZ2" >> ssh_commands.txt
echo "ssh -i IMS_AUTH_SERVICE_KEY_PAIR_AZ2.pem ec2-user@$AUTH_SERVICE_PRIVATE_IP_AZ2" >> ssh_commands.txt

echo "\n✅ Retrieved Private IPv4 Addresses for EC2 instances and prepared SSH commands"

# Running SSH commands to start Docker Containers in API Gateway EC2 instances
echo "Start API Gateway Docker containers in EC2 instances..."
./deployment/ec2/api-gateway-run.sh
echo "\n✅ Successfully started API Gateway Docker containers."

##### STEP 5: Launch Application Load Balancer (ALB) in Public Subnet
# Create ALB --> Set up a public Application Load Balancer in a specified subnet
echo "Creating the Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer --name ims-alb --subnets $PUBLIC_SUBNET_AZ1_ID $PUBLIC_SUBNET_AZ2_ID --security-groups $ALB_SG_ID --query "LoadBalancers[0].LoadBalancerArn" --output text) || { echo "❌ Failed to create ALB"; exit 1; }
echo "\t- ALB_ARN=$ALB_ARN"
echo "ALB_ARN=$ALB_ARN" >> variables.txt

# Create Target Group --> Defines where ALB should forward traffic (API Gateway on Port 8080)
echo "Creating the Target Group for API Gateway..."
API_GATEWAY_TG_ARN=$(aws elbv2 create-target-group --name "$API_GATEWAY_SERVICE-tg" --protocol HTTP --port 8080 --vpc-id $VpcId --query "TargetGroups[0].TargetGroupArn" --output text) || { echo "❌ Failed to create Target Group"; exit 1; }
echo "✅ Created ALB and Target Group for API Gateway."
echo "\t- API_GATEWAY_TG_ARN=$API_GATEWAY_TG_ARN"
echo "API_GATEWAY_TG_ARN=$API_GATEWAY_TG_ARN" >> variables.txt

# Modify API Gateway target group health check endpoint
echo "Modifying health check settings for the API Gateway Target Group..."
aws elbv2 modify-target-group \
    --target-group-arn $API_GATEWAY_TG_ARN \
    --health-check-path "/healthcheck" \
    --health-check-port "8080" \
    --health-check-protocol "HTTP" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 5 \
    --unhealthy-threshold-count 2 >/dev/null 2>&1 || { echo "❌ Failed to modify health check"; exit 1; }
echo "✅ Successfully configured API Gateway Target Group."

# Register Target --> Links the API Gateway EC2 Instance to the target group
echo "Registering API Gateway EC2 instance to the Target Group..."
aws elbv2 register-targets --target-group-arn $API_GATEWAY_TG_ARN --targets Id=$API_GATEWAY_INSTANCE_ID_AZ1 Id=$API_GATEWAY_INSTANCE_ID_AZ2 || { echo "❌ Failed to register targets"; exit 1; }
echo "✅ Successfully Registered API Gateway EC2 instances to target group."

# Create Listener --> Configured ALB to listen on port 80 and forward requests to Target Group
echo "Creating ALB Listener..."
ALB_LISTENER_ARN=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$API_GATEWAY_TG_ARN --query "Listeners[0].ListenerArn" --output text) || { echo "❌ Failed to create ALB listener"; exit 1; }
echo "✅ Successfully created ALB Listener."
echo "\t- ALB_LISTENER_ARN=$ALB_LISTENER_ARN"
echo "ALB_LISTENER_ARN=$ALB_LISTENER_ARN" >> variables.txt

# Wait for the ALB to be in available state
echo "Waiting for the Load Balancer $ALB_ARN to be available..."
aws elbv2 wait load-balancer-available --load-balancer-arn $ALB_ARN || { echo "❌ ALB is not available"; exit 1; }
echo "✅ ALB $ALB_ARN is AVAILABLE."

# Get the DNS name of the Load Balancer
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arn $ALB_ARN --query "LoadBalancers[0].DNSName" --output text) || { echo "❌ Failed to get ALB DNS name"; exit 1; }
echo "\t- ALB_DNS_NAME=$ALB_DNS_NAME"
echo "ALB_DNS_NAME=$ALB_DNS_NAME" >> variables.txt

# Test API Gateway HealthCheck endpoint
echo "Testing API Gateway HealthCheck endpoint..."
echo "\tcurl http://$ALB_DNS_NAME/healthcheck"
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" http://$ALB_DNS_NAME/healthcheck)
if [ "$HTTP_STATUS" -eq 200 ]; then
  echo -e "✅ Health check passed! (HTTP 200)"
else
  echo -e "❌ Health check failed! (HTTP $HTTP_STATUS)"
fi

echo "✅ Launched IMS to AWS EC2!"

############### END OF DEPLOYMENT ###############
