#!/usr/bin/env ruby

# List all resources on AWS which are not mentioned in any terraform state
# files.

require_relative "../lib/stateless_resources"

s3 = Aws::S3::Resource.new(region: "eu-west-1", profile: ENV["AWS_PROFILE"])
ec2 = Aws::EC2::Client.new(region: "eu-west-2", profile: ENV["AWS_PROFILE"])

aws_resources = StatelessResources::AwsResources.new(
  s3client: s3,
  ec2client: ec2,
)

terraform_state = StatelessResources::TerraformStateManager.new(
  s3client: s3,
  bucket: "cloud-platform-terraform-state",
  prefix: "cloud-platform-network/",
  dir: "state-files/cloud-platform-network"
)

unlisted_nat_gateways = (aws_resources.nat_gateway_ids - terraform_state.nat_gateway_ids).sort
unlisted_vpcs = (aws_resources.vpc_ids - terraform_state.vpc_ids).sort

####################################

# This is a temporary hack so that I can confirm the code still works as I move
# parts of it around. Once proper unit tests exist, this will be deleted.
expected = [
  "nat-03c4ef7991e5570da",
  "nat-047c2caaab4603d0d",
  "nat-06ada4dc2beb9cf5e",
  "nat-06cc3719834125f64",
  "nat-0b02f4d851ec4b7ba",
  "nat-0dc9232ab42919ba3",
  "nat-0de253ad0c6d4a58f",
  "nat-0e49a5ae888cc9050",
  "nat-0e76c85907f19a2e6",
  "nat-0e8e62b49a8787cd7",
  "nat-0f1509bbff438b942",
  "nat-0f6e554694378158b"
]
binding.pry unless unlisted_nat_gateways == expected

expected = [
  "vpc-0267b8f3c5fae7d13",
  "vpc-04e9f82e4d988355a",
  "vpc-057ac86d",
  "vpc-0a9ab8481d742855e",
  "vpc-0b857224f5167262d",
  "vpc-0bab8ed9b758fe5ae",
  "vpc-0c4c69a47d9d1cde4",
]
binding.pry unless unlisted_vpcs == expected
puts "pass"
