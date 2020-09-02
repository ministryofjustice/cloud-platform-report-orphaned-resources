module OrphanedResources
  class AwsResources < Lister
    attr_reader :s3client, :ec2client, :route53client

    def initialize(params)
      @s3client = params.fetch(:s3client)
      @ec2client = params.fetch(:ec2client)
      @route53client = params.fetch(:route53client)
    end

    def vpc_ids
      @_vpc_ids ||= ec2client.describe_vpcs.vpcs.map { |vpc| vpc.vpc_id }.sort
    end

    def nat_gateway_ids
      list = vpc_ids.map { |id| nat_gateway_ids_for_vpc(id) }
      clean_list(list)
    end

    def subnets
      list = vpc_ids.map { |id| subnet_ids(id) }
      clean_list(list)
    end

    def route_tables
      list = subnets.map { |id| route_tables_for_subnet(id) }
      clean_list(list)
    end

    def route_table_associations
      list = subnets.map { |id| route_table_associations_for_subnet(id) }
      clean_list(list)
    end

    def internet_gateways
      list = ec2client.describe_internet_gateways
        .internet_gateways
        .map(&:internet_gateway_id)
      clean_list(list)
    end

    # This includes all hosted zones belonging to namespaces in live-1
    def hosted_zones
      list = route53client.list_hosted_zones .hosted_zones.map(&:name)
      clean_list(list)
    end

    private

    def route_tables_for_subnet(subnet_id)
      route_table_association_objects(subnet_id)
        .map(&:route_table_id)
    end

    def route_table_associations_for_subnet(subnet_id)
      route_table_association_objects(subnet_id)
        .map { |hash| hash["route_table_association_id"] }
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
        .map(&:subnet_id)
        .sort
    end

    def nat_gateway_ids_for_vpc(vpc_id)
      ec2client.describe_nat_gateways(filter: [{name: "vpc-id", values: [vpc_id]}])
        .nat_gateways
        .map(&:nat_gateway_id)
    end
  end
end
