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

unlisted_subnets = (aws_resources.subnets - terraform_state.subnets).sort
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

expected = [
  "subnet-00b69b12d4f09e071",
  "subnet-0138864ff21b5366c",
  "subnet-020b24a6ef7781907",
  "subnet-037b76b614e2c1f1b",
  "subnet-04847ca33eb45c59c",
  "subnet-04c6bd06dde440689",
  "subnet-057566078595c41af",
  "subnet-05d07bbd206da8487",
  "subnet-0679de94b1e070064",
  "subnet-0702b6672f19c9455",
  "subnet-0763be12e7637c6de",
  "subnet-07e7075e4ada33083",
  "subnet-0830b27266c3f9ba0",
  "subnet-09655e4b0e4c2f24c",
  "subnet-09da019b3486e69c2",
  "subnet-0a806db0f701ce9ec",
  "subnet-0c23108235d1060c8",
  "subnet-0c4ae9dfc30cf7592",
  "subnet-0c86152e56fcd5c55",
  "subnet-0ca05b946be668f41",
  "subnet-0ce2286bbef6c2da8",
  "subnet-0ef4a35a676601e6b",
  "subnet-0f1f08505f709a87e",
  "subnet-0f52304b43a1c2b43",
  "subnet-0f54fdcdfc525343a",
  "subnet-0f9ae7697e56c1450",
  "subnet-4178f728",
  "subnet-a069a0da",
  "subnet-cdf6e980"]
binding.pry unless unlisted_subnets == expected

puts "pass"
