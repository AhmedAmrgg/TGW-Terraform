# 🏗️ AWS Transit Gateway Project (Terraform)

This project demonstrates how to connect multiple VPCs using **AWS Transit Gateway (TGW)** for inter-VPC communication using **Terraform**.

---

## 📘 Architecture Overview

The setup includes:

- **VPC-A** , **VPC-B** , **VPC-C** (created via `for_each` loop)
- **Public Subnet** in VPC-A (for Bastion Host)
- **Private Subnets** in both VPCs
- **Internet Gateway** (VPC-A only)
- **Transit Gateway (TGW)** for communication between VPCs
- **Route Tables** for routing traffic correctly
- **EC2 instances**:
  - 1 Bastion Host (Public)
  - 1 Private EC2 per VPC
- **Security Groups** to allow SSH and ICMP (ping)

---

## 🧩 Components

| Component | Description |
|------------|-------------|
| **aws_vpc.vpcs** | Creates two VPCs using locals |
| **aws_subnet.public_subnets** | Public subnet in VPC-A for bastion host |
| **aws_subnet.private_subnets** | Private subnet per VPC |
| **aws_internet_gateway.igws** | Internet Gateway for VPC-A |
| **aws_ec2_transit_gateway.main** | Central Transit Gateway for inter-VPC routing |
| **aws_ec2_transit_gateway_vpc_attachment** | Attaches each VPC to TGW |
| **aws_ec2_transit_gateway_route_table_association/propagation** | Associates and propagates TGW routes |
| **aws_route_table.public_rts** | Public route table for internet access |
| **aws_route_table.private_route_table-A/B** | Private route tables routing through TGW |
| **aws_instance.bastion** | Bastion host for SSH access |
| **aws_instance.ec2_instances** | EC2 instances in private subnets |
| **aws_security_group.sg** | SGs for private instances |
| **aws_security_group.bastion_sg** | SG for bastion host |

---



## ⚙️ Prerequisites

- Terraform ≥ 1.5  
- AWS CLI configured (`aws configure`)  
- Existing key pairs in AWS (`XXXX`, `XXXX1`)  
- Proper IAM permissions to create networking resources  

---

## 🚀 How to Deploy

1. Clone this repo:
   ```bash
   git clone https://github.com/<your-username>/tgw-terraform-project.git
   cd tgw-terraform-project
   ```
Initialize Terraform:
```
terraform init
```
Validate and plan:
```
terraform validate
terraform plan
```
Apply the configuration:
```
terraform apply -auto-approve
```
Once deployed, SSH into Bastion:
```
ssh -i xxxxx.pem ec2-user@<bastion-public-ip>
```
From the Bastion Host, connect to private EC2s via their private IPs:
```
ssh -i xxxxx.pem ec2-user@<private-ec2-ip>
```
To destroy all resources:
```
terraform destroy -auto-approve
```