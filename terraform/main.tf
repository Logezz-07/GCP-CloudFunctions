terraform {
  backend "gcs" {
    bucket = "roger-470808-terraform-state"
    prefix = "cloud-functions"
  }

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
  project = var.project_id
  region  = var.region
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

# Archive each function folder into zip
data "archive_file" "functions" {
  for_each    = toset(var.functions)
  type        = "zip"
  source_dir  = "../${each.key}"
  output_path = "/tmp/${each.key}.zip"
  excludes    = ["node_modules","README.md"]
}

# Upload each zip to bucket
resource "google_storage_bucket_object" "function_objects" {
  for_each = toset(var.functions)
  name     = "${each.key}-${data.archive_file.functions[each.key].output_sha}.zip"
  bucket   = data.google_storage_bucket.bucket.name
  source   = data.archive_file.functions[each.key].output_path
}

# Deploy or update Cloud Functions
resource "google_cloudfunctions2_function" "functions" {
  for_each    = toset(var.functions)
  name        = each.key
  location    = var.region
  description = "Terraform-managed Cloud Function: ${each.key}"

  build_config {
    runtime     = "nodejs20"
    entry_point = "helloHttp"

    source {
      storage_source {
        bucket = data.google_storage_bucket.bucket.name
        object = google_storage_bucket_object.function_objects[each.key].name
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

# Allow public HTTP invoke for each function
resource "google_cloud_run_service_iam_member" "public_invoker" {
  for_each = google_cloudfunctions2_function.functions

  location = each.value.location
  service  = each.value.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_cloudfunctions2_function.functions]
}

# Output all function URLs
output "function_urls" {
  value = {
    for k, f in google_cloudfunctions2_function.functions :
    k => f.service_config[0].uri
  }
}
