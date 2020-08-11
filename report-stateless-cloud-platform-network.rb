#!/usr/bin/env ruby

require "pry-byebug"
require "json"
require "bundler/setup"
require "aws-sdk-ec2"
require "aws-sdk-s3"
require 'slack-notifier'


@state_file_path_local = "state-files/cloud-platform-network"
@slack_token = ENV["SLACK_TOKEN"]

#*******Methods to get resource data directly from AWS using ruby sdk***************


def nat_gateway_ids_for_vpc(client, vpc_id)
  filter = [ { name: "vpc-id", values: [vpc_id] } ]
  data = client.describe_nat_gateways(filter: filter)
  data.nat_gateways.map { |ng| ng.nat_gateway_id }.sort
end

def subnets_ids_for_vpc(client, vpc_id)
  filters = [ { name: "vpc-id", values: [vpc_id] } ]
  data = client.describe_subnets(filters: filters)
  data.subnets.map { |sn| sn.subnet_id }.sort
end

def route_tables_for_subnet(client, subnet_id)
  filters = [ { name: "association.subnet-id", values: [subnet_id] } ]
  route_table_id = String.new
  data = client.describe_route_tables(filters: filters)
  data[:route_tables][0][:associations].each do |route|
    route_table_id = (route[:route_table_id])
    # A subnet can only be associated to one route table, so we can break as soon as we assign the first route table (the rest will be duplicates)
    break
  end
  return route_table_id
end

def route_tables_assoc_for_subnet(client, subnet_id)
  filters = [ { name: "association.subnet-id", values: [subnet_id] } ]
  route_table_association_id = String.new
  data = client.describe_route_tables(filters: filters)
  data[:route_tables][0][:associations].each do |route|
    route_table_association_id = (route[:route_table_association_id])
    # A subnet can only be associated to one route table, so we can break as soon as we assign the first route table assoc (the rest will be duplicates)
    break
  end
  return route_table_association_id
end


def internet_gateway_ids_for_vpc(client)
    data = client.describe_internet_gateways()
    data.internet_gateways.map { |ng| ng.internet_gateway_id }.sort
end

def vpc_ids(client)
    data = client.describe_vpcs()
    data.vpcs.map { |vpc| vpc.vpc_id }.sort
end

#**********Methods to get data from tf state files****************

def nat_gateway_ids_from_terraform_state(statefile)
  str = File.read(statefile)
  data = JSON.parse(str)
  list = data["resources"]
  nat_gateway = list.filter { |m| m["name"] == "private_nat_gateway" }.first
  nat_gateway["instances"].map { |ng| ng.dig("attributes", "nat_gateway_id") }.sort
end

def subnet_ids_from_terraform_state(statefile)
  begin
    str = File.read(statefile)
    data = JSON.parse(str)
    subnets_ids_public = data['outputs']['external_subnets_ids']['value']
    subnets_ids_pvt = data['outputs']['internal_subnets_ids']['value']
    subnets_ids = subnets_ids_public | subnets_ids_pvt
    return subnets_ids
  rescue => e
  end
end

def route_table_ids_from_terraform_state(statefile)
  begin
    str = File.read(statefile)
    data = JSON.parse(str)
    route_table_ids_public = data['outputs']['private_route_tables']['value']
    route_table_ids_pvt = data['outputs']['public_route_tables']['value']
    route_table_ids = route_table_ids_public | route_table_ids_pvt
    return route_table_ids
  rescue => e
  end
end


def route_table_associations_from_terraform_state(statefile)
  begin

    route_table_association_pvt_list = []
    route_table_association_pub_list = []
    str = File.read(statefile)
    data = JSON.parse(str)
    list = data["resources"]
    route_table_association_pvt = list.filter { |m| m["type"] == "aws_route_table_association" }[3] # The private route tbl assoc are in iteration 3 
    route_table_association_pub = list.filter { |m| m["type"] == "aws_route_table_association" }[4] # The private route tbl assoc are in iteration 4 
    route_table_association_pvt_list = route_table_association_pvt["instances"].map { |route_tbl_assoc| route_tbl_assoc.dig("attributes", "id") }.sort 
    route_table_association_pub_list = route_table_association_pub["instances"].map { |route_tbl_assoc| route_tbl_assoc.dig("attributes", "id") }.sort 
    return route_table_association_pvt_list | route_table_association_pub_list # Add the public route tbl assoc (in iteration 2) to the private ones before returning

  rescue => e
  end
end


def internet_gateway_ids_from_terraform_state(statefile)
    str = File.read(statefile)
    data = JSON.parse(str)
    list = data["resources"]
    nat_gateway = list.filter { |m| m["name"] == "public_internet_gateway" }.first
    nat_gateway["instances"].map { |ng| ng.dig("attributes", "gateway_id") }.sort
end


