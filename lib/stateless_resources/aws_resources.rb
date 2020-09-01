module StatelessResources
  class AwsResources
    attr_reader :s3client, :ec2client

    def initialize(params)
      @s3client = params.fetch(:s3client)
      @ec2client = params.fetch(:ec2client)
    end

    def vpc_ids
      @_vpc_ids ||= ec2client.describe_vpcs.vpcs.map { |vpc| vpc.vpc_id }.sort
    end

    def nat_gateway_ids
      vpc_ids
        .map { |id| nat_gateway_ids_for_vpc(id) }
        .flatten
        .uniq
        .sort
    end

    private

    def nat_gateway_ids_for_vpc(vpc_id)
      ec2client.describe_nat_gateways(filter: [{name: "vpc-id", values: [vpc_id]}])
        .nat_gateways
        .map(&:nat_gateway_id)
    end
  end
end
