

module State

    def route53_zones_from_terraform_state(statefile)
        hosted_zones_zones_arr = []
        Find.find(statefile) do |file|
            hosted_zones_from_state = []
            file_arr = file.split('.')
            if file_arr.count() == 2 # folder name is returned as the first element, so we are only concerned with any file names that contain '.'
                begin
                    file_name = file.to_s
                    str = File.read(file_name)
                    data = JSON.parse(str)
                    list = data["resources"]
                    zone_name = list.filter { |m| m["type"] == "aws_route53_zone" }.first
                    hosted_zones_from_state.push(zone_name["instances"].map { |zone| zone.dig("attributes", "name") }.sort[0])
                rescue => e
                end
            end 
            hosted_zones_from_state.each do |each_host_zone|
                hosted_zones_zones_arr.push(each_host_zone)
            end
        end
        return hosted_zones_zones_arr.compact
    end

end