def get_state_vpc_names_from_s3key(s3)

  s3_state_bucket_keys = s3.bucket("cloud-platform-terraform-state").objects(prefix:'cloud-platform-network', delimiter: '').collect(&:"key")

  keys = []
  vpc_names = []
  s3_state_bucket_keys.each { |vpc_name| keys << vpc_name.delete(' ') }
  
  keys.each do |key|
    key_split = key.split('/')
    vpc_names.push(key_split[1])
  end

  return vpc_names

end 


def get_vpc_ids_from_aws(client)

  vpc_ids_aws = []

  # Get the whole data for all vpcs 
  data = client.describe_vpcs()

  # Create a file containing the vpc ids only
  File.open("output-files/vpc_actual_ids.txt","w") do |f|
    f.puts data.vpcs.map { |vpc| vpc.vpc_id }.sort
  end

  File.open('output-files/vpc_actual_ids.txt').each { |vpc| vpc_ids_aws << vpc.strip }

  #vpc_actual_ids.shift(1)
  return vpc_ids_aws

end 

# all the state files for each vpc 
def download_state_files(s3)

  #Iterate each state file for each vpc ( by name ) to get the bucket key containing the vpc name
  s3_keys_list = []
  s3_keys_list = s3.bucket("cloud-platform-terraform-state").objects(prefix:'cloud-platform-network/', delimiter: '').collect(&:key) 
  s3_keys_list.drop(1).each do |each_key|
      begin
          #extract the name from the key
          each_key_list = each_key.split('/')
          bucket_name = "cloud-platform-terraform-state"
          statefile_name_output = @state_file_path_local+"/vpc-network-"+each_key_list[1]+".tfstate"
          download_state_from_s3(s3, bucket_name, each_key, statefile_name_output)
      rescue => e 
      end
  end
end


# The s3 key for the network state contains the vpc name. We therefore need to dynamically fetch each name in the state
# and iterate through them to get the corresponding vpc id and vpc name. The state file can then be downloaded for each vpc and finally getting vpc id
def get_vpc_ids_with_names_from_state(s3)

  vpc_ids_with_names_in_state = []
  
  #Iterate each state file for each vpc ( by name ) and get the corresponding vpc ids
  get_state_vpc_names_from_s3key(s3).each do |vpc_name_in_key|
    begin
      str = File.read(@state_file_path_local+"/vpc-network-"+vpc_name_in_key+".tfstate")
      data = JSON.parse(str)
      vpc_id_from_statefile = data['outputs']['vpc_id']['value']
      vpc_name_from_statefile = data['outputs']['vpc_name']['value']
      vpc_ids_with_names_in_state.push(vpc_id_from_statefile.strip+'|'+vpc_name_from_statefile)
    rescue => e
    end
  end

  return vpc_ids_with_names_in_state

end


def download_state_from_s3(s3, bucket_name, key, statefile_path)
  # Loop through all the dynamically fetched vpc names and download the network state file from s3
  obj = s3.bucket(bucket_name).object(key)
  obj.get(response_target: statefile_path)
end

s3 = Aws::S3::Resource.new(region:'eu-west-1', profile: ENV["AWS_PROFILE"])

#binding.pry
ec2 = Aws::EC2::Client.new(region:'eu-west-2', profile: ENV["AWS_PROFILE"])

download_state_files(s3)

vpc_ids_from_aws = get_vpc_ids_from_aws(ec2)
vpc_ids_with_names_from_state = get_vpc_ids_with_names_from_state(s3)
vpc_ids_from_state = []

vpc_ids_with_names_from_state.each do |vpc_id_with_name|
  each_vpc_id_with_name = vpc_id_with_name.split('|')
  vpc_ids_from_state.push(each_vpc_id_with_name[0])
end

# combine both the aws vpc ids with those fetched from the state
vpc_ids_all = vpc_ids_from_aws | vpc_ids_from_state

# remove any duplicates from the combined vpc ids. The end array will only contain the stateless vpc ids
vpc_ids_stateless = vpc_ids_all.uniq


###########REPORT STATELESS RESOURCES######################

def send_slack_notification(slack_token, message)
  notifier = Slack::Notifier.new "https://hooks.slack.com/services/T02DYEB3A/"+slack_token do
    defaults channel: "#ecr-scan-test-1",username: "notifier"
  end
  notifier.ping message
end

#******** Compare the natgateway ids **********************


def report_stateless_natgateways(ec2, vpc_ids_with_names_from_state)
  vpc_ids_with_names_from_state.each do |vpc_id_with_name|
    each_vpc_id_with_name = vpc_id_with_name.split('|')
    vpc_id = each_vpc_id_with_name[0]
    vpc_name = each_vpc_id_with_name[1]
    compare_and_report_data(nat_gateway_ids_for_vpc(ec2, vpc_id), nat_gateway_ids_from_terraform_state(@state_file_path_local+"/vpc-network-"+vpc_name+".tfstate"), vpc_name, "nat-gateways")
  end
