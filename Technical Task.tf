provider "aws" {
    region = "us-east-2"
access_key = ""
secret_key = ""
  }

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "newtechnicaltask"  
  acl    = "public-read"
     
     website {
    index_document = "index.html" 
     }
   } 

resource "aws_s3_bucket_object" "index_object" {
bucket = "newtechnicaltask"
key    = "index.html"
source = "html/index.html"
acl    = "public-read"
} 

resource "aws_s3_bucket_object" "error_object" {
  bucket = "newtechnicaltask"
  key    = "error.html"
  source = "html/error.html"
  acl    = "public-read"
} 

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = "aws_s3_bucket.newtechnicaltask.bucket.s3.amazonaws.com"
    origin_id   = "website"

  }
  
   enabled  = true
   is_ipv6_enabled = true

 
   default_root_object = "index.html"

   default_cache_behavior {
    allowed_methods = [
      "HEAD",
      "GET"
    ]
    cached_methods = [
      "HEAD",
      "GET"
    ]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    default_ttl = 0
    max_ttl     = 0
    min_ttl     = 0
    target_origin_id = "website"
    viewer_protocol_policy = "redirect-to-https"
    compress = true
  }
   
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods = ["HEAD", "GET"]
    cached_methods = ["HEAD", "GET"]
  
    forwarded_values {
      cookies {
        forward = "none"
      }
      query_string = false
    }
    default_ttl            = 1800
    max_ttl                = 1800
    min_ttl                = 1800
    target_origin_id       = "website"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  viewer_certificate {
   cloudfront_default_certificate = true 
  }

  restrictions {
       geo_restriction {
         restriction_type = "none"
       }
     }

}

resource "aws_iam_role" "newtechnicaltask_codepipeline" { 
  name = "newtechnicaltask_codepipeline"

  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com" 
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {  
  name = "codepipeline_policy"
  role = aws_iam_role.newtechnicaltask_codepipeline.name
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObjectAcl", 
        "cloudfront:GetInvalidation", 
        "s3:PutObject" 
      ],
      "Resource": [ 
         "arn:aws:s3:::newtechnicaltask",
         "arn:aws:s3:::newtechnicaltask/*"
      ]
    }
  ]
}
EOF
}

resource  "aws_codepipeline" "newtechnicaltask_pipeline" { 
  name  = "newtechnicaltask_pipeline" 
  role_arn = "arn:aws:iam::016352642720:role/newtechnicaltask_codepipeline" 
  
  
  artifact_store {
    location = "newtechnicaltask" 
    type     = "S3"
  } 
 
  stage {
    name = "Source" 

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "Github"
      version          = "2" 
      output_artifacts = ["SourceArtifacts"]

      configuration = {
          Owner                = "${var.source_repo_github_owner}"
          OAuthToken           = ""
          FullRepositoryId     = "${var.source_repo_github_owner}/${var.source_repo_github}"
          Branch               = "main"
          PollForSourceChanges = "true"
      }
    }
  }

 stage {   
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "s3"
      input_artifacts = ["OutputArtifacts"] 
      version         = "1"

      configuration = {
           BucketName = "newechnicaltask"
              Extract =  "true"
        
   }
  } 
 }
}

locals {
  webhook_secret = "super-secret"
}

resource "aws_codepipeline_webhook" "newtechnicaltask_pipeline" {
  name = "newtechnicaltask_pipeline" 
  authentication = "GITHUB_HMAC"
  target_action = "Source"
  target_pipeline = "aws_codepipeline.newtechnicaltask_pipeline"

authentication_configuration {
  secret_token = local.webhook_secret
}

filter {
  json_path = "$.ref"
  match_equals = "refs/heads/{Branch}"  
 }
}

resource "github_repository_webhook" "newtechnicaltask_pipeline" { 
  repository ="/${var.source_repo_github_owner}/${var.source_repo_github}"
 

   configuration {
     url = aws_codepipeline_webhook.newtechnicaltask_pipeline.url
     content_type = "json"
     secret = local.webhook_secret

   }
     events = ["push"]    
}

