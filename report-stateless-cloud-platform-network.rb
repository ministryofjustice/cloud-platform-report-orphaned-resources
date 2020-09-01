#!/usr/bin/env ruby

require "pry-byebug"

require "./lib/stateless_resources"

include Helper
@state_file_path_local = "state-files/cloud-platform-network"

# *******Methods to get resource data directly from AWS using ruby sdk***************

# def nat_gateway_ids_for_vpc(client, vpc_id)
#   filter = [{name: "vpc-id", values: [vpc_id]}]
#   data = client.describe_nat_gateways(filter: filter)
#   data.nat_gateways.map { |ng| ng.nat_gateway_id }.sort
# end

def subnets_ids_for_vpc(client, vpc_id)
  filters = [{name: "vpc-id", values: [vpc_id]}]
  data = client.describe_subnets(filters: filters)
  data.subnets.map { |sn| sn.subnet_id }.sort
end

def route_tables_for_subnet(client, subnet_id)
  filters = [{name: "association.subnet-id", values: [subnet_id]}]
  route_table_id = ""
  data = client.describe_route_tables(filters: filters)
  data[:route_tables][0][:associations].each do |route|
    route_table_id = (route[:route_table_id])
    # A subnet can only be associated to one route table, so we can break as soon as we assign the first route table (the rest will be duplicates)
    break
  end
  route_table_id
end

def route_tables_assoc_for_subnet(client, subnet_id)
  filters = [{name: "association.subnet-id", values: [subnet_id]}]
  route_table_association_id = ""
  data = client.describe_route_tables(filters: filters)
  data[:route_tables][0][:associations].each do |route|
    route_table_association_id = (route[:route_table_association_id])
    # A subnet can only be associated to one route table, so we can break as soon as we assign the first route table assoc (the rest will be duplicates)
    break
  end
  route_table_association_id
end

def internet_gateway_ids_for_vpc(client)
  data = client.describe_internet_gateways
  data.internet_gateways.map { |ng| ng.internet_gateway_id }.sort
end

# def vpc_ids(client)
#   data = client.describe_vpcs
#   data.vpcs.map { |vpc| vpc.vpc_id }.sort
# end

# **********Methods to get data from tf state files****************

# def nat_gateway_ids_from_terraform_state(statefile)
#   str = File.read(statefile)
#   data = JSON.parse(str)
#   list = data["resources"]
#   nat_gateway = list.filter { |m| m["name"] == "private_nat_gateway" }.first
#   nat_gateway["instances"].map { |ng| ng.dig("attributes", "nat_gateway_id") }.sort
# end

def subnet_ids_from_terraform_state(statefile)
  str = File.read(statefile)
  data = JSON.parse(str)
  subnets_ids_public = data["outputs"]["external_subnets_ids"]["value"]
  subnets_ids_pvt = data["outputs"]["internal_subnets_ids"]["value"]
  subnets_ids = subnets_ids_public | subnets_ids_pvt
  subnets_ids
rescue => e
end

def route_table_ids_from_terraform_state(statefile)
  str = File.read(statefile)
  data = JSON.parse(str)
  route_table_ids_public = data["outputs"]["private_route_tables"]["value"]
  route_table_ids_pvt = data["outputs"]["public_route_tables"]["value"]
  route_table_ids = route_table_ids_public | route_table_ids_pvt
  route_table_ids
rescue => e
end

def route_table_associations_from_terraform_state(statefile)
  route_table_association_pvt_list = []
  route_table_association_pub_list = []
  str = File.read(statefile)
  data = JSON.parse(str)
  list = data["resources"]
  route_table_association_pvt = list.filter { |m| m["type"] == "aws_route_table_association" }[3] # The private route tbl assoc are in iteration 3
  route_table_association_pub = list.filter { |m| m["type"] == "aws_route_table_association" }[4] # The private route tbl assoc are in iteration 4
  route_table_association_pvt_list = route_table_association_pvt["instances"].map { |route_tbl_assoc| route_tbl_assoc.dig("attributes", "id") }.sort
  route_table_association_pub_list = route_table_association_pub["instances"].map { |route_tbl_assoc| route_tbl_assoc.dig("attributes", "id") }.sort
  route_table_association_pvt_list | route_table_association_pub_list # Add the public route tbl assoc (in iteration 2) to the private ones before returning
rescue => e
end

def internet_gateway_ids_from_terraform_state(statefile)
  str = File.read(statefile)
  data = JSON.parse(str)
  list = data["resources"]
  nat_gateway = list.filter { |m| m["name"] == "public_internet_gateway" }.first
  nat_gateway["instances"].map { |ng| ng.dig("attributes", "gateway_id") }.sort
end

def vpc_ids_from_aws(ec2client)
  ec2client.describe_vpcs.vpcs.map { |vpc| vpc.vpc_id }.sort
end

def vpc_ids(local_statefiles)
  local_statefiles.map { |file|
    data = JSON.parse(File.read(file))
    data.dig("outputs", "vpc_id", "value")
  }.compact
end

# ##########REPORT STATELESS RESOURCES######################

def send_slack_notification(slack_token, message)
  notifier = Slack::Notifier.new "https://hooks.slack.com/services/T02DYEB3A/" + slack_token do
    defaults channel: "#ecr-scan-test-1", username: "notifier"
  end
  notifier.ping message
