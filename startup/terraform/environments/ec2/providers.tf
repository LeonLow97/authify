terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94.1"
    }
  }
  required_version = ">= 1.2.0"
}

provider "http" {}
