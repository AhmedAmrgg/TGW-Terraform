variable "vpcs" {
  description = "Map of VPC configurations"
  type = map(object({
    cidr           = string
    subnet_public  = string
    subnet_private = string
    az             = string
  }))

  default = {
    vpc-A  = {
      cidr = "10.1.0.0/16"
      subnet_public  = "10.1.1.0/24"
      subnet_private = "10.1.2.0/24"
      az             = "us-east-1a"
    }
    vpc-B  = {
      cidr = "10.2.0.0/16"
      subnet_public  = "10.2.1.0/24"
      subnet_private = "10.2.2.0/24"
      az             = "us-east-1a"
    }
    vpc-C = {
      cidr            = "10.3.0.0/16"
      subnet_public   = "10.3.1.0/24"
      subnet_private  = "10.3.2.0/24"
      az              = "us-east-1a"
    }
  }
}
