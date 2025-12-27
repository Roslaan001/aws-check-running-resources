#!/bin/bash
# script to check running AWS resources across all regions available in users AWS account

set -euo pipefail

# Initialize global counters
declare -A TOTAL_COUNTS
# Define resource keys to ensure they are initialized
for key in vpcs subnets igws nat_gateways route_tables security_groups vpc_peering ec2_instances rds_instances eks_clusters load_balancers s3_buckets lambda_functions dynamodb_tables app_runner_services amplify_apps route53_zones cloudfront_distributions; do
    TOTAL_COUNTS[$key]=0
done

declare -A REGION_RESOURCES
REGIONS_WITH_RESOURCES=()

echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo "++ AWS resource checking across all regions ++"
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "grab your popcorn 🍿🍿🍿"
echo ""
echo ""
# use the AWS credentials in the users home env
# get all the available AWS regions in user's account and produce an error if no AWS credentials is found
echo "Fetching all available regions in your AWS account..."
if ! regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); then
    echo "Error: Could not fetch regions. Check your AWS credentials."
    exit 1
fi

echo "Regions found in your AWS are: $regions"
echo ""

# helper function to process and print resource info
check_resource() {
    local display_name="$1"
    local map_key="$2"
    local content="$3"
    local region_prefix="${4:-}" # used for recording region specific stats key

    echo "  $display_name:"
    
    if [ -z "$content" ]; then
        echo "    No $display_name found"
        return
    fi
    
    # Count lines (resources)
    local count
    count=$(echo "$content" | wc -l)
    
    # Print content
    echo "$content" | while read -r line; do
        echo "    - $line"
    done
    
    # Update Globals
    TOTAL_COUNTS[$map_key]=$((${TOTAL_COUNTS[$map_key]} + count))
    
    # update Region Specific
    if [ -n "$region_prefix" ]; then
        HAS_RESOURCES=true
        
        case "$map_key" in
            nat_gateways)        suffix="nats" ;;
            ec2_instances)       suffix="ec2" ;;
            rds_instances)       suffix="rds" ;;
            eks_clusters)        suffix="eks" ;;
            load_balancers)      suffix="lbs" ;;
            lambda_functions)    suffix="lambda_functions" ;;
            dynamodb_tables)     suffix="dynamodb_tables" ;;
            app_runner_services) suffix="app_runner_services" ;;
            amplify_apps)        suffix="amplify_apps" ;;
            *)                   suffix="$map_key" ;;
        esac
        
        REGION_RESOURCES["${region_prefix}_${suffix}"]=$count
    fi
}

