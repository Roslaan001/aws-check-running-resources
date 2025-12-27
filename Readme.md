# AWS Resource Checker

A Bash script to scan specific AWS resources across all regions in your AWS account and provide a summary of active resources.

## Description

This script iterates through all available AWS regions and checks for the existence of various resources. It outputs details for each region and provides a consolidated summary at the end, making it easy to see where your resources are deployed.

## Prerequisites

- **AWS CLI**: Ensure the AWS Command Line Interface is installed and configured with appropriate credentials.
  - Configuration: Run `aws configure` to set up your access key, secret key, and default region. OR
  - Configuration: Run `aws login`(new aws cli authentication) to set up your access key, secret key, and default region. This authentication mode only last 12 hours 
- **Bash**: The script is written in Bash and requires a Bash environment to run.

## Installation & Usage

You can run this script by either cloning the repository or running it directly.

### Method 1: Clone the Repository (Recommended)

1. Clone the repository:

    ```bash
    git clone https://github.com/Roslaan001/aws-check-running-resources.git
    cd aws-check-running-resources
    ```

2. Make sure the script is executable:

    ```bash
    chmod +x aws_check_resources.sh
    ```

3. Run the script:

    ```bash
    ./aws_check_resources.sh
    ```

### Method 2: Quick Run (No Clone)

You can run the script directly from your terminal without cloning the repository:

```bash
bash <(curl -sL https://raw.githubusercontent.com/Roslaan001/aws-check-running-resources/main/aws_check_resources.sh)
```

## Resources Checked

The script checks for the following resources per region:

- **Networking:**
  - VPCs
  - Subnets (Count only)
  - Internet Gateways
  - NAT Gateways
  - Route Tables (Count only)
  - Security Groups (Count only)
  - VPC Peering Connections
  - Load Balancers (ALB/NLB)
  - Route53 Hosted Zones (Global check)
  - CloudFront Distributions (Global check)

- **Compute:**
  - EC2 Instances (Running instances only)
  - Lambda Functions
  - App Runner Services
  - EKS Clusters

- **Database & Storage:**
  - RDS Instances
  - DynamoDB Tables
  - S3 Buckets (Global check)

- **Mobile & Web:**
  - Amplify Apps

## Output

The script provides:

1. **Per-Region Details:** Lists resources found in each checked region.
2. **Summary:** A total count of all resources found across the account.
3. **Regions with Resources:** A filtered list of only the regions that contain resources, detailing what was found.

## Author

Script provided with ❤️ from Abdulwahab Abdulsomad (Roslaan).
