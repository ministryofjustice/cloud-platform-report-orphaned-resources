#!/usr/bin/env ruby

require "pry-byebug"
require_relative "../lib/stateless_resources"

AWS_REGION = "eu-west-2"

def route53_hosted_zones
  route53 = Aws::Route53::Client.new(region: AWS_REGION, profile: ENV["AWS_PROFILE"])
  zone_data = route53.list_hosted_zones
  zone_data.hosted_zones.map { |zone| zone.name }.uniq.sort
end

# Download all the state files for each vpc
def download_state_files
  prefixes = [
    "cloud-platform",
    "cloud-platform-eks",
    "cloud-platform-environments",
  ]

  StatelessResources::TerraformStateManager.new(
    s3client: Aws::S3::Resource.new(region: "eu-west-1", profile: ENV["AWS_PROFILE"]),
    bucket: "cloud-platform-terraform-state",
    prefix: "",
    dir: "state-files"
  ).download_terraform_states_for_prefixes(prefixes)
end

def zones_from_terraform_states(files)
  list = files.inject([]) do |arr, file|
    arr += zones_from_terraform_state(file)
  end
  list.flatten.map { |name| name.sub(/\.$/, "") }.uniq
end

def zones_from_terraform_state(statefile)
  return [] if FileTest.empty?(statefile)

  data = JSON.parse(File.read(statefile))
  if data.has_key?("resources")
    zones = data.fetch("resources").filter { |res| res["type"] == "aws_route53_zone" }
    zones.map { |zone| zone.fetch("instances").map { |instance| instance.dig("attributes", "name") } }.flatten
  else
    []
  end
end

##############################################

hosted_zones = zones_from_terraform_states(download_state_files)

pp hosted_zones
