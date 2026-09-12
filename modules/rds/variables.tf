variable "identifier" {
  description = "Unique identifier of the RDS instance."
  type        = string
}

variable "db_name" {
  description = "Name of the initial database created inside the instance."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
}

variable "subnet_group_name" {
  description = "Name of the DB subnet group (shared across instances)."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security group IDs attached to the instance."
  type        = list(string)
}

variable "db_user" {
  description = "Master username for the instance."
  type        = string
}

variable "db_pass" {
  description = "Master password for the instance. Provide via TF_VAR_db_pass, never commit it."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.db_pass)) >= 12
    error_message = "db_pass must be at least 12 characters long and provided via TF_VAR_db_pass."
  }
}