end

def report_stateless_subnets(ec2, vpc_ids_with_names_from_state)
  vpc_ids_with_names_from_state.each do |vpc_id_with_name|
    each_vpc_id_with_name = vpc_id_with_name.split('|')
    vpc_id = each_vpc_id_with_name[0]
    vpc_name = each_vpc_id_with_name[1]
    compare_and_report_data(subnets_ids_for_vpc(ec2, vpc_id), subnet_ids_from_terraform_state(@state_file_path_local+"/vpc-network-"+vpc_name+".tfstate"), vpc_name, "subnets")
  end
end

def report_stateless_route_tables(ec2, vpc_ids_with_names_from_state)
  begin
    vpc_ids_with_names_from_state.each do |vpc_id_with_name|
      each_vpc_id_with_name = vpc_id_with_name.split('|')
      vpc_id = each_vpc_id_with_name[0]
      vpc_name = each_vpc_id_with_name[1]
      subnets_ids_for_vpc_arr = subnets_ids_for_vpc(ec2, vpc_id)
      route_tables_ids_arr = []
      subnets_ids_for_vpc_arr.each do |subnet_id|
        route_tables_ids_arr.push(route_tables_for_subnet(ec2, subnet_id).strip)
      end
      # each of the public subnets are associated to the same route table. The public route table will be duplicated for every public subnet. So we can remove these. 
      route_tables_ids_arr = route_tables_ids_arr.uniq
      compare_and_report_data(route_tables_ids_arr, route_table_ids_from_terraform_state(@state_file_path_local+"/vpc-network-"+vpc_name+".tfstate"), vpc_name, "route-tables")
    end
  rescue => e
  end
end


def report_stateless_route_tables_assoc(ec2, vpc_ids_with_names_from_state)
  begin
    vpc_ids_with_names_from_state.each do |vpc_id_with_name|
      each_vpc_id_with_name = vpc_id_with_name.split('|')
      vpc_id = each_vpc_id_with_name[0]
      vpc_name = each_vpc_id_with_name[1]
      subnets_ids_for_vpc_arr = subnets_ids_for_vpc(ec2, vpc_id)
      route_tables_ids_assoc_arr = []
      subnets_ids_for_vpc_arr.each do |subnet_id|
        route_tables_ids_assoc_arr.push(route_tables_assoc_for_subnet(ec2, subnet_id).strip)
      end
      compare_and_report_data(route_tables_ids_assoc_arr, route_table_associations_from_terraform_state(@state_file_path_local+"/vpc-network-"+vpc_name+".tfstate"), vpc_name, "route-tables")
    end
  rescue => e
  end
end


def compare_and_report_data(aws_data, state_data, vpc_name, resource)
  begin
    state_data.collect { |e| e.strip }
    aws_data.collect { |e| e.strip }
    state_data.sort
    aws_data.sort

    if state_data.to_set != aws_data.to_set
      state_data_str = state_data.join(" | ")
      aws_data_str = aws_data.join(" | ")

      pp 'VPC: '+vpc_name+' : some '+resource+' do not match between the state and actual'
      pp 'STATE:'
      pp state_data_str
      pp 'ACTUAL:'
      pp aws_data_str

      send_slack_notification(@slack_token, 'VPC: '+vpc_name+' | RESOURCE: '+resource+' | STATE: ('+state_data_str+') | ACTUAL: ('+aws_data_str+')')
    end
  rescue => e
  end
end



#pp route_tables_assoc_for_subnet(ec2, "subnet-05457126ff452defb")


#pp route_tables_for_subnet(ec2, "subnet-04aa61fd2c67cc729")

#binding.pry
report_stateless_natgateways(ec2,vpc_ids_with_names_from_state)
report_stateless_subnets(ec2,vpc_ids_with_names_from_state)
report_stateless_route_tables(ec2, vpc_ids_with_names_from_state)
#report_stateless_route_tables_assoc(ec2,vpc_ids_with_names_from_state)
#pp subnet_ids_from_terraform_state(@state_file_path_local+"/vpc-network-iawan-test.tfstate")

#pp nat_gateway_ids_for_vpc(ec2, "vpc-0c16457fd570a1f0b")
#pp nat_gateway_ids_from_terraform_state(@state_file_path_local+"/vpc-network-iawan-test.tfstate")

#********Get the internet gateway*************************************************

#pp internet_gateway_ids_for_vpc(ec2)
#pp internet_gateway_ids_from_terraform_state("terraform.tfstate")

#********Get the vpc ids***********************
#pp vpc_ids(ec2)

#*********Get the subnets*******************

#pp subnets_ids_for_vpc(ec2, "vpc-0c16457fd570a1f0b")


#****Get the route table ids for each subnet*******

#pp route_tables_for_subnet(ec2, "subnet-0386053fb92e69994")
#route_tables_for_subnet(ec2, "subnet-05fe20e709ed69201")

