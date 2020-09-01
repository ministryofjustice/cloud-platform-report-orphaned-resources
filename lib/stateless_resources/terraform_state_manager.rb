module StatelessResources
  class TerraformStateManager
    attr_reader :s3client, :bucket, :prefix, :dir

    def initialize(args)
      @s3client = args.fetch(:s3client)
      @bucket = args.fetch(:bucket)
      @prefix = args.fetch(:prefix)
      @dir = args.fetch(:dir)
    end

    def local_statefiles
      @files ||= download_files
    end

    def vpc_ids
      local_statefiles.map { |file|
        data = JSON.parse(File.read(file))
        data.dig("outputs", "vpc_id", "value")
      }.compact
    end

    def nat_gateway_ids
      list = local_statefiles.inject([]) { |ids, file| ids << nat_gateway_ids_from_statefile(file) }
      clean_list(list)
    end

    def subnets
      list = local_statefiles.inject([]) { |ids, file| ids << subnet_ids_from_statefile(file) }
      clean_list(list)
    end

    private

    def subnet_ids_from_statefile(file)
      data = JSON.parse(File.read(file))
      data.dig("outputs", "external_subnets_ids", "value").to_a + data.dig("outputs", "internal_subnets_ids", "value").to_a
    end

    def nat_gateway_ids_from_statefile(file)
      JSON.parse(File.read(file))
        .fetch("resources")
        .find_all { |hash| hash["name"] = "private_nat_gateway" }
        .map { |hash| hash["instances"] }
        .flatten
        .map { |hash| hash.dig("attributes", "nat_gateway_id") }
        .compact
    end

    def download_files
      keys = s3client.bucket("cloud-platform-terraform-state").objects(prefix: "cloud-platform-network/", delimiter: "").collect(&:key)

      keys.map do |key|
        name = key.split("/")[1] # e.g. "cloud-platform-network/live-1/terraform.tfstate" -> "live-1"
        outfile = "#{dir}/#{name}.tfstate"
        unless FileTest.exists?(outfile)
          s3client.bucket(bucket).object(key).get(response_target: outfile)
        end
        outfile
      end
    end

    def clean_list(list)
      list
        .flatten
        .uniq
        .reject(&:nil?)
        .reject(&:empty?)
        .sort
    end
  end
end
