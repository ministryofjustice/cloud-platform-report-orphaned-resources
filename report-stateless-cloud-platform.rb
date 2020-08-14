#!/usr/bin/env ruby

require "pry-byebug"
require "json"
require "bundler/setup"
require "aws-sdk-ec2"
require "aws-sdk-s3"
require "slack-notifier"
require "aws-sdk-autoscaling"
require "aws-sdk-route53"
require "find"

require "./modules/helper_methods.rb"
require "./modules/data_from_aws.rb"
require "./modules/data_from_state.rb"

include Helper
include Aws
include State

s3_bucket_region = "eu-west-1"
route53_bucket_region = "eu-west-2"
ec2_bucket_region = "eu-west-2"

state_file_path_cloud_platform = "state-files/cloud-platform"
state_file_path_cloud_platform_network = "state-files/cloud-platform-network"

Helper.download_state_files(Aws.get_aws_client("s3", "eu-west-1"), "cloud-platform-terraform-state", "cloud-platform", state_file_path_cloud_platform)
Helper.compare_and_report_data_host_zones(Aws.get_hosted_zones(Aws.get_aws_client("route53", route53_bucket_region)), State.route53_zones_from_terraform_state(state_file_path_cloud_platform), "aws_hosted_zones")

# Helper::compare_and_report_data(Aws::nat_gateway_ids_for_vpc(Aws::get_hosted_zones(Aws::get_aws_client("ec2", ec2_bucket_region)), vpc_id), State::nat_gateway_ids_from_terraform_state(state_file_path_cloud_platform), vpc_name, "nat-gateways")
