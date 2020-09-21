module OrphanedResources
  class TerraformStateManager < Lister
    attr_reader :s3client, :bucket, :cache_dir

    def initialize(args)
      @s3client = args.fetch(:s3client)
      @bucket = args.fetch(:bucket)
      @cache_dir = args.fetch(:cache_dir)
    end

    def local_statefiles
      @files ||= download_files
    end

    def vpcs
      list = local_statefiles.map { |file|
        data = parse_json(file)
        data.dig("outputs", "vpc_id", "value")
      }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    def nat_gateways
      list = local_statefiles.inject([]) { |ids, file| ids << nat_gateway_ids_from_statefile(file) }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    def subnets
      list = local_statefiles.inject([]) { |ids, file| ids << subnet_ids_from_statefile(file) }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    def route_tables
      list = local_statefiles.inject([]) { |ids, file| ids << route_tables_from_statefile(file) }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    def route_table_associations
      list = local_statefiles.inject([]) { |ids, file| ids << route_table_associations_from_statefile(file) }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    def internet_gateways
      list = local_statefiles.inject([]) { |ids, file| ids << internet_gateways_from_statefile(file) }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    def hosted_zones
      list = local_statefiles.inject([]) { |ids, file| ids << hosted_zones_from_statefile(file) }
      clean_list(list).map { |id| ResourceTuple.new(id: id) }
    end

    private

    def internet_gateways_from_statefile(file)
      json_resources(file)
        .find_all { |h| h["name"] == "public_internet_gateway" }
        .map { |h| h["instances"] }
        .flatten
        .map { |h| h.dig("attributes", "gateway_id") }
    end

    def route_tables_from_statefile(file)
      data = parse_json(file)
      data.dig("outputs", "private_route_tables", "value").to_a + data.dig("outputs", "public_route_tables", "value").to_a
    end

    def route_table_associations_from_statefile(file)
      json_resources(file)
        .find_all { |res| res["type"] == "aws_route_table_association" }
        .map { |res| res["instances"] }
        .flatten
        .map { |res| res.dig("attributes", "id") }
    end

    def subnet_ids_from_statefile(file)
      data = parse_json(file)
      data.dig("outputs", "external_subnets_ids", "value").to_a + data.dig("outputs", "internal_subnets_ids", "value").to_a
    end

    def nat_gateway_ids_from_statefile(file)
      json_resources(file)
        .find_all { |hash| hash["name"] = "private_nat_gateway" }
        .map { |hash| hash["instances"] }
        .flatten
        .map { |hash| hash.dig("attributes", "nat_gateway_id") }
        .compact
    end

    def hosted_zones_from_statefile(file)
      json_resources(file)
        .find_all { |res| res["type"] == "aws_route53_zone" }
        .map { |zone| zone["instances"] }
        .flatten
        .map { |inst| inst.dig("attributes", "name") }
    end

    def download_files
      s3client.bucket(bucket)
        .objects
        .collect(&:key)
        .find_all { |key| key =~ /terraform.tfstate$/ }
        .map { |key| download_file(key) }
    end

    def download_file(key)
      outfile = File.join(cache_dir, key)
      d = File.dirname(outfile)
      FileUtils.mkdir_p(d) unless Dir.exist?(d)
      s3client.bucket(bucket).object(key).get(response_target: outfile) unless FileTest.exists?(outfile)
      outfile
    end

    def json_resources(file)
      data = parse_json(file)
      data.fetch("resources", [])
    end

    def parse_json(file)
      JSON.parse(File.read(file))
    rescue JSON::ParserError
      {}
    end
  end
end
