module StatelessResources
  class AwsResources
    attr_reader :s3client, :ec2client

    def initialize(params)
      @s3client = params.fetch(:s3client)
      @ec2client = params.fetch(:ec2client)
    end

    def vpc_ids
      ec2client.describe_vpcs.vpcs.map { |vpc| vpc.vpc_id }.sort
    end
  end
end