check_region_resources() {
    local region=$1
    # a global flag to track if this region has any resources
    HAS_RESOURCES=false
    
    echo "----------------------------------------"
    echo "Checking region: $region"
    echo "----------------------------------------"
    
    # --- VPCs ---
    vpcs=$(aws ec2 describe-vpcs --region "$region" --query 'Vpcs[].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    check_resource "VPCs" "vpcs" "$vpcs" "$region"
    
    
    # --- Subnets (Only shows subnet counts not IDs) ---
    echo "  Subnets:"
    subnets=$(aws ec2 describe-subnets --region "$region" --query 'Subnets[].[SubnetId]' --output text 2>/dev/null || echo "")
    if [ -n "$subnets" ]; then
        cnt=$(echo "$subnets" | wc -l)
        echo "    Found $cnt subnets"
        TOTAL_COUNTS[subnets]=$((${TOTAL_COUNTS[subnets]} + cnt))
        REGION_RESOURCES["${region}_subnets"]=$cnt
        HAS_RESOURCES=true
    else
        echo "    No subnets found in $region"
    fi

    # --- IGWs ---
    igws=$(aws ec2 describe-internet-gateways --region "$region" --query 'InternetGateways[].[InternetGatewayId,Attachments[0].VpcId,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    check_resource "Internet Gateways" "igws" "$igws" "$region"

    # --- NAT Gateways ---
    nats=$(aws ec2 describe-nat-gateways --region "$region" --query 'NatGateways[?State==`available`].[NatGatewayId,VpcId,SubnetId,State]' --output text 2>/dev/null || echo "")
    check_resource "NAT Gateways" "nat_gateways" "$nats" "$region"

    # --- Route Tables (Only shows route tables counts not IDs) ---
    echo "  Route Tables:"
    rts=$(aws ec2 describe-route-tables --region "$region" --query 'RouteTables[].[RouteTableId]' --output text 2>/dev/null || echo "")
    if [ -n "$rts" ]; then
        cnt=$(echo "$rts" | wc -l)
        echo "    Found $cnt route tables"
        TOTAL_COUNTS[route_tables]=$((${TOTAL_COUNTS[route_tables]} + cnt))
        HAS_RESOURCES=true
    else
        echo "    No Route Tables found in $region"
    fi

    # --- Security Groups (Only shows security groups counts not IDs) ---
    echo "  Security Groups:"
    sgs=$(aws ec2 describe-security-groups --region "$region" --query 'SecurityGroups[].[GroupId]' --output text 2>/dev/null || echo "")
    if [ -n "$sgs" ]; then
        cnt=$(echo "$sgs" | wc -l)
        echo "    Found $cnt security groups"
        TOTAL_COUNTS[security_groups]=$((${TOTAL_COUNTS[security_groups]} + cnt))
        HAS_RESOURCES=true
    else
        echo "    No Security Groups found in $region"
    fi

    # --- VPC Peering ---
    peering=$(aws ec2 describe-vpc-peering-connections --region "$region" --query 'VpcPeeringConnections[?Status.Code==`active`].[VpcPeeringConnectionId,RequesterVpcInfo.VpcId,AccepterVpcInfo.VpcId]' --output text 2>/dev/null || echo "")
    check_resource "VPC Peering Connections" "vpc_peering" "$peering" "$region"
    
    # --- EC2 Instances ---
    instances=$(aws ec2 describe-instances --region "$region" --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    check_resource "EC2 Instances" "ec2_instances" "$instances" "$region"

    # --- RDS Instances ---
    rds=$(aws rds describe-db-instances --region "$region" --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' --output text 2>/dev/null || echo "")
    check_resource "RDS Instances" "rds_instances" "$rds" "$region"

    # --- EKS Clusters ---
    eks_list=$(aws eks list-clusters --region "$region" --query 'clusters[]' --output text 2>/dev/null || echo "")
    
    eks_content=""
    if [ -n "$eks_list" ]; then
        for cluster in $eks_list; do
            # original script did this call for every cluster
            st=$(aws eks describe-cluster --region "$region" --name "$cluster" --query 'cluster.status' --output text 2>/dev/null || echo "Unknown")
            if [ -z "$eks_content" ]; then
                eks_content="$cluster ($st)"
            else
                eks_content="$eks_content"$'\n'"$cluster ($st)"
            fi
        done
    fi
    check_resource "EKS Clusters" "eks_clusters" "$eks_content" "$region"

    # --- Load Balancers ---
    lbs=$(aws elbv2 describe-load-balancers --region "$region" --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code]' --output text 2>/dev/null || echo "")
    check_resource "Load Balancers (ALB/NLB)" "load_balancers" "$lbs" "$region"

    # --- Lambda Functions ---
    lambdas=$(aws lambda list-functions --region "$region" --query 'Functions[].[FunctionName,Runtime,LastModified]' --output text 2>/dev/null || echo "")
    check_resource "Lambda Functions" "lambda_functions" "$lambdas" "$region"

    # --- DynamoDB Tables ---
    dynamo=$(aws dynamodb list-tables --region "$region" --query 'TableNames[]' --output text 2>/dev/null || echo "")
    check_resource "DynamoDB Tables" "dynamodb_tables" "$dynamo" "$region"

    # --- App Runner Services ---
    apprunner=$(aws apprunner list-services --region "$region" --query 'ServiceSummaryList[].[ServiceName,Status,ServiceUrl]' --output text 2>/dev/null || echo "")
    check_resource "App Runner Services" "app_runner_services" "$apprunner" "$region"

    # --- Amplify Apps ---
    amplify=$(aws amplify list-apps --region "$region" --query 'apps[].[name,defaultDomain,productionBranch.branchName]' --output text 2>/dev/null || echo "")
    check_resource "Amplify Apps" "amplify_apps" "$amplify" "$region"

    # --- S3 Buckets (region is global, check is only once) ---
    if [ "$region" == "us-east-1" ]; then
        echo "  S3 Buckets (Global):"
        buckets=$(aws s3 ls --output text 2>/dev/null | wc -l || echo "0")
        echo "    Found $buckets buckets"
        TOTAL_COUNTS[s3_buckets]=$buckets
        if [ "$buckets" -gt 0 ]; then
            HAS_RESOURCES=true
        fi
        
        # --- Route53 Hosted Zones (Global) ---
        r53=$(aws route53 list-hosted-zones --query 'HostedZones[].[Name,Id,Config.PrivateZone]' --output text 2>/dev/null || echo "")
        check_resource "Route53 Hosted Zones (Global)" "route53_zones" "$r53" ""
        
        # --- CloudFront Distributions (Global) ---
        cf=$(aws cloudfront list-distributions --query 'DistributionList.Items[].[Id,DomainName,Status]' --output text 2>/dev/null || echo "")
        check_resource "CloudFront Distributions (Global)" "cloudfront_distributions" "$cf" ""
    fi

    # Record if this region had anything
    if [ "$HAS_RESOURCES" = true ]; then
        REGIONS_WITH_RESOURCES+=("$region")
    fi
    echo ""
}

# main Loop where all regions are checked
for region in $regions; do
    check_region_resources "$region"
done

# print  the Summary of all resources found across all regions in your AWS account ---
echo "++++++++++++++++++++++++++++++++++++++++++++"
echo "           SUMMARY OF ALL RESOURCES        "
echo "++++++++++++++++++++++++++++++++++++++++++++"
echo ""

echo "TOTAL RESOURCES FOUND ACROSS ALL REGIONS IN YOUR AWS ACCOUNT:"
echo "================================"
echo "  VPCs:                    ${TOTAL_COUNTS[vpcs]}"
echo "  Subnets:                 ${TOTAL_COUNTS[subnets]}"
echo "  Internet Gateways:       ${TOTAL_COUNTS[igws]}"
echo "  NAT Gateways:            ${TOTAL_COUNTS[nat_gateways]}"
echo "  Route Tables:            ${TOTAL_COUNTS[route_tables]}"
echo "  Security Groups:         ${TOTAL_COUNTS[security_groups]}"
echo "  VPC Peering Connections: ${TOTAL_COUNTS[vpc_peering]}"
echo "  EC2 Instances (running): ${TOTAL_COUNTS[ec2_instances]}"
echo "  RDS Instances:           ${TOTAL_COUNTS[rds_instances]}"
echo "  EKS Clusters:            ${TOTAL_COUNTS[eks_clusters]}"
echo "  Load Balancers:          ${TOTAL_COUNTS[load_balancers]}"
echo "  Lambda Functions:        ${TOTAL_COUNTS[lambda_functions]}"
echo "  DynamoDB Tables:         ${TOTAL_COUNTS[dynamodb_tables]}"
echo "  App Runner Services:     ${TOTAL_COUNTS[app_runner_services]}"
echo "  Amplify Apps:            ${TOTAL_COUNTS[amplify_apps]}"
echo "  S3 Buckets:              ${TOTAL_COUNTS[s3_buckets]}"
echo "  Route53 Hosted Zones:    ${TOTAL_COUNTS[route53_zones]}"
echo "  CloudFront Distributions:${TOTAL_COUNTS[cloudfront_distributions]}"
echo ""

if [ ${#REGIONS_WITH_RESOURCES[@]} -eq 0 ]; then
    echo "No resources found in any region."
else
    echo "REGIONS WITH RESOURCES (${#REGIONS_WITH_RESOURCES[@]} total):"
    echo "-----------------------------------"
    for r in "${REGIONS_WITH_RESOURCES[@]}"; do
        echo "  $r:"
        # only print specific resources as per original design
        [ "${REGION_RESOURCES[${r}_vpcs]:-0}" -gt 0 ] && echo "    - VPCs: ${REGION_RESOURCES[${r}_vpcs]}"
        [ "${REGION_RESOURCES[${r}_subnets]:-0}" -gt 0 ] && echo "    - Subnets: ${REGION_RESOURCES[${r}_subnets]}"
        [ "${REGION_RESOURCES[${r}_igws]:-0}" -gt 0 ] && echo "    - Internet Gateways: ${REGION_RESOURCES[${r}_igws]}"
        [ "${REGION_RESOURCES[${r}_nats]:-0}" -gt 0 ] && echo "    - NAT Gateways: ${REGION_RESOURCES[${r}_nats]}"
        [ "${REGION_RESOURCES[${r}_ec2]:-0}" -gt 0 ] && echo "    - EC2 Instances: ${REGION_RESOURCES[${r}_ec2]}"
        [ "${REGION_RESOURCES[${r}_rds]:-0}" -gt 0 ] && echo "    - RDS Instances: ${REGION_RESOURCES[${r}_rds]}"
        [ "${REGION_RESOURCES[${r}_eks]:-0}" -gt 0 ] && echo "    - EKS Clusters: ${REGION_RESOURCES[${r}_eks]}"
        [ "${REGION_RESOURCES[${r}_lbs]:-0}" -gt 0 ] && echo "    - Load Balancers: ${REGION_RESOURCES[${r}_lbs]}"
        [ "${REGION_RESOURCES[${r}_lambda_functions]:-0}" -gt 0 ] && echo "    - Lambda Functions: ${REGION_RESOURCES[${r}_lambda_functions]}"
        [ "${REGION_RESOURCES[${r}_dynamodb_tables]:-0}" -gt 0 ] && echo "    - DynamoDB Tables: ${REGION_RESOURCES[${r}_dynamodb_tables]}"
        [ "${REGION_RESOURCES[${r}_app_runner_services]:-0}" -gt 0 ] && echo "    - App Runner Services: ${REGION_RESOURCES[${r}_app_runner_services]}"
        [ "${REGION_RESOURCES[${r}_amplify_apps]:-0}" -gt 0 ] && echo "    - Amplify Apps: ${REGION_RESOURCES[${r}_amplify_apps]}"
    done
fi

echo ""
echo "==========================================="
echo "Resource check complete! ❤️❤️❤️ from Roslaan"
echo "==========================================="