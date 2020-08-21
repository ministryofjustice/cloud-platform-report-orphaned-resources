#!/usr/bin/env ruby

require "pry-byebug"
require_relative "../lib/stateless_resources"

AWS_REGION = "eu-west-2"

def route53_hosted_zones
  route53 = Aws::Route53::Client.new(region: AWS_REGION, profile: ENV["AWS_PROFILE"])
  zone_data = route53.list_hosted_zones
  hosted_zones = zone_data.hosted_zones.map { |zone| zone.name }.uniq.sort
  return hosted_zones
end

# Download all the state files for each vpc
def download_state_files(bucket_name, statefile_path)
  s3 = Aws::S3::Resource.new(region: "eu-west-1", profile: ENV["AWS_PROFILE"])

  downloader = StatelessResources::TerraformStateManager.new(
    s3client: s3,
    bucket: bucket_name,
    prefix: "",
    dir: "state-files"
  )

  prefixes = [
    "cloud-platform",
    "cloud-platform-eks",
    "cloud-platform-environments",
  ]

  objects = objects_matching_prefixes(s3, bucket_name, prefixes)

  objects.map { |object| downloader.download_terraform_state(object.key) }
end

def objects_matching_prefixes(s3, bucket_name, prefixes)
  objects = s3.bucket(bucket_name).objects

  objects.filter do |object|
    prefix = object.key.split("/").first
    prefixes.include?(prefix)
  end
end

##############################################

files = download_state_files("cloud-platform-terraform-state", "state-files")

list = []

files.each do |file|
  unless FileTest.empty?(file)
    data = JSON.parse(File.read(file))
    if data.has_key?("resources")
      zones = data.fetch("resources").filter { |res| res["type"] == "aws_route53_zone" }
      list += zones.map { |zone| zone.fetch("instances").map { |instance| instance.dig("attributes", "name") } }
    end
  end
end

hosted_zones = list.flatten.map { |name| name.sub(/\.$/, "") }.uniq

binding.pry

puts "done"
