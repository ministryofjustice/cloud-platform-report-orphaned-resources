#!/usr/bin/env ruby

require "pry-byebug"
require "json"
require "bundler/setup"
require "aws-sdk-ec2"
require "aws-sdk-s3"
require 'slack-notifier'
require "aws-sdk-autoscaling"
require "aws-sdk-route53"
require "find"

@state_file_path_local = "state-files/cloud-platform"
@slack_token = ENV["SLACK_TOKEN"]

#*******Methods to get resource data directly from AWS using ruby sdk***************


def asg_for_arn(asg, auto_scaling_group_arn)
    filter = [ { name: "auto_scaling_group_arn", values: [auto_scaling_group_arn] } ]
    data = asg.describe_auto_scaling_groups(filter: filter)
    data.auto_scaling_groups.map { |each_asg| each_asg.auto_scaling_group_name }.sort
end


def get_hosted_zones(route53)
  hosted_zones = []
  data = route53.list_hosted_zones
  hosted_zones = data.hosted_zones.map { |zone| zone.name }.sort
  return hosted_zones 
end


#************ Methods to get data from state files****************


def route53_zones_from_terraform_state(s3)
  hosted_zones_from_state = []
  get_state_vpc_names_from_s3key(s3).each do |vpc_name_in_key|
    begin
      str = File.read(@state_file_path_local+"/cloud-platform-"+vpc_name_in_key+".tfstate")
      data = JSON.parse(str)
      list = data["resources"]
      zone_name = list.filter { |m| m["type"] == "aws_route53_zone" }.first
      hosted_zones_from_state.push(zone_name["instances"].map { |zone| zone.dig("attributes", "name") }.sort[0])
    rescue => e
    end
  end
  return hosted_zones_from_state
end

# Download all the state files for each vpc 
def download_state_files(s3)
  #Iterate each state file for each vpc ( by name ) to get the bucket key containing the vpc name
    s3_keys_list = []
    s3_keys_list = s3.bucket("cloud-platform-terraform-state").objects(prefix:'cloud-platform/', delimiter: '').collect(&:key) 
    s3_keys_list.drop(1).each do |each_key| #skip the first as this has no key
        begin
            #extract the name from the key
            each_key_list = each_key.split('/')
            bucket_name = "cloud-platform-terraform-state"
            statefile_name_output = @state_file_path_local+"/cloud-platform-"+each_key_list[1]+".tfstate"
            download_state_from_s3(s3, bucket_name, each_key, statefile_name_output)
        rescue => e 
        end
    end
end

def get_state_vpc_names_from_s3key(s3)

  s3_state_bucket_keys = s3.bucket("cloud-platform-terraform-state").objects(prefix:'cloud-platform', delimiter: '').collect(&:"key")

  keys = []
  vpc_names = []
  s3_state_bucket_keys.each { |vpc_name| keys << vpc_name.delete(' ') }
  
  keys.each do |key|
    key_split = key.split('/')
    vpc_names.push(key_split[1])
  end

  return vpc_names

end 

def get_state_filenames()
  state_files_names = []
  Find.find(@state_file_path_local) do |file|
    state_files_names.push(file.strip)
  end
  state_files_names.delete_at 0
  return state_files_names
end


def download_state_from_s3(s3, bucket_name, key, statefile_path)
  # Loop through all the dynamically fetched vpc names and download the network state file from s3
  obj = s3.bucket(bucket_name).object(key)
  obj.get(response_target: statefile_path)
end


s3 = Aws::S3::Resource.new(region:'eu-west-1', profile: ENV["AWS_PROFILE"])
#binding.pry
#asg = Aws::AutoScaling::Client.new(region:'eu-west-2', profile: ENV["AWS_PROFILE"])
route53 = Aws::Route53::Client.new(region:'eu-west-2', profile: ENV["AWS_PROFILE"])

ec2 = Aws::EC2::Client.new(region:'eu-west-2', profile: ENV["AWS_PROFILE"])

download_state_files(s3)

###########REPORT STATELESS RESOURCES######################

def send_slack_notification(slack_token, message)
  notifier = Slack::Notifier.new "https://hooks.slack.com/services/T02DYEB3A/"+slack_token do
    defaults channel: "#ecr-scan-test-1",username: "notifier"
  end
  notifier.ping message
end

#******** Compare the natgateway ids **********************

#pp get_hosted_zones(route53)
#puts '************STATE ZONES**************'
#pp route53_zones_from_terraform_state(s3)

def compare_and_report_data(aws_data, state_data, resource)
  #all_data = aws_data | state_data
  #  send_slack_notification(@slack_token, 'VPC: '+vpc_name+' | RESOURCE: '+resource+' | STATE: ('+state_data_str+') | ACTUAL: ('+aws_data_str+')')
  #puts all_data.uniq
  puts '*******AWS*******'
  puts aws_data
  puts '*******STATE*******'
  puts state_data
end
  

compare_and_report_data(get_hosted_zones(route53), route53_zones_from_terraform_state(s3), "aws_hosted_zones")
