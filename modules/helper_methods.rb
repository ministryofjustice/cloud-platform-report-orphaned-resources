module Helper


    def send_slack_notification(slack_token, message)
        notifier = Slack::Notifier.new "https://hooks.slack.com/services/T02DYEB3A/"+slack_token do
            defaults channel: "#ecr-scan-test-1",username: "notifier"
        end
        notifier.ping message
    end

    # method to filter out any dns that are suffixed with cloud-platform
    def filter_host_zones(filter, data)
        host_zones_filtered = []
        host_zones = data
        host_zones.each do |host_zone|
        host_zones_arr = host_zone.split('.')
            if host_zones_arr[1] == 'cloud-platform'
                host_zones_filtered.push(host_zone)
            end
        end
        return host_zones_filtered
    end


    


    #******** Compare two sets of arrays and send to slack **********************

    def compare_and_report_data_host_zones(aws_data, state_data, resource)
        begin
            aws_data = filter_host_zones('cloud-platform', aws_data)
            state_data.collect { |e| e.strip }
            aws_data.collect { |e| e.strip }
            state_data.sort
            aws_data.sort

            state_data_str = state_data.join(" | ")
            aws_data_str = aws_data.join(" | ")
            pp 'Comparison of resource '+resource+' between the state and actual'
            pp 'STATE:'
            pp state_data_str
            pp 'ACTUAL:'
            pp aws_data_str
            send_slack_notification(ENV["SLACK_TOKEN"], '| RESOURCE: '+resource+' | STATE: ('+state_data_str+') | ACTUAL: ('+aws_data_str+')')
        rescue => e 
        end
    end

  
    def download_state_from_s3(s3, bucket_name, key, statefile_full_path)
        # Loop through all the dynamically fetched vpc names and download the network state file from s3
        obj = s3.bucket(bucket_name).object(key)
        obj.get(response_target: statefile_full_path)
    end
    
    # Download all the state files for each vpc 
    def download_state_files(s3, bucket_name, prefix_folder, statefile_path)
        #Iterate each state file for each vpc ( by name ) to get the bucket key containing the vpc name
        s3_keys_list = []
        s3_keys_list = s3.bucket(bucket_name).objects(prefix:prefix_folder+'/', delimiter: '').collect(&:key) 
        s3_keys_list.drop(1).each do |each_key| #skip the first as this has no key
            begin
                #extract the name from the key
                each_key_list = each_key.split('/')
                statefile_name_output = statefile_path+"/"+prefix_folder+"-"+each_key_list[1]+".tfstate"
                download_state_from_s3(s3, bucket_name, each_key, statefile_name_output)
            rescue => e 
            end
        end
    end
end