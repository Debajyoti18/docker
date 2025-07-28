#!/bin/bash
set -e


REGION="us-east-1"
TIMESTAMP=$(date +%s)
KEY_NAME="dj1-$TIMESTAMP"
VPC_NAME="vpc-$TIMESTAMP"
SG_NAME="my-sg-$TIMESTAMP"


echo "Creating new infrastructure with timestamp: $TIMESTAMP"


# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $REGION
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION


# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION


# Create Subnet
echo "Creating Subnet..."
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${REGION}a --region $REGION --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region $REGION


# Create Route Table and add route
echo "Creating Route Table..."
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region $REGION


# Create Security Group
echo "Creating Security Group..."
SG_ID=$(aws ec2 create-security-group --group-name $SG_NAME --description "Allow SSH from anywhere" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0


# Create Key Pair
echo "Creating Key Pair..."
aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem


# Get Ubuntu AMI
echo "Getting Ubuntu AMI..."
AMI_ID=$(aws ec2 describe-images --owners 099720109477 --region $REGION --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" --query 'Images[*].[ImageId,CreationDate]' --output text | sort -k2 | tail -n1 | awk '{print $1}')


# Launch Instance
echo "Launching EC2 Instance..."
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $KEY_NAME --security-group-ids $SG_ID --subnet-id $SUBNET_ID --region $REGION --query 'Instances[0].InstanceId' --output text)


echo "================================"
echo "New Infrastructure Created:"
echo "VPC ID: $VPC_ID"
echo "Subnet ID: $SUBNET_ID"
echo "Security Group ID: $SG_ID"
echo "Instance ID: $INSTANCE_ID"
echo "Key File: $KEY_NAME.pem"
echo "================================"


sudo docker build -t debajyotidj1/java-app:latest .
sudo docker images
sudo docker push debajyotidj1/java-app:latest


FROM openjdk:17             # Start with a Java 17 image
WORKDIR /app                # Set working directory inside the container
COPY . .                    # Copy all files from current dir into /app
RUN javac Hello.java        # Compile the Java file
CMD ["java", "Hello"]       # Run the compiled program


sudo docker build -t debajyotidj1/java-app:latest .
sudo docker images
sudo docker push debajyotidj1/java-app:latest


sudo apt update
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo docker login
sudo docker pull debajyotidj1/java-app:latest
sudo docker run debajyotidj1/java-app:latest


