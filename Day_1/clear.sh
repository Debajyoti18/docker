#!/bin/bash
set -e

REGION="us-east-1"

# Infrastructure IDs to delete
VPC_ID="vpc-083c39685fa974baa"
SUBNET_ID="subnet-03f9b01d7dfa2bd81"
SG_ID="sg-09b81c1d7f587b29f"
INSTANCE_ID="i-038931c94b1ce0471"
KEY_NAME="dj1-1753718428.pem"

echo "Starting cleanup of AWS infrastructure..."
echo "================================"

# Terminate EC2 Instance
echo "Terminating EC2 Instance: $INSTANCE_ID"
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION

# Wait for instance to terminate
echo "Waiting for instance to terminate..."
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
echo "Instance terminated successfully"

# Delete Key Pair
echo "Deleting Key Pair: $KEY_NAME"
aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION
# Remove local key file if it exists
if [ -f "$KEY_NAME.pem" ]; then
    rm "$KEY_NAME.pem"
    echo "Local key file $KEY_NAME.pem deleted"
fi

# Delete Security Group
echo "Deleting Security Group: $SG_ID"
aws ec2 delete-security-group --group-id $SG_ID --region $REGION

# Get Route Table ID associated with the subnet
echo "Finding and cleaning up Route Table..."
RT_ID=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.subnet-id,Values=$SUBNET_ID" --query 'RouteTables[0].RouteTableId' --output text)

if [ "$RT_ID" != "None" ] && [ "$RT_ID" != "" ]; then
    # Disassociate route table from subnet
    ASSOCIATION_ID=$(aws ec2 describe-route-tables --route-table-ids $RT_ID --region $REGION --query 'RouteTables[0].Associations[?SubnetId==`'$SUBNET_ID'`].RouteTableAssociationId' --output text)
    if [ "$ASSOCIATION_ID" != "" ]; then
        echo "Disassociating Route Table from Subnet..."
        aws ec2 disassociate-route-table --association-id $ASSOCIATION_ID --region $REGION
    fi
    
    # Delete custom routes (keep local route)
    echo "Deleting custom routes from Route Table..."
    aws ec2 delete-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --region $REGION || echo "Route may not exist or already deleted"
    
    # Delete Route Table
    echo "Deleting Route Table: $RT_ID"
    aws ec2 delete-route-table --route-table-id $RT_ID --region $REGION
fi

# Get Internet Gateway ID
echo "Finding and detaching Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)

if [ "$IGW_ID" != "None" ] && [ "$IGW_ID" != "" ]; then
    # Detach Internet Gateway from VPC
    echo "Detaching Internet Gateway: $IGW_ID from VPC: $VPC_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
    
    # Delete Internet Gateway
    echo "Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
fi

# Delete Subnet
echo "Deleting Subnet: $SUBNET_ID"
aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION

# Delete VPC
echo "Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION

echo "================================"
echo "Cleanup completed successfully!"
echo "All infrastructure has been deleted:"
echo "- EC2 Instance: $INSTANCE_ID"
echo "- Key Pair: $KEY_NAME"
echo "- Security Group: $SG_ID"
echo "- Route Table: $RT_ID"
echo "- Internet Gateway: $IGW_ID"
echo "- Subnet: $SUBNET_ID"
echo "- VPC: $VPC_ID"
echo "================================"
