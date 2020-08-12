# cloud-platform-report-stateless-resources

Overview 

This respository contains 'Ruby' code, which upon execution will report on the stateless resources in AWS.

The scope of what is within a 'state' is confined to the 'terraform state' persistent in the ```cloud-platform-terrform-state``` bucket and mainly for
the infrastructure resources and terraform state files that reside under the keys ```cloud-platform``` and ```cloud-platform-network```. 

The resource reporting is done for each VPC. 

The reporting medium is slack. The slack token needs to be set as an environment variable with the name ```SLACK_TOKEN```

There are two key scripts as follows:

```
(1) report-stateless-cloud-platform-network.rb
(2) report-stateless-cloud-platform.rb
```

At the bottom of the script ```report-stateless-cloud-platform-network.rb``` you can choose which resources you would like to report for by ensuring to uncomment the report method for that resource. This needs to be improved to make report selecting more intuitive. 

The current reporting methods are as follows:

```sh
report_stateless_natgateways(ec2,vpc_ids_with_names_from_state)
report_stateless_subnets(ec2,vpc_ids_with_names_from_state)
report_stateless_route_tables(ec2, vpc_ids_with_names_from_state)
```

The ```report-stateless-cloud-platform.rb``` scripts reports on the ```route 53 hosted zones``` 

Requirements:

Below are the followng requirements

(1) Ensure your AWS credentials are set to the environment from which you want to execute the scripts. The AWS profile should be set under the profile name ```moj-cp``` e.g export AWS_PROFILE=moj-cp

(2) As reporting is done on slack ensure you have a ```SLACK_TOKEN``` environmment variable set e.g ```export SLACK_TOKEN=YOUR_TOKEN```

(2) Ensure Ruby 2.7.1 or greater is installed on the environment.

(3) Run ```bundle install`` from the root folde of the repository to fetch the required gems

Modules

Key methods such as getting data from AWS and the state file are independent and reside in modules, under the ```modules```folder. 
Currently only the ```report-stateless-cloud-platform.rb``` script is making use of the modules and the  ```report-stateless-cloud-platform-network.rb``` script is yet to be re-factored for it to utilise the modules. Once re-factored it maybe more efficient to combine the Ruby scripts into one single script. 

