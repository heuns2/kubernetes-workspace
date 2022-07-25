variable "cluster_name" {
  default = "test-cluster"
}

variable "cluster_version" {
  default = "1.21"
}

variable "oidc_thumbprint_list" {
  default = []
  type = list(string)
}

