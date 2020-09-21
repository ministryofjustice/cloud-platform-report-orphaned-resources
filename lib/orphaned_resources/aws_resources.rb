module OrphanedResources
  class AwsResources < Lister
    attr_reader :s3client, :ec2client, :route53client

    VPC_HOME = "https://eu-west-2.console.aws.amazon.com/vpc/home?region=eu-west-2"
    EC2_HOME = "https://eu-west-2.console.aws.amazon.com/ec2/v2/home?region=eu-west-2"

    NAT_GATEWAY_URL = VPC_HOME + "#NatGatewayDetails:natGatewayId="
    INTERNET_GATEWAY_URL = VPC_HOME + "#InternetGateway:internetGatewayId="
    ROUTE_TABLE_URL = VPC_HOME + "#RouteTables:search="
    SUBNET_URL = VPC_HOME + "#subnets:search="
    VPC_URL = VPC_HOME + "#VpcDetails:VpcId="

    def initialize(params)
      @s3client = params.fetch(:s3client)
      @ec2client = params.fetch(:ec2client)
      @route53client = params.fetch(:route53client)
    end

    def vpcs
      @_vpc_ids ||= ec2client.describe_vpcs.vpcs.map { |vpc|
        url = VPC_URL + vpc.vpc_id
        ResourceTuple.new(id: vpc.vpc_id, aws_console_url: url).add_cluster_tag(vpc)
      }.sort
    end

    def nat_gateways
      list = vpcs.map { |vpc| nat_gateway_ids_for_vpc(vpc.id) }
      clean_list(list)
    end

    def subnets
      @_subnet_ids ||= begin
                      list = vpcs.map { |vpc| subnet_ids(vpc.id) }
                      clean_list(list)
                    end
    end

    def route_tables
      list = subnets.map { |sn| route_tables_for_subnet(sn.id) }
      clean_list(list)
    end

    def route_table_associations
      list = subnets.map { |sn| route_table_associations_for_subnet(sn.id) }
      clean_list(list)
    end

    def internet_gateways
      list = ec2client.describe_internet_gateways
        .internet_gateways
        .map { |igw|
          url = INTERNET_GATEWAY_URL + igw.internet_gateway_id
          ResourceTuple.new(id: igw.internet_gateway_id, aws_console_url: url).add_cluster_tag(igw)
        }
      clean_list(list)
    end

    # This includes all hosted zones belonging to namespaces in live-1
    def hosted_zones
      list = route53client
        .list_hosted_zones
        .hosted_zones
        .map { |z|
          HostedZoneTuple.new(
            id: z.name.sub(/\.$/, ""), # trim trailing '.'
            hosted_zone_id: z.id
          )
        }
      clean_list(list)
    end

    private

    def route_tables_for_subnet(subnet_id)
      route_table_association_objects(subnet_id)
        .map { |rt|
          url = ROUTE_TABLE_URL + rt.route_table_id
          ResourceTuple.new(id: rt.route_table_id, aws_console_url: url)
        }
    end

    def route_table_associations_for_subnet(subnet_id)
      route_table_association_objects(subnet_id)
        .map { |rta| ResourceTuple.new(id: rta.route_table_association_id) }
    end

    def route_table_association_objects(subnet_id)
      ec2client.describe_route_tables(filters: [{name: "association.subnet-id", values: [subnet_id]}])
        .route_tables
        .map(&:associations)
        .flatten
    end

    def subnet_ids(vpc_id)
      ec2client.describe_subnets(filters: [{name: "vpc-id", values: [vpc_id]}])
        .subnets
        .map { |sn|
        url = SUBNET_URL + sn.subnet_id
        ResourceTuple.new(id: sn.subnet_id, aws_console_url: url).add_cluster_tag(sn)
      }
        .sort
    end

    def nat_gateway_ids_for_vpc(vpc_id)
      ec2client.describe_nat_gateways(filter: [{name: "vpc-id", values: [vpc_id]}])
        .nat_gateways
        .map { |ngw|
          url = NAT_GATEWAY_URL + ngw.nat_gateway_id
          ResourceTuple.new(id: ngw.nat_gateway_id, aws_console_url: url).add_cluster_tag(ngw)
        }
    end
  end
end
