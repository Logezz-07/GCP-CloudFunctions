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

# Storage bucket for function source
resource "google_storage_bucket" "bucket" {
  name                        = "roger-470808-gcf-source"  # Globally unique
  location                    = "us-central1"                       # Can stay US; bucket is multi-region
  uniform_bucket_level_access = true
}

# Archive Function-1 folder into zip
data "archive_file" "function1" {
  type        = "zip"
  source_dir  = "../Function-1"      # Relative path from terraform folder
  output_path = "/tmp/function-1.zip"
}

# Upload zip to GCS bucket
resource "google_storage_bucket_object" "function1" {
  name   = "function-1.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.function1.output_path
}

# Deploy Cloud Function
resource "google_cloudfunctions2_function" "function1" {
  name        = "function-1"
  location    = "us-central1"
  description = "Terraform-managed Function-1"

  build_config {
    runtime     = "nodejs20"
    entry_point = "helloHttp"  # Change if your function exports a different function

    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
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
