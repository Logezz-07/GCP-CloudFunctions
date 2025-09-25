terraform {
  

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.34.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}

provider "google" {
  project = "roger-470808"
  region  = "us-central1"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "functions" {
  description = "List of function folders to deploy"
  type        = list(string)
}

# Use existing bucket for function source
data "google_storage_bucket" "bucket" {
  name = "roger-470808-gcf-source"
}

# Archive Function-1 folder into zip
data "archive_file" "function1" {
  type        = "zip"
  source_dir  = "../Function-1"        # Relative path from terraform folder
  output_path = "/tmp/function-1.zip"
  excludes    = ["node_modules","README.md"]
}

# Upload zip to GCS bucket
resource "google_storage_bucket_object" "function1" {
  name   = "function-1-${data.archive_file.function1.output_sha}.zip"  # unique for every code change
  bucket = data.google_storage_bucket.bucket.name
  source = data.archive_file.function1.output_path
}

# Deploy or update Cloud Function
resource "google_cloudfunctions2_function" "function1" {
  name        = "function-1"
  location    = "us-central1"
  description = "Terraform-managed Function-1"

  build_config {
    runtime     = "nodejs20"
    entry_point = "helloHttp"

    source {
      storage_source {
        bucket = data.google_storage_bucket.bucket.name
        object = google_storage_bucket_object.function1.name
      }
    }
  }

  service_config {
    min_instance_count = 1
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    ingress_settings   = "ALLOW_ALL"
  }
}

# Output Function URL
output "function1_url" {
  value = google_cloudfunctions2_function.function1.service_config[0].uri
}
