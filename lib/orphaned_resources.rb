require "bundler/setup"
require "json"
require "aws-sdk-ec2"
require "aws-sdk-s3"
require "aws-sdk-route53"

require_relative "./orphaned_resources/lister"
require_relative "./orphaned_resources/terraform_state_manager"
require_relative "./orphaned_resources/aws_resources"
require_relative "./orphaned_resources/reporter"
require_relative "./orphaned_resources/resource_tuple"
require_relative "./orphaned_resources/hosted_zone_tuple"