end

# ******** Compare the natgateway ids **********************

# def report_stateless_natgateways(ec2, vpc_ids_with_names_from_state)
#   vpc_ids_with_names_from_state.each do |vpc_id_with_name|
#     each_vpc_id_with_name = vpc_id_with_name.split("|")
#     vpc_id = each_vpc_id_with_name[0]
#     vpc_name = each_vpc_id_with_name[1]
#     compare_and_report_data(nat_gateway_ids_for_vpc(ec2, vpc_id), nat_gateway_ids_from_terraform_state(@state_file_path_local + "/vpc-network-" + vpc_name + ".tfstate"), vpc_name, "nat-gateways")
#   end
# end

def report_stateless_subnets(ec2, vpc_ids_with_names_from_state)
  vpc_ids_with_names_from_state.each do |vpc_id_with_name|
    each_vpc_id_with_name = vpc_id_with_name.split("|")
    vpc_id = each_vpc_id_with_name[0]
    vpc_name = each_vpc_id_with_name[1]
    compare_and_report_data(subnets_ids_for_vpc(ec2, vpc_id), subnet_ids_from_terraform_state(@state_file_path_local + "/vpc-network-" + vpc_name + ".tfstate"), vpc_name, "subnets")
  end
end

def report_stateless_route_tables(ec2, vpc_ids_with_names_from_state)
  vpc_ids_with_names_from_state.each do |vpc_id_with_name|
    each_vpc_id_with_name = vpc_id_with_name.split("|")
    vpc_id = each_vpc_id_with_name[0]
    vpc_name = each_vpc_id_with_name[1]
    subnets_ids_for_vpc_arr = subnets_ids_for_vpc(ec2, vpc_id)
    route_tables_ids_arr = []
    subnets_ids_for_vpc_arr.each do |subnet_id|
      route_tables_ids_arr.push(route_tables_for_subnet(ec2, subnet_id).strip)
    end
    # each of the public subnets are associated to the same route table. The public route table will be duplicated for every public subnet. So we can remove these.
    route_tables_ids_arr = route_tables_ids_arr.uniq
    compare_and_report_data(route_tables_ids_arr, route_table_ids_from_terraform_state(@state_file_path_local + "/vpc-network-" + vpc_name + ".tfstate"), vpc_name, "route-tables")
  end
rescue => e
end

def report_stateless_route_tables_assoc(ec2, vpc_ids_with_names_from_state)
  vpc_ids_with_names_from_state.each do |vpc_id_with_name|
    each_vpc_id_with_name = vpc_id_with_name.split("|")
    vpc_id = each_vpc_id_with_name[0]
    vpc_name = each_vpc_id_with_name[1]
    subnets_ids_for_vpc_arr = subnets_ids_for_vpc(ec2, vpc_id)
    route_tables_ids_assoc_arr = []
    subnets_ids_for_vpc_arr.each do |subnet_id|
      route_tables_ids_assoc_arr.push(route_tables_assoc_for_subnet(ec2, subnet_id).strip)
    end
    compare_and_report_data(route_tables_ids_assoc_arr, route_table_associations_from_terraform_state(@state_file_path_local + "/vpc-network-" + vpc_name + ".tfstate"), vpc_name, "route-tables")
  end
rescue => e
end

def compare_and_report_data(aws_data, state_data, vpc_name, resource)
  state_data.collect { |e| e.strip }
  aws_data.collect { |e| e.strip }
  state_data.sort
  aws_data.sort

  if state_data.to_set != aws_data.to_set
    state_data_str = state_data.join(" | ")
    aws_data_str = aws_data.join(" | ")

    pp "VPC: " + vpc_name + " : some " + resource + " do not match between the state and actual"
    pp "STATE:"
    pp state_data_str
    pp "ACTUAL:"
    pp aws_data_str

    send_slack_notification(ENV["SLACK_TOKEN"], "VPC: " + vpc_name + " | RESOURCE: " + resource + " | STATE: (" + state_data_str + ") | ACTUAL: (" + aws_data_str + ")")
  end
rescue => e
end

s3 = Aws::S3::Resource.new(region: "eu-west-1", profile: ENV["AWS_PROFILE"])

# binding.pry
ec2 = Aws::EC2::Client.new(region: "eu-west-2", profile: ENV["AWS_PROFILE"])

statefiles = StatelessResources::TerraformStateManager.new(
  s3client: s3,
  bucket: "cloud-platform-terraform-state",
  prefix: "cloud-platform-network/",
  dir: "state-files/cloud-platform-network"
).download_files

unlisted_vpcs = vpc_ids_from_aws(ec2) - vpc_ids(statefiles)

# This is a temporary hack so that I can confirm the code still works as I move
# parts of it around. Once proper unit tests exist, this will be deleted.
expected = [
  "vpc-0267b8f3c5fae7d13",
  "vpc-04e9f82e4d988355a",
  "vpc-057ac86d",
  "vpc-0a9ab8481d742855e",
  "vpc-0b857224f5167262d",
  "vpc-0bab8ed9b758fe5ae",
  "vpc-0c4c69a47d9d1cde4",
]
binding.pry unless unlisted_vpcs.sort == expected
puts "pass"
