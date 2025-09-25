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

# Use existing bucket
data "google_storage_bucket" "bucket" {
  name = "roger-470808-gcf-source"
}

# Archive Function-1 folder into zip (exclude node_modules)
data "archive_file" "function1" {
  type        = "zip"
  source_dir  = "../Function-1"      # relative to terraform folder
  output_path = "/tmp/function-1.zip"
  excludes    = ["node_modules/*", "README.md"]
}

# Upload zip to GCS bucket with fixed name
resource "google_storage_bucket_object" "function1" {
  name   = "function-1.zip"
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
