require "bundler/setup"
require "json"
require "aws-sdk-ec2"
require "aws-sdk-s3"
require "slack-notifier"

require_relative "./stateless_resources/terraform_state_manager"

require "./modules/helper_methods.rb"